# App.jl - Application framework for Therapy.jl
#
# Provides a clean API for building Therapy.jl applications with:
# - File-based routing (Next.js style)
# - `dev(app)` - Development server with HMR via Revise.jl
# - `build(app)` - Static site generation
#
# Example app.jl:
#   using Therapy
#
#   app = App(
#       routes_dir = "src/routes",
#       components_dir = "src/components",
#       interactive = [
#           "InteractiveCounter" => "#counter-demo",
#       ],
#       title = "My App"
#   )
#
#   # Run with: julia app.jl dev|build
#   Therapy.run(app)

using HTTP
using Sockets

"""
Interactive component configuration.
Specifies where to inject compiled Wasm components.
"""
struct InteractiveComponent
    name::String              # Component name (file name without .jl)
    container_selector::String
    component::Union{Function, Nothing}  # Loaded component function
end

"""
Application configuration.
"""
mutable struct App
    routes_dir::String
    components_dir::String
    routes::Vector{Pair{String, Function}}  # Discovered routes
    interactive::Vector{InteractiveComponent}
    title::String
    layout::Union{Function, Nothing}
    layout_name::Union{Symbol, Nothing}  # Deferred layout resolution (for SPA)
    output_dir::String
    tailwind::Bool
    dark_mode::Bool
    base_path::String  # Base path for deployment (e.g., "/Therapy.jl" for GitHub Pages)
    _loaded::Bool  # Whether components/routes have been loaded

    function App(;
        routes_dir::String = "src/routes",
        components_dir::String = "src/components",
        routes::Vector = Pair{String, Function}[],
        interactive::Vector = [],
        title::String = "Therapy.jl App",
        layout::Union{Function, Symbol, Nothing} = nothing,
        output_dir::String = "dist",
        tailwind::Bool = true,
        dark_mode::Bool = true,
        base_path::String = ""
    )
        # Convert interactive to InteractiveComponent if needed
        ic = InteractiveComponent[]
        for item in interactive
            if item isa InteractiveComponent
                push!(ic, item)
            elseif item isa Pair
                push!(ic, InteractiveComponent(string(item.first), item.second, nothing))
            end
        end
        # Support both Function and Symbol for layout
        # Symbol is resolved after components are loaded
        layout_fn = layout isa Function ? layout : nothing
        layout_sym = layout isa Symbol ? layout : nothing
        new(routes_dir, components_dir, routes, ic, title, layout_fn, layout_sym, output_dir, tailwind, dark_mode, rstrip(base_path, '/'), false)
    end
end

"""
Compiled interactive component with Wasm and hydration.
"""
struct CompiledInteractive
    component::InteractiveComponent
    compiled::Any
    html::String
    js::String
    wasm_bytes::Vector{UInt8}
    wasm_filename::String
end

# =============================================================================
# File-based Route Discovery
# =============================================================================

"""
Discover routes from the routes directory.
Returns vector of (path, file_path) pairs.
"""
function discover_routes(routes_dir::String)::Vector{Tuple{String, String}}
    routes = Tuple{String, String}[]

    if !isdir(routes_dir)
        return routes
    end

    scan_routes_dir!(routes, routes_dir, routes_dir)

    # Sort: specific routes before dynamic, index files last in their directory
    sort!(routes, by = r -> route_sort_key(r[1]))

    return routes
end

"""
Recursively scan directory for route files.
"""
function scan_routes_dir!(routes::Vector{Tuple{String, String}}, base_dir::String, current_dir::String)
    for entry in readdir(current_dir)
        full_path = joinpath(current_dir, entry)

        if isdir(full_path)
            scan_routes_dir!(routes, base_dir, full_path)
        elseif endswith(entry, ".jl")
            route_path = file_to_route_path(base_dir, full_path)
            push!(routes, (route_path, full_path))
        end
    end
end

"""
Convert file path to route path.
"""
function file_to_route_path(base_dir::String, file_path::String)::String
    rel = relpath(file_path, base_dir)
    rel = replace(rel, r"\.jl$" => "")

    # Handle index files
    if endswith(rel, "index")
        rel = replace(rel, r"/?index$" => "")
    end

    parts = split(rel, ['/', '\\'])
    route_parts = String[]

    for part in parts
        isempty(part) && continue

        if startswith(part, "[...") && endswith(part, "]")
            # Catch-all: [...slug] -> *
            push!(route_parts, "*")
        elseif startswith(part, "[") && endswith(part, "]")
            # Dynamic: [id] -> :id
            param = part[2:end-1]
            push!(route_parts, ":" * param)
        else
            push!(route_parts, part)
        end
    end

    path = "/" * join(route_parts, "/")
    return path == "/" ? "/" : rstrip(path, '/')
end

"""
Sort key for routes (specific before dynamic).
"""
function route_sort_key(path::String)
    score = 0
    if contains(path, "*")
        score += 1000
    end
    score += count(':', path) * 10
    score += length(path)
    return score
end

# =============================================================================
# Component Loading
# =============================================================================

"""
Discover islands from the global registry.
Called after loading component files which register islands via island().
"""
function discover_islands()
    islands = InteractiveComponent[]
    for def in get_islands()
        # Use therapy-island element as container - no manual IDs needed!
        selector = "therapy-island[data-component=\"" * lowercase(string(def.name)) * "\"]"
        push!(islands, InteractiveComponent(string(def.name), selector, def.render_fn))
    end
    return islands
end

"""
Load all components and routes for the app.
"""
function load_app!(app::App)
    app._loaded && return

    println("Loading app...")

    # Clear island registry for fresh discovery
    clear_islands!()

    # Load components first (they may be used by routes)
    # This also registers islands via island() calls
    if isdir(app.components_dir)
        println("  Loading components from $(app.components_dir)/")
        for file in readdir(app.components_dir)
            if endswith(file, ".jl")
                path = joinpath(app.components_dir, file)
                println("    - $file")
                include(path)
            end
        end
    end

    # Auto-discover islands from registry (registered via island() calls)
    discovered_islands = discover_islands()
    if !isempty(discovered_islands)
        println("  Discovered $(length(discovered_islands)) islands")
        # Merge with any manually specified interactive components
        # Manual config takes precedence (allows custom selectors)
        existing_names = Set(ic.name for ic in app.interactive)
        for island in discovered_islands
            if island.name ∉ existing_names
                push!(app.interactive, island)
            end
        end
    end

    # Resolve layout_name Symbol to actual function (for SPA app-level layout)
    if app.layout === nothing && app.layout_name !== nothing
        try
            app.layout = Base.invokelatest(eval, app.layout_name)
            println("  Resolved layout: $(app.layout_name)")
        catch e
            @warn "Could not resolve layout: $(app.layout_name)" exception=e
        end
    end

    # Load interactive component functions for manually specified components
    # (Islands auto-discovered already have their render_fn set)
    for (i, ic) in enumerate(app.interactive)
        if ic.component === nothing
            # Try to find the function by name
            component_file = joinpath(app.components_dir, "$(ic.name).jl")
            if isfile(component_file)
                fn = Base.invokelatest(eval, Symbol(ic.name))
                app.interactive[i] = InteractiveComponent(ic.name, ic.container_selector, fn)
            else
                @warn "Interactive component not found: $(ic.name) at $component_file"
            end
        end
    end

    # Discover and load routes
    if isdir(app.routes_dir) && isempty(app.routes)
        println("  Discovering routes from $(app.routes_dir)/")
        discovered = discover_routes(app.routes_dir)

        for (route_path, file_path) in discovered
            println("    $route_path -> $(relpath(file_path, app.routes_dir))")
            # Load the route file - it should return a function
            route_fn = include(file_path)
            if route_fn isa Function
                push!(app.routes, route_path => route_fn)
            else
                @warn "Route file $file_path should return a Function, got $(typeof(route_fn))"
            end
        end
    end

    app._loaded = true
    println("  Loaded $(length(app.routes)) routes, $(length(app.interactive)) interactive components")
end

"""
Reload a specific file (for HMR).
"""
function reload_file!(app::App, file_path::String)
    println("  Reloading: $file_path")

    try
        # Re-include the file
        result = include(file_path)

        # If it's a route file, update the route
        if startswith(file_path, app.routes_dir)
            route_path = file_to_route_path(app.routes_dir, file_path)
            if result isa Function
                # Update existing route or add new one
                idx = findfirst(r -> r.first == route_path, app.routes)
                if idx !== nothing
                    app.routes[idx] = route_path => result
                else
                    push!(app.routes, route_path => result)
                end
            end
        end

        # If it's a component file, update interactive components
        if startswith(file_path, app.components_dir)
            component_name = replace(basename(file_path), ".jl" => "")
            for (i, ic) in enumerate(app.interactive)
                if ic.name == component_name && result isa Function
                    app.interactive[i] = InteractiveComponent(ic.name, ic.container_selector, result)
                end
            end
        end

        return true
    catch e
        @error "Error reloading $file_path" exception=(e, catch_backtrace())
        return false
    end
end

# =============================================================================
# Component Compilation
# =============================================================================

"""
Compile all interactive components to Wasm.
"""
function compile_interactive_components(app::App; for_build::Bool=false)::Vector{CompiledInteractive}
    compiled = CompiledInteractive[]

    for ic in app.interactive
        if ic.component === nothing
            @warn "Skipping unloaded component: $(ic.name)"
            continue
        end

        println("  Compiling $(ic.name)...")

        # Generate unique wasm filename
        wasm_filename = "$(lowercase(ic.name)).wasm"

        # Determine wasm path for hydration JS
        # In dev mode: use root-relative path (/)
        # In build mode: use base_path for GitHub Pages subpaths
        wasm_path = if for_build && !isempty(app.base_path)
            "$(app.base_path)/$wasm_filename"
        else
            "/$wasm_filename"
        end

        # Compile with container selector for scoped DOM queries
        # Use invokelatest to handle world age issues from dynamic loading
        result = Base.invokelatest(compile_component, ic.component;
            container_selector=ic.container_selector,
            component_name=ic.name,
            wasm_path=wasm_path)

        js = result.hydration.js

        push!(compiled, CompiledInteractive(
            ic,
            result,
            result.html,
            js,
            result.wasm.bytes,
            wasm_filename
        ))

        println("    Wasm: $(length(result.wasm.bytes)) bytes")
    end

    return compiled
end

# =============================================================================
# HTML Generation
# =============================================================================

"""
Generate full HTML page or partial content with injected components.

If `partial=true`, returns just the page content area (for SPA navigation).
The page content is what goes inside #page-content, NOT the full Layout.

For true SPA behavior:
- Full page: Layout wraps route content
- Partial: Just the route content (swaps into #page-content)
"""
function generate_page(
    app::App,
    route_path::String,
    component_fn::Function,
    compiled_components::Vector{CompiledInteractive};
    for_build::Bool=false,
    partial::Bool=false
)
    # Render the route component (should return just page content, not Layout)
    # Islands render directly as <therapy-island> elements via SSR
    page_content = render_to_string(Base.invokelatest(component_fn))

    # For partial requests (SPA navigation), return just the page content
    # This swaps into #page-content, so we don't include Layout
    if partial
        # Find islands in page content
        islands_used = Set{String}()
        for cc in compiled_components
            selector = cc.component.container_selector
            component_name = lowercase(cc.component.name)
            if startswith(selector, "therapy-island")
                if contains(page_content, "therapy-island data-component=\"$component_name\"")
                    push!(islands_used, cc.component.name)
                end
            end
        end

        # Include hydration JS for islands in this page
        all_js = join([cc.js for cc in compiled_components if cc.component.name in islands_used], "\n\n")

        partial_html = page_content
        if !isempty(all_js)
            partial_html *= """
<script>
$(all_js)
</script>
"""
        end
        return partial_html
    end

    # For full page renders, apply Layout if configured
    if app.layout !== nothing
        content = render_to_string(Base.invokelatest(app.layout, RawHtml(page_content)))
    else
        content = page_content
    end

    # For therapy-island selectors, the content is already rendered by SSR
    # For legacy #id selectors, inject compiled HTML into placeholder containers
    # Track which islands are actually used on this page
    islands_used = Set{String}()

    for cc in compiled_components
        selector = cc.component.container_selector
        component_name = lowercase(cc.component.name)

        if startswith(selector, "therapy-island")
            # Check if this island is actually in the rendered content
            if contains(content, "therapy-island data-component=\"$component_name\"")
                push!(islands_used, cc.component.name)
            end
        else
            # Legacy: inject into placeholder div with ID
            id = lstrip(selector, '#')
            pattern = Regex("<div[^>]*id=\"$id\"[^>]*>.*?</div>", "s")
            if contains(content, "id=\"$id\"")
                replacement = "<div id=\"$id\">$(cc.html)</div>"
                content = replace(content, pattern => replacement)
                push!(islands_used, cc.component.name)
            end
        end
    end

    # Only include hydration JS for islands actually used on this page
    all_js = join([cc.js for cc in compiled_components if cc.component.name in islands_used], "\n\n")

    # Generate page title
    page_title = if route_path == "/"
        app.title
    else
        "$(titlecase(replace(strip(route_path, '/'), "-" => " "))) - $(app.title)"
    end

    # Build HTML document
    # Add base tag for proper relative URL resolution
    # In build mode: use base_path for GitHub Pages subpath deployment
    # In dev mode: use "/" so relative links work from any page
    base_href = (for_build && !isempty(app.base_path)) ? "$(app.base_path)/" : "/"
    base_tag = "\n    <base href=\"$base_href\">"

    html = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$(page_title)</title>$(base_tag)
"""

    if app.tailwind
        html *= """
    <script src="https://cdn.tailwindcss.com"></script>
    <script>
        tailwind.config = {
            darkMode: 'class',
            theme: {
                extend: {
                    fontFamily: {
                        sans: ['Source Sans 3', 'system-ui', 'sans-serif'],
                        serif: ['Lora', 'Georgia', 'Cambria', 'serif'],
                    }
                }
            }
        }
    </script>
"""
    end

    html *= """
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Lora:ital,wght@0,400;0,500;0,600;0,700;1,400&family=Source+Sans+3:wght@400;500;600;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/themes/prism-tomorrow.min.css">
    <style>
        html { scroll-behavior: smooth; }
        pre code { font-family: 'Fira Code', 'Monaco', 'Consolas', monospace; }
    </style>
"""

    if app.dark_mode
        html *= """
    <script>
        (function() {
            try {
                const saved = localStorage.getItem('therapy-theme');
                if (saved === 'dark' || (!saved && window.matchMedia('(prefers-color-scheme: dark)').matches)) {
                    document.documentElement.classList.add('dark');
                }
            } catch (e) {}
        })();
    </script>
"""
    end

    html *= """
</head>
<body class="antialiased">
<div id="therapy-content">
$(content)
</div>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/prism.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/components/prism-julia.min.js"></script>
"""

    if !isempty(all_js)
        html *= """
    <script>
$(all_js)
    </script>
"""
    end

    # Include client-side router script for SPA navigation
    # Works for both dev server (partial responses) and static builds (extracts from full page)
    router_js = render_to_string(client_router_script(content_selector="#page-content", base_path=app.base_path))
    html *= router_js

    # Include WebSocket client script (for server signals)
    # This enables real-time updates in dev mode and shows warnings on static hosting
    ws_js = render_to_string(websocket_client_script())
    html *= ws_js

    html *= """
</body>
</html>
"""

    return html
end

# =============================================================================
# Development Server with HMR
# =============================================================================

"""
    dev(app::App; port::Int=8080, host::String="127.0.0.1")

Start development server with hot module reloading.

Uses Revise.jl if available for automatic code reloading.
"""
function dev(app::App; port::Int=8080, host::String="127.0.0.1")
    println("\n━━━ Therapy.jl Dev Server ━━━")
    println("Hot Module Reloading enabled")

    # Load app using standard load_app! (which uses include)
    load_app!(app)

    # Compile interactive components
    println("\nCompiling interactive components...")
    compiled_components = compile_interactive_components(app)

    # Track file modification times for HMR
    file_mtimes = Dict{String, Float64}()

    function track_files()
        for dir in [app.routes_dir, app.components_dir]
            isdir(dir) || continue
            for (root, _, files) in walkdir(dir)
                for file in files
                    endswith(file, ".jl") || continue
                    path = joinpath(root, file)
                    file_mtimes[path] = mtime(path)
                end
            end
        end
    end

    track_files()
    println("  Watching $(length(file_mtimes)) files for changes")

    function check_for_changes()
        # Check if any files changed (for re-including and recompiling Wasm)
        changed = String[]
        for (path, old_mtime) in file_mtimes
            if isfile(path) && mtime(path) > old_mtime
                push!(changed, path)
                file_mtimes[path] = mtime(path)
            end
        end
        return changed
    end

    # Try to find an available port
    function find_available_port(start_port, max_attempts=10)
        for attempt in 0:max_attempts-1
            test_port = start_port + attempt
            try
                # Try to bind briefly to check if port is available
                server = Sockets.listen(Sockets.IPv4(host), test_port)
                close(server)
                return test_port
            catch e
                if attempt == max_attempts - 1
                    error("Could not find available port (tried $start_port-$(start_port + max_attempts - 1))")
                end
            end
        end
        return start_port
    end

    actual_port = find_available_port(port)
    if actual_port != port
        println("\nNote: Port $port in use, using port $actual_port instead")
    end

    println("\nStarting server on http://$host:$actual_port")
    println("Press Ctrl+C to stop\n")

    # Last check time for polling
    last_check = Ref(time())
    check_interval = 1.0  # Check every second

    # Stream-based handler for WebSocket support
    function stream_handler(stream::HTTP.Stream)
        request = stream.message
        path = HTTP.URI(request.target).path
        path = path == "" ? "/" : path

        # Check for file changes
        if time() - last_check[] > check_interval
            changed = check_for_changes()
            if !isempty(changed)
                println("\n━━━ Files changed ━━━")

                # Reload each changed file
                for file in changed
                    reload_file!(app, file)
                end

                # Recompile interactive components if any component changed
                if any(f -> contains(f, app.components_dir), changed)
                    println("  Recompiling Wasm...")
                    compiled_components = compile_interactive_components(app)
                end
                println("━━━ Ready ━━━\n")
            end
            last_check[] = time()
        end

        # Handle WebSocket upgrade requests
        if path == "/ws"
            is_upgrade = any(h -> lowercase(String(h.first)) == "upgrade" &&
                                  lowercase(String(h.second)) == "websocket", request.headers)
            if is_upgrade
                handle_websocket(stream)
                return
            end
        end

        # Check if this is a partial request (for client-side navigation)
        is_partial = any(h -> lowercase(String(h.first)) == "x-therapy-partial" && String(h.second) == "1", request.headers)

        # Serve Wasm files
        for cc in compiled_components
            if path == "/$(cc.wasm_filename)"
                HTTP.setstatus(stream, 200)
                HTTP.setheader(stream, "Content-Type" => "application/wasm")
                HTTP.startwrite(stream)
                write(stream, cc.wasm_bytes)
                return
            end
        end

        # Match routes
        for (route_path, component_fn) in app.routes
            route_match = route_path == path ||
                         (endswith(route_path, "/") && path == rstrip(route_path, '/')) ||
                         (path == route_path * "/")

            if route_match
                try
                    html = Base.invokelatest(generate_page, app, String(path), component_fn, compiled_components; partial=is_partial)
                    HTTP.setstatus(stream, 200)
                    HTTP.setheader(stream, "Content-Type" => "text/html; charset=utf-8")
                    HTTP.startwrite(stream)
                    write(stream, html)
                    return
                catch e
                    @error "Error rendering page" exception=(e, catch_backtrace())
                    HTTP.setstatus(stream, 500)
                    HTTP.startwrite(stream)
                    write(stream, "Error: $e")
                    return
                end
            end
        end

        HTTP.setstatus(stream, 404)
        HTTP.startwrite(stream)
        write(stream, "Not Found: $path")
    end

    server = HTTP.listen!(stream_handler, host, actual_port)

    try
        wait(server)
    catch e
        if e isa InterruptException
            println("\nShutting down server...")
            close(server)
        else
            rethrow(e)
        end
    end
end

# =============================================================================
# Static Site Build
# =============================================================================

"""
    build(app::App)

Build static site from a Therapy.jl application.
"""
function build(app::App)
    println("\n━━━ Therapy.jl Static Build ━━━")
    println("Output: $(app.output_dir)")

    # Load app
    load_app!(app)

    # Clean and create output directory
    rm(app.output_dir, recursive=true, force=true)
    mkpath(app.output_dir)

    # Compile interactive components (for_build=true to use base_path)
    println("\nCompiling interactive components...")
    compiled_components = compile_interactive_components(app; for_build=true)

    # Write Wasm files
    for cc in compiled_components
        wasm_path = joinpath(app.output_dir, cc.wasm_filename)
        write(wasm_path, cc.wasm_bytes)
        println("  Wrote: $(cc.wasm_filename)")
    end

    # Build pages
    println("\nBuilding pages...")
    for (route_path, component_fn) in app.routes
        # Skip dynamic routes for static build
        if contains(route_path, ":") || contains(route_path, "*")
            println("  Skipping dynamic route: $route_path")
            continue
        end

        println("  Building: $route_path")

        html = generate_page(app, route_path, component_fn, compiled_components; for_build=true)

        # Determine output path
        if route_path == "/"
            output_path = joinpath(app.output_dir, "index.html")
        else
            route_dir = joinpath(app.output_dir, strip(route_path, '/'))
            mkpath(route_dir)
            output_path = joinpath(route_dir, "index.html")
        end

        write(output_path, html)
    end

    # Create 404 page
    write(joinpath(app.output_dir, "404.html"), """
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Page Not Found - $(app.title)</title>
    $(app.tailwind ? "<script src=\"https://cdn.tailwindcss.com\"></script>" : "")
    <link href="https://fonts.googleapis.com/css2?family=Lora:wght@400;500;600;700&family=Source+Sans+3:wght@400;500;600;700&display=swap" rel="stylesheet">
    <script>
        tailwind.config = {
            darkMode: 'class',
            theme: {
                extend: {
                    fontFamily: {
                        sans: ['Source Sans 3', 'system-ui', 'sans-serif'],
                        serif: ['Lora', 'Georgia', 'serif'],
                    }
                }
            }
        }
        try {
            if (localStorage.getItem('therapy-theme') === 'dark') {
                document.documentElement.classList.add('dark');
            }
        } catch (e) {}
    </script>
</head>
<body class="antialiased bg-stone-100 dark:bg-neutral-950">
    <div class="min-h-screen flex items-center justify-center">
        <div class="text-center">
            <h1 class="text-6xl font-serif font-semibold text-stone-300 dark:text-neutral-700">404</h1>
            <p class="text-xl text-neutral-600 dark:text-neutral-400 mt-4">Page not found</p>
            <a href="$(isempty(app.base_path) ? "/" : app.base_path * "/")" class="inline-block mt-6 px-6 py-3 bg-emerald-700 dark:bg-emerald-600 text-white rounded hover:bg-emerald-800 dark:hover:bg-emerald-500 transition">
                Go Home
            </a>
        </div>
    </div>
</body>
</html>
""")

    # Create .nojekyll for GitHub Pages
    write(joinpath(app.output_dir, ".nojekyll"), "")

    println("\n━━━ Build Complete! ━━━")
    println("Files:")
    for (root, dirs, files) in walkdir(app.output_dir)
        for file in files
            rel_path = relpath(joinpath(root, file), app.output_dir)
            println("  $rel_path")
        end
    end
end

# =============================================================================
# CLI Entry Point
# =============================================================================

"""
    run(app::App)

Run the app based on command line arguments.
- `julia app.jl dev` - Start development server with HMR
- `julia app.jl build` - Build static site
"""
function run(app::App)
    if length(ARGS) == 0 || ARGS[1] == "build"
        build(app)
    elseif ARGS[1] == "dev"
        dev(app)
    else
        println("Usage: julia app.jl [dev|build]")
        println("  dev   - Start development server with HMR")
        println("  build - Build static site to $(app.output_dir)/")
    end
end
