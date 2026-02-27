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
])

# ─── Event Prop Mapping ───

const HYDRATE_EVENT_MAP = Dict{Symbol, Int32}(
    :on_click       => Int32(0),   # EVENT_CLICK
    :on_input       => Int32(1),   # EVENT_INPUT
    :on_change      => Int32(2),   # EVENT_CHANGE
    :on_keydown     => Int32(3),   # EVENT_KEYDOWN
    :on_keyup       => Int32(4),   # EVENT_KEYUP
    :on_pointerdown => Int32(5),   # EVENT_POINTERDOWN
    :on_pointermove => Int32(6),   # EVENT_POINTERMOVE
    :on_pointerup   => Int32(7),   # EVENT_POINTERUP
    :on_focus       => Int32(8),   # EVENT_FOCUS
    :on_blur        => Int32(9),   # EVENT_BLUR
    :on_submit      => Int32(10),  # EVENT_SUBMIT
    :on_dblclick    => Int32(11),  # EVENT_DBLCLICK
    :on_contextmenu => Int32(12),  # EVENT_CONTEXTMENU
)

# ─── Transform Context ───

mutable struct IslandTransformContext
    signal_alloc::SignalAllocator
    getter_map::Dict{Symbol, Int32}   # e.g., :count => 1
    setter_map::Dict{Symbol, Int32}   # e.g., :set_count => 1
    handler_count::Int
    handler_bodies::Vector{Expr}
    el_count::Int
end

IslandTransformContext() = IslandTransformContext(
    SignalAllocator(),
    Dict{Symbol, Int32}(),
    Dict{Symbol, Int32}(),
    0, Expr[], 0
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

    # Pass 2: Transform element tree
    hydrate_stmts = Any[]
    for stmt in stmts
        stmt isa LineNumberNode && continue
        _is_create_signal_assign(stmt) && continue  # handled in pass 1
        _transform_to_hydrate!(hydrate_stmts, stmt, ctx)
    end

    return IslandTransformResult(
        ctx.signal_alloc,
        ctx.getter_map,
        ctx.setter_map,
        hydrate_stmts,
        ctx.handler_bodies
    )
end

# ─── Pass 1: Signal Scanning ───

"""Detect `count, set_count = create_signal(x)` pattern."""
function _is_create_signal_assign(expr)
    expr isa Expr || return false
    expr.head === :(=) || return false
    lhs, rhs = expr.args[1], expr.args[2]
    lhs isa Expr && lhs.head === :tuple && length(lhs.args) == 2 || return false
    rhs isa Expr && rhs.head === :call || return false
    return rhs.args[1] === :create_signal
end

function _scan_create_signal!(ctx, expr)
    _is_create_signal_assign(expr) || return

    getter = expr.args[1].args[1]::Symbol
    setter = expr.args[1].args[2]::Symbol
    initial_expr = expr.args[2].args[2]

    initial = _extract_initial_value(initial_expr)
    idx = allocate_signal!(ctx.signal_alloc, Int32, initial)
    ctx.getter_map[getter] = idx
    ctx.setter_map[setter] = idx
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
    elseif _is_assignment_expr(expr) && !_is_create_signal_assign(expr)
        # Non-signal assignment: pass through (loop counter initialization etc.)
        push!(stmts, _rewrite_signal_ops(expr, ctx))
    else
        # Pass-through (non-signal, non-element statements)
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

function _is_element_call_expr(expr)
    expr isa Expr || return false
    expr.head === :call || return false
    name = expr.args[1]
    name isa Symbol || return false
    return name in HYDRATE_ELEMENT_NAMES
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
    elseif _is_bind_bool_pair(arg)
        _transform_bind_bool!(stmts, arg, el_sym, ctx)
    elseif _is_bind_modal_pair(arg)
        _transform_bind_modal!(stmts, arg, el_sym, ctx)
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
    elseif _is_assignment_expr(arg) && !_is_create_signal_assign(arg)
        # Assignment inside element child (loop counter init etc.)
        push!(stmts, _rewrite_signal_ops(arg, ctx))
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
    push!(ctx.handler_bodies, handler_body)

    push!(stmts, :(hydrate_add_listener($el_sym, Int32($event_type), Int32($handler_idx))))
end

function _transform_handler_closure(closure_expr, ctx)
    if closure_expr isa Expr && closure_expr.head === :(->)
        body = closure_expr.args[2]
        return _rewrite_signal_ops(body, ctx)
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
        if expr.head === :call
            fname = expr.args[1]

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
        end

        # Recurse into sub-expressions
        new_args = Any[_rewrite_signal_ops(a, ctx) for a in expr.args]
        return Expr(expr.head, new_args...)
    end

    # Wrap bare integer literals to Int32 for Wasm
    if expr isa Int && !(expr isa Int32)
        return :(Int32($expr))
    end

    return expr
end

# ─── BindBool/BindModal Detection and Transform ───

# Data-state mode constants
const DATA_STATE_MODE_MAP = Dict{Tuple{String,String}, Int32}(
    ("closed", "open")         => Int32(0),
    ("off", "on")              => Int32(1),
    ("unchecked", "checked")   => Int32(2),
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

# ─── Children Slot Transform ───

"""
Transform a `children` reference into a leaf element open/close pair.

During hydration, <therapy-children> is treated as a leaf element — the cursor
advances to it and immediately closes without descending into its children.
Children content is opaque to the parent island (already server-rendered in DOM).
"""
function _transform_children_slot!(stmts, ctx)
    el_sym = Symbol("el_", ctx.el_count)
    ctx.el_count += 1
    push!(stmts, :($el_sym = hydrate_element_open(position)))
    push!(stmts, :(hydrate_element_close(position, $el_sym)))
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

    # Build WasmGlobal type tuple: position + signal globals
    wg_types = Type[WG{Int32, 0}]
    for sig in result.signal_alloc.signals
        T = sig.type === Bool ? Int32 : sig.type
        push!(wg_types, WG{T, sig.index})
    end
    arg_types_tuple = Tuple(wg_types)

    # Build parameter expressions: position::WasmGlobal{Int32,0}, signal_1::WasmGlobal{Int32,1}, ...
    param_exprs = Any[:(position::$(WG{Int32, 0}))]
    for sig in result.signal_alloc.signals
        T = sig.type === Bool ? Int32 : sig.type
        sym = Symbol("signal_", sig.index)
        wg_type = WG{T, sig.index}
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
    Core.eval(mod, :(const hydrate_match_binding = $(hydrate_match_binding)))
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
    return mod
end
