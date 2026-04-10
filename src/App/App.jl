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
using FileWatching

"""
Interactive component configuration.
Specifies where to inject compiled interactive components.
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
    middleware::Vector{Function}  # Application-level middleware (Oxygen pattern)
    _loaded::Bool  # Whether components/routes have been loaded
    _tailwind_css_built::Bool  # Whether Tailwind CSS was compiled (for build mode)

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
        base_path::String = "",
        middleware::Vector = Function[]
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
        new(routes_dir, components_dir, routes, ic, title, layout_fn, layout_sym, output_dir, tailwind, dark_mode, rstrip(base_path, '/'), Function[mw for mw in middleware], false, false)
    end
end

"""
Compiled interactive component with JS hydration.
"""
struct CompiledInteractive
    component::InteractiveComponent
    compiled::Any       # IslandJSOutput (JST backend)
    html::String
    js::String          # Inline JavaScript for hydration
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
Excludes _layout.jl files which are used for nested layouts, not routes.
"""
function scan_routes_dir!(routes::Vector{Tuple{String, String}}, base_dir::String, current_dir::String)
    for entry in readdir(current_dir)
        full_path = joinpath(current_dir, entry)

        if isdir(full_path)
            scan_routes_dir!(routes, base_dir, full_path)
        elseif endswith(entry, ".jl") && entry != "_layout.jl"
            # Skip _layout.jl files - they're handled by the router for nested layouts
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
    app_module(app)

Get or create the application module where all components and routes are evaluated.
This ensures components are always in scope when route files load — both during
initial load_app! and HMR reload. Equivalent to Vite's module graph: every file
can reference any other loaded component without explicit imports.
"""
function app_module(app::App)
    mod_name = :TherapyApp
    if isdefined(Main, mod_name)
        return getfield(Main, mod_name)
    end
    # Create the module in Main with Therapy re-exported
    mod = Core.eval(Main, :(module $mod_name
        using Therapy
    end))
    return mod
end

"""
Load all components and routes for the app.
"""
function load_app!(app::App)
    app._loaded && return

    println("Loading app...")
    mod = app_module(app)

    # Load components first (they may be used by routes)
    # This also registers islands via island() calls
    if isdir(app.components_dir)
        println("  Loading components from $(app.components_dir)/")
        for file in readdir(app.components_dir)
            if endswith(file, ".jl")
                path = joinpath(app.components_dir, file)
                println("    - $file")
                Base.include(mod, path)
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

    # Resolve layout_name Symbol to actual function
    # Components are loaded into the app module
    if app.layout === nothing && app.layout_name !== nothing
        try
            app.layout = Base.invokelatest(getfield, mod, app.layout_name)
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
                fn = Base.invokelatest(getfield, mod, Symbol(ic.name))
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
            # Load the route file into the app module (components in scope)
            route_fn = Base.include(mod, file_path)
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
        # Re-include into the app module (all components + routes in scope)
        mod = app_module(app)
        result = Base.include(mod, file_path)

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
Compile all interactive island components to WASM via WasmTarget.jl.
"""
function compile_interactive_components(app::App; for_build::Bool=false, optimize_wasm::Bool=false)::Vector{CompiledInteractive}
    compiled = CompiledInteractive[]

    for ic in app.interactive
        if ic.component === nothing
            @warn "Skipping unloaded component: $(ic.name)"
            continue
        end

        println("  Compiling $(ic.name)...")

        island_name = Symbol(ic.name)

        local result
        try
            result = Base.invokelatest(compile_island, island_name; optimize_wasm=optimize_wasm)
        catch e
            @warn "Failed to compile $(ic.name), skipping" exception=(e, catch_backtrace())
            continue
        end

        push!(compiled, CompiledInteractive(
            ic,
            result,
            "",         # html: SSR renders directly via therapy-island
            result.js   # inline JS IIFE
        ))

        wasm_kb = round(result.wasm_size / 1024; digits=1)
        println("    WASM: $(wasm_kb) KB, $(result.n_signals) signals, $(result.n_handlers) handlers")
    end

    return compiled
end

"""
Compile a SINGLE interactive island component by name (for surgical HMR).
Returns the CompiledInteractive or nothing on failure.
"""
function compile_single_island(app::App, island_name::String; optimize_wasm::Bool=false)::Union{CompiledInteractive, Nothing}
    # Find the InteractiveComponent by name (case-insensitive)
    ic = nothing
    for c in app.interactive
        if lowercase(c.name) == lowercase(island_name)
            ic = c
            break
        end
    end

    if ic === nothing || ic.component === nothing
        @warn "Island not found or not loaded: $island_name"
        return nothing
    end

    t0 = time()
    local result
    try
        result = Base.invokelatest(compile_island, Symbol(ic.name); optimize_wasm=optimize_wasm)
    catch e
        @warn "Failed to compile $island_name" exception=(e, catch_backtrace())
        return nothing
    end

    elapsed = round((time() - t0) * 1000; digits=0)
    wasm_kb = round(result.wasm_size / 1024; digits=1)
    println("    $(ic.name): $(wasm_kb) KB, $(elapsed)ms")

    return CompiledInteractive(ic, result, "", result.js)
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
            # Signal runtime must load before island scripts (cross-island pub/sub)
            partial_html *= render_to_string(signal_runtime_script())
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
    # No <base href> tag — it breaks #hash anchor links (same issue as Astro/Vue/Next.js).
    # Instead, all URLs are prefixed with base_path at build time.
    html = """
<!DOCTYPE html>
<html lang="en" data-base-path="$(app.base_path)">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$(page_title)</title>
    <script>
    (function(){var bp=document.documentElement.getAttribute('data-base-path')||'';var sk=bp?'therapy-theme:'+bp:'therapy-theme';var t=localStorage.getItem(sk);if(!t)t=window.matchMedia('(prefers-color-scheme:dark)').matches?'dark':'light';if(t==='dark')document.documentElement.classList.add('dark');})();
    </script>
"""

    if app.tailwind
        if app._tailwind_css_built
            # Use compiled CSS (both dev and build modes)
            css_path = if for_build && !isempty(app.base_path)
                "$(app.base_path)/styles.css"
            else
                "/styles.css"
            end
            html *= """
    <link rel="stylesheet" href="$css_path">
"""
        else
            # Fallback: CDN (only if Tailwind CLI unavailable)
            html *= """
    <script src="https://cdn.tailwindcss.com"></script>
    <script>
        tailwind.config = {
            darkMode: 'class',
            theme: {
                extend: {
                    fontFamily: {
                        sans: ['Optima', 'Palatino Linotype', 'Book Antiqua', 'EB Garamond', 'serif'],
                        serif: ['EB Garamond', 'Palatino Linotype', 'Book Antiqua', 'Georgia', 'serif'],
                    }
                }
            }
        }
    </script>
"""
        end
    end

    html *= """
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=EB+Garamond:ital,wght@0,400;0,500;0,600;0,700;1,400&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/themes/prism-tomorrow.min.css">
    <style>
        html { scroll-behavior: smooth; }
        pre code { font-family: 'JuliaMono', 'Fira Code', 'JetBrains Mono', monospace; }
    </style>
"""

    if app.dark_mode
        html *= """
    <script>
        (function() {
            try {
                var bp = document.documentElement.getAttribute('data-base-path') || '';
                var sk = bp ? 'therapy-theme:' + bp : 'therapy-theme';
                var tk = bp ? 'suite-active-theme:' + bp : 'suite-active-theme';
                var s = localStorage.getItem(sk);
                if (s === 'dark' || (!s && window.matchMedia('(prefers-color-scheme: dark)').matches)) {
                    document.documentElement.classList.add('dark');
                }
                var t = localStorage.getItem(tk);
                if (t && t !== 'default') {
                    document.documentElement.setAttribute('data-theme', t);
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
        # Signal runtime must load before island scripts (cross-island pub/sub)
        html *= render_to_string(signal_runtime_script())
        html *= """
    <script>
$(all_js)
    </script>
"""
    end

    # Include client-side router script for SPA navigation
    # Works for both dev server (partial responses) and static builds (extracts from full page)
    # IMPORTANT: Only use base_path in build mode. In dev mode, use empty string so
    # relative paths like "./book/" resolve correctly to "/book/" (not "/Therapy.jl/book/")
    router_base_path = for_build ? app.base_path : ""
    router_js = render_to_string(client_router_script(content_selector="#page-content", base_path=router_base_path))
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

# HMR change types — defined at module top level (required for @enum)
@enum HMRChangeType HMR_COMPONENT HMR_ROUTE HMR_CSS

struct HMREvent
    change_type::HMRChangeType
    file_path::String
    island_name::String  # Only set for HMR_COMPONENT changes
end

"""
    dev(app::App; port::Int=8080, host::String="127.0.0.1")

Start development server with hot module replacement.

Uses FileWatching for instant OS-level file change detection.
"""
function dev(app::App; port::Int=8080, host::String="127.0.0.1", optimize_wasm::Bool=false)
    println("\n━━━ Therapy.jl Dev Server ━━━")
    println("Hot Module Replacement enabled")

    # Load app using standard load_app! (which uses include)
    load_app!(app)

    # Build Tailwind CSS (avoids CDN warning and 300KB download)
    dev_css_bytes = UInt8[]
    if app.tailwind
        println("\nBuilding Tailwind CSS...")
        candidate_dirs = [".", dirname(app.routes_dir), dirname(app.components_dir)]
        docs_dir = "."
        for dir in candidate_dirs
            if isfile(joinpath(dir, "input.css"))
                docs_dir = dir
                break
            end
        end
        routes_rel = isempty(docs_dir) || docs_dir == "." ? app.routes_dir : relpath(app.routes_dir, docs_dir)
        components_rel = isempty(docs_dir) || docs_dir == "." ? app.components_dir : relpath(app.components_dir, docs_dir)
        source_paths = [
            joinpath(".", routes_rel, "**", "*.jl"),
            joinpath(".", components_rel, "**", "*.jl")
        ]
        input_path = ensure_tailwind_input(docs_dir; source_paths=source_paths)
        css_output = tempname() * ".css"
        if build_tailwind_css(input_css=input_path, output_file=css_output, minify=false, cwd=docs_dir)
            dev_css_bytes = read(css_output)
            app._tailwind_css_built = true
            println("  Built: $(round(length(dev_css_bytes) / 1024, digits=1)) KB")
            rm(css_output, force=true)
        else
            println("  Tailwind CLI not available, using CDN fallback")
        end
    end

    # Pre-render pages to populate ISLAND_PROPS_CACHE with actual prop values
    for (route_path, component_fn) in app.routes
        (contains(route_path, ":") || contains(route_path, "*")) && continue
        try; Base.invokelatest(component_fn); catch; end
    end

    # Compile interactive components (now with cached props)
    println("\nCompiling interactive components...")
    compiled_components = compile_interactive_components(app; optimize_wasm=optimize_wasm)

    # ── HMR: FileWatching-based change detection (HM-001) ──
    # Replaces 1-second mtime polling with OS-level file watching.
    # FileWatching.watch_folder uses inotify (Linux) / kqueue (macOS) for
    # instant notification — no polling loop, no missed changes.

    # Channel for watcher tasks to communicate changes to server
    hmr_channel = Channel{HMREvent}(32)

    # Map file path → island name for component files
    function file_to_island_name(filepath::String, components_dir::String)
        basename_no_ext = replace(basename(filepath), ".jl" => "")
        return lowercase(basename_no_ext)
    end

    # Classify a changed file
    function classify_change(filepath::String)
        if startswith(filepath, app.components_dir)
            island = file_to_island_name(filepath, app.components_dir)
            return HMREvent(HMR_COMPONENT, filepath, island)
        elseif startswith(filepath, app.routes_dir)
            return HMREvent(HMR_ROUTE, filepath, "")
        elseif endswith(filepath, ".css")
            return HMREvent(HMR_CSS, filepath, "")
        else
            return HMREvent(HMR_ROUTE, filepath, "")  # Default: treat as route
        end
    end

    # Start background watcher for a directory tree
    function start_dir_watcher(dir::String)
        isdir(dir) || return

        # Watch each directory (FileWatching.watch_folder watches one level)
        dirs_to_watch = String[dir]
        for (root, subdirs, _) in walkdir(dir)
            for sd in subdirs
                push!(dirs_to_watch, joinpath(root, sd))
            end
        end

        for watch_dir in dirs_to_watch
            @async begin
                while isopen(hmr_channel)
                    try
                        (filename, events) = FileWatching.watch_folder(watch_dir)
                        # Only care about .jl and .css files
                        (endswith(filename, ".jl") || endswith(filename, ".css")) || continue
                        filepath = joinpath(watch_dir, filename)
                        isfile(filepath) || continue
                        event = classify_change(filepath)
                        put!(hmr_channel, event)
                    catch e
                        e isa InvalidStateException && break  # Channel closed
                        e isa InterruptException && break
                        @error "HMR watcher error in $watch_dir" exception=(e, catch_backtrace())
                        sleep(0.5)
                    end
                end
            end
        end

        return length(dirs_to_watch)
    end

    # Start watchers for component and route directories
    n_component_dirs = start_dir_watcher(app.components_dir)
    n_route_dirs = start_dir_watcher(app.routes_dir)
    total_watched = something(n_component_dirs, 0) + something(n_route_dirs, 0)
    println("  Watching $(total_watched) directories for changes (OS-level, instant)")

    # Background task: process HMR events from the channel
    hmr_processor = @async begin
        while isopen(hmr_channel)
            try
                event = take!(hmr_channel)
                println("\n━━━ HMR: $(event.change_type) ━━━")
                println("  File: $(event.file_path)")
                if event.change_type == HMR_COMPONENT
                    println("  Island: $(event.island_name)")
                end

                # Reload the changed file
                reload_file!(app, event.file_path)

                if event.change_type == HMR_COMPONENT
                    # Pre-render to populate props cache
                    for (rp, cfn) in app.routes
                        (contains(rp, ":") || contains(rp, "*")) && continue
                        try; Base.invokelatest(cfn); catch; end
                    end
                    # Surgical recompilation: only the changed island (HM-002)
                    println("  Recompiling island: $(event.island_name)...")
                    new_compiled = Base.invokelatest(compile_single_island, app, event.island_name; optimize_wasm=optimize_wasm)
                    if new_compiled !== nothing
                        # Update the matching entry in compiled_components
                        idx = findfirst(cc -> lowercase(cc.component.name) == event.island_name, compiled_components)
                        if idx !== nothing
                            compiled_components[idx] = new_compiled
                        else
                            push!(compiled_components, new_compiled)
                        end
                        # HM-003: Push new WASM/JS to all connected browsers
                        broadcast_all(Dict(
                            "type" => "hmr",
                            "event" => "island_update",
                            "island" => event.island_name,
                            "wasm_js" => new_compiled.js
                        ))
                        println("  WS push: island_update → $(ws_connection_count()) clients")
                    end
                elseif event.change_type == HMR_ROUTE
                    # HM-007: Route change → tell browser to reload
                    println("  Route reloaded — pushing page_reload")
                    broadcast_all(Dict(
                        "type" => "hmr",
                        "event" => "page_reload"
                    ))
                elseif event.change_type == HMR_CSS
                    # HM-006: CSS change → rebuild and hot-inject
                    println("  Rebuilding CSS...")
                    candidate_dirs = [".", dirname(app.routes_dir), dirname(app.components_dir)]
                    docs_dir = "."
                    for dir in candidate_dirs
                        if isfile(joinpath(dir, "input.css"))
                            docs_dir = dir
                            break
                        end
                    end
                    routes_rel = isempty(docs_dir) || docs_dir == "." ? app.routes_dir : relpath(app.routes_dir, docs_dir)
                    components_rel = isempty(docs_dir) || docs_dir == "." ? app.components_dir : relpath(app.components_dir, docs_dir)
                    source_paths = [
                        joinpath(".", routes_rel, "**", "*.jl"),
                        joinpath(".", components_rel, "**", "*.jl")
                    ]
                    input_path = ensure_tailwind_input(docs_dir; source_paths=source_paths)
                    css_output = tempname() * ".css"
                    if build_tailwind_css(input_css=input_path, output_file=css_output, minify=false, cwd=docs_dir)
                        dev_css_bytes = read(css_output)
                        rm(css_output, force=true)
                        css_str = String(dev_css_bytes)
                        broadcast_all(Dict(
                            "type" => "hmr",
                            "event" => "css_update",
                            "css" => css_str
                        ))
                        println("  WS push: css_update → $(ws_connection_count()) clients ($(round(length(css_str) / 1024; digits=1)) KB)")
                    else
                        println("  CSS rebuild failed — Tailwind CLI not available")
                    end
                end

                println("━━━ Ready ━━━\n")
            catch e
                e isa InvalidStateException && break
                e isa InterruptException && break
                @error "HMR processor error" exception=(e, catch_backtrace())
            end
        end
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

    # Route handler: HTTP.Request → HTTP.Response (middleware-compatible)
    # This is the base handler that middleware wraps (Oxygen pattern).
    function route_handler(req::HTTP.Request)
        path = HTTP.URI(req.target).path
        path = path == "" ? "/" : path

        is_partial = any(h -> lowercase(String(h.first)) == "x-therapy-partial" && String(h.second) == "1", req.headers)

        for (route_path, component_fn) in app.routes
            route_match = route_path == path ||
                         (endswith(route_path, "/") && path == rstrip(route_path, '/')) ||
                         (path == route_path * "/")

            if route_match
                try
                    html = Base.invokelatest(generate_page, app, String(path), component_fn, compiled_components; partial=is_partial)
                    return HTTP.Response(200, ["Content-Type" => "text/html; charset=utf-8"], body=html)
                catch e
                    @error "Error rendering page" exception=(e, catch_backtrace())
                    return HTTP.Response(500, body="Error: $e")
                end
            end
        end

        return HTTP.Response(404, body="Not Found: $path")
    end

    # Compose middleware around route handler (Oxygen pattern: once at startup)
    composed_handler = compose_middleware(route_handler, app.middleware)

    # Stream-based handler for WebSocket support
    function stream_handler(stream::HTTP.Stream)
        request = stream.message
        path = HTTP.URI(request.target).path
        path = path == "" ? "/" : path

        # HMR change detection is now handled by background FileWatching tasks
        # (see hmr_processor above) — no per-request polling needed.

        # Handle WebSocket upgrade requests (bypass middleware)
        if handle_ws_upgrade(stream)
            return
        end

        # Serve compiled Tailwind CSS (bypass middleware)
        if path == "/styles.css" && !isempty(dev_css_bytes)
            HTTP.setstatus(stream, 200)
            HTTP.setheader(stream, "Content-Type" => "text/css; charset=utf-8")
            HTTP.startwrite(stream)
            write(stream, dev_css_bytes)
            return
        end

        # Run request through middleware chain → route handler → response
        response = composed_handler(request)
        write_response(stream, response)
    end

    server = HTTP.listen!(stream_handler, host, actual_port)

    try
        wait(server)
    catch e
        if e isa InterruptException
            println("\nShutting down server...")
            close(hmr_channel)  # Stop HMR watcher tasks
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
function build(app::App; optimize_wasm::Bool=false)
    println("\n━━━ Therapy.jl Static Build ━━━")
    println("Output: $(app.output_dir)")

    # Load app
    load_app!(app)

    # Clean and create output directory
    rm(app.output_dir, recursive=true, force=true)
    mkpath(app.output_dir)

    # Build Tailwind CSS (if enabled)
    if app.tailwind
        println("\nBuilding Tailwind CSS...")
        # Find input.css - check current directory first (after app changes to its dir),
        # then check routes/components parent directories
        candidate_dirs = [
            ".",                                   # Current directory (e.g., docs/)
            dirname(app.routes_dir),              # Parent of routes (e.g., src/)
            dirname(app.components_dir)           # Parent of components
        ]
        docs_dir = "."  # Default
        for dir in candidate_dirs
            if isfile(joinpath(dir, "input.css"))
                docs_dir = dir
                break
            end
        end

        # Source paths relative to where input.css is located
        # These are used by @source directive in input.css (Tailwind v4)
        routes_rel = isempty(docs_dir) || docs_dir == "." ? app.routes_dir : relpath(app.routes_dir, docs_dir)
        components_rel = isempty(docs_dir) || docs_dir == "." ? app.components_dir : relpath(app.components_dir, docs_dir)
        source_paths = [
            joinpath(".", routes_rel, "**", "*.jl"),
            joinpath(".", components_rel, "**", "*.jl")
        ]
        input_path = ensure_tailwind_input(docs_dir; source_paths=source_paths)
        output_path = joinpath(app.output_dir, "styles.css")

        # Try to build with CLI
        if build_tailwind_css(
            input_css = input_path,
            output_file = output_path,
            minify = true,
            cwd = docs_dir
        )
            app._tailwind_css_built = true
            file_size = filesize(output_path)
            println("  Built: styles.css ($(round(file_size / 1024, digits=1)) KB)")
        else
            app._tailwind_css_built = false
            println("  Using CDN fallback (install Tailwind CLI for optimized builds)")
        end
    end

    # Pre-render pages to populate ISLAND_PROPS_CACHE with actual prop values.
    # Islands like SearchableList(items_data=["Julia",...]) need their props
    # available at WASM compile time so constant data is embedded in the module.
    println("\nPre-rendering pages (collecting island props)...")
    for (route_path, component_fn) in app.routes
        contains(route_path, ":") || contains(route_path, "*") && continue
        try
            Base.invokelatest(component_fn)
        catch e
            @debug "Pre-render skipped for $route_path" exception=e
        end
    end

    # Compile interactive components (now with cached props from pre-render)
    println("\nCompiling interactive components...")
    compiled_components = compile_interactive_components(app; for_build=true, optimize_wasm=optimize_wasm)

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
    tailwind_404 = if app.tailwind && app._tailwind_css_built
        css_path = isempty(app.base_path) ? "/styles.css" : "$(app.base_path)/styles.css"
        "<link rel=\"stylesheet\" href=\"$css_path\">"
    elseif app.tailwind
        """<script src="https://cdn.tailwindcss.com"></script>
    <script>
        tailwind.config = {
            darkMode: 'class',
            theme: {
                extend: {
                    fontFamily: {
                        sans: ['Optima', 'Palatino Linotype', 'Book Antiqua', 'EB Garamond', 'serif'],
                        serif: ['EB Garamond', 'Palatino Linotype', 'Book Antiqua', 'Georgia', 'serif'],
                    }
                }
            }
        }
    </script>"""
    else
        ""
    end
    write(joinpath(app.output_dir, "404.html"), """
<!DOCTYPE html>
<html data-base-path="$(app.base_path)">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Page Not Found - $(app.title)</title>
    $(tailwind_404)
    <link href="https://fonts.googleapis.com/css2?family=EB+Garamond:ital,wght@0,400;0,500;0,600;0,700;1,400&display=swap" rel="stylesheet">
    <script>
        (function() {
            try {
                var bp = '$(app.base_path)';
                var sk = bp ? 'therapy-theme:' + bp : 'therapy-theme';
                var tk = bp ? 'suite-active-theme:' + bp : 'suite-active-theme';
                var s = localStorage.getItem(sk);
                if (s === 'dark' || (!s && window.matchMedia('(prefers-color-scheme: dark)').matches)) {
                    document.documentElement.classList.add('dark');
                }
                var t = localStorage.getItem(tk);
                if (t && t !== 'default') {
                    document.documentElement.setAttribute('data-theme', t);
                }
            } catch (e) {}
        })();
    </script>
</head>
<body class="antialiased bg-warm-50 dark:bg-warm-950">
    <div class="min-h-screen flex items-center justify-center">
        <div class="text-center">
            <h1 class="text-6xl font-serif font-semibold text-warm-300 dark:text-warm-700">404</h1>
            <p class="text-xl text-warm-600 dark:text-warm-400 mt-4">Page not found</p>
            <a href="$(isempty(app.base_path) ? "/" : app.base_path * "/")" class="inline-block mt-6 px-6 py-3 bg-accent-700 dark:bg-accent-600 text-white rounded hover:bg-accent-800 dark:hover:bg-accent-500 transition">
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
    optim = "--optim" in ARGS
    if length(ARGS) == 0 || ARGS[1] == "build"
        build(app; optimize_wasm=optim)
    elseif ARGS[1] == "dev"
        dev(app; optimize_wasm=optim)
    else
        println("Usage: julia app.jl [dev|build] [--optim]")
        println("  dev      - Start development server with HMR")
        println("  build    - Build static site to $(app.output_dir)/")
        println("  --optim  - Optimize WASM with wasm-tools (smaller binaries)")
    end
end
