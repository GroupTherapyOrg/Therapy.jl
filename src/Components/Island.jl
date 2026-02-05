# Island.jl - Interactive island components that compile to WASM
#
# Islands are the boundary between static SSR and interactive client code.
# Like Leptos #[island], marking a component as an island means:
# - It will be compiled to WebAssembly
# - It will hydrate on the client
# - Its signals and event handlers become interactive

"""
Definition of an interactive island component.
"""
struct IslandDef
    name::Symbol
    render_fn::Function
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

"""
    @island function Counter(; initial=0) ... end

Define an interactive island component that compiles to WASM.

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
    render_fname = Symbol("_island_render_", fname)
    name_sym = QuoteNode(fname)

    # Rewrite the function definition to use the internal name
    expr_copy = _rename_function(expr, render_fname)

    # Use GlobalRef to bind module-internal names at macro expansion time
    _IslandDef = GlobalRef(@__MODULE__, :IslandDef)
    _REGISTRY = GlobalRef(@__MODULE__, :ISLAND_REGISTRY)

    return esc(quote
        # Define the underlying render function with internal name
        $expr_copy

        # Register in ISLAND_REGISTRY and bind the user-visible name to IslandDef
        const $fname = $_IslandDef($name_sym, $render_fname)
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
Accepts keyword arguments as props.
Uses invokelatest to handle dynamically loaded islands.
"""
function (def::IslandDef)(; kwargs...)
    props = Dict{Symbol, Any}(kwargs...)
    content = if isempty(props)
        Base.invokelatest(def.render_fn)
    else
        Base.invokelatest(def.render_fn; kwargs...)
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
