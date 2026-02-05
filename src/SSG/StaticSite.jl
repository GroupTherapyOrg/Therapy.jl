# StaticSite.jl - Static Site Generator for Therapy.jl
#
# Generates static HTML sites from Therapy.jl components with
# WebAssembly interactivity. Perfect for documentation, blogs,
# and GitHub Pages deployment.
#
# How it works (SSR + Hydration):
# 1. Build time: Renders components to static HTML with hydration markers (data-hk)
# 2. Build time: Compiles interactive handlers to Wasm modules
# 3. Runtime: Browser loads HTML (fast initial paint)
# 4. Runtime: JavaScript loads Wasm and connects event handlers (page becomes interactive)

"""
Configuration for static site generation.
"""
struct SiteConfig
    output_dir::String
    title::String
    use_tailwind_cdn::Bool
    include_prism::Bool
    base_path::String

    function SiteConfig(;
        output_dir::String = "dist",
        title::String = "Therapy.jl Site",
        use_tailwind_cdn::Bool = true,
        include_prism::Bool = true,
        base_path::String = ""
    )
        new(output_dir, title, use_tailwind_cdn, include_prism, rstrip(base_path, '/'))
    end
end

"""
Represents a page route in the static site.
"""
struct PageRoute
    path::String           # URL path (e.g., "/", "/about/")
    component::Function    # Function that returns a VNode
    title::String          # Page title
end

"""
Result of building a static site.
"""
struct BuildResult
    success::Bool
    pages_built::Int
    output_dir::String
    errors::Vector{String}
end

"""
    generate_html_page(component_fn; config, route) -> String

Generate a full HTML page from a Therapy.jl component.
"""
function generate_html_page(component_fn::Function; config::SiteConfig, route::PageRoute)
    # Render the component to HTML
    content = render_to_string(Base.invokelatest(component_fn))

    page_title = isempty(route.title) ? config.title : "$(route.title) - $(config.title)"

    tailwind_script = config.use_tailwind_cdn ? """
    <script src="https://cdn.tailwindcss.com"></script>
    <script>
        tailwind.config = {
            theme: {
                extend: {
                    fontFamily: {
                        sans: ['Inter', 'system-ui', 'sans-serif'],
                    }
                }
            }
        }
    </script>""" : ""

    prism_css = config.include_prism ?
        """<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/themes/prism-tomorrow.min.css">""" : ""

    prism_js = config.include_prism ? """
    <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/prism.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/components/prism-julia.min.js"></script>""" : ""

    """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$(page_title)</title>
    $(tailwind_script)
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=EB+Garamond:ital,wght@0,400;0,500;0,600;0,700;1,400&display=swap" rel="stylesheet">
    $(prism_css)
    <style>
        html { scroll-behavior: smooth; }
        pre code { font-family: 'JuliaMono', 'Fira Code', 'JetBrains Mono', monospace; }
    </style>
</head>
<body class="antialiased">
$(content)
$(prism_js)
    <script type="module">
        // Hydration support for Wasm modules
        const wasmPath = document.body.dataset.wasmModule;
        if (wasmPath) {
            try {
                const response = await fetch(wasmPath);
                const bytes = await response.arrayBuffer();
                const imports = {
                    dom: {
                        update_text_i32: (hk, value) => {
                            const el = document.querySelector('[data-hk="' + hk + '"]');
                            if (el) el.textContent = String(value);
                        },
                        update_text_f64: (hk, value) => {
                            const el = document.querySelector('[data-hk="' + hk + '"]');
                            if (el) el.textContent = String(value);
                        },
                        set_visible: (hk, visible) => {
                            const el = document.querySelector('[data-hk="' + hk + '"]');
                            if (el) el.style.display = visible ? '' : 'none';
                        }
                    }
                };
                const { instance } = await WebAssembly.instantiate(bytes, imports);
                document.querySelectorAll('[data-handler]').forEach(el => {
                    const handlerName = el.dataset.handler;
                    const eventType = el.dataset.event || 'click';
                    const handler = instance.exports[handlerName];
                    if (handler) el.addEventListener(eventType, handler);
                });
                if (instance.exports.init) instance.exports.init();
            } catch (err) {
                console.warn('Wasm load failed:', err);
            }
        }
    </script>
</body>
</html>
"""
end

"""
    build_static_site(routes; config) -> BuildResult

Build a static site from a list of routes.

# Arguments
- `routes`: Vector of PageRoute or tuples (path, component) or (path, component, title)
- `config`: SiteConfig with output directory and options

# Example
```julia
routes = [
    PageRoute("/", HomePage, "Home"),
    PageRoute("/about/", AboutPage, "About Us"),
]

result = build_static_site(routes, config=SiteConfig(output_dir="dist"))
```
"""
function build_static_site(routes::Vector; config::SiteConfig = SiteConfig())
    errors = String[]
    pages_built = 0

    println("Building static site...")
    println("  Output: $(config.output_dir)")

    # Clean and create output directory
    rm(config.output_dir, recursive=true, force=true)
    mkpath(config.output_dir)
    mkpath(joinpath(config.output_dir, "wasm"))

    # Normalize routes
    normalized_routes = PageRoute[]
    for r in routes
        if r isa PageRoute
            push!(normalized_routes, r)
        elseif r isa Tuple
            if length(r) == 2
                push!(normalized_routes, PageRoute(r[1], r[2], ""))
            else
                push!(normalized_routes, PageRoute(r[1], r[2], r[3]))
            end
        end
    end

    # Build each route
    for route in normalized_routes
        try
            println("  Building: $(route.path)")

            html = generate_html_page(route.component, config=config, route=route)

            # Determine output path
            if route.path == "/"
                output_path = joinpath(config.output_dir, "index.html")
            else
                output_dir = joinpath(config.output_dir, strip(route.path, '/'))
                mkpath(output_dir)
                output_path = joinpath(output_dir, "index.html")
            end

            write(output_path, html)
            pages_built += 1
        catch e
            push!(errors, "Error building $(route.path): $(sprint(showerror, e))")
        end
    end

    # Create 404 page
    write(joinpath(config.output_dir, "404.html"), """
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Page Not Found - $(config.title)</title>
    $(config.use_tailwind_cdn ? "<script src=\"https://cdn.tailwindcss.com\"></script>" : "")
</head>
<body class="antialiased bg-gray-50">
    <div class="min-h-screen flex items-center justify-center">
        <div class="text-center">
            <h1 class="text-6xl font-bold text-gray-300">404</h1>
            <p class="text-xl text-gray-600 mt-4">Page not found</p>
            <a href="$(isempty(config.base_path) ? "/" : config.base_path * "/")" class="inline-block mt-6 px-6 py-3 bg-indigo-600 text-white rounded-lg hover:bg-indigo-500 transition">Go Home</a>
        </div>
    </div>
</body>
</html>
""")

    # Create .nojekyll for GitHub Pages
    write(joinpath(config.output_dir, ".nojekyll"), "")

    success = isempty(errors)
    if success
        println("\nBuild complete! $(pages_built) pages generated.")
    else
        println("\nBuild completed with errors:")
        for err in errors
            println("  - $err")
        end
    end

    return BuildResult(success, pages_built, config.output_dir, errors)
end
