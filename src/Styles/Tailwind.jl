# Tailwind.jl - Tailwind CSS integration for Therapy.jl
#
# Two modes:
# 1. CDN (development) - Quick setup, no build step
# 2. CLI (production) - Optimized, only includes used classes
#
# The CLI binary is auto-downloaded on first use (zero config).

import Downloads
import SHA

# ─── Tailwind CLI Auto-Provisioning ────────────────────────────────────────

const TAILWIND_VERSION = "v4.1.18"

# Platform → binary name mapping
const TAILWIND_BINARIES = Dict{Tuple{Symbol, Symbol}, String}(
    (:Darwin, :aarch64)  => "tailwindcss-macos-arm64",
    (:Darwin, :x86_64)   => "tailwindcss-macos-x64",
    (:Linux, :x86_64)    => "tailwindcss-linux-x64",
    (:Linux, :aarch64)   => "tailwindcss-linux-arm64",
    (:Windows, :x86_64)  => "tailwindcss-windows-x64.exe",
)

# SHA256 checksums for v4.1.18 binaries
const TAILWIND_CHECKSUMS = Dict{String, String}(
    "tailwindcss-macos-arm64"     => "7f27711dceac1a580b6ad58ddac46e59202c85a6c16f2f08f6fdcdee261008e1",
    "tailwindcss-macos-x64"       => "1e8a77fd796a3a4aa3d8727887de926ef9d38477aba113fd7c32c0d31a32a3ab",
    "tailwindcss-linux-x64"       => "737becf8d4ad1115ea98df69fa94026d402ca8feb91306a035b5b004167da8dd",
    "tailwindcss-linux-arm64"     => "7a7702db6c93718a9b6655d455304edda18600f5a4f195242342ed3b5b70ebe8",
    "tailwindcss-windows-x64.exe" => "55bc5a2e294520a74fe3523eaa11915ef50047e7228a545aa181ec413cf52612",
)

"""
    _tailwind_binary_name() -> String

Return the Tailwind CLI binary name for the current platform.
"""
function _tailwind_binary_name()
    key = (Sys.KERNEL, Sys.ARCH)
    if haskey(TAILWIND_BINARIES, key)
        return TAILWIND_BINARIES[key]
    end
    error("""
        Unsupported platform: $(Sys.KERNEL)-$(Sys.ARCH)
        Supported platforms: $(join(["$k[1]-$k[2]" for k in keys(TAILWIND_BINARIES)], ", "))
        You can manually download the Tailwind CLI from:
        https://github.com/tailwindlabs/tailwindcss/releases/tag/$(TAILWIND_VERSION)
        """)
end

"""
    _tailwind_cache_dir() -> String

Return the cache directory for Tailwind CLI binaries.
Uses the first Julia depot path (typically ~/.julia/).
"""
function _tailwind_cache_dir()
    return joinpath(first(Base.DEPOT_PATH), "tailwind", TAILWIND_VERSION)
end

"""
    _verify_tailwind_checksum(path::String, binary_name::String)

Verify the SHA256 checksum of a downloaded Tailwind binary.
Deletes the file and throws an error if verification fails.
"""
function _verify_tailwind_checksum(path::String, binary_name::String)
    expected = get(TAILWIND_CHECKSUMS, binary_name, nothing)
    expected === nothing && return  # No checksum available, skip verification

    actual = bytes2hex(open(SHA.sha256, path))
    if actual != expected
        rm(path, force=true)
        error("""
            SHA256 checksum mismatch for $(binary_name)!
            Expected: $(expected)
            Got:      $(actual)
            The downloaded binary has been deleted. Please try again.
            """)
    end
end

"""
    ensure_tailwind_cli() -> String

Ensure a working Tailwind CSS CLI binary is available and return its path.

On first call, downloads the correct platform-specific binary from GitHub Releases
and caches it in `~/.julia/tailwind/vX.Y.Z/`. Subsequent calls return the cached path.
The download is verified with SHA256 checksums.
"""
function ensure_tailwind_cli()::String
    binary_name = _tailwind_binary_name()

    # 1. Check Julia-managed cache first (most common path after first run)
    cache_dir = _tailwind_cache_dir()
    cached_path = joinpath(cache_dir, binary_name)
    if isfile(cached_path)
        return cached_path
    end

    # 2. Download from GitHub Releases
    mkpath(cache_dir)
    url = "https://github.com/tailwindlabs/tailwindcss/releases/download/$(TAILWIND_VERSION)/$(binary_name)"

    println("  Downloading Tailwind CSS $(TAILWIND_VERSION) for $(Sys.KERNEL)-$(Sys.ARCH)...")
    println("  URL: $(url)")

    try
        Downloads.download(url, cached_path)
    catch e
        rm(cached_path, force=true)
        error("""
            Failed to download Tailwind CSS CLI: $(e)

            You can manually download it from:
            $(url)

            Then place it at: $(cached_path)
            Or anywhere in your project directory as 'tailwindcss'
            """)
    end

    # 3. Make executable (Unix only)
    if !Sys.iswindows()
        chmod(cached_path, 0o755)
    end

    # 4. Verify checksum
    _verify_tailwind_checksum(cached_path, binary_name)

    println("  Cached at: $(cached_path)")
    return cached_path
end

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
    const CARD = "bg-warm-50 rounded-lg shadow p-6"
    const CARD_DARK = "bg-warm-800 rounded-lg shadow p-6"

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

Build Tailwind CSS using the CLI.

Search order for the CLI binary:
1. Auto-provisioned binary via `ensure_tailwind_cli()` (auto-downloads on first use)
2. `tailwindcss` in system PATH
3. `npx tailwindcss` (requires Node.js)

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

    # 1. Try auto-provisioned binary (downloads on first use, cached thereafter)
    try
        cli_path = ensure_tailwind_cli()
        cmd = `$cli_path -i $abs_input -o $abs_output $minify_flag $cwd_flag`
        Base.run(cmd, wait=true)
        return true
    catch e
        @debug "Auto-provisioned Tailwind CLI failed: $e"
    end

    # 2. Try standalone CLI in PATH
    try
        cmd = `tailwindcss -i $abs_input -o $abs_output $minify_flag $cwd_flag`
        Base.run(cmd, wait=true)
        return true
    catch
        # Standalone CLI not found, try npx
    end

    # 3. Try npx (requires Node.js + tailwindcss installed)
    try
        cmd = `npx tailwindcss -i $abs_input -o $abs_output $minify_flag $cwd_flag`
        Base.run(cmd, wait=true)
        return true
    catch
        # npx also failed
    end

    @warn "Tailwind CLI not available. Auto-download failed and no CLI found in PATH. Using CDN fallback."
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
  --font-sans: 'Optima', 'Palatino Linotype', 'Book Antiqua', 'EB Garamond', serif;
  --font-serif: 'EB Garamond', 'Palatino Linotype', 'Book Antiqua', Georgia, serif;
}

/* Custom base styles */
@layer base {
  html {
    scroll-behavior: smooth;
  }
  pre code {
    font-family: 'JuliaMono', 'Fira Code', 'JetBrains Mono', monospace;
  }
}
"""
        write(input_path, input_content)
        println("  Created: input.css")
    end

    return input_path
end
