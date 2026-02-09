# Router.jl - File-path based routing like Next.js
#
# Directory structure:
#   routes/
#     index.jl        -> /
#     about.jl        -> /about
#     users/
#       index.jl      -> /users
#       [id].jl       -> /users/:id  (dynamic param)
#     posts/
#       [...slug].jl  -> /posts/*    (catch-all)

# Include client-side router functionality
include("ClientRouter.jl")

# Include reactive route hooks (use_params, use_query)
include("Hooks.jl")

# Include nested routing and Outlet support
include("Outlet.jl")

"""
Represents a route with its path pattern and handler.
"""
struct Route
    pattern::String           # URL pattern like "/users/:id"
    file_path::String         # File path to the route module
    params::Vector{Symbol}    # Parameter names like [:id]
    is_catch_all::Bool        # Whether this is a [...slug] route
    layout_path::Union{String, Nothing}  # Optional layout file path
    parent_layouts::Vector{String}       # Stack of parent layout paths
end

# Constructor with defaults for backwards compatibility
function Route(pattern::String, file_path::String, params::Vector{Symbol}, is_catch_all::Bool)
    Route(pattern, file_path, params, is_catch_all, nothing, String[])
end

"""
Router configuration and state.
"""
mutable struct Router
    routes::Vector{Route}
    routes_dir::String
    layout::Union{Function, Nothing}  # Optional global layout wrapper
    layouts::Dict{String, Function}   # Cached layout functions by path
end

"""
    create_router(routes_dir::String; layout=nothing) -> Router

Create a router by scanning the routes directory.

Supports nested layouts via `_layout.jl` files. When a directory contains
a `_layout.jl` file, all routes in that directory and subdirectories will
be wrapped with that layout. The layout should use `Outlet()` to render
child content.

# Example
```julia
router = create_router("routes")
# Scans routes/ directory and builds route table

# Directory structure with layouts:
# routes/
#   _layout.jl        -> Global layout (nav + footer)
#   index.jl          -> / (wrapped by _layout.jl)
#   users/
#     _layout.jl      -> Users section layout
#     index.jl        -> /users (wrapped by both layouts)
#     [id].jl         -> /users/:id (wrapped by both layouts)
```
"""
function create_router(routes_dir::String; layout=nothing)
    routes = Route[]

    if isdir(routes_dir)
        scan_routes!(routes, routes_dir, routes_dir, String[])
    end

    # Sort routes: specific routes before dynamic, catch-all last
    sort!(routes, by=route_priority)

    Router(routes, routes_dir, layout, Dict{String, Function}())
end

"""
Priority for route sorting (lower = higher priority).
"""
function route_priority(route::Route)
    score = 0
    if route.is_catch_all
        score += 1000
    end
    score += length(route.params) * 10
    score += count('/', route.pattern)
    return score
end

"""
Recursively scan a directory for route files.
Collects _layout.jl files to build the layout stack for nested routing.
"""
function scan_routes!(routes::Vector{Route}, base_dir::String, current_dir::String, parent_layouts::Vector{String})
    # Check for layout file in current directory
    layout_path = joinpath(current_dir, "_layout.jl")
    current_layouts = if isfile(layout_path)
        vcat(parent_layouts, [layout_path])
    else
        parent_layouts
    end

    for entry in readdir(current_dir)
        full_path = joinpath(current_dir, entry)

        if isdir(full_path)
            scan_routes!(routes, base_dir, full_path, current_layouts)
        elseif endswith(entry, ".jl") && entry != "_layout.jl"
            route = parse_route_file(base_dir, full_path, current_layouts)
            if route !== nothing
                push!(routes, route)
            end
        end
    end
end

"""
Parse a route file path into a Route struct.
"""
function parse_route_file(base_dir::String, file_path::String, layouts::Vector{String}=String[])
    rel_path = relpath(file_path, base_dir)
    rel_path = replace(rel_path, r"\.jl$" => "")

    # Handle index files
    if endswith(rel_path, "index")
        rel_path = replace(rel_path, r"/?index$" => "")
    end

    parts = split(rel_path, ['/', '\\'])
    pattern_parts = String[]
    params = Symbol[]
    is_catch_all = false

    for part in parts
        isempty(part) && continue

        if startswith(part, "[...") && endswith(part, "]")
            # Catch-all: [...slug]
            param_name = part[5:end-1]
            push!(params, Symbol(param_name))
            push!(pattern_parts, "*")
            is_catch_all = true
        elseif startswith(part, "[") && endswith(part, "]")
            # Dynamic: [id]
            param_name = part[2:end-1]
            push!(params, Symbol(param_name))
            push!(pattern_parts, ":" * param_name)
        else
            push!(pattern_parts, part)
        end
    end

    pattern = "/" * join(pattern_parts, "/")
    pattern == "/" || (pattern = rstrip(pattern, '/'))

    # Get the most specific layout (last in the stack) for this route's directory
    layout_path = isempty(layouts) ? nothing : layouts[end]

    return Route(pattern, file_path, params, is_catch_all, layout_path, copy(layouts))
end

"""
Match a URL path against the router's routes.
Returns (route, params) or (nothing, nothing).
"""
function match_route(router::Router, path::String)
    path = isempty(path) ? "/" : path
    startswith(path, "/") || (path = "/" * path)
    length(path) > 1 && endswith(path, "/") && (path = path[1:end-1])

    for route in router.routes
        params = try_match(route, path)
        if params !== nothing
            return (route, params)
        end
    end

    return (nothing, nothing)
end

"""
Try to match a path against a route pattern.
"""
function try_match(route::Route, path::String)
    route_parts = split(route.pattern, "/"; keepempty=false)
    path_parts = split(path, "/"; keepempty=false)

    # Handle root
    if isempty(route_parts) && isempty(path_parts)
        return Dict{Symbol, String}()
    end

    params = Dict{Symbol, String}()
    param_idx = 1

    for (i, route_part) in enumerate(route_parts)
        if route_part == "*"
            # Catch-all
            if param_idx <= length(route.params)
                params[route.params[param_idx]] = join(path_parts[i:end], "/")
            end
            return params
        elseif startswith(route_part, ":")
            # Dynamic param
            i > length(path_parts) && return nothing
            if param_idx <= length(route.params)
                params[route.params[param_idx]] = path_parts[i]
                param_idx += 1
            end
        else
            # Static segment
            (i > length(path_parts) || path_parts[i] != route_part) && return nothing
        end
    end

    # Check all path parts consumed
    !route.is_catch_all && length(path_parts) != length(route_parts) && return nothing

    return params
end

"""
    handle_request(router::Router, path::String; query_string::String="") -> (html::String, route::Route, params::Dict)

Handle an HTTP request by matching the route and rendering the page.

Supports nested layouts via `_layout.jl` files. When a route has parent layouts,
they are rendered from outermost to innermost, with each layout using `Outlet()`
to render its child content.

# Arguments
- `router`: The Router instance
- `path`: The URL path (e.g., "/users/123")
- `query_string`: Optional query string (e.g., "page=2&sort=name")
"""
function handle_request(router::Router, path::String; query_string::String="")
    route, params = match_route(router, path)

    if route === nothing
        # 404
        return ("<h1>404 - Not Found</h1>", nothing, Dict{Symbol,String}())
    end

    # Set route state for reactive hooks (use_params, use_query)
    set_route_params!(params)
    set_route_path!(path)
    if !isempty(query_string)
        set_route_query!(parse_query_string(query_string))
    else
        set_route_query!(Dict{Symbol, String}())
    end

    # Load and render the route with nested layouts
    page_content = render_with_layouts(router, route, params)

    # Apply global layout if present (wraps everything)
    if router.layout !== nothing
        page_content = router.layout(page_content, params)
    end

    html = render_to_string(page_content)
    return (html, route, params)
end

"""
    render_with_layouts(router::Router, route::Route, params::Dict) -> VNode

Render a route with its nested layout stack.
Layouts are rendered from outermost to innermost, each using Outlet()
to render child content.
"""
function render_with_layouts(router::Router, route::Route, params::Dict{Symbol, String})
    # Load the page component
    page_fn = load_route(route)
    page_content = Base.invokelatest(page_fn, params)

    # If no layouts, just return the page content
    if isempty(route.parent_layouts)
        return page_content
    end

    # Load all layout functions
    layout_fns = Function[]
    for layout_path in route.parent_layouts
        layout_fn = get!(router.layouts, layout_path) do
            load_layout(layout_path)
        end
        push!(layout_fns, layout_fn)
    end

    # Render from innermost to outermost
    # Start with the page content, then wrap with each layout
    current_content = page_content

    for i in length(layout_fns):-1:1
        layout_fn = layout_fns[i]
        inner_content = current_content  # Capture for closure

        # Render layout with outlet context
        current_content = with_outlet_context(params) do
            set_outlet_child!(inner_content)
            Base.invokelatest(layout_fn, params)
        end
    end

    return current_content
end

"""
    load_layout(layout_path::String) -> Function

Load a layout file and return its layout function.
"""
function load_layout(layout_path::String)
    if !isfile(layout_path)
        error("Layout file not found: $layout_path")
    end

    mod = include(layout_path)
    if mod isa Function
        return mod
    else
        error("Layout $(layout_path) must return a function")
    end
end

"""
Load a route file and return its Page function.
"""
function load_route(route::Route)
    # The route file should return a function that takes params
    mod = include(route.file_path)
    if mod isa Function
        return mod
    else
        error("Route $(route.file_path) must return a function")
    end
end

"""
    NavLink(href::String, children...; class="", active_class="active", inactive_class="", exact=false)

Navigation link that uses client-side routing and highlights when active.

Uses a three-class model to avoid CSS conflicts:
- `class`: Always-on structural classes (e.g. `text-sm font-medium transition-colors`)
- `active_class`: Added when active, removed when inactive (e.g. `text-accent-700 font-semibold`)
- `inactive_class`: Added when inactive, removed when active (e.g. `text-warm-600 hover:text-accent-600`)

On server render, `class` and `inactive_class` are both applied (inactive is the default state).
The client-side router swaps `inactive_class` ↔ `active_class` on navigation.

# Arguments
- `href`: The destination path
- `class`: CSS classes always applied to the link
- `active_class`: CSS classes added when link matches current route (default: "active")
- `inactive_class`: CSS classes added when link does NOT match current route (default: "")
- `exact`: Only match path exactly, not prefix match (default: false)

# Example
```julia
NavLink("/about", "About Us")
NavLink("/", "Home",
    class="text-sm font-medium transition-colors",
    active_class="text-accent-700 font-semibold",
    inactive_class="text-warm-600 hover:text-accent-600",
    exact=true)
```
"""
function NavLink(href::String, children...; class::String="", active_class::String="active", inactive_class::String="", exact::Bool=false, kwargs...)
    props = Dict{Symbol, Any}(kwargs...)
    props[:href] = href
    # Server render: structural class + inactive_class (default state)
    full_class = isempty(inactive_class) ? class : (isempty(class) ? inactive_class : class * " " * inactive_class)
    props[:class] = full_class
    props[:data_navlink] = "true"
    props[:data_active_class] = active_class
    if !isempty(inactive_class)
        props[:data_inactive_class] = inactive_class
    end
    if exact
        props[:data_exact] = "true"
    end
    VNode(:a, props, collect(Any, children))
end

"""
Generate the client-side router JavaScript.
"""
function router_script()
    RawHtml("""
<script>
// Therapy.jl Client-Side Router
(function() {
    function navigate(href) {
        history.pushState({}, '', href);
        loadPage(href);
    }

    function loadPage(href) {
        fetch(href, { headers: { 'X-Therapy-Partial': '1' } })
            .then(r => r.text())
            .then(html => {
                document.getElementById('app').innerHTML = html;
                updateNavLinks();
                // Re-hydrate Wasm
                if (window.TherapyHydrate) window.TherapyHydrate();
            });
    }

    function updateNavLinks() {
        document.querySelectorAll('[data-navlink]').forEach(link => {
            const activeClass = link.dataset.activeClass || 'active';
            if (link.getAttribute('href') === window.location.pathname) {
                link.classList.add(activeClass);
            } else {
                link.classList.remove(activeClass);
            }
        });
    }

    // Handle link clicks
    document.addEventListener('click', e => {
        const link = e.target.closest('a[data-navlink]');
        if (link) {
            e.preventDefault();
            navigate(link.getAttribute('href'));
        }
    });

    // Handle back/forward
    window.addEventListener('popstate', () => loadPage(window.location.pathname));

    // Initial nav link state
    updateNavLinks();
})();
</script>
""")
end

"""
Print the route table for debugging.
"""
function print_routes(router::Router)
    println("Routes:")
    for route in router.routes
        params_str = isempty(route.params) ? "" : " ($(join(route.params, ", ")))"
        println("  $(route.pattern)$(params_str) -> $(route.file_path)")
    end
end
