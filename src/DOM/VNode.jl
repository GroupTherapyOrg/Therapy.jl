# VNode.jl - Virtual DOM node representation

"""
Raw HTML content that won't be escaped.
Use carefully - can introduce XSS if used with untrusted input.
"""
struct RawHtml
    content::String
end

"""
A virtual DOM node representing an HTML element or component.

VNodes are lightweight representations used for:
- Server-side rendering to HTML strings
- Client-side DOM construction
- Diffing and reconciliation
"""
struct VNode
    tag::Symbol
    props::Dict{Symbol, Any}
    children::Vector{Any}
end

"""
    VNode(tag::Symbol; kwargs...)

Create a VNode with the given tag and props.
"""
function VNode(tag::Symbol; kwargs...)
    VNode(tag, Dict{Symbol, Any}(kwargs), Any[])
end

"""
    VNode(tag::Symbol, children...; kwargs...)

Create a VNode with children and props.
"""
function VNode(tag::Symbol, children::Vararg{Any}; kwargs...)
    VNode(tag, Dict{Symbol, Any}(kwargs), collect(Any, children))
end

"""
Fragment for grouping multiple elements without a wrapper.
"""
struct Fragment
    children::Vector{Any}
end

Fragment(children...) = Fragment(collect(Any, children))

"""
A conditional render node that can be toggled by Wasm.
"""
struct ShowNode
    condition::Any         # Signal getter or function returning Bool or truthy value
    content::Any           # The rendered content (VNode, Fragment, etc.)
    initial_visible::Bool  # Initial visibility state
end

"""
    Show(condition) do ... end -> ShowNode

Conditionally render children based on a boolean condition.
Similar to SolidJS's <Show> component.

The condition should be a signal getter. When compiled to Wasm,
the visibility will be toggled dynamically.

# Examples
```julia
visible, set_visible = create_signal(true)

Show(visible) do
    Div("I'm visible!")
end
```
"""
function Show(render::Function, condition::Function)
    # Note: do-block syntax passes render first, condition second
    initial = condition()
    visible = !isnothing(initial) && initial != false && initial != 0
    content = render()
    ShowNode(condition, content, visible)
end

function Show(render::Function, condition::Bool)
    content = condition ? render() : nothing
    ShowNode(() -> condition, content, condition)
end

# Support SignalGetter directly as condition (for Wasm compilation)
function Show(render::Function, condition::SignalGetter)
    initial = condition()
    visible = !isnothing(initial) && initial != false && initial != 0
    content = render()
    ShowNode(condition, content, visible)
end

# Positional syntax: Show(condition, render)
function Show(condition::Bool, render::Function)
    if condition
        render()  # Return the content directly when true
    else
        nothing   # Return nothing when false
    end
end

"""
Parse mixed args into props dict and children vector.
Handles both keyword-style props and positional children.
"""
function parse_element_args(args...; kwargs...)
    props = Dict{Symbol, Any}(kwargs)
    children = Any[]

    for arg in args
        if arg isa Pair{Symbol, <:Any}
            props[arg.first] = arg.second
        elseif arg isa Dict
            merge!(props, arg)
        else
            push!(children, arg)
        end
    end

    return props, children
end

"""
A list render node for iterating over collections.
Similar to SolidJS's <For> component.
"""
struct ForNode
    items::Any           # Items to iterate (can be signal getter or vector)
    render::Function     # Function that takes (item, index) and returns VNode
end

"""
    For(items) do item, index
        ...
    end -> ForNode

Render a list of items.

# Examples
```julia
items, set_items = create_signal(["a", "b", "c"])

For(items) do item, index
    Li(item)
end
```
"""
function For(render::Function, items)
    ForNode(items, render)
end

# Alternative syntax: For(items, render)
function For(items, render::Function)
    ForNode(items, render)
end
