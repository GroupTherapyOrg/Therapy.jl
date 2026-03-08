# IslandTransform.jl - AST-level @island body transformation for Leptos-style compilation
#
# Transforms an island function body expression into:
# 1. A hydrate function (cursor walk, event attachment, bindings)
# 2. Extracted handler functions (signal reads/writes)
# 3. Signal allocation (WasmGlobal indices)
#
# Design: ralph_loops/research/therapy/compiled-element-protocol.md (THERAPY-3103)
# Pipeline: ralph_loops/research/therapy/compiled-signals-protocol.md (THERAPY-3104)
# Implementation: THERAPY-3111

using WasmTarget: WasmGlobal

# ─── Element Name Registry ───

const HYDRATE_ELEMENT_NAMES = Set{Symbol}([
    :Div, :Span, :Button, :P, :Input, :Form, :A, :H1, :H2, :H3,
    :H4, :H5, :H6, :Ul, :Ol, :Li, :Table, :Tr, :Td, :Th,
    :Img, :Br, :Hr, :Section, :Article, :Header, :Footer,
    :Nav, :Main, :Aside, :Label, :Textarea, :Select, :Option,
    :Details, :Summary, :Pre, :Code, :Strong, :Em, :Small,
    # SVG elements (needed for ThemeToggle and other icon-using components)
    :Svg, :Path, :Circle, :Rect, :Line, :G,
])

# ─── Event Prop Mapping ───

const HYDRATE_EVENT_MAP = Dict{Symbol, Int32}(
    :on_click        => Int32(0),   # EVENT_CLICK
    :on_input        => Int32(1),   # EVENT_INPUT
    :on_change       => Int32(2),   # EVENT_CHANGE
    :on_keydown      => Int32(3),   # EVENT_KEYDOWN
    :on_keyup        => Int32(4),   # EVENT_KEYUP
    :on_pointerdown  => Int32(5),   # EVENT_POINTERDOWN
    :on_pointermove  => Int32(6),   # EVENT_POINTERMOVE
    :on_pointerup    => Int32(7),   # EVENT_POINTERUP
    :on_focus        => Int32(8),   # EVENT_FOCUS
    :on_blur         => Int32(9),   # EVENT_BLUR
    :on_submit       => Int32(10),  # EVENT_SUBMIT
    :on_dblclick     => Int32(11),  # EVENT_DBLCLICK
    :on_contextmenu  => Int32(12),  # EVENT_CONTEXTMENU
    :on_pointerenter => Int32(13),  # EVENT_POINTERENTER
    :on_pointerleave => Int32(14),  # EVENT_POINTERLEAVE
    :on_dismiss      => Int32(15),  # EVENT_DISMISS (no DOM binding — DismissableLayer only)
)

# ─── Transform Context ───

mutable struct IslandTransformContext
    signal_alloc::SignalAllocator
    getter_map::Dict{Symbol, Int32}   # e.g., :count => 1
    setter_map::Dict{Symbol, Int32}   # e.g., :set_count => 1
    handler_count::Int
    handler_bodies::Vector{Expr}
    el_count::Int
    potential_vars::Dict{Symbol, Any} # collected in pass 1b, not yet allocated
    var_map::Dict{Symbol, Int32}      # promoted vars with global indices (allocated on demand)
    in_handler::Bool                  # true when rewriting handler closure bodies
    context_map::Dict{Symbol, Tuple{Int32, Symbol}}  # context key => (signal_global_idx, getter_symbol)
end

IslandTransformContext() = IslandTransformContext(
    SignalAllocator(),
    Dict{Symbol, Int32}(),
    Dict{Symbol, Int32}(),
    0, Expr[], 0,
    Dict{Symbol, Any}(),
    Dict{Symbol, Int32}(),
    false,
    Dict{Symbol, Tuple{Int32, Symbol}}()
)

# ─── Transform Result ───

"""
    IslandTransformResult

Result of transforming an @island body. Contains all info needed to build an
IslandCompilationSpec via build_island_spec().
"""
struct IslandTransformResult
    signal_alloc::SignalAllocator
    getter_map::Dict{Symbol, Int32}
    setter_map::Dict{Symbol, Int32}
    hydrate_stmts::Vector{Any}
    handler_bodies::Vector{Expr}
    var_map::Dict{Symbol, Int32}
    context_map::Dict{Symbol, Tuple{Int32, Symbol}}  # context key => (signal_global_idx, getter_symbol)
end

# ─── Main Entry Point ───

"""
    transform_island_body(body::Expr) -> IslandTransformResult

Transform an @island function body into hydration instructions.

Two-pass approach:
1. Scan for create_signal calls → allocate globals, build name maps
2. Transform element tree → hydration open/close pairs, event attachment, bindings
"""
function transform_island_body(body::Expr)::IslandTransformResult
    ctx = IslandTransformContext()

    stmts = body.head === :block ? body.args : Any[body]

    # Pass 1: Scan create_signal calls
    for stmt in stmts
        stmt isa LineNumberNode && continue
        _scan_create_signal!(ctx, stmt)
    end

    # Pass 1b: Scan variable assignments (e.g., timer_id = Int32(0))
    # These become Wasm globals shared across handlers (no DOM bindings).
    for stmt in stmts
        stmt isa LineNumberNode && continue
        _scan_var_assign!(ctx, stmt)
    end

    # Pass 1c: Scan provide_context calls to map context keys to signal globals
    for stmt in stmts
        stmt isa LineNumberNode && continue
        _scan_provide_context!(ctx, stmt)
    end

    # Pass 2: Transform element tree
    hydrate_stmts = Any[]
    for stmt in stmts
        stmt isa LineNumberNode && continue
        if _is_create_signal_assign(stmt)
            # Signal globals allocated in pass 1; emit runtime init if needed
            _emit_runtime_signal_init!(hydrate_stmts, stmt, ctx)
            continue
        end
        if _is_provide_context_call(stmt)
            # provide_context handled in pass 1c; skip in hydration output
            # (context is a compile-time mapping, no runtime action needed in Wasm)
            continue
        end
        _transform_to_hydrate!(hydrate_stmts, stmt, ctx)
    end

    return IslandTransformResult(
        ctx.signal_alloc,
        ctx.getter_map,
        ctx.setter_map,
        hydrate_stmts,
        ctx.handler_bodies,
        ctx.var_map,
        ctx.context_map
    )
end

# ─── Pass 1: Signal Scanning ───

"""Detect `count, set_count = create_signal(x)` or `count, set_count = use_context_signal(:key, x)` pattern."""
function _is_create_signal_assign(expr)
    expr isa Expr || return false
    expr.head === :(=) || return false
    lhs, rhs = expr.args[1], expr.args[2]
    lhs isa Expr && lhs.head === :tuple && length(lhs.args) == 2 || return false
    rhs isa Expr && rhs.head === :call || return false
    return rhs.args[1] === :create_signal || rhs.args[1] === :use_context_signal
end

function _scan_create_signal!(ctx, expr)
    _is_create_signal_assign(expr) || return

    getter = expr.args[1].args[1]::Symbol
    setter = expr.args[1].args[2]::Symbol
    rhs = expr.args[2]

    # For use_context_signal(:key, initial), the initial value is the 3rd arg
    # For create_signal(initial), the initial value is the 2nd arg
    if rhs.args[1] === :use_context_signal
        initial_expr = length(rhs.args) >= 3 ? rhs.args[3] : Int32(0)
    else
        initial_expr = rhs.args[2]
    end

    initial = _extract_initial_value(initial_expr)
    idx = allocate_signal!(ctx.signal_alloc, Int32, initial)
    ctx.getter_map[getter] = idx
    ctx.setter_map[setter] = idx
end

# ─── Pass 1b: Variable Assignment Scanning ───

"""Detect `timer_id = Int32(0)` or `timer_id = literal` — non-signal top-level assignment."""
function _is_var_assign(expr)
    expr isa Expr || return false
    expr.head === :(=) || return false
    lhs = expr.args[1]
    lhs isa Symbol || return false
    # Not a tuple destructure (create_signal pattern)
    return true
end

"""
Known import stub function names available in compiled island bodies.
Includes both `compiled_` prefixed names and their natural aliases from the eval module.
"""
const COMPILABLE_FUNCTION_NAMES = Set{Symbol}([
    # Natural names (aliases in eval module for island bodies)
    :storage_get_i32, :storage_set_i32, :set_dark_mode, :get_is_dark_mode,
    :set_timeout, :clear_timeout,
    :get_target_value_f64, :get_target_checked,
    :get_key_code, :get_modifiers,
    :get_pointer_x, :get_pointer_y, :get_pointer_id,
    # Phase 6: Modal behavior imports (natural names)
    :push_escape_handler, :pop_escape_handler,
    :lock_scroll, :unlock_scroll,
    :store_active_element, :restore_active_element,
    :prevent_default,
    # Phase 7: Focus trap cycling
    :cycle_focus_in_current_target,
    # Phase 7: Pointer/geometry imports for Slider drag
    :capture_pointer, :release_pointer,
    :get_pointer_x, :get_pointer_y, :get_pointer_id,
    :get_bounding_rect_x, :get_bounding_rect_w,
    :get_drag_delta_x, :get_drag_delta_y,
    # Style manipulation for Slider/Resizable
    :set_style_percent, :set_style_numeric,
    # T32: Event data index + auto-register descendants
    :get_event_data_index,
    :register_match_descendants, :register_bit_descendants,
    # DOM manipulation (imports 0, 15-16, 95)
    :update_text, :show_element, :hide_element, :get_elements_count,
    # Type constructors
    :Int32, :Float64,
])

"""
Check if an RHS expression is compilable to Wasm (not SSR-only).

Compilable RHS patterns:
- Literals: Int32(x), integer, Bool
- Import stub calls: compiled_*(…) or known natural names (storage_get_i32, etc.)
- Simple arithmetic on compilable sub-expressions

NOT compilable (SSR-only):
- Unknown function calls: apply_theme(), cn(), etc.
- Variable references to SSR-only values: theme, class, etc.
"""
function _is_compilable_rhs(expr)
    # Literals
    expr isa Int32 && return true
    expr isa Integer && return true
    expr isa Bool && return true
    # Symbols — could be loop vars or SSR vars, allow them as they're checked later
    expr isa Symbol && return true
    expr isa Expr || return false
    if expr.head === :call
        fname = expr.args[1]
        # Known compilable function names (import stubs + type constructors)
        if fname isa Symbol
            fname in COMPILABLE_FUNCTION_NAMES && return true
            startswith(string(fname), "compiled_") && return true
        end
        # Arithmetic on compilable sub-expressions
        if fname in (:+, :-, :*, :÷, :%, :<, :>, :(==), :(!=), :(<=), :(>=))
            return all(_is_compilable_rhs(a) for a in expr.args[2:end])
        end
        # Unknown function call — SSR-only
        return false
    end
    # Allow if/ternary on compilable sub-expressions
    if expr.head === :if
        return all(_is_compilable_rhs(a) for a in expr.args if !(a isa LineNumberNode))
    end
    return false
end

function _scan_var_assign!(ctx, expr)
    _is_var_assign(expr) || return
    # Skip create_signal assignments (already handled in pass 1)
    _is_create_signal_assign(expr) && return

    name = expr.args[1]::Symbol
    initial_expr = expr.args[2]

    # Only collect compilable variables — SSR-only assignments (theme, class, etc.) are skipped
    _is_compilable_rhs(initial_expr) || return

    # Collect as potential variable — will be promoted to global on demand
    # when first referenced inside a handler closure body.
    initial = _extract_initial_value(initial_expr)
    ctx.potential_vars[name] = initial
end

# ─── Pass 1c: Context Scanning ───

"""Detect `provide_context(:key, signal_getter)` call pattern."""
function _is_provide_context_call(expr)
    expr isa Expr || return false
    expr.head === :call || return false
    length(expr.args) >= 3 || return false
    return expr.args[1] === :provide_context
end

"""Scan provide_context(:key, value) calls to map context keys to signal global indices.

Supports two forms:
1. `provide_context(:key, signal_getter)` — single key maps to signal global
2. `provide_context(:key, (getter, setter))` — tuple form, maps key to signal global
"""
function _scan_provide_context!(ctx, expr)
    _is_provide_context_call(expr) || return

    key_expr = expr.args[2]
    value_expr = expr.args[3]

    # Extract the Symbol key (e.g., :dialog_open from QuoteNode(:dialog_open))
    key = nothing
    if key_expr isa QuoteNode && key_expr.value isa Symbol
        key = key_expr.value
    elseif key_expr isa Symbol
        key = key_expr
    end
    key === nothing && return

    # Extract the value — must be a known signal getter or setter
    if value_expr isa Symbol
        if haskey(ctx.getter_map, value_expr)
            # Context key maps to this signal's global index
            ctx.context_map[key] = (ctx.getter_map[value_expr], value_expr)
        elseif haskey(ctx.setter_map, value_expr)
            # Context key maps to this signal's global index (setter)
            ctx.context_map[key] = (ctx.setter_map[value_expr], value_expr)
        end
    elseif value_expr isa Expr && value_expr.head === :tuple && length(value_expr.args) == 2
        # Tuple form: provide_context(:key, (getter, setter))
        getter_sym = value_expr.args[1]
        setter_sym = value_expr.args[2]
        if getter_sym isa Symbol && haskey(ctx.getter_map, getter_sym)
            ctx.context_map[key] = (ctx.getter_map[getter_sym], getter_sym)
        elseif setter_sym isa Symbol && haskey(ctx.setter_map, setter_sym)
            ctx.context_map[key] = (ctx.setter_map[setter_sym], setter_sym)
        end
    end
end

"""Detect `use_context(:key)` call pattern."""
function _is_use_context_call(expr)
    expr isa Expr || return false
    expr.head === :call || return false
    length(expr.args) == 2 || return false
    return expr.args[1] === :use_context
end

"""Extract the Symbol key from a use_context(:key) call."""
function _extract_context_key(expr)
    key_expr = expr.args[2]
    if key_expr isa QuoteNode && key_expr.value isa Symbol
        return key_expr.value
    elseif key_expr isa Symbol
        return key_expr
    end
    return nothing
end

"""
Detect `alias = use_context(:key)` assignment pattern.
This creates a compile-time alias so `alias()` resolves to the context's signal global.
"""
function _is_use_context_assign(expr, ctx)
    expr isa Expr || return false
    expr.head === :(=) || return false
    lhs = expr.args[1]
    lhs isa Symbol || return false
    rhs = expr.args[2]
    _is_use_context_call(rhs) || return false
    key = _extract_context_key(rhs)
    key === nothing && return false
    return haskey(ctx.context_map, key)
end

"""
Handle `alias = use_context(:key)` — create a getter alias in the getter_map
so that `alias()` resolves to the context's signal global read.
"""
function _handle_use_context_assign!(ctx, expr)
    alias = expr.args[1]::Symbol
    rhs = expr.args[2]
    key = _extract_context_key(rhs)::Symbol
    signal_idx, original_sym = ctx.context_map[key]
    # Create a getter alias so alias() → signal_N[]
    ctx.getter_map[alias] = signal_idx
end

"""Promote a potential variable to a Wasm global (called on first handler-body reference)."""
function _promote_var_to_global!(ctx, name::Symbol)
    haskey(ctx.var_map, name) && return  # Already promoted
    initial = get(ctx.potential_vars, name, Int32(0))
    idx = allocate_variable!(ctx.signal_alloc, name, Int32, initial)
    ctx.var_map[name] = idx
end

function _extract_initial_value(expr)
    expr isa Int32 && return expr
    expr isa Integer && return Int32(expr)
    expr isa Bool && return Int32(expr ? 1 : 0)
    # Int32(x) call
    if expr isa Expr && expr.head === :call && expr.args[1] === :Int32 && length(expr.args) == 2
        inner = expr.args[2]
        inner isa Integer && return Int32(inner)
    end
    # Symbol (prop name) — actual value comes from props at runtime
    return Int32(0)
end

"""Check if a create_signal initial value is a runtime expression (needs Wasm global.set at hydration time)."""
function _is_runtime_initial(expr)
    expr isa Int32 && return false
    expr isa Integer && return false
    expr isa Bool && return false
    # Int32(literal) — compile-time
    if expr isa Expr && expr.head === :call && expr.args[1] === :Int32 && length(expr.args) == 2
        inner = expr.args[2]
        inner isa Integer && return false
    end
    # Everything else (symbols, function calls) is runtime
    return true
end

"""
Emit a runtime signal initialization if the create_signal initial value
comes from a variable or function call (not a compile-time literal).

For `dark, set_dark = create_signal(initial)` where `initial` is a variable:
  → `signal_N[] = initial` in the hydrate body (sets the Wasm global at runtime)

This is needed for patterns like ThemeToggle where the initial value
comes from localStorage: `initial = storage_get_i32(THEME_KEY)`
"""
function _emit_runtime_signal_init!(stmts, stmt, ctx)
    rhs = stmt.args[2]
    # For use_context_signal(:key, initial), initial is at position 3
    # For create_signal(initial), initial is at position 2
    if rhs.args[1] === :use_context_signal
        initial_expr = length(rhs.args) >= 3 ? rhs.args[3] : Int32(0)
    else
        initial_expr = rhs.args[2]
    end
    _is_runtime_initial(initial_expr) || return

    getter = stmt.args[1].args[1]::Symbol
    signal_idx = ctx.getter_map[getter]
    signal_sym = Symbol("signal_", signal_idx)

    # Emit: signal_N[] = rewritten_initial
    rewritten = _rewrite_signal_ops(initial_expr, ctx)
    push!(stmts, :($signal_sym[] = $rewritten))
end

# ─── Pass 2: Element Tree Transform ───

function _transform_to_hydrate!(stmts, expr, ctx)
    if _is_element_call_expr(expr)
        _transform_element_call!(stmts, expr, ctx)
    elseif expr isa Expr && expr.head === :call && expr.args[1] === :Fragment
        _transform_fragment!(stmts, expr, ctx)
    elseif _is_match_show_expr(expr)
        _transform_match_show!(stmts, expr, ctx)
    elseif _is_show_expr(expr)
        _transform_show!(stmts, expr, ctx)
    elseif expr === :children
        # Children slot: treat <therapy-children> as a leaf element (open + close)
        _transform_children_slot!(stmts, ctx)
    elseif _is_while_expr(expr)
        # While loop: transform body, preserve loop structure
        _transform_while!(stmts, expr, ctx)
    elseif _is_for_expr(expr)
        # For loop: convert to while loop with counter
        _transform_for!(stmts, expr, ctx)
    elseif expr isa Expr && expr.head === :if
        # If/else: transform both branches (for mode branching in multi-mode components)
        _transform_if!(stmts, expr, ctx)
    elseif _is_use_context_assign(expr, ctx)
        # use_context assignment: alias = use_context(:key)
        # Maps the alias to the context's signal global (compile-time only, no Wasm output)
        _handle_use_context_assign!(ctx, expr)
    elseif _is_assignment_expr(expr) && !_is_create_signal_assign(expr)
        # Non-signal assignment: only pass through if the LHS is a known compilable variable.
        # SSR-only assignments (classes = apply_theme(...), etc.) are silently skipped.
        name = expr.args[1]
        if name isa Symbol && (haskey(ctx.potential_vars, name) || haskey(ctx.var_map, name))
            push!(stmts, _rewrite_signal_ops(expr, ctx))
        end
    elseif expr isa Expr && expr.head === :... && length(expr.args) == 1
        # Splat expression at top level: children..., kwargs..., etc.
        inner_sym = expr.args[1]
        if inner_sym === :children
            _transform_children_slot!(stmts, ctx)
        end
        # All other splats (kwargs..., attrs...) are SSR-only — skip
    elseif expr isa Expr && expr.head in (:&&, :||)
        # Short-circuit expressions: theme !== :default && (classes = apply_theme(...))
        # These are SSR-only — skip entirely
    elseif expr isa Expr && expr.head === :call && _is_compilable_top_level_call(expr)
        # Compilable import stub calls at top level (e.g., push_escape_handler)
        push!(stmts, _rewrite_signal_ops(expr, ctx))
    else
        # Pass-through (non-signal, non-element statements — SSR-only function calls, etc.)
    end
end

"""Detect Show() in both forms: direct call and do-block."""
function _is_show_expr(expr)
    expr isa Expr || return false
    # Direct: Show(condition, content)
    if expr.head === :call && length(expr.args) >= 1 && expr.args[1] === :Show
        return true
    end
    # Do-block: Expr(:do, Expr(:call, :Show, ...), Expr(:->))
    if expr.head === :do && length(expr.args) >= 2
        call_expr = expr.args[1]
        return call_expr isa Expr && call_expr.head === :call && length(call_expr.args) >= 1 && call_expr.args[1] === :Show
    end
    return false
end

# Compilable top-level function calls — import stubs that should be included in the hydrate body.
# These are calls to compiled import stubs (like push_escape_handler) that execute during hydration,
# not inside event handlers. Calls inside handler closures are already passed through by _rewrite_signal_ops.
const COMPILABLE_TOP_LEVEL_CALLS = Set{Symbol}([
    :compiled_push_escape_handler, :compiled_pop_escape_handler,
    :push_escape_handler, :pop_escape_handler,
    :compiled_add_click_outside_listener, :compiled_remove_click_outside_listener,
    :add_click_outside_listener, :remove_click_outside_listener,
    :compiled_push_dismiss_layer, :compiled_pop_dismiss_layer,
    :push_dismiss_layer, :pop_dismiss_layer,
    :compiled_lock_scroll, :compiled_unlock_scroll,
    :lock_scroll, :unlock_scroll,
    :compiled_focus_first_tabbable, :focus_first_tabbable,
    :compiled_store_active_element, :compiled_restore_active_element,
    :store_active_element, :restore_active_element,
    # Phase 7: ShowDescendants + event delegation
    :compiled_show_descendants, :show_descendants,
    :compiled_get_event_closest_role, :get_event_closest_role,
    :compiled_get_parent_island_root, :get_parent_island_root,
    # Focus trap cycling (Phase 7 import 89)
    :compiled_prevent_default, :prevent_default,
    :compiled_cycle_focus_in_current_target, :cycle_focus_in_current_target,
    # Auto-register descendants (T32 imports 90-91)
    :compiled_register_match_descendants, :register_match_descendants,
    :compiled_register_bit_descendants, :register_bit_descendants,
    # DOM manipulation (imports 0, 15-16, 95)
    :compiled_update_text, :update_text,
    :compiled_show_element, :show_element,
    :compiled_hide_element, :hide_element,
    :compiled_get_elements_count, :get_elements_count,
])

function _is_compilable_top_level_call(expr)
    expr isa Expr || return false
    expr.head === :call || return false
    name = expr.args[1]
    name isa Symbol || return false
    return name in COMPILABLE_TOP_LEVEL_CALLS
end

function _is_element_call_expr(expr)
    expr isa Expr || return false
    expr.head === :call || return false
    name = expr.args[1]
    if name isa Symbol
        return name in HYDRATE_ELEMENT_NAMES
    end
    # SUITE-1102: Handle module-qualified element names (e.g. Therapy.Button)
    if name isa Expr && name.head === :. && length(name.args) == 2
        inner = name.args[2]
        actual_name = inner isa QuoteNode ? inner.value : nothing
        return actual_name isa Symbol && actual_name in HYDRATE_ELEMENT_NAMES
    end
    return false
end

function _transform_element_call!(stmts, expr, ctx)
    el_sym = Symbol("el_", ctx.el_count)
    ctx.el_count += 1

    # Open element
    push!(stmts, :($el_sym = hydrate_element_open(position)))

    # Process arguments (props and children)
    for arg in expr.args[2:end]
        _process_element_arg!(stmts, arg, el_sym, ctx)
    end

    # Close element
    push!(stmts, :(hydrate_element_close(position, $el_sym)))
end

function _process_element_arg!(stmts, arg, el_sym, ctx)
    if _is_event_pair(arg)
        _transform_event_pair!(stmts, arg, el_sym, ctx)
    elseif _is_match_bind_bool_pair(arg)
        _transform_match_bind_bool!(stmts, arg, el_sym, ctx)
    elseif _is_bit_bind_bool_pair(arg)
        _transform_bit_bind_bool!(stmts, arg, el_sym, ctx)
    elseif _is_bind_bool_pair(arg)
        _transform_bind_bool!(stmts, arg, el_sym, ctx)
    elseif _is_bind_modal_pair(arg)
        _transform_bind_modal!(stmts, arg, el_sym, ctx)
    elseif _is_show_descendants_pair(arg)
        _transform_show_descendants!(stmts, arg, el_sym, ctx)
    elseif _is_pair_expr(arg) && !_is_event_pair(arg)
        # Static prop — skip (already in SSR HTML)
    elseif _is_element_call_expr(arg)
        _transform_element_call!(stmts, arg, ctx)
    elseif arg isa Expr && arg.head === :call && arg.args[1] === :Fragment
        _transform_fragment!(stmts, arg, ctx)
    elseif _is_match_show_expr(arg)
        _transform_match_show!(stmts, arg, ctx)
    elseif _is_show_expr(arg)
        _transform_show!(stmts, arg, ctx)
    elseif arg isa Symbol && haskey(ctx.getter_map, arg)
        # Signal as text child: Span(count) → text binding
        signal_idx = ctx.getter_map[arg]
        push!(stmts, :(hydrate_text_binding($el_sym, Int32($signal_idx))))
    elseif arg === :children
        # Children slot inside an element: treat <therapy-children> as leaf
        _transform_children_slot!(stmts, ctx)
    elseif arg isa Expr && arg.head === :block
        # begin...end block as element child: unwrap and process inner statements
        _transform_block_as_child!(stmts, arg, el_sym, ctx)
    elseif _is_while_expr(arg)
        # While loop as element child (per-child pattern)
        _transform_while!(stmts, arg, ctx)
    elseif _is_for_expr(arg)
        # For loop as element child (per-child pattern)
        _transform_for!(stmts, arg, ctx)
    elseif arg isa Expr && arg.head === :if
        # If/else inside element children — could be binding props or child elements.
        # Process branches with _process_element_arg! so binding pairs get el_sym context.
        _transform_if_as_prop!(stmts, arg, el_sym, ctx)
    elseif _is_assignment_expr(arg) && !_is_create_signal_assign(arg)
        # Assignment inside element child (loop counter init etc.)
        push!(stmts, _rewrite_signal_ops(arg, ctx))
    elseif arg isa Expr && arg.head === :... && length(arg.args) == 1
        # Splat expression: children..., kwargs..., attrs..., etc.
        inner_sym = arg.args[1]
        if inner_sym === :children
            # children... is a children slot (same as bare :children symbol)
            _transform_children_slot!(stmts, ctx)
        end
        # All other splats (kwargs..., attrs...) are SSR-only — skip
    elseif arg isa String || arg isa Number || arg isa Bool
        # Static text/number child — skip
    else
        # Unknown arg — skip
    end
end

# ─── Pair/Prop Detection ───

function _is_pair_expr(expr)
    expr isa Expr || return false
    expr.head === :call || return false
    return expr.args[1] === :(=>)
end

function _is_event_pair(expr)
    _is_pair_expr(expr) || return false
    name_expr = expr.args[2]
    name_expr isa QuoteNode || return false
    return haskey(HYDRATE_EVENT_MAP, name_expr.value)
end

# ─── Event Handler Transform ───

function _transform_event_pair!(stmts, expr, el_sym, ctx)
    prop_name = expr.args[2].value::Symbol
    handler_closure = expr.args[3]
    event_type = HYDRATE_EVENT_MAP[prop_name]

    handler_idx = Int32(ctx.handler_count)
    ctx.handler_count += 1

    handler_body = _transform_handler_closure(handler_closure, ctx)
    _set_handler_body!(ctx, handler_idx, handler_body)

    push!(stmts, :(hydrate_add_listener($el_sym, Int32($event_type), Int32($handler_idx))))
end

function _transform_handler_closure(closure_expr, ctx)
    if closure_expr isa Expr && closure_expr.head === :(->)
        body = closure_expr.args[2]
        old_in_handler = ctx.in_handler
        ctx.in_handler = true
        result = _rewrite_signal_ops(body, ctx)
        ctx.in_handler = old_in_handler
        return result
    end
    return Expr(:block, :(return nothing))
end

"""
Rewrite signal operations in handler bodies:
- set_count(expr) → signal_N[] = expr; compiled_trigger_bindings(N, signal_N[])
- count()         → signal_N[]
- Integer literal → Int32(literal) for Wasm compatibility
"""
function _rewrite_signal_ops(expr, ctx)
    if expr isa Expr
        # Variable global assignment in handler: timer_id = value → var_N[] = value
        if expr.head === :(=) && expr.args[1] isa Symbol
            name = expr.args[1]
            # Already promoted variable → rewrite
            if haskey(ctx.var_map, name)
                idx = ctx.var_map[name]
                var_sym = Symbol("var_", idx)
                rewritten_rhs = _rewrite_signal_ops(expr.args[2], ctx)
                return :($var_sym[] = $rewritten_rhs)
            end
            # Potential variable encountered in handler → promote and rewrite
            if ctx.in_handler && haskey(ctx.potential_vars, name)
                _promote_var_to_global!(ctx, name)
                idx = ctx.var_map[name]
                var_sym = Symbol("var_", idx)
                rewritten_rhs = _rewrite_signal_ops(expr.args[2], ctx)
                return :($var_sym[] = $rewritten_rhs)
            end
        end

        if expr.head === :call
            fname = expr.args[1]

            # set_timeout with inline closure: extract callback as handler
            if fname === :set_timeout && length(expr.args) >= 3
                first_arg = expr.args[2]
                if first_arg isa Expr && first_arg.head === :(->)
                    callback_idx = ctx.handler_count
                    ctx.handler_count += 1
                    callback_body = _rewrite_signal_ops(first_arg.args[2], ctx)
                    _set_handler_body!(ctx, callback_idx, callback_body)
                    ms_arg = _rewrite_signal_ops(expr.args[3], ctx)
                    return :(compiled_set_timeout(Int32($callback_idx), $ms_arg))
                end
            end

            # Setter: set_count(value) → assign + trigger
            if fname isa Symbol && haskey(ctx.setter_map, fname)
                signal_idx = ctx.setter_map[fname]
                signal_sym = Symbol("signal_", signal_idx)
                value_arg = length(expr.args) >= 2 ? expr.args[2] : :(Int32(0))
                rewritten_value = _rewrite_signal_ops(value_arg, ctx)
                return Expr(:block,
                    :($signal_sym[] = $rewritten_value),
                    :(compiled_trigger_bindings(Int32($signal_idx), $signal_sym[]))
                )
            end

            # Getter: count() → signal_N[]
            if fname isa Symbol && haskey(ctx.getter_map, fname) && length(expr.args) == 1
                signal_idx = ctx.getter_map[fname]
                signal_sym = Symbol("signal_", signal_idx)
                return :($signal_sym[])
            end

            # use_context(:key) → resolve to signal global read
            # Within the same island, context maps to a signal global
            if fname === :use_context && length(expr.args) == 2
                key = _extract_context_key(expr)
                if key !== nothing && haskey(ctx.context_map, key)
                    signal_idx, _ = ctx.context_map[key]
                    signal_sym = Symbol("signal_", signal_idx)
                    return :($signal_sym[])
                end
            end
        end

        # Recurse into sub-expressions
        new_args = Any[_rewrite_signal_ops(a, ctx) for a in expr.args]
        return Expr(expr.head, new_args...)
    end

    # Variable global read: already promoted → var_N[]
    if expr isa Symbol && haskey(ctx.var_map, expr)
        idx = ctx.var_map[expr]
        var_sym = Symbol("var_", idx)
        return :($var_sym[])
    end

    # Potential variable read in handler → promote and rewrite
    if expr isa Symbol && ctx.in_handler && haskey(ctx.potential_vars, expr)
        _promote_var_to_global!(ctx, expr)
        idx = ctx.var_map[expr]
        var_sym = Symbol("var_", idx)
        return :($var_sym[])
    end

    # Wrap bare integer literals to Int32 for Wasm
    if expr isa Int && !(expr isa Int32)
        return :(Int32($expr))
    end

    return expr
end

"""Store handler body at the correct index (handler_idx). Grows vector as needed."""
function _set_handler_body!(ctx, handler_idx, body)
    idx = handler_idx + 1  # Julia 1-indexed
    while length(ctx.handler_bodies) < idx
        push!(ctx.handler_bodies, Expr(:block, :(return nothing)))
    end
    ctx.handler_bodies[idx] = body
end

# ─── BindBool/BindModal Detection and Transform ───

# Data-state mode constants
const DATA_STATE_MODE_MAP = Dict{Tuple{String,String}, Int32}(
    ("closed", "open")         => Int32(0),
    ("off", "on")              => Int32(1),
    ("unchecked", "checked")   => Int32(2),
    ("inactive", "active")     => Int32(3),
)

# Aria attribute code constants
const ARIA_ATTR_MAP = Dict{Symbol, Int32}(
    :aria_pressed  => Int32(0),
    :aria_checked  => Int32(1),
    :aria_expanded => Int32(2),
    :aria_selected => Int32(3),
)

"""Detect `:prop_name => BindBool(signal, off, on)` pair."""
function _is_bind_bool_pair(expr)
    _is_pair_expr(expr) || return false
    value = expr.args[3]
    value isa Expr || return false
    value.head === :call || return false
    return value.args[1] === :BindBool
end

"""Detect `:prop_name => BindModal(signal, mode)` pair."""
function _is_bind_modal_pair(expr)
    _is_pair_expr(expr) || return false
    value = expr.args[3]
    value isa Expr || return false
    value.head === :call || return false
    return value.args[1] === :BindModal
end

"""
Transform BindBool prop into hydration binding registration.

Detects the prop name to determine binding type:
- `Symbol("data-state") => BindBool(signal, off, on)` → data_state binding
- `:aria_pressed => BindBool(signal, ...)` → aria binding
"""
function _transform_bind_bool!(stmts, expr, el_sym, ctx)
    prop_name_expr = expr.args[2]  # QuoteNode or Expr(:call, :Symbol, ...)
    bind_call = expr.args[3]       # BindBool(signal, off, on)

    # Extract signal from BindBool args
    signal_expr = length(bind_call.args) >= 2 ? bind_call.args[2] : nothing
    signal_idx = _resolve_signal_idx(signal_expr, ctx)
    signal_idx === nothing && return  # Not a known signal

    # Determine prop name
    prop_name = _extract_prop_name(prop_name_expr)

    if prop_name === Symbol("data-state")
        # Data-state binding: use mode from off/on strings
        off_val = length(bind_call.args) >= 3 ? string(bind_call.args[3]) : "closed"
        on_val = length(bind_call.args) >= 4 ? string(bind_call.args[4]) : "open"
        mode = get(DATA_STATE_MODE_MAP, (off_val, on_val), Int32(0))
        push!(stmts, :(hydrate_data_state_binding($el_sym, Int32($signal_idx), Int32($mode))))
    elseif haskey(ARIA_ATTR_MAP, prop_name)
        # Aria binding
        attr_code = ARIA_ATTR_MAP[prop_name]
        push!(stmts, :(hydrate_aria_binding($el_sym, Int32($signal_idx), Int32($attr_code))))
    end
end

"""Transform BindModal prop into hydration modal binding registration."""
function _transform_bind_modal!(stmts, expr, el_sym, ctx)
    bind_call = expr.args[3]  # BindModal(signal, mode)

    signal_expr = length(bind_call.args) >= 2 ? bind_call.args[2] : nothing
    signal_idx = _resolve_signal_idx(signal_expr, ctx)
    signal_idx === nothing && return

    mode_expr = length(bind_call.args) >= 3 ? bind_call.args[3] : Int32(0)
    mode = _extract_int32(mode_expr)

    push!(stmts, :(hydrate_modal_binding($el_sym, Int32($signal_idx), Int32($mode))))
end

"""Detect `:prop_name => ShowDescendants(signal)` pair."""
function _is_show_descendants_pair(expr)
    _is_pair_expr(expr) || return false
    value = expr.args[3]
    value isa Expr || return false
    value.head === :call || return false
    return value.args[1] === :ShowDescendants
end

"""Transform ShowDescendants prop into show_descendants binding registration."""
function _transform_show_descendants!(stmts, expr, el_sym, ctx)
    bind_call = expr.args[3]  # ShowDescendants(signal)

    signal_expr = length(bind_call.args) >= 2 ? bind_call.args[2] : nothing
    signal_idx = _resolve_signal_idx(signal_expr, ctx)
    signal_idx === nothing && return

    push!(stmts, :(hydrate_show_descendants_binding($el_sym, Int32($signal_idx))))
end

"""Resolve a signal expression to its global index."""
function _resolve_signal_idx(expr, ctx)
    if expr isa Symbol && haskey(ctx.getter_map, expr)
        return ctx.getter_map[expr]
    end
    return nothing
end

"""Extract prop name from QuoteNode or Symbol("name") call."""
function _extract_prop_name(expr)
    if expr isa QuoteNode
        return expr.value::Symbol
    elseif expr isa Expr && expr.head === :call && expr.args[1] === :Symbol && length(expr.args) >= 2
        return Symbol(expr.args[2])
    end
    return :unknown
end

"""Extract Int32 value from expression."""
function _extract_int32(expr)
    expr isa Int32 && return expr
    expr isa Integer && return Int32(expr)
    if expr isa Expr && expr.head === :call && expr.args[1] === :Int32 && length(expr.args) == 2
        inner = expr.args[2]
        inner isa Integer && return Int32(inner)
    end
    return Int32(0)
end

# ─── If/Else Transform ───

"""
Transform an if/else expression. Both branches are recursively transformed.

Used for mode branching in multi-mode components (e.g., Accordion single vs multiple).
"""
function _transform_if!(stmts, expr, ctx)
    condition = _rewrite_signal_ops(expr.args[1], ctx)

    true_stmts = Any[]
    true_body = expr.args[2]
    inner = true_body isa Expr && true_body.head === :block ? true_body.args : Any[true_body]
    for stmt in inner
        stmt isa LineNumberNode && continue
        _transform_to_hydrate!(true_stmts, stmt, ctx)
    end

    if length(expr.args) >= 3 && expr.args[3] !== nothing
        false_stmts = Any[]
        false_body = expr.args[3]
        # Handle elseif chains: Expr(:elseif, ...) has same structure as :if
        inner_f = false_body isa Expr && false_body.head in (:block, :elseif) ? false_body.args : Any[false_body]
        if false_body isa Expr && false_body.head === :elseif
            # elseif becomes a nested if
            _transform_if!(false_stmts, false_body, ctx)
        else
            for stmt in inner_f
                stmt isa LineNumberNode && continue
                _transform_to_hydrate!(false_stmts, stmt, ctx)
            end
        end
        # Only emit if block when at least one branch has hydration content
        if !isempty(true_stmts) || !isempty(false_stmts)
            push!(stmts, Expr(:if, condition, Expr(:block, true_stmts...), Expr(:block, false_stmts...)))
        end
    else
        # Only emit if block when it has hydration content (skip SSR-only conditionals)
        if !isempty(true_stmts)
            push!(stmts, Expr(:if, condition, Expr(:block, true_stmts...)))
        end
    end
end

"""
Transform an if/else expression that appears as an element argument (prop or child).

Unlike _transform_if! which uses _transform_to_hydrate!, this uses _process_element_arg!
so that binding pairs (MatchBindBool, BitBindBool, BindBool) inside branches
have access to the element symbol (el_sym) needed for emitting binding registration calls.

Example:
```julia
Button(
    if m_flag == Int32(0)
        Symbol("data-state") => MatchBindBool(active, i, "off", "on")
    else
        Symbol("data-state") => BitBindBool(active, i, "off", "on")
    end,
)
```
"""
function _transform_if_as_prop!(stmts, expr, el_sym, ctx)
    condition = _rewrite_signal_ops(expr.args[1], ctx)

    true_stmts = Any[]
    true_body = expr.args[2]
    inner = true_body isa Expr && true_body.head === :block ? true_body.args : Any[true_body]
    for stmt in inner
        stmt isa LineNumberNode && continue
        _process_element_arg!(true_stmts, stmt, el_sym, ctx)
    end

    if length(expr.args) >= 3 && expr.args[3] !== nothing
        false_stmts = Any[]
        false_body = expr.args[3]
        if false_body isa Expr && false_body.head === :elseif
            _transform_if_as_prop!(false_stmts, false_body, el_sym, ctx)
            push!(stmts, Expr(:if, condition, Expr(:block, true_stmts...), Expr(:block, false_stmts...)))
        else
            inner_f = false_body isa Expr && false_body.head === :block ? false_body.args : Any[false_body]
            for stmt in inner_f
                stmt isa LineNumberNode && continue
                _process_element_arg!(false_stmts, stmt, el_sym, ctx)
            end
            push!(stmts, Expr(:if, condition, Expr(:block, true_stmts...), Expr(:block, false_stmts...)))
        end
    else
        push!(stmts, Expr(:if, condition, Expr(:block, true_stmts...)))
    end
end

# ─── MatchBindBool / BitBindBool Detection and Transform ───

"""Detect `:prop => MatchBindBool(signal, match_value, off, on)` pair."""
function _is_match_bind_bool_pair(expr)
    _is_pair_expr(expr) || return false
    value = expr.args[3]
    value isa Expr || return false
    value.head === :call || return false
    return value.args[1] === :MatchBindBool
end

"""Detect `:prop => BitBindBool(signal, bit_index, off, on)` pair."""
function _is_bit_bind_bool_pair(expr)
    _is_pair_expr(expr) || return false
    value = expr.args[3]
    value isa Expr || return false
    value.head === :call || return false
    return value.args[1] === :BitBindBool
end

"""
Transform MatchBindBool prop into match-based hydration binding registration.

`:prop => MatchBindBool(signal, match_value, off, on)`
→ `hydrate_match_data_state_binding(el, signal_idx, match_value, mode)` for data-state
→ `hydrate_match_aria_binding(el, signal_idx, match_value, attr_code)` for aria attrs
"""
function _transform_match_bind_bool!(stmts, expr, el_sym, ctx)
    prop_name_expr = expr.args[2]
    bind_call = expr.args[3]  # MatchBindBool(signal, match_value, off, on)

    signal_expr = length(bind_call.args) >= 2 ? bind_call.args[2] : nothing
    signal_idx = _resolve_signal_idx(signal_expr, ctx)
    signal_idx === nothing && return

    match_value = length(bind_call.args) >= 3 ? bind_call.args[3] : Int32(0)
    rewritten_match = _rewrite_signal_ops(match_value, ctx)

    prop_name = _extract_prop_name(prop_name_expr)

    if prop_name === Symbol("data-state")
        off_val = length(bind_call.args) >= 4 ? string(bind_call.args[4]) : "closed"
        on_val = length(bind_call.args) >= 5 ? string(bind_call.args[5]) : "open"
        mode = get(DATA_STATE_MODE_MAP, (off_val, on_val), Int32(0))
        push!(stmts, :(hydrate_match_data_state_binding($el_sym, Int32($signal_idx), $rewritten_match, Int32($mode))))
    elseif haskey(ARIA_ATTR_MAP, prop_name)
        attr_code = ARIA_ATTR_MAP[prop_name]
        push!(stmts, :(hydrate_match_aria_binding($el_sym, Int32($signal_idx), $rewritten_match, Int32($attr_code))))
    end
end

"""
Transform BitBindBool prop into bit-based hydration binding registration.

`:prop => BitBindBool(signal, bit_index, off, on)`
→ `hydrate_bit_data_state_binding(el, signal_idx, bit_index, mode)` for data-state
→ `hydrate_bit_aria_binding(el, signal_idx, bit_index, attr_code)` for aria attrs
"""
function _transform_bit_bind_bool!(stmts, expr, el_sym, ctx)
    prop_name_expr = expr.args[2]
    bind_call = expr.args[3]  # BitBindBool(signal, bit_index, off, on)

    signal_expr = length(bind_call.args) >= 2 ? bind_call.args[2] : nothing
    signal_idx = _resolve_signal_idx(signal_expr, ctx)
    signal_idx === nothing && return

    bit_index = length(bind_call.args) >= 3 ? bind_call.args[3] : Int32(0)
    rewritten_bit = _rewrite_signal_ops(bit_index, ctx)

    prop_name = _extract_prop_name(prop_name_expr)

    if prop_name === Symbol("data-state")
        off_val = length(bind_call.args) >= 4 ? string(bind_call.args[4]) : "closed"
        on_val = length(bind_call.args) >= 5 ? string(bind_call.args[5]) : "open"
        mode = get(DATA_STATE_MODE_MAP, (off_val, on_val), Int32(0))
        push!(stmts, :(hydrate_bit_data_state_binding($el_sym, Int32($signal_idx), $rewritten_bit, Int32($mode))))
    elseif haskey(ARIA_ATTR_MAP, prop_name)
        attr_code = ARIA_ATTR_MAP[prop_name]
        push!(stmts, :(hydrate_bit_aria_binding($el_sym, Int32($signal_idx), $rewritten_bit, Int32($attr_code))))
    end
end

# ─── Children Slot Transform ───

"""
Transform a `children` reference into a children slot skip call.

During hydration, <therapy-children> is treated as opaque — the cursor
advances to it and immediately skips past it without descending into children.
Children content is handled by child islands independently.
"""
function _transform_children_slot!(stmts, ctx)
    push!(stmts, :(hydrate_children_slot(position)))
end

# ─── While Loop Transform ───

"""Detect `while condition ... end` expression."""
function _is_while_expr(expr)
    expr isa Expr || return false
    return expr.head === :while
end

"""Detect assignment expression (not create_signal)."""
function _is_assignment_expr(expr)
    expr isa Expr || return false
    return expr.head === :(=) && !(expr.args[1] isa Expr && expr.args[1].head === :tuple)
end

"""
Transform a while loop: preserve loop structure, transform body statements.

While loops are used for per-child patterns (Tabs, Accordion) where the number
of items is determined at runtime from props.
"""
function _transform_while!(stmts, expr, ctx)
    condition = _rewrite_signal_ops(expr.args[1], ctx)
    body_stmts = Any[]

    body = expr.args[2]
    inner_stmts = body.head === :block ? body.args : Any[body]
    for stmt in inner_stmts
        stmt isa LineNumberNode && continue
        _transform_to_hydrate!(body_stmts, stmt, ctx)
    end

    push!(stmts, Expr(:while, condition, Expr(:block, body_stmts...)))
end

# ─── Fragment Transform ───

function _transform_fragment!(stmts, expr, ctx)
    for arg in expr.args[2:end]
        _transform_to_hydrate!(stmts, arg, ctx)
    end
end

# ─── Show Transform ───

"""
Transform Show() to hydration cursor walk with visibility binding.

Handles three AST forms:
1. Direct: `Show(condition, content)` — Expr(:call, :Show, cond, content)
2. Do-block (parsed): `Show(cond) do; content; end` — Expr(:do, Expr(:call, :Show, cond), Expr(:->, params, body))
3. Do-block (desugared): `Show(() -> content, cond)` — Expr(:call, :Show, Expr(:->), cond)
"""
function _transform_show!(stmts, expr, ctx)
    condition = nothing
    content_exprs = Any[]

    if expr.head === :do
        # Do-block form: Expr(:do, Expr(:call, :Show, condition...), Expr(:->, params, body))
        call_expr = expr.args[1]  # Expr(:call, :Show, condition_args...)
        lambda_expr = expr.args[2]  # Expr(:->, params, body)
        condition = length(call_expr.args) >= 2 ? call_expr.args[2] : nothing
        _extract_lambda_content!(content_exprs, lambda_expr)
    else
        # Call form: Expr(:call, :Show, args...)
        args = expr.args[2:end]
        if length(args) >= 2 && args[1] isa Expr && args[1].head === :->
            # Desugared do-block: Show(() -> content, condition)
            condition = args[2]
            _extract_lambda_content!(content_exprs, args[1])
        elseif length(args) >= 2
            # Direct: Show(condition, content)
            condition = args[1]
            push!(content_exprs, args[2])
        elseif length(args) >= 1
            condition = args[1]
        end
    end

    el_sym = Symbol("el_", ctx.el_count)
    ctx.el_count += 1

    push!(stmts, :($el_sym = hydrate_element_open(position)))

    if condition isa Symbol && haskey(ctx.getter_map, condition)
        signal_idx = ctx.getter_map[condition]
        push!(stmts, :(hydrate_visibility_binding($el_sym, Int32($signal_idx))))
    end

    for content in content_exprs
        _process_element_arg!(stmts, content, el_sym, ctx)
    end

    push!(stmts, :(hydrate_element_close(position, $el_sym)))
end

"""Extract content expressions from a lambda Expr(:->, params, body)."""
function _extract_lambda_content!(content_exprs, lambda_expr)
    body = lambda_expr.args[2]
    if body isa Expr && body.head === :block
        for child in body.args
            child isa LineNumberNode && continue
            push!(content_exprs, child)
        end
    else
        push!(content_exprs, body)
    end
end

# ─── Block-as-Child Transform ───

"""
Transform a begin...end block as an element child.

Unwraps the block and processes each inner statement as if it were an element child.
This enables per-child patterns where a loop and its counter initialization are
wrapped in a begin block inside an element call: `Div(begin i=0; while i<n; ...; end; end)`.
"""
function _transform_block_as_child!(stmts, block_expr, el_sym, ctx)
    for stmt in block_expr.args
        stmt isa LineNumberNode && continue
        _process_element_arg!(stmts, stmt, el_sym, ctx)
    end
end

# ─── For Loop Transform ───

"""Detect `for i in range; body; end` expression."""
function _is_for_expr(expr)
    expr isa Expr || return false
    return expr.head === :for
end

"""
Transform a for loop to a while loop with counter variable.

Handles patterns:
- `for i in 0:n-1; body; end` → while loop with i starting at 0, bound n
- `for i in 1:n; body; end` → while loop with i starting at 0, bound n (adjusts to 0-based)
- `for i in range_expr; body; end` → while loop with rewritten range

The loop counter is available inside the body for per-child operations like
match_binding values.
"""
function _transform_for!(stmts, expr, ctx)
    iter_expr = expr.args[1]  # Expr(:(=), :i, range)
    body = expr.args[2]

    # Extract loop variable and range
    # Skip for-loops with non-Symbol loop variables (tuple destructuring, etc.)
    # These are SSR-only patterns (e.g., `for child in children`, `for (i, item) in enumerate(...)`)
    if !(iter_expr.args[1] isa Symbol)
        return  # Skip SSR-only for-loop
    end
    loop_var = iter_expr.args[1]::Symbol
    range_expr = iter_expr.args[2]

    # Extract range start and end
    start_val, end_val = _extract_for_range(range_expr, ctx)

    # Generate: loop_var = start_val
    push!(stmts, :($loop_var = $start_val))

    # Generate while loop: while loop_var < end_val; body; loop_var += Int32(1); end
    body_stmts = Any[]
    inner_stmts = body.head === :block ? body.args : Any[body]
    for stmt in inner_stmts
        stmt isa LineNumberNode && continue
        _transform_to_hydrate!(body_stmts, stmt, ctx)
    end
    # Increment counter
    push!(body_stmts, :($loop_var = $loop_var + Int32(1)))

    push!(stmts, Expr(:while, :($loop_var < $end_val), Expr(:block, body_stmts...)))
end

"""Extract start and end values from a for-loop range expression."""
function _extract_for_range(range_expr, ctx)
    if range_expr isa Expr && range_expr.head === :call && range_expr.args[1] === :(:)
        if length(range_expr.args) == 3
            # start:end form
            raw_start = _rewrite_signal_ops(range_expr.args[2], ctx)
            raw_end = range_expr.args[3]
            # Handle end+1 form: for i in 0:n-1, end is n-1 so we need end+1 = n
            # Actually just use end+1 as the while bound (while i <= end → while i < end+1)
            end_val = _rewrite_signal_ops(Expr(:call, :+, raw_end, :(Int32(1))), ctx)
            return (raw_start, end_val)
        elseif length(range_expr.args) == 2
            # 1:end short form
            raw_end = _rewrite_signal_ops(range_expr.args[2], ctx)
            end_val = _rewrite_signal_ops(Expr(:call, :+, raw_end, :(Int32(1))), ctx)
            return (:(Int32(1)), end_val)
        end
    end
    # Fallback: assume 0-based
    return (:(Int32(0)), _rewrite_signal_ops(range_expr, ctx))
end

# ─── MatchShow Transform ───

"""
Detect MatchShow() in both direct call and do-block forms.

MatchShow(signal, value) — show content when signal == value.
This compiles to a match_binding (import 75) during hydration.
"""
function _is_match_show_expr(expr)
    expr isa Expr || return false
    # Direct: MatchShow(signal, value, content)
    if expr.head === :call && length(expr.args) >= 1 && expr.args[1] === :MatchShow
        return true
    end
    # Do-block: Expr(:do, Expr(:call, :MatchShow, signal, value), Expr(:->, params, body))
    if expr.head === :do && length(expr.args) >= 2
        call_expr = expr.args[1]
        return call_expr isa Expr && call_expr.head === :call && length(call_expr.args) >= 1 && call_expr.args[1] === :MatchShow
    end
    return false
end

"""
Transform MatchShow() to hydration cursor walk with match binding.

MatchShow(signal, value) do; content; end
→ hydrate_element_open + hydrate_match_binding(el, signal_idx, value) + content + close

Unlike Show() which uses visibility_binding (show/hide based on truthy/falsy),
MatchShow uses match_binding (show when signal == value, hide otherwise).
Used for per-child patterns like Tabs (show panel when active == tab_index).
"""
function _transform_match_show!(stmts, expr, ctx)
    signal_cond = nothing
    match_value = nothing
    content_exprs = Any[]

    if expr.head === :do
        # Do-block form: Expr(:do, Expr(:call, :MatchShow, signal, value), Expr(:->, params, body))
        call_expr = expr.args[1]
        lambda_expr = expr.args[2]
        signal_cond = length(call_expr.args) >= 2 ? call_expr.args[2] : nothing
        match_value = length(call_expr.args) >= 3 ? call_expr.args[3] : nothing
        _extract_lambda_content!(content_exprs, lambda_expr)
    else
        # Call form: MatchShow(signal, value, content)
        args = expr.args[2:end]
        if length(args) >= 3
            signal_cond = args[1]
            match_value = args[2]
            push!(content_exprs, args[3])
        elseif length(args) >= 2
            signal_cond = args[1]
            match_value = args[2]
        end
    end

    el_sym = Symbol("el_", ctx.el_count)
    ctx.el_count += 1

    push!(stmts, :($el_sym = hydrate_element_open(position)))

    # Register match binding: show when signal == value
    if signal_cond isa Symbol && haskey(ctx.getter_map, signal_cond)
        signal_idx = ctx.getter_map[signal_cond]
        rewritten_value = _rewrite_signal_ops(match_value, ctx)
        push!(stmts, :(hydrate_match_binding($el_sym, Int32($signal_idx), $rewritten_value)))
    end

    for content in content_exprs
        _process_element_arg!(stmts, content, el_sym, ctx)
    end

    push!(stmts, :(hydrate_element_close(position, $el_sym)))
end

# ─── Function Generation ───

"""
    build_island_spec(component_name::String, body_expr::Expr) -> IslandCompilationSpec

Transform an island body expression and build a compilable IslandCompilationSpec.

Uses eval to create typed Julia functions with WasmGlobal parameters that
WasmTarget can compile to Wasm.
"""
function build_island_spec(component_name::String, body_expr::Expr)::IslandCompilationSpec
    result = transform_island_body(body_expr)
    n_sigs = signal_count(result.signal_alloc)
    WG = WasmGlobal

    # Build WasmGlobal type tuple: position + signal globals + variable globals
    wg_types = Type[WG{Int32, 0}]
    for sig in result.signal_alloc.signals
        T = sig.type === Bool ? Int32 : sig.type
        push!(wg_types, WG{T, sig.index})
    end
    for var in result.signal_alloc.variables
        T = var.type === Bool ? Int32 : var.type
        push!(wg_types, WG{T, var.index})
    end
    arg_types_tuple = Tuple(wg_types)

    # Build parameter expressions: position::WasmGlobal{Int32,0}, signal_1::WasmGlobal{Int32,1}, ..., var_N::WasmGlobal{Int32,N}
    param_exprs = Any[:(position::$(WG{Int32, 0}))]
    for sig in result.signal_alloc.signals
        T = sig.type === Bool ? Int32 : sig.type
        sym = Symbol("signal_", sig.index)
        wg_type = WG{T, sig.index}
        push!(param_exprs, :($sym::$wg_type))
    end
    for var in result.signal_alloc.variables
        T = var.type === Bool ? Int32 : var.type
        sym = Symbol("var_", var.index)
        wg_type = WG{T, var.index}
        push!(param_exprs, :($sym::$wg_type))
    end

    # Create temporary module for generated functions
    temp_mod = _create_island_eval_module()

    # Generate and eval hydrate function
    hydrate_body = Expr(:block, result.hydrate_stmts..., :(return nothing))
    hydrate_name = Symbol("_hydrate_", component_name)
    hydrate_fn_expr = Expr(:function,
        Expr(:(::),
            Expr(:call, hydrate_name, param_exprs...),
            :Nothing
        ),
        hydrate_body
    )
    Core.eval(temp_mod, hydrate_fn_expr)
    hydrate_fn = Base.invokelatest(getfield, temp_mod, hydrate_name)

    # Generate and eval handler functions
    handlers = NamedTuple{(:fn, :arg_types, :name), Tuple{Function, Tuple, String}}[]
    for (i, handler_body) in enumerate(result.handler_bodies)
        hname = Symbol("handler_", i - 1)
        handler_fn_expr = Expr(:function,
            Expr(:(::),
                Expr(:call, hname, param_exprs...),
                :Nothing
            ),
            Expr(:block, handler_body, :(return nothing))
        )
        Core.eval(temp_mod, handler_fn_expr)
        fn = Base.invokelatest(getfield, temp_mod, hname)
        push!(handlers, (fn=fn, arg_types=arg_types_tuple, name=string("handler_", i - 1)))
    end

    return IslandCompilationSpec(
        component_name,
        hydrate_fn,
        arg_types_tuple,
        handlers,
        result.signal_alloc
    )
end

"""Create a module with all helper function bindings for eval'd island functions."""
function _create_island_eval_module()
    mod = Module()
    Core.eval(mod, :(using WasmTarget: WasmGlobal))
    # Bind hydration helper functions
    Core.eval(mod, :(const hydrate_element_open = $(hydrate_element_open)))
    Core.eval(mod, :(const hydrate_element_close = $(hydrate_element_close)))
    Core.eval(mod, :(const hydrate_add_listener = $(hydrate_add_listener)))
    Core.eval(mod, :(const hydrate_text_binding = $(hydrate_text_binding)))
    Core.eval(mod, :(const hydrate_visibility_binding = $(hydrate_visibility_binding)))
    Core.eval(mod, :(const hydrate_attribute_binding = $(hydrate_attribute_binding)))
    Core.eval(mod, :(const hydrate_data_state_binding = $(hydrate_data_state_binding)))
    Core.eval(mod, :(const hydrate_aria_binding = $(hydrate_aria_binding)))
    Core.eval(mod, :(const hydrate_modal_binding = $(hydrate_modal_binding)))
    Core.eval(mod, :(const hydrate_show_descendants_binding = $(hydrate_show_descendants_binding)))
    Core.eval(mod, :(const hydrate_match_binding = $(hydrate_match_binding)))
    Core.eval(mod, :(const hydrate_match_data_state_binding = $(hydrate_match_data_state_binding)))
    Core.eval(mod, :(const hydrate_match_aria_binding = $(hydrate_match_aria_binding)))
    Core.eval(mod, :(const hydrate_bit_data_state_binding = $(hydrate_bit_data_state_binding)))
    Core.eval(mod, :(const hydrate_bit_aria_binding = $(hydrate_bit_aria_binding)))
    Core.eval(mod, :(const hydrate_children_slot = $(hydrate_children_slot)))
    Core.eval(mod, :(const compiled_trigger_bindings = $(compiled_trigger_bindings)))
    Core.eval(mod, :(const compiled_get_event_data_index = $(compiled_get_event_data_index)))
    Core.eval(mod, :(const compiled_get_prop_i32 = $(compiled_get_prop_i32)))
    Core.eval(mod, :(const compiled_get_prop_count = $(compiled_get_prop_count)))
    # MatchShow is only used at the AST level (not at runtime) — no binding needed
    # Bind event getter stubs (for handler bodies that read event data)
    # Use natural names (without compiled_ prefix) so island bodies read naturally
    Core.eval(mod, :(const get_target_value_f64 = $(compiled_get_target_value_f64)))
    Core.eval(mod, :(const get_target_checked = $(compiled_get_target_checked)))
    Core.eval(mod, :(const get_key_code = $(compiled_get_key_code)))
    Core.eval(mod, :(const get_modifiers = $(compiled_get_modifiers)))
    Core.eval(mod, :(const get_pointer_x = $(compiled_get_pointer_x)))
    Core.eval(mod, :(const get_pointer_y = $(compiled_get_pointer_y)))
    Core.eval(mod, :(const get_pointer_id = $(compiled_get_pointer_id)))
    # Storage/dark mode stubs — natural names for island bodies
    Core.eval(mod, :(const storage_get_i32 = $(compiled_storage_get_i32)))
    Core.eval(mod, :(const storage_set_i32 = $(compiled_storage_set_i32)))
    Core.eval(mod, :(const set_dark_mode = $(compiled_set_dark_mode)))
    Core.eval(mod, :(const get_is_dark_mode = $(compiled_get_is_dark_mode)))
    # Timer stubs — natural and compiled names for handler bodies
    Core.eval(mod, :(const set_timeout = $(compiled_set_timeout)))
    Core.eval(mod, :(const clear_timeout = $(compiled_clear_timeout)))
    Core.eval(mod, :(const compiled_set_timeout = $(compiled_set_timeout)))
    Core.eval(mod, :(const compiled_clear_timeout = $(compiled_clear_timeout)))
    # Escape handler stubs — natural and compiled names (Phase 6)
    Core.eval(mod, :(const push_escape_handler = $(compiled_push_escape_handler)))
    Core.eval(mod, :(const pop_escape_handler = $(compiled_pop_escape_handler)))
    Core.eval(mod, :(const compiled_push_escape_handler = $(compiled_push_escape_handler)))
    Core.eval(mod, :(const compiled_pop_escape_handler = $(compiled_pop_escape_handler)))
    # Click-outside stubs — natural and compiled names (Phase 6)
    Core.eval(mod, :(const add_click_outside_listener = $(compiled_add_click_outside_listener)))
    Core.eval(mod, :(const remove_click_outside_listener = $(compiled_remove_click_outside_listener)))
    Core.eval(mod, :(const compiled_add_click_outside_listener = $(compiled_add_click_outside_listener)))
    Core.eval(mod, :(const compiled_remove_click_outside_listener = $(compiled_remove_click_outside_listener)))
    # DismissableLayer stubs — natural and compiled names (imports 93-94)
    Core.eval(mod, :(const push_dismiss_layer = $(compiled_push_dismiss_layer)))
    Core.eval(mod, :(const pop_dismiss_layer = $(compiled_pop_dismiss_layer)))
    Core.eval(mod, :(const compiled_push_dismiss_layer = $(compiled_push_dismiss_layer)))
    Core.eval(mod, :(const compiled_pop_dismiss_layer = $(compiled_pop_dismiss_layer)))
    # Scroll lock stubs — natural and compiled names (Phase 6)
    Core.eval(mod, :(const lock_scroll = $(compiled_lock_scroll)))
    Core.eval(mod, :(const unlock_scroll = $(compiled_unlock_scroll)))
    Core.eval(mod, :(const compiled_lock_scroll = $(compiled_lock_scroll)))
    Core.eval(mod, :(const compiled_unlock_scroll = $(compiled_unlock_scroll)))
    # Focus management stubs — natural and compiled names (Phase 6)
    Core.eval(mod, :(const focus_first_tabbable = $(compiled_focus_first_tabbable)))
    Core.eval(mod, :(const compiled_focus_first_tabbable = $(compiled_focus_first_tabbable)))
    Core.eval(mod, :(const store_active_element = $(compiled_store_active_element)))
    Core.eval(mod, :(const restore_active_element = $(compiled_restore_active_element)))
    Core.eval(mod, :(const compiled_store_active_element = $(compiled_store_active_element)))
    Core.eval(mod, :(const compiled_restore_active_element = $(compiled_restore_active_element)))
    # ShowDescendants + event delegation stubs — natural and compiled names (Phase 7)
    Core.eval(mod, :(const show_descendants = $(compiled_show_descendants)))
    Core.eval(mod, :(const compiled_show_descendants = $(compiled_show_descendants)))
    Core.eval(mod, :(const get_event_closest_role = $(compiled_get_event_closest_role)))
    Core.eval(mod, :(const compiled_get_event_closest_role = $(compiled_get_event_closest_role)))
    Core.eval(mod, :(const get_parent_island_root = $(compiled_get_parent_island_root)))
    Core.eval(mod, :(const compiled_get_parent_island_root = $(compiled_get_parent_island_root)))
    # Focus trap stubs — natural and compiled names (Phase 7 imports 52, 89)
    Core.eval(mod, :(const prevent_default = $(compiled_prevent_default)))
    Core.eval(mod, :(const compiled_prevent_default = $(compiled_prevent_default)))
    Core.eval(mod, :(const cycle_focus_in_current_target = $(compiled_cycle_focus_in_current_target)))
    Core.eval(mod, :(const compiled_cycle_focus_in_current_target = $(compiled_cycle_focus_in_current_target)))
    # Auto-register descendants stubs — natural and compiled names (T32 imports 90-91)
    Core.eval(mod, :(const register_match_descendants = $(compiled_register_match_descendants)))
    Core.eval(mod, :(const compiled_register_match_descendants = $(compiled_register_match_descendants)))
    Core.eval(mod, :(const register_bit_descendants = $(compiled_register_bit_descendants)))
    Core.eval(mod, :(const compiled_register_bit_descendants = $(compiled_register_bit_descendants)))
    # Event data index — natural name alias (T32)
    Core.eval(mod, :(const get_event_data_index = $(compiled_get_event_data_index)))
    # Props f64 getter — was missing from eval module
    Core.eval(mod, :(const compiled_get_prop_f64 = $(compiled_get_prop_f64)))
    Core.eval(mod, :(const get_prop_f64 = $(compiled_get_prop_f64)))
    # Pointer capture/release and bounding rect — natural and compiled names
    Core.eval(mod, :(const capture_pointer = $(compiled_capture_pointer)))
    Core.eval(mod, :(const compiled_capture_pointer = $(compiled_capture_pointer)))
    Core.eval(mod, :(const release_pointer = $(compiled_release_pointer)))
    Core.eval(mod, :(const compiled_release_pointer = $(compiled_release_pointer)))
    Core.eval(mod, :(const get_bounding_rect_x = $(compiled_get_bounding_rect_x)))
    Core.eval(mod, :(const compiled_get_bounding_rect_x = $(compiled_get_bounding_rect_x)))
    Core.eval(mod, :(const get_bounding_rect_w = $(compiled_get_bounding_rect_w)))
    Core.eval(mod, :(const compiled_get_bounding_rect_w = $(compiled_get_bounding_rect_w)))
    Core.eval(mod, :(const get_drag_delta_x = $(compiled_get_drag_delta_x)))
    Core.eval(mod, :(const compiled_get_drag_delta_x = $(compiled_get_drag_delta_x)))
    Core.eval(mod, :(const get_drag_delta_y = $(compiled_get_drag_delta_y)))
    Core.eval(mod, :(const compiled_get_drag_delta_y = $(compiled_get_drag_delta_y)))
    # Style percent/numeric — natural and compiled names (imports 96-97)
    Core.eval(mod, :(const set_style_percent = $(compiled_set_style_percent)))
    Core.eval(mod, :(const compiled_set_style_percent = $(compiled_set_style_percent)))
    Core.eval(mod, :(const set_style_numeric = $(compiled_set_style_numeric)))
    Core.eval(mod, :(const compiled_set_style_numeric = $(compiled_set_style_numeric)))
    # DOM manipulation — natural name aliases (imports 0, 15-16)
    Core.eval(mod, :(const update_text = $(compiled_update_text)))
    Core.eval(mod, :(const compiled_update_text = $(compiled_update_text)))
    Core.eval(mod, :(const show_element = $(compiled_show_element)))
    Core.eval(mod, :(const compiled_show_element = $(compiled_show_element)))
    Core.eval(mod, :(const hide_element = $(compiled_hide_element)))
    Core.eval(mod, :(const compiled_hide_element = $(compiled_hide_element)))
    Core.eval(mod, :(const get_elements_count = $(compiled_get_elements_count)))
    Core.eval(mod, :(const compiled_get_elements_count = $(compiled_get_elements_count)))
    return mod
end
