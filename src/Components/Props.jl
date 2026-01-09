# Props.jl - Component props handling

"""
Props container for component properties.
Provides typed access to component props with defaults.
"""
struct Props
    data::Dict{Symbol, Any}
    children::Vector{Any}
end

Props() = Props(Dict{Symbol, Any}(), Any[])
Props(data::Dict) = Props(data, Any[])
Props(data::Dict, children::Vector) = Props(data, children)

"""
    get_prop(props::Props, key::Symbol, default=nothing)

Get a prop value with optional default.

# Examples
```julia
component(:Greeting) do props
    name = get_prop(props, :name, "World")
    P("Hello, ", name, "!")
end
```
"""
function get_prop(props::Props, key::Symbol, default=nothing)
    get(props.data, key, default)
end

"""
    get_prop(props::Props, key::Symbol, ::Type{T}, default::T) where T

Get a typed prop value.
"""
function get_prop(props::Props, key::Symbol, ::Type{T}, default::T) where T
    val = get(props.data, key, default)
    val isa T ? val : default
end

"""
    get_children(props::Props)

Get component children.
"""
function get_children(props::Props)
    props.children
end

"""
    has_prop(props::Props, key::Symbol)

Check if a prop exists.
"""
function has_prop(props::Props, key::Symbol)
    haskey(props.data, key)
end

# Enable props.key syntax via getproperty
function Base.getproperty(props::Props, key::Symbol)
    if key == :data
        getfield(props, :data)
    elseif key == :children
        getfield(props, :children)
    else
        get_prop(props, key)
    end
end

# Enable iteration over props
Base.keys(props::Props) = keys(props.data)
Base.values(props::Props) = values(props.data)
Base.iterate(props::Props) = iterate(props.data)
Base.iterate(props::Props, state) = iterate(props.data, state)
Base.length(props::Props) = length(props.data)
