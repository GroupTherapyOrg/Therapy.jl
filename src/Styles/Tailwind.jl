# Tailwind.jl - Tailwind CSS integration for Therapy.jl
#
# Two modes:
# 1. CDN (development) - Quick setup, no build step
# 2. CLI (production) - Optimized, only includes used classes

"""
    tailwind_cdn(; plugins=[], config=nothing)

Generate Tailwind CSS CDN script tag for development.
Uses the Play CDN which works great for development.

# Example
```julia
render_page(MyApp();
    head_extra = tailwind_cdn()
)
```
"""
function tailwind_cdn(; plugins::Vector{String}=String[], dark_mode::String="class")
    plugin_urls = join([
        "<script src=\"https://cdn.tailwindcss.com/\$(p)\"></script>"
        for p in plugins
    ], "\n    ")

    config_script = """
    <script>
        tailwind.config = {
            darkMode: '$(dark_mode)',
            theme: {
                extend: {}
            }
        }
    </script>
    """

    return """
    <script src="https://cdn.tailwindcss.com"></script>
    $(plugin_urls)
    $(config_script)
    """
end

"""
    tailwind_config(; content=["**/*.jl"], theme=Dict(), plugins=[])

Generate a tailwind.config.js content for production builds.
Write this to tailwind.config.js and run the Tailwind CLI.

# Example
```julia
config = tailwind_config(
    content = ["src/**/*.jl", "routes/**/*.jl"],
    theme = Dict("extend" => Dict("colors" => Dict("brand" => "#ff6b6b")))
)
write("tailwind.config.js", config)
# Then run: npx tailwindcss -i input.css -o output.css
```
"""
function tailwind_config(;
    content::Vector{String}=["**/*.jl"],
    theme::Dict=Dict(),
    plugins::Vector{String}=String[],
    dark_mode::String="class"
)
    content_json = "[" * join(["\"$c\"" for c in content], ", ") * "]"
    theme_json = dict_to_js(theme)
    plugins_json = "[" * join(plugins, ", ") * "]"

    return """
/** @type {import('tailwindcss').Config} */
module.exports = {
    content: $(content_json),
    darkMode: '$(dark_mode)',
    theme: $(theme_json),
    plugins: $(plugins_json),
}
"""
end

"""
Convert a Julia Dict to JavaScript object literal string.
"""
function dict_to_js(d::Dict)
    if isempty(d)
        return "{}"
    end

    parts = String[]
    for (k, v) in d
        key = string(k)
        if v isa Dict
            value = dict_to_js(v)
        elseif v isa String
            value = "\"$v\""
        elseif v isa Vector
            value = "[" * join(["\"$x\"" for x in v], ", ") * "]"
        else
            value = string(v)
        end
        push!(parts, "\"$key\": $value")
    end

    return "{\n        " * join(parts, ",\n        ") * "\n    }"
end

"""
    tw(classes...)

Helper to join Tailwind classes. Filters out empty strings and nothing.

# Example
```julia
Div(:class => tw("flex", "items-center", is_active && "bg-blue-500"),
    "Content"
)
```
"""
function tw(classes...)
    valid = filter(c -> c !== nothing && c !== "" && c !== false, classes)
    return join(string.(valid), " ")
end

# Export tw helper
export tw

"""
Base CSS for Tailwind (minimal reset).
Include this if not using the CDN.
"""
const TAILWIND_BASE_CSS = """
@tailwind base;
@tailwind components;
@tailwind utilities;
"""

"""
    tailwind_input_css()

Returns the input CSS content for Tailwind CLI.
Write this to input.css before running the Tailwind CLI.
"""
function tailwind_input_css()
    return TAILWIND_BASE_CSS
end

"""
Common Tailwind class combinations as Julia constants for convenience.
"""
module TW
    # Layout
    const FLEX_CENTER = "flex items-center justify-center"
    const FLEX_BETWEEN = "flex items-center justify-between"
    const FLEX_COL = "flex flex-col"
    const GRID_CENTER = "grid place-items-center"

    # Sizing
    const FULL = "w-full h-full"
    const SCREEN = "w-screen h-screen"

    # Spacing
    const CONTAINER = "container mx-auto px-4"

    # Buttons
    const BTN = "px-4 py-2 rounded font-medium transition-colors"
    const BTN_PRIMARY = "px-4 py-2 rounded font-medium bg-blue-500 text-white hover:bg-blue-600"
    const BTN_SECONDARY = "px-4 py-2 rounded font-medium bg-gray-200 text-gray-800 hover:bg-gray-300"
    const BTN_DANGER = "px-4 py-2 rounded font-medium bg-red-500 text-white hover:bg-red-600"

    # Inputs
    const INPUT = "px-3 py-2 border rounded focus:outline-none focus:ring-2 focus:ring-blue-500"

    # Cards
    const CARD = "bg-white rounded-lg shadow p-6"
    const CARD_DARK = "bg-gray-800 rounded-lg shadow p-6"

    # Text
    const HEADING = "text-2xl font-bold"
    const SUBHEADING = "text-lg font-semibold text-gray-600"
    const MUTED = "text-gray-500 text-sm"
end

export TW

"""
    build_tailwind_css(;
        input_css::String,
        output_file::String,
        minify::Bool=true,
        cwd::String="."
    )

Build Tailwind CSS using the CLI. Tries local binary, standalone CLI, then npx.

Tailwind v4 auto-detects config from:
- `@config` directive in input CSS
- `tailwind.config.js` in the same directory as input CSS

Returns `true` if build succeeded, `false` if no CLI available.

# Example
```julia
success = build_tailwind_css(
    input_css = "docs/input.css",
    output_file = "docs/dist/styles.css",
    cwd = "docs"
)
```
"""
function build_tailwind_css(;
    input_css::String,
    output_file::String,
    minify::Bool=true,
    cwd::String="."
)
    # Ensure output directory exists
    mkpath(dirname(output_file))

    # Convert all paths to absolute to avoid issues with --cwd
    abs_input = abspath(input_css)
    abs_output = abspath(output_file)
    abs_cwd = abspath(cwd)

    minify_flag = minify ? `--minify` : ``
    cwd_flag = `--cwd $abs_cwd`

    # Search for local binary in multiple locations
    # Use ./ prefix for current directory to ensure it's executed as a path, not a command
    search_paths = [
        joinpath(cwd, "tailwindcss"),                      # Same dir as cwd
        joinpath(dirname(cwd), "tailwindcss"),             # One level up from cwd
        joinpath(dirname(dirname(cwd)), "tailwindcss"),    # Two levels up (e.g., for docs/src/)
        joinpath(".", "tailwindcss"),                       # Current working directory with ./
        joinpath("..", "tailwindcss"),                      # Parent of current working directory
        joinpath("..", "..", "tailwindcss")                 # Grandparent of current working directory
    ]
    local_binary_idx = findfirst(isfile, search_paths)
    local_binary = local_binary_idx !== nothing ? abspath(search_paths[local_binary_idx]) : nothing

    # Try local binary first (use Base.run to avoid conflict with Therapy.run)
    if local_binary !== nothing
        try
            cmd = `$local_binary -i $abs_input -o $abs_output $minify_flag $cwd_flag`
            Base.run(cmd, wait=true)
            return true
        catch e
            # Local binary failed, continue to try other methods
            @debug "Local tailwindcss binary failed: $e"
        end
    end

    # Try standalone CLI in PATH
    try
        cmd = `tailwindcss -i $abs_input -o $abs_output $minify_flag $cwd_flag`
        Base.run(cmd, wait=true)
        return true
    catch
        # Standalone CLI not found, try npx
    end

    # Try npx (requires Node.js + tailwindcss installed)
    try
        cmd = `npx tailwindcss -i $abs_input -o $abs_output $minify_flag $cwd_flag`
        Base.run(cmd, wait=true)
        return true
    catch
        # npx also failed
    end

    @warn "Tailwind CLI not found. Install standalone CLI or Node.js. Using CDN fallback."
    return false
end

"""
    ensure_tailwind_input(dir::String; source_paths::Vector{String}=["./src/**/*.jl"])

Create input.css in the given directory if it doesn't exist.
Uses Tailwind v4 CSS-first configuration format with @source directives.
Returns the path to the input file.
"""
function ensure_tailwind_input(dir::String; source_paths::Vector{String}=["./src/**/*.jl"])
    input_path = joinpath(dir, "input.css")

    if !isfile(input_path)
        # Generate @source directives for each content path
        source_directives = join(["@source \"$path\";" for path in source_paths], "\n")

        input_content = """
@import "tailwindcss";

/* Configure content sources for Tailwind v4 */
$source_directives

/* Theme customizations */
@theme {
  --font-sans: 'Source Sans 3', system-ui, sans-serif;
  --font-serif: 'Lora', Georgia, Cambria, serif;
}

/* Custom base styles */
@layer base {
  html {
    scroll-behavior: smooth;
  }
  pre code {
    font-family: 'Fira Code', 'Monaco', 'Consolas', monospace;
  }
}
"""
        write(input_path, input_content)
        println("  Created: input.css")
    end

    return input_path
end
