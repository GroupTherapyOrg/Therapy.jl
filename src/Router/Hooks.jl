# Hooks.jl - Reactive route hooks for Therapy.jl
#
# Provides leptos-style reactive hooks for accessing route parameters and query strings.
# These hooks integrate with the reactivity system to enable components that
# automatically update when route changes occur.

"""
    RouteParams

Represents the current route parameters as a reactive context.
This is set by the router when handling requests and can be accessed
via the `use_params` hook.
"""
struct RouteParams
    params::Dict{Symbol, String}
end

"""
    RouteQuery

Represents the current query string parameters as a reactive context.
This is set by the router when handling requests and can be accessed
via the `use_query` hook.
"""
struct RouteQuery
    query::Dict{Symbol, String}
end

# Global signals for route state (reactive on client-side)
# These are updated by the router during navigation
const ROUTE_PARAMS = Ref{Dict{Symbol, String}}(Dict{Symbol, String}())
const ROUTE_QUERY = Ref{Dict{Symbol, String}}(Dict{Symbol, String}())
const ROUTE_PATH = Ref{String}("/")

# Subscribers that get notified when route changes
const ROUTE_PARAMS_SUBSCRIBERS = Set{Any}()
const ROUTE_QUERY_SUBSCRIBERS = Set{Any}()

"""
    set_route_params!(params::Dict{Symbol, String})

Internal function to set the current route parameters.
Called by the router during request handling.
"""
function set_route_params!(params::Dict{Symbol, String})
    ROUTE_PARAMS[] = params
    # Notify all subscribers
    for effect in ROUTE_PARAMS_SUBSCRIBERS
        try
            run_effect!(effect)
        catch e
            @warn "Error running route params subscriber" exception=e
        end
    end
end

"""
    set_route_query!(query::Dict{Symbol, String})

Internal function to set the current query parameters.
Called by the router during request handling.
"""
function set_route_query!(query::Dict{Symbol, String})
    ROUTE_QUERY[] = query
    # Notify all subscribers
    for effect in ROUTE_QUERY_SUBSCRIBERS
        try
            run_effect!(effect)
        catch e
            @warn "Error running route query subscriber" exception=e
        end
    end
end

"""
    set_route_path!(path::String)

Internal function to set the current route path.
Called by the router during request handling.
"""
function set_route_path!(path::String)
    ROUTE_PATH[] = path
end

"""
    use_params() -> Dict{Symbol, String}
    use_params(key::Symbol) -> Union{String, Nothing}
    use_params(key::Symbol, default::String) -> String

Reactive hook to access current route parameters.

When called without arguments, returns the entire params dictionary.
When called with a key, returns that specific parameter value.
When called with a key and default, returns the parameter or the default.

This hook is reactive - components using it will re-render when
route parameters change (via client-side navigation).

# Examples
```julia
# In a route like /users/[id].jl
function UserPage()
    params = use_params()
    user_id = params[:id]

    Div(
        H1("User Profile"),
        P("User ID: ", user_id)
    )
end

# Or get a specific param with default
function ProductPage()
    product_id = use_params(:id, "unknown")

    Div("Product: ", product_id)
end

# Get a specific param (may be nothing)
function SearchPage()
    category = use_params(:category)  # Union{String, Nothing}

    if category === nothing
        return Div("All categories")
    end
    Div("Category: ", category)
end
```

# Note
For SSR, the params are set by the router before rendering.
For client-side navigation, params update reactively via JavaScript.
"""
function use_params()::Dict{Symbol, String}
    # Register with current effect for reactivity
    effect = current_effect()
    if effect !== nothing
        push!(ROUTE_PARAMS_SUBSCRIBERS, effect)
    end
    return ROUTE_PARAMS[]
end

function use_params(key::Symbol)::Union{String, Nothing}
    params = use_params()
    return get(params, key, nothing)
end

function use_params(key::Symbol, default::String)::String
    params = use_params()
    return get(params, key, default)
end

"""
    use_query() -> Dict{Symbol, String}
    use_query(key::Symbol) -> Union{String, Nothing}
    use_query(key::Symbol, default::String) -> String

Reactive hook to access current query string parameters.

When called without arguments, returns the entire query dictionary.
When called with a key, returns that specific query parameter value.
When called with a key and default, returns the parameter or the default.

This hook is reactive - components using it will re-render when
query parameters change (via client-side navigation).

# Examples
```julia
# Access query params like ?page=2&sort=name
function SearchResults()
    query = use_query()
    page = get(query, :page, "1")
    sort = get(query, :sort, "date")

    Div(
        P("Page: ", page),
        P("Sort by: ", sort)
    )
end

# Or get a specific param
function FilteredList()
    filter = use_query(:filter, "all")

    Div("Showing: ", filter)
end
```

# Note
For SSR, the query params are parsed from the URL before rendering.
For client-side navigation, query updates reactively via JavaScript.
"""
function use_query()::Dict{Symbol, String}
    # Register with current effect for reactivity
    effect = current_effect()
    if effect !== nothing
        push!(ROUTE_QUERY_SUBSCRIBERS, effect)
    end
    return ROUTE_QUERY[]
end

function use_query(key::Symbol)::Union{String, Nothing}
    query = use_query()
    return get(query, key, nothing)
end

function use_query(key::Symbol, default::String)::String
    query = use_query()
    return get(query, key, default)
end

"""
    use_location() -> String

Reactive hook to access the current route path.

# Example
```julia
function Breadcrumb()
    path = use_location()

    Div(:class => "breadcrumb",
        "Current path: ", path
    )
end
```
"""
function use_location()::String
    return ROUTE_PATH[]
end

"""
    parse_query_string(query_string::String) -> Dict{Symbol, String}

Parse a query string into a dictionary of parameters.
Handles URL decoding.

# Example
```julia
parse_query_string("page=2&sort=name&filter=active")
# Returns: Dict(:page => "2", :sort => "name", :filter => "active")
```
"""
function parse_query_string(query_string::String)::Dict{Symbol, String}
    result = Dict{Symbol, String}()
    isempty(query_string) && return result

    # Remove leading ? if present
    query_string = lstrip(query_string, '?')

    for part in split(query_string, '&')
        isempty(part) && continue

        if contains(part, '=')
            key, value = split(part, '=', limit=2)
            # URL decode
            key = decode_uri_component(key)
            value = decode_uri_component(value)
            result[Symbol(key)] = value
        else
            # Key without value, treat as empty string
            key = decode_uri_component(part)
            result[Symbol(key)] = ""
        end
    end

    return result
end

"""
    decode_uri_component(str::AbstractString) -> String

Decode a URL-encoded string (percent-encoding).
"""
function decode_uri_component(str::AbstractString)::String
    # Convert to String if needed
    s = String(str)

    # Simple URL decoding
    s = replace(s, '+' => ' ')

    # Replace %XX patterns
    result = IOBuffer()
    i = 1
    while i <= length(s)
        if s[i] == '%' && i + 2 <= length(s)
            try
                hex = s[i+1:i+2]
                char = Char(parse(UInt8, hex, base=16))
                write(result, char)
                i += 3
            catch
                write(result, s[i])
                i += 1
            end
        else
            write(result, s[i])
            i += 1
        end
    end
    return String(take!(result))
end

"""
    encode_uri_component(str::AbstractString) -> String

Encode a string for use in a URL (percent-encoding).
"""
function encode_uri_component(str::AbstractString)::String
    result = IOBuffer()
    for char in str
        # Check if alphanumeric or unreserved
        if isletter(char) || isdigit(char) || char in ['-', '_', '.', '~']
            write(result, char)
        else
            for byte in codeunits(string(char))
                write(result, '%')
                write(result, uppercase(string(byte, base=16, pad=2)))
            end
        end
    end
    return String(take!(result))
end

# Cleanup function to remove disposed effects from subscribers
function cleanup_route_subscribers!()
    # This would be called by the effect disposal system
    # to remove dead subscribers
    filter!(e -> !isdisposed(e), ROUTE_PARAMS_SUBSCRIBERS)
    filter!(e -> !isdisposed(e), ROUTE_QUERY_SUBSCRIBERS)
end

# Helper to check if an effect is disposed
function isdisposed(effect)
    try
        return effect.disposed
    catch
        return false
    end
end
