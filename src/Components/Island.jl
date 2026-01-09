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
end

# Global registry of islands for auto-discovery
const ISLAND_REGISTRY = Dict{Symbol, IslandDef}()

"""
    island(name::Symbol) do ... end -> IslandDef

Define an interactive island component that compiles to WASM.

Islands are the interactive parts of your app. Everything else is static HTML.
This follows the Leptos islands pattern - static by default, opt-in to interactivity.

# Examples
```julia
# Define an interactive counter
Counter = island(:Counter) do
    count, set_count = create_signal(0)

    Div(:class => "flex gap-4",
        Button(:on_click => () -> set_count(count() - 1), "-"),
        Span(count),
        Button(:on_click => () -> set_count(count() + 1), "+")
    )
end

# Use it in a route (auto-wrapped in <therapy-island>)
function Index()
    Layout(
        H1("My App"),
        Counter()  # Renders as interactive island
    )
end
```
"""
function island(render_fn::Function, name::Symbol)
    def = IslandDef(name, render_fn)
    ISLAND_REGISTRY[name] = def
    return def
end

# Support island(:Name) do ... end syntax
island(name::Symbol) = render_fn -> island(render_fn, name)

"""
Make IslandDef callable - returns an IslandVNode for rendering.
"""
function (def::IslandDef)()
    content = def.render_fn()
    return IslandVNode(def.name, content)
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
