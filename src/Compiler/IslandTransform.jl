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
    elseif _is_show_expr(expr)
        _transform_show!(stmts, expr, ctx)
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
    elseif _is_pair_expr(arg) && !_is_event_pair(arg)
        # Static prop — skip (already in SSR HTML)
    elseif _is_element_call_expr(arg)
        _transform_element_call!(stmts, arg, ctx)
    elseif arg isa Expr && arg.head === :call && arg.args[1] === :Fragment
        _transform_fragment!(stmts, arg, ctx)
    elseif _is_show_expr(arg)
        _transform_show!(stmts, arg, ctx)
    elseif arg isa Symbol && haskey(ctx.getter_map, arg)
        # Signal as text child: Span(count) → text binding
        signal_idx = ctx.getter_map[arg]
        push!(stmts, :(hydrate_text_binding($el_sym, Int32($signal_idx))))
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
    Core.eval(mod, :(const compiled_trigger_bindings = $(compiled_trigger_bindings)))
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
