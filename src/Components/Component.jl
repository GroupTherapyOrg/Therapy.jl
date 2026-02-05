# Component.jl - Component definition and instantiation

"""
Definition of a reusable component.
"""
struct ComponentDef
    name::Symbol
    render::Function
end

"""
Instance of a component with props.
"""
struct ComponentInstance
    def::ComponentDef
    props::Props
end

"""
    component(name::Symbol, render::Function) -> ComponentDef
    component(name::Symbol) do props ... end -> ComponentDef

Define a reusable component.

# Examples
```julia
# Simple component
Greeting = component(:Greeting) do props
    name = get_prop(props, :name, "World")
    P("Hello, ", name, "!")
end

# Use the component
Greeting(:name => "Julia")

# Component with children
Card = component(:Card) do props
    Div(:class => "card",
        Div(:class => "card-title", get_prop(props, :title)),
        Div(:class => "card-body", get_children(props)...)
    )
end

# Use with children
Card(:title => "My Card",
    P("Card content here")
)
```
"""
function component(render::Function, name::Symbol)
    def = ComponentDef(name, render)

    # Return a callable that creates instances
    return function(args...; kwargs...)
        props_data, children = parse_element_args(args...; kwargs...)
        props = Props(props_data, children)
        ComponentInstance(def, props)
    end
end

# Also support component(:Name) do ... end syntax
component(name::Symbol) = render -> component(render, name)

"""
Render a component instance to a VNode.
Uses invokelatest to handle dynamically loaded components.
"""
function render_component(instance::ComponentInstance)
    Base.invokelatest(instance.def.render, instance.props)
end

# Make ComponentInstance callable for nesting
function (instance::ComponentInstance)()
    render_component(instance)
end

"""
Expand a VNode tree recursively.

Handles VNode, Fragment, Vector, and ComponentInstance (deprecated, for backward compat).
"""
function expand_tree(node)
    if node isa ComponentInstance
        # Deprecated path: ComponentInstance from legacy component() calls
        expand_tree(render_component(node))
    elseif node isa VNode
        VNode(
            node.tag,
            node.props,
            [expand_tree(child) for child in node.children]
        )
    elseif node isa Fragment
        Fragment([expand_tree(child) for child in node.children])
    elseif node isa Vector
        [expand_tree(child) for child in node]
    else
        node
    end
end
