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

"""
Represents a route with its path pattern and handler.
"""
struct Route
    pattern::String           # URL pattern like "/users/:id"
    file_path::String         # File path to the route module
    params::Vector{Symbol}    # Parameter names like [:id]
    is_catch_all::Bool        # Whether this is a [...slug] route
end

"""
Router configuration and state.
"""
mutable struct Router
    routes::Vector{Route}
    routes_dir::String
    layout::Union{Function, Nothing}  # Optional layout wrapper
end

"""
    create_router(routes_dir::String; layout=nothing) -> Router

Create a router by scanning the routes directory.

# Example
```julia
router = create_router("routes")
# Scans routes/ directory and builds route table
```
"""
function create_router(routes_dir::String; layout=nothing)
    routes = Route[]

    if isdir(routes_dir)
        scan_routes!(routes, routes_dir, routes_dir)
    end

    # Sort routes: specific routes before dynamic, catch-all last
    sort!(routes, by=route_priority)

    Router(routes, routes_dir, layout)
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
"""
function scan_routes!(routes::Vector{Route}, base_dir::String, current_dir::String)
    for entry in readdir(current_dir)
        full_path = joinpath(current_dir, entry)

        if isdir(full_path)
            scan_routes!(routes, base_dir, full_path)
        elseif endswith(entry, ".jl")
            route = parse_route_file(base_dir, full_path)
            if route !== nothing
                push!(routes, route)
            end
        end
    end
end

"""
Parse a route file path into a Route struct.
"""
function parse_route_file(base_dir::String, file_path::String)
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

    return Route(pattern, file_path, params, is_catch_all)
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
    handle_request(router::Router, path::String) -> (html::String, route::Route, params::Dict)

Handle an HTTP request by matching the route and rendering the page.
"""
function handle_request(router::Router, path::String)
    route, params = match_route(router, path)

    if route === nothing
        # 404
        return ("<h1>404 - Not Found</h1>", nothing, Dict{Symbol,String}())
    end

    # Load and render the route
    # Use invokelatest to handle world age issues with dynamic include
    page_fn = load_route(route)
    page_content = Base.invokelatest(page_fn, params)

    # Apply layout if present
    if router.layout !== nothing
        page_content = router.layout(page_content, params)
    end

    html = render_to_string(page_content)
    return (html, route, params)
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
    NavLink(href::String, children...; class="", active_class="active")

Navigation link that highlights when active.
"""
function NavLink(href::String, children...; class::String="", active_class::String="active", kwargs...)
    props = Dict{Symbol, Any}(kwargs...)
    props[:href] = href
    props[:class] = class
    props[:data_navlink] = "true"
    props[:data_active_class] = active_class
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
