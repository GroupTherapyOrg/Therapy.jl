# Outlet.jl - Nested route rendering for Therapy.jl
#
# Provides the Outlet component for rendering child routes within parent layouts.
# This enables Leptos-style nested routing where parent routes wrap child content.
#
# Example:
#   routes/
#     users/
#       _layout.jl      -> Layout for all /users/* routes
#       index.jl        -> /users
#       [id].jl         -> /users/:id
#       [id]/
#         posts.jl      -> /users/:id/posts
#
# In _layout.jl:
#   function UsersLayout()
#       Div(:class => "users-container",
#           Sidebar(),
#           Outlet()  # Child routes render here
#       )
#   end

"""
    OutletContext

Context for tracking the current route stack during nested route rendering.
Each nested level pushes its child content onto the stack.
"""
mutable struct OutletContext
    # Stack of child content to render (VNodes or functions)
    child_stack::Vector{Any}
    # Current params being passed down
    params::Dict{Symbol, String}
end

# Global outlet context stack
const OUTLET_CONTEXT_STACK = Vector{OutletContext}()

"""
    push_outlet_context!(ctx::OutletContext)

Push an outlet context onto the stack for nested rendering.
"""
function push_outlet_context!(ctx::OutletContext)
    push!(OUTLET_CONTEXT_STACK, ctx)
end

"""
    pop_outlet_context!()

Pop the current outlet context from the stack.
"""
function pop_outlet_context!()
    if !isempty(OUTLET_CONTEXT_STACK)
        pop!(OUTLET_CONTEXT_STACK)
    end
end

"""
    current_outlet_context() -> Union{OutletContext, Nothing}

Get the current outlet context if one exists.
"""
function current_outlet_context()
    isempty(OUTLET_CONTEXT_STACK) ? nothing : OUTLET_CONTEXT_STACK[end]
end

"""
    set_outlet_child!(content)

Set the child content to be rendered by the next Outlet() call.
Called by the router when rendering nested routes.
"""
function set_outlet_child!(content)
    ctx = current_outlet_context()
    if ctx !== nothing
        push!(ctx.child_stack, content)
    end
end

"""
    get_outlet_child() -> Any

Get and consume the next child content to render.
Returns nothing if no child content is available.
"""
function get_outlet_child()
    ctx = current_outlet_context()
    if ctx === nothing || isempty(ctx.child_stack)
        return nothing
    end
    return pop!(ctx.child_stack)
end

# OutletNode is defined in DOM/VNode.jl to ensure it's available before SSR/Render.jl

"""
    Outlet(; fallback=nothing) -> OutletNode

Create an Outlet placeholder for nested route content.

The Outlet component marks where child route content should be rendered
within a parent layout. When a nested route matches, its content replaces
the Outlet.

# Arguments
- `fallback`: Optional content to render when no child route matches

# Example
```julia
# In a layout file (e.g., users/_layout.jl)
function UsersLayout()
    Div(:class => "users-page",
        # Navigation stays visible for all /users/* routes
        Nav(
            NavLink("/users/", "All Users"),
            NavLink("/users/new", "New User")
        ),

        # Child route content renders here
        Main(:class => "content",
            Outlet()
        )
    )
end

# When navigating to /users/, the Outlet renders the users/index.jl content
# When navigating to /users/123, the Outlet renders the users/[id].jl content
```

# Fallback Example
```julia
function AdminLayout()
    Div(
        Header("Admin Panel"),
        Outlet(fallback = P("Select a section from the menu"))
    )
end
```
"""
function Outlet(; fallback=nothing)
    OutletNode(fallback)
end

"""
    render_outlet(node::OutletNode) -> VNode

Render an OutletNode by fetching the child content from the context.
Called during SSR to resolve the placeholder to actual content.
"""
function render_outlet(node::OutletNode)
    child = get_outlet_child()

    if child === nothing
        # No child route content - use fallback if provided
        if node.fallback !== nothing
            return node.fallback isa Function ? node.fallback() : node.fallback
        else
            # Return an empty div placeholder
            return VNode(:div, Dict{Symbol, Any}(:data_outlet => "empty"), Any[])
        end
    end

    # Render the child content
    if child isa Function
        return child()
    else
        return child
    end
end

"""
    with_outlet_context(f, params::Dict{Symbol, String})

Execute a function within a new outlet context.
Used by the router when rendering nested routes.
"""
function with_outlet_context(f, params::Dict{Symbol, String}=Dict{Symbol, String}())
    ctx = OutletContext(Any[], params)
    push_outlet_context!(ctx)
    try
        return f()
    finally
        pop_outlet_context!()
    end
end

"""
    NestedRoute

Represents a nested route configuration with parent and children.
Used for programmatic route definitions (alternative to file-based).
"""
struct NestedRoute
    path::String
    component::Any  # Function that returns VNode
    children::Vector{NestedRoute}
end

"""
    NestedRoute(path, component; children=[])

Create a nested route definition.

# Example
```julia
routes = NestedRoute("/users", UsersLayout, children=[
    NestedRoute("", UsersIndex),           # /users
    NestedRoute(":id", UserDetail),        # /users/:id
    NestedRoute(":id/posts", UserPosts)    # /users/:id/posts
])
```
"""
function NestedRoute(path::String, component; children::Vector{NestedRoute}=NestedRoute[])
    NestedRoute(path, component, children)
end

"""
    match_nested_route(routes::Vector{NestedRoute}, path::String) -> Vector{Tuple{NestedRoute, Dict{Symbol,String}}}

Match a path against nested routes, returning the matched route stack.
The stack includes all parent routes that need to be rendered.
"""
function match_nested_route(routes::Vector{NestedRoute}, path::String)
    path = isempty(path) ? "/" : path
    startswith(path, "/") || (path = "/" * path)
    length(path) > 1 && endswith(path, "/") && (path = path[1:end-1])

    path_parts = split(path, "/"; keepempty=false)

    function match_recursive(routes::Vector{NestedRoute}, remaining_parts::Vector, matched_stack::Vector, params::Dict{Symbol, String})
        for route in routes
            route_parts = split(route.path, "/"; keepempty=false)

            # Try to match this route's path segment
            new_params = copy(params)
            if try_match_parts(route_parts, remaining_parts, new_params)
                consumed = isempty(route_parts) ? 0 : length(route_parts)
                new_remaining = remaining_parts[consumed+1:end]

                new_stack = push!(copy(matched_stack), (route, new_params))

                # If no more path remaining
                if isempty(new_remaining)
                    # Try to match an index child (empty path) if this route has children
                    if !isempty(route.children)
                        for child in route.children
                            if isempty(child.path) || child.path == ""
                                # Found index child, add it to the stack
                                return push!(copy(new_stack), (child, new_params))
                            end
                        end
                    end
                    # No index child, return current stack
                    return new_stack
                end

                # Try to match children
                if !isempty(route.children)
                    result = match_recursive(route.children, new_remaining, new_stack, new_params)
                    if result !== nothing
                        return result
                    end
                end
            end
        end

        return nothing
    end

    return match_recursive(routes, collect(path_parts), Tuple{NestedRoute, Dict{Symbol,String}}[], Dict{Symbol, String}())
end

"""
Helper to match path segments against route pattern segments.
"""
function try_match_parts(route_parts::Vector, path_parts::Vector, params::Dict{Symbol, String})
    # Empty route pattern matches at this level
    if isempty(route_parts)
        return true
    end

    # Not enough path parts
    if length(route_parts) > length(path_parts)
        return false
    end

    for (i, route_part) in enumerate(route_parts)
        path_part = path_parts[i]

        if startswith(route_part, ":")
            # Dynamic parameter
            param_name = route_part[2:end]
            params[Symbol(param_name)] = String(path_part)
        elseif route_part == "*"
            # Catch-all
            params[:rest] = join(path_parts[i:end], "/")
            return true
        elseif route_part != path_part
            return false
        end
    end

    return true
end

"""
    render_nested_routes(matched_stack::Vector{Tuple{NestedRoute, Dict{Symbol,String}}}, params::Dict{Symbol,String}) -> VNode

Render a stack of matched nested routes with proper Outlet context.
"""
function render_nested_routes(matched_stack::Vector, params::Dict{Symbol, String})
    if isempty(matched_stack)
        return nothing
    end

    # Merge all params from the matched stack
    merged_params = Dict{Symbol, String}()
    for (_, route_params) in matched_stack
        merge!(merged_params, route_params)
    end

    # Render from innermost to outermost, setting up outlet context
    function render_level(idx)
        if idx > length(matched_stack)
            return nothing
        end

        route, _ = matched_stack[idx]

        with_outlet_context(merged_params) do
            # Set up the child content for Outlet to render
            if idx < length(matched_stack)
                child_content = render_level(idx + 1)
                set_outlet_child!(child_content)
            end

            # Render this level's component
            if route.component isa Function
                return route.component()
            else
                return route.component
            end
        end
    end

    return render_level(1)
end
