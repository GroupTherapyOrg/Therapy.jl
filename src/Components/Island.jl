# Island.jl - Interactive island components that compile to JS
#
# Islands are the boundary between static SSR and interactive client code.
# Like Leptos #[island], marking a component as an island means:
# - It will be compiled to WebAssembly
# - It will hydrate on the client
# - Its signals and event handlers become interactive

"""
Definition of an interactive island component.

The `body` field stores the original function body expression (Expr) for JS compilation.
When present, `compile_island()` uses this directly instead of requiring a separate
registered hydration body. This ensures ONE body compiles to both SSR and JS.
"""
struct IslandDef
    name::Symbol
    render_fn::Function
    has_children::Bool
    body::Union{Expr, Nothing}
    prop_names::Vector{Symbol}  # keyword argument names (for JS prop hydration)
end

# Backward-compatible constructors
IslandDef(name::Symbol, render_fn::Function) = IslandDef(name, render_fn, false, nothing, Symbol[])
IslandDef(name::Symbol, render_fn::Function, has_children::Bool) = IslandDef(name, render_fn, has_children, nothing, Symbol[])
IslandDef(name::Symbol, render_fn::Function, has_children::Bool, body::Union{Expr, Nothing}) = IslandDef(name, render_fn, has_children, body, Symbol[])

"""
Marker wrapping children content for SSR rendering as `<therapy-children>`.

During SSR, ChildrenSlot renders as `<therapy-children>...content...</therapy-children>`.
During hydration, the parent island's cursor skips past this element.
"""
struct ChildrenSlot
    content::Any  # VNode or other renderable
end

"""
Rendered island ready for hydration.
"""
struct IslandVNode
    name::Symbol
    content::Any  # VNode or other renderable
    props::Dict{Symbol, Any}  # Serialized as data-props for hydration
end

IslandVNode(name::Symbol, content::Any) = IslandVNode(name, content, Dict{Symbol, Any}())

# Global registry of islands for auto-discovery
const ISLAND_REGISTRY = Dict{Symbol, IslandDef}()

# Registry for prop transforms — compute extra props for hydration (e.g., mode flags)
# Transform functions mutate the props dict in-place, adding computed keys.
const ISLAND_PROPS_TRANSFORMS = Dict{Symbol, Function}()

"""
    register_island_props_transform!(name::Symbol, f::Function)

Register a function `f(props::Dict{Symbol,Any}, args::Tuple)` that adds computed props
for hydration. Called during `IslandDef()(args...; kwargs...)` before SSR.
The `args` parameter provides access to positional children for counting items.
"""
register_island_props_transform!(name::Symbol, f::Function) = (ISLAND_PROPS_TRANSFORMS[name] = f)

"""
    @island function Counter(; initial=0) ... end

Define an interactive island component that compiles to JS.

The function's keyword arguments become the island's props interface.
Props are serialized as `data-props` JSON on the `<therapy-island>` tag
for hydration.

# Examples
```julia
@island function Counter(; initial=0)
    count, set_count = create_signal(initial)

    Div(:class => "flex gap-4",
        Button(:on_click => () -> set_count(count() - 1), "-"),
        Span(count),
        Button(:on_click => () -> set_count(count() + 1), "+")
    )
end

# Use with default props
Counter()

# Use with custom props
Counter(initial=5)
```
"""
macro island(expr)
    # Validate: must be a function definition
    if !_is_function_def(expr)
        error("@island requires a function definition: @island function Name(; kwargs...) ... end")
    end

    # Extract function name and create internal render function name
    fname = _extract_function_name(expr)

    # Enforce: all kwargs must have type annotations
    _check_kwarg_types(expr, fname)
    render_fname = Symbol("_island_render_", fname)
    name_sym = QuoteNode(fname)

    # Check if body references `children` (children slot support)
    # BUT skip if the function already declares `children` as a parameter
    # (e.g., Toggle(children...; ...) or Collapsible(children...; ...))
    body = _extract_function_body(expr)
    has_children = _body_references_children(body) && !_has_children_param(expr)

    # Rewrite the function definition to use the internal name
    expr_copy = _rename_function(expr, render_fname)

    # If body uses children, add children=nothing as first positional arg
    if has_children
        expr_copy = _add_children_param(expr_copy)
    end

    # Capture the original body expression for JS compilation
    body_expr = QuoteNode(body)

    # Extract keyword argument names for JS prop hydration
    prop_names_val = _extract_kwarg_names(expr)

    # Use GlobalRef to bind module-internal names at macro expansion time
    _IslandDef = GlobalRef(@__MODULE__, :IslandDef)
    _REGISTRY = GlobalRef(@__MODULE__, :ISLAND_REGISTRY)

    return esc(quote
        # Define the underlying render function with internal name
        $expr_copy

        # Register in ISLAND_REGISTRY and bind the user-visible name to IslandDef
        $fname = $_IslandDef($name_sym, $render_fname, $has_children, $body_expr, $prop_names_val)
        $_REGISTRY[$name_sym] = $fname
    end)
end

# Helper: check if an expression is a function definition
function _is_function_def(expr)
    expr isa Expr || return false
    if expr.head === :function
        return true
    end
    # Short-form: f(x) = ...
    if expr.head === :(=) && expr.args[1] isa Expr && expr.args[1].head === :call
        return true
    end
    false
end

# Helper: extract function name from a function definition AST
function _extract_function_name(expr)
    if expr.head === :function
        sig = expr.args[1]
        if sig isa Expr && sig.head === :call
            return sig.args[1]
        elseif sig isa Expr && sig.head === :where
            # function Name(...) where T
            call = sig.args[1]
            return call.args[1]
        end
    elseif expr.head === :(=)
        # Short-form: Name(x) = ...
        call = expr.args[1]
        return call.args[1]
    end
    error("Cannot extract function name from expression")
end

# Helper: rename the function in a function definition AST
function _rename_function(expr, new_name)
    expr = copy(expr)
    if expr.head === :function
        sig = copy(expr.args[1])
        if sig isa Expr && sig.head === :call
            sig.args[1] = new_name
        elseif sig isa Expr && sig.head === :where
            call = copy(sig.args[1])
            call.args[1] = new_name
            sig.args[1] = call
        end
        expr.args[1] = sig
    elseif expr.head === :(=)
        call = copy(expr.args[1])
        call.args[1] = new_name
        expr.args[1] = call
    end
    return expr
end

"""
    island(name::Symbol) do ... end -> IslandDef

Legacy syntax for defining islands. Prefer `@island function Name(...) end`.

!!! warning "Deprecated"
    Use `@island function Name(; kwargs...) ... end` instead.
    The `island(:Name) do ... end` syntax will be removed in a future version.
"""
function island(render_fn::Function, name::Symbol)
    Base.depwarn(
        "island(:$name) do ... end is deprecated. Use @island function $name(; kwargs...) ... end instead.",
        :island
    )
    def = IslandDef(name, render_fn)
    ISLAND_REGISTRY[name] = def
    return def
end

# Support island(:Name) do ... end syntax (deprecated)
island(name::Symbol) = render_fn -> island(render_fn, name)

"""
Make IslandDef callable - returns an IslandVNode for rendering.
Accepts both positional and keyword arguments.
Uses invokelatest to handle dynamically loaded islands.

When called with a do-block (e.g., `Wrapper() do; P("child"); end`), the
do-block function is the first positional arg. If the island has_children,
we call the function to get VNodes and wrap in ChildrenSlot.
"""
function (def::IslandDef)(args...; kwargs...)
    props = Dict{Symbol, Any}(kwargs...)

    # Apply props transform if registered (adds computed hydration props like _m, _c)
    if haskey(ISLAND_PROPS_TRANSFORMS, def.name)
        ISLAND_PROPS_TRANSFORMS[def.name](props, args)
    end

    # Handle children slot: if island has_children, always wrap in ChildrenSlot
    processed_args = if def.has_children && !isempty(args) && args[1] isa Function
        # Do-block: call function to get VNode content, wrap in ChildrenSlot
        children_content = Base.invokelatest(args[1])
        (ChildrenSlot(children_content), args[2:end]...)
    elseif def.has_children
        # No do-block: pass empty ChildrenSlot so <therapy-children> still appears in SSR
        (ChildrenSlot(nothing), args...)
    else
        args
    end

    content = if isempty(processed_args) && isempty(props)
        Base.invokelatest(def.render_fn)
    elseif isempty(processed_args)
        Base.invokelatest(def.render_fn; kwargs...)
    elseif isempty(props)
        Base.invokelatest(def.render_fn, processed_args...)
    else
        Base.invokelatest(def.render_fn, processed_args...; kwargs...)
    end
    return IslandVNode(def.name, content, props)
end

"""
Get all registered islands.
"""
get_islands() = values(ISLAND_REGISTRY)

"""
Get island by name.
"""
get_island(name::Symbol) = get(ISLAND_REGISTRY, name, nothing)

"""
Clear island registry (useful for reloading in dev mode).
"""
clear_islands!() = empty!(ISLAND_REGISTRY)

"""
Check if a name is a registered island.
"""
is_island(name::Symbol) = haskey(ISLAND_REGISTRY, name)

# ─── Kwarg Type Enforcement ───

"""
Check that all keyword arguments in an @island function have type annotations.
Error at macro expansion time if any kwarg is untyped.

Examples:
- `initial::Int64 = 0` → OK (typed with default)
- `title::String` → OK (typed, no default)
- `count = 0` → ERROR
- `title` → ERROR
"""
function _check_kwarg_types(expr, fname)
    sig = if expr.head === :function
        expr.args[1]
    elseif expr.head === :(=)
        expr.args[1]
    else
        return
    end
    sig isa Expr || return

    for arg in sig.args[2:end]
        arg isa Expr || continue
        if arg.head === :parameters
            for kwarg in arg.args
                # kwarg... splat — skip
                if kwarg isa Expr && kwarg.head === :...
                    continue
                end
                # Bare symbol: `title` — no type, no default
                if kwarg isa Symbol
                    error("@island $fname: kwarg `$kwarg` needs a type annotation. Fix: $kwarg::String")
                end
                # Expr with :kw head: `name = default` or `name::Type = default`
                if kwarg isa Expr && kwarg.head === :kw
                    name_part = kwarg.args[1]
                    # If name_part is just a Symbol, it has no type annotation
                    if name_part isa Symbol
                        error("@island $fname: kwarg `$name_part` needs a type annotation. Fix: $name_part::Type = $(kwarg.args[2])")
                    end
                    # If name_part is Expr with :: head, it's typed — OK
                end
                # Expr with :: head: `name::Type` (no default) — OK
            end
        end
    end
end

# ─── Prop / Kwarg Helpers ───

"""Extract keyword argument names from a function definition expression.
Returns a Vector{Symbol} of kwarg names (e.g., [:initial_open] for `CellToggle(; initial_open=1)`)."""
function _extract_kwarg_names(expr)
    sig = if expr.head === :function
        expr.args[1]
    elseif expr.head === :(=)
        expr.args[1]
    else
        return Symbol[]
    end
    sig isa Expr || return Symbol[]

    # Find the :parameters node (contains keyword arguments)
    names = Symbol[]
    for arg in sig.args[2:end]
        arg isa Expr || continue
        if arg.head === :parameters
            for kwarg in arg.args
                if kwarg isa Symbol
                    push!(names, kwarg)
                elseif kwarg isa Expr && kwarg.head === :kw
                    # Handle both `name = default` and `name::Type = default`
                    kw_name = kwarg.args[1]
                    if kw_name isa Symbol
                        push!(names, kw_name)
                    elseif kw_name isa Expr && kw_name.head === :(::) && kw_name.args[1] isa Symbol
                        push!(names, kw_name.args[1])
                    end
                elseif kwarg isa Expr && kwarg.head === :(::) && kwarg.args[1] isa Symbol
                    # Handle `name::Type` without default
                    push!(names, kwarg.args[1])
                elseif kwarg isa Expr && kwarg.head === :... && length(kwarg.args) >= 1 && kwarg.args[1] isa Symbol
                    # kwargs... splat — skip, not a named prop
                end
            end
        end
    end
    return names
end

# ─── Children Slot Helpers ───

"""Extract function body from a function definition expression."""
function _extract_function_body(expr)
    if expr.head === :function
        return expr.args[2]
    elseif expr.head === :(=)
        return expr.args[2]
    end
    return Expr(:block)
end

"""Check if an expression references the bare symbol `children`."""
function _body_references_children(expr)
    expr === :children && return true
    expr isa Expr || return false
    return any(_body_references_children, expr.args)
end

"""Check if a function definition already has `children` as a parameter (positional or varargs)."""
function _has_children_param(expr)
    sig = if expr.head === :function
        expr.args[1]
    elseif expr.head === :(=)
        expr.args[1]
    else
        return false
    end
    sig isa Expr || return false
    # Walk signature args (skip function name at position 1)
    for arg in sig.args[2:end]
        arg === :children && return true
        arg isa Expr || continue
        # children... → Expr(:..., :children)
        if arg.head === :... && length(arg.args) >= 1 && arg.args[1] === :children
            return true
        end
        # children=default → Expr(:kw, :children, default)
        if arg.head === :kw && length(arg.args) >= 1 && arg.args[1] === :children
            return true
        end
    end
    return false
end

"""Add `children=nothing` as first positional arg to a function definition."""
function _add_children_param(expr)
    expr = copy(expr)
    if expr.head === :function
        sig = copy(expr.args[1])
        if sig isa Expr && sig.head === :call
            sig.args = copy(sig.args)
            # When keyword args exist, :parameters node sits at position 2 —
            # positional args must come AFTER it in Julia's AST.
            insert_pos = 2
            if length(sig.args) >= 2 && sig.args[2] isa Expr && sig.args[2].head === :parameters
                insert_pos = 3
            end
            insert!(sig.args, insert_pos, Expr(:kw, :children, :nothing))
        end
        expr.args[1] = sig
    elseif expr.head === :(=)
        call = copy(expr.args[1])
        call.args = copy(call.args)
        insert_pos = 2
        if length(call.args) >= 2 && call.args[2] isa Expr && call.args[2].head === :parameters
            insert_pos = 3
        end
        insert!(call.args, insert_pos, Expr(:kw, :children, :nothing))
        expr.args[1] = call
    end
    return expr
end
