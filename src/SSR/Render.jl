# Render.jl - Server-side rendering to HTML

"""
Self-closing HTML tags (void elements).
"""
const VOID_ELEMENTS = Set([
    :area, :base, :br, :col, :embed, :hr, :img, :input, :link,
    :meta, :param, :source, :track, :wbr
])

"""
HTML attributes that don't need a value (boolean attributes).
"""
const BOOLEAN_ATTRIBUTES = Set([
    :async, :autofocus, :autoplay, :checked, :controls, :default,
    :defer, :disabled, :formnovalidate, :hidden, :ismap, :loop,
    :multiple, :muted, :nomodule, :novalidate, :open, :playsinline,
    :readonly, :required, :reversed, :selected
])

"""
SSR context for tracking hydration keys and state.
"""
mutable struct SSRContext
    hydration_key::Int
    signals::Dict{Int, Any}  # Signal ID -> current value (for hydration)
end

SSRContext() = SSRContext(0, Dict{Int, Any}())

"""
Generate next hydration key.
"""
function next_hydration_key!(ctx::SSRContext)::Int
    ctx.hydration_key += 1
    return ctx.hydration_key
end

"""
    render_to_string(node) -> String

Render a VNode tree to an HTML string.

# Examples
```julia
html = render_to_string(
    Div(:class => "container",
        H1("Hello World"),
        P("Welcome to Therapy.jl!")
    )
)
# => "<div class=\"container\"><h1>Hello World</h1><p>Welcome to Therapy.jl!</p></div>"
```
"""
function render_to_string(node)::String
    io = IOBuffer()
    ctx = SSRContext()
    render_html!(io, node, ctx)
    return String(take!(io))
end

"""
    render_to_string(node, ctx::SSRContext) -> String

Render with an existing SSR context (for hydration key tracking).
"""
function render_to_string(node, ctx::SSRContext)::String
    io = IOBuffer()
    render_html!(io, node, ctx)
    return String(take!(io))
end

"""
Internal: Render a node to the IO buffer.
"""
function render_html!(io::IO, node::VNode, ctx::SSRContext)
    tag = string(node.tag)

    # Open tag
    print(io, "<", tag)

    # Add hydration key
    hk = next_hydration_key!(ctx)
    print(io, " data-hk=\"", hk, "\"")

    # Render props
    render_props!(io, node.props, ctx)

    if node.tag in VOID_ELEMENTS
        # Self-closing
        print(io, " />")
    else
        print(io, ">")

        # Render children
        for child in node.children
            render_html!(io, child, ctx)
        end

        # Close tag
        print(io, "</", tag, ">")
    end
end

function render_html!(io::IO, node::ComponentInstance, ctx::SSRContext)
    # Render the component, then render its output
    rendered = render_component(node)
    render_html!(io, rendered, ctx)
end

function render_html!(io::IO, node::Fragment, ctx::SSRContext)
    for child in node.children
        render_html!(io, child, ctx)
    end
end

function render_html!(io::IO, node::ShowNode, ctx::SSRContext)
    # Render a wrapper span with show marker
    hk = next_hydration_key!(ctx)
    style = node.initial_visible ? "" : " style=\"display:none\""
    print(io, "<span data-hk=\"", hk, "\" data-show=\"true\"", style, ">")
    if node.content !== nothing
        render_html!(io, node.content, ctx)
    end
    print(io, "</span>")
end

function render_html!(io::IO, node::AbstractString, ctx::SSRContext)
    # Escape HTML entities
    print(io, escape_html(node))
end

function render_html!(io::IO, node::RawHtml, ctx::SSRContext)
    # Raw HTML - no escaping (use carefully!)
    print(io, node.content)
end

function render_html!(io::IO, node::Number, ctx::SSRContext)
    print(io, node)
end

function render_html!(io::IO, node::Bool, ctx::SSRContext)
    # Don't render booleans (like React)
end

function render_html!(io::IO, node::Nothing, ctx::SSRContext)
    # Don't render nothing
end

function render_html!(io::IO, node::Function, ctx::SSRContext)
    # Call function (e.g., signal getter) and render its result
    result = node()
    render_html!(io, result, ctx)
end

function render_html!(io::IO, node::Vector, ctx::SSRContext)
    for child in node
        render_html!(io, child, ctx)
    end
end

"""
Render props as HTML attributes.
"""
function render_props!(io::IO, props::Dict{Symbol, Any}, ctx::SSRContext)
    for (key, value) in props
        # Skip event handlers (they're for client-side only)
        startswith(string(key), "on_") && continue

        # Handle special cases
        if key == :class
            print(io, " class=\"", escape_html(string(value)), "\"")
        elseif key == :style && value isa Dict
            print(io, " style=\"", render_style(value), "\"")
        elseif key == :dangerously_set_inner_html
            # Skip, handled in children
            continue
        elseif key in BOOLEAN_ATTRIBUTES
            if value === true
                print(io, " ", string(key))
            end
        elseif value !== nothing && value !== false
            attr_name = replace(string(key), "_" => "-")
            if value isa Function
                # Call signal getters
                print(io, " ", attr_name, "=\"", escape_html(string(value())), "\"")
            else
                print(io, " ", attr_name, "=\"", escape_html(string(value)), "\"")
            end
        end
    end
end

"""
Render a style dict to CSS string.
"""
function render_style(style::Dict)::String
    parts = String[]
    for (key, value) in style
        # Convert camelCase to kebab-case
        css_key = replace(string(key), r"([A-Z])" => s"-\1")
        css_key = lowercase(css_key)
        push!(parts, "$css_key: $value")
    end
    return join(parts, "; ")
end

"""
Escape HTML entities.
"""
function escape_html(s::AbstractString)::String
    s = replace(s, "&" => "&amp;")
    s = replace(s, "<" => "&lt;")
    s = replace(s, ">" => "&gt;")
    s = replace(s, "\"" => "&quot;")
    s = replace(s, "'" => "&#39;")
    return s
end

"""
    render_page(node; title="Therapy App", wasm_url=nothing, head_extra="") -> String

Render a complete HTML document with the Therapy.jl runtime.

# Arguments
- `node`: The root VNode or component to render
- `title`: Page title (default: "Therapy App")
- `wasm_url`: URL to the Wasm module (optional, enables client-side reactivity)
- `head_extra`: Extra HTML to include in <head>

# Examples
```julia
html = render_page(
    MyApp(),
    title="My App",
    wasm_url="/app.wasm"
)
```
"""
function render_page(node; title::String="Therapy App", wasm_url::Union{String,Nothing}=nothing, head_extra::String="")
    body_content = render_to_string(node)

    # Get the runtime JS path
    runtime_js = get_runtime_js()

    wasm_script = if wasm_url !== nothing
        """
        <script>
            window.Therapy.loadWasm('$(wasm_url)').then(instance => {
                console.log('App ready');
            });
        </script>
        """
    else
        ""
    end

    return """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>$(escape_html(title))</title>
        $(head_extra)
    </head>
    <body>
        $(body_content)
        <script>
        $(runtime_js)
        </script>
        $(wasm_script)
    </body>
    </html>
    """
end

"""
Get the Therapy.jl runtime JavaScript code.
"""
function get_runtime_js()::String
    runtime_path = joinpath(@__DIR__, "..", "Runtime", "JS", "runtime.js")
    if isfile(runtime_path)
        return read(runtime_path, String)
    else
        # Fallback minimal runtime
        return """
        window.Therapy = {
            elements: new Map(),
            init() {
                document.querySelectorAll('[data-hk]').forEach(el => {
                    this.elements.set(parseInt(el.dataset.hk), el);
                });
            }
        };
        document.addEventListener('DOMContentLoaded', () => window.Therapy.init());
        """
    end
end
