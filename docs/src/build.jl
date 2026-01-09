# build.jl - Static site generator for Therapy.jl docs
#
# Generates a static site from Therapy.jl components for GitHub Pages deployment.
# Uses REAL Therapy.jl compilation for interactive Wasm demos.
#
# Usage:
#   julia --project=../.. docs/src/build.jl
#
# Output goes to docs/dist/

using Therapy

const DOCS_ROOT = dirname(@__FILE__)
const DIST_DIR = joinpath(dirname(DOCS_ROOT), "dist")

# Routes to generate (path => source file)
const ROUTES = [
    "/" => "routes/index.jl",
    "/getting-started/" => "routes/getting-started.jl",
]

"""
Interactive Counter component - compiled to Wasm using Therapy.jl
"""
function InteractiveCounter()
    count, set_count = create_signal(0)

    Div(:class => "flex justify-center items-center gap-6",
        Button(:class => "w-12 h-12 rounded-full bg-white text-indigo-600 text-2xl font-bold hover:bg-indigo-100 transition",
               :on_click => () -> set_count(count() - 1),
               "-"),
        Span(:class => "text-5xl font-bold tabular-nums",
             count),
        Button(:class => "w-12 h-12 rounded-full bg-white text-indigo-600 text-2xl font-bold hover:bg-indigo-100 transition",
               :on_click => () -> set_count(count() + 1),
               "+")
    )
end

"""
Build the interactive counter using Therapy.jl's compile_component.
Returns the HTML, Wasm bytes, and hydration JS.
"""
function build_interactive_counter()
    println("  Compiling InteractiveCounter with Therapy.jl...")

    # Use container_selector to scope DOM queries to #counter-demo
    # This prevents conflicts with other data-hk attributes on the page
    compiled = compile_component(InteractiveCounter; container_selector="#counter-demo")

    println("    Wasm: $(length(compiled.wasm.bytes)) bytes")
    println("    Exports: $(join(compiled.wasm.exports, ", "))")

    return compiled
end

"""
Generate a full HTML page with Tailwind CSS.
"""
function generate_page(component_fn; title="Therapy.jl Docs", counter_html="", counter_js="")
    # Get the rendered component HTML (use invokelatest for dynamic includes)
    content = render_to_string(Base.invokelatest(component_fn))

    # If we have counter HTML, inject it into the counter-demo div
    if !isempty(counter_html)
        content = replace(content,
            r"<div[^>]*id=\"counter-demo\"[^>]*>.*?</div>"s =>
            """<div id="counter-demo" class="bg-white/10 backdrop-blur rounded-xl p-8 max-w-md mx-auto">$counter_html</div>""")
    end

    # Wrap in full HTML document
    """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$(title)</title>

    <!-- Tailwind CSS from CDN -->
    <script src="https://cdn.tailwindcss.com"></script>

    <!-- Custom Tailwind config -->
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
    </script>

    <!-- Inter font -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">

    <!-- Syntax highlighting -->
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/themes/prism-tomorrow.min.css">

    <style>
        html { scroll-behavior: smooth; }
        pre code { font-family: 'Fira Code', 'Monaco', 'Consolas', monospace; }
    </style>
</head>
<body class="antialiased">
    $(content)

    <!-- Syntax highlighting -->
    <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/prism.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/components/prism-julia.min.js"></script>

    $(isempty(counter_js) ? "" : "<script>\n$counter_js\n</script>")
</body>
</html>
"""
end

"""
Build all static pages.
"""
function build()
    println("Building Therapy.jl documentation site...")
    println("Output directory: $DIST_DIR")

    # Clean and create dist directory
    rm(DIST_DIR, recursive=true, force=true)
    mkpath(DIST_DIR)
    mkpath(joinpath(DIST_DIR, "wasm"))

    # Build the interactive counter component using Therapy.jl compilation
    println("\n━━━ Compiling Interactive Components ━━━")
    compiled_counter = build_interactive_counter()

    # Write the Wasm file
    wasm_path = joinpath(DIST_DIR, "app.wasm")
    write(wasm_path, compiled_counter.wasm.bytes)
    println("  Wrote: $wasm_path")

    # Generate each route
    println("\n━━━ Building Pages ━━━")
    for (route_path, source_file) in ROUTES
        println("  Building: $route_path")

        # Load the component module
        source_path = joinpath(DOCS_ROOT, source_file)
        component_fn = include(source_path)

        # Generate HTML
        route_title = if route_path == "/"
            "Therapy.jl - Reactive Web Framework for Julia"
        else
            "Therapy.jl - $(titlecase(basename(strip(route_path, '/'))))"
        end

        # For the home page, include the compiled counter
        if route_path == "/"
            html = Base.invokelatest(generate_page, component_fn,
                title=route_title,
                counter_html=compiled_counter.html,
                counter_js=compiled_counter.hydration.js)
        else
            html = Base.invokelatest(generate_page, component_fn, title=route_title)
        end

        # Determine output path
        if route_path == "/"
            output_path = joinpath(DIST_DIR, "index.html")
        else
            output_dir = joinpath(DIST_DIR, strip(route_path, '/'))
            mkpath(output_dir)
            output_path = joinpath(output_dir, "index.html")
        end

        write(output_path, html)
        println("    -> $(output_path)")
    end

    # Create a simple 404 page
    write(joinpath(DIST_DIR, "404.html"), """
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Page Not Found - Therapy.jl</title>
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="antialiased bg-gray-50">
    <div class="min-h-screen flex items-center justify-center">
        <div class="text-center">
            <h1 class="text-6xl font-bold text-gray-300">404</h1>
            <p class="text-xl text-gray-600 mt-4">Page not found</p>
            <a href="/" class="inline-block mt-6 px-6 py-3 bg-indigo-600 text-white rounded-lg hover:bg-indigo-500 transition">
                Go Home
            </a>
        </div>
    </div>
</body>
</html>
""")

    # Create .nojekyll file for GitHub Pages
    write(joinpath(DIST_DIR, ".nojekyll"), "")

    println("\n━━━ Build Complete! ━━━")
    println("Files in dist/:")
    for (root, dirs, files) in walkdir(DIST_DIR)
        for file in files
            rel_path = relpath(joinpath(root, file), DIST_DIR)
            println("  $rel_path")
        end
    end
end

# Run build if this is the main script
if abspath(PROGRAM_FILE) == @__FILE__
    build()
end
