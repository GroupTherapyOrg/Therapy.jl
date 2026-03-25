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
Tags where content should NOT be HTML escaped (raw text elements).
"""
const RAW_TEXT_ELEMENTS = Set([:script, :style])

"""
SSR context for tracking hydration keys and state.
"""
mutable struct SSRContext
    hydration_key::Int
    signals::Dict{Int, Any}  # Signal ID -> current value (for hydration)
    in_raw_text_element::Bool  # True when inside script/style tags
end

SSRContext() = SSRContext(0, Dict{Int, Any}(), false)

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

    # Add hydration key (skip for script/style - no hydration needed)
    if node.tag ∉ RAW_TEXT_ELEMENTS
        hk = next_hydration_key!(ctx)
        print(io, " data-hk=\"", hk, "\"")
    end

    # Render props
    render_props!(io, node.props, ctx)

    if node.tag in VOID_ELEMENTS
        # Self-closing
        print(io, " />")
    else
        print(io, ">")

        # Track if we're inside a raw text element (script/style)
        was_in_raw = ctx.in_raw_text_element
        if node.tag in RAW_TEXT_ELEMENTS
            ctx.in_raw_text_element = true
        end

        # Render children
        for child in node.children
            render_html!(io, child, ctx)
        end

        # Restore raw text state
        ctx.in_raw_text_element = was_in_raw

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

function render_html!(io::IO, node::IslandVNode, ctx::SSRContext)
    # Render island with wrapper element for hydration
    # The therapy-island element marks the hydration boundary
    name = lowercase(string(node.name))
    print(io, "<therapy-island data-component=\"", name, "\"")

    # Serialize props as data-props JSON attribute for hydration
    if !isempty(node.props)
        props_json = _props_to_json(node.props)
        print(io, " data-props=\"", escape_html(props_json), "\"")
    end

    print(io, ">")

    # IMPORTANT: Reset hydration key counter for island content
    # This ensures island-internal hk values match between:
    # 1. compile_component() which analyzes the component in isolation
    # 2. Page rendering where the island appears at any position
    # Save the current hk, reset to 0, render island content, then restore
    saved_hk = ctx.hydration_key
    ctx.hydration_key = 0
    render_html!(io, node.content, ctx)
    ctx.hydration_key = saved_hk

    print(io, "</therapy-island>")
end

function render_html!(io::IO, slot::ChildrenSlot, ctx::SSRContext)
    # Render children slot content wrapped in <therapy-children> element.
    # During hydration, the parent island's cursor skips past this element.
    # Nested islands inside are discovered by the top-level JS traversal.
    print(io, "<therapy-children>")
    if slot.content !== nothing
        render_html!(io, slot.content, ctx)
    end
    print(io, "</therapy-children>")
end

function render_html!(io::IO, node::IslandDef, ctx::SSRContext)
    # If an IslandDef is rendered directly, call it first to get IslandVNode
    render_html!(io, node(), ctx)
end

function render_html!(io::IO, node::AbstractString, ctx::SSRContext)
    # Don't escape content inside script/style tags (raw text elements)
    if ctx.in_raw_text_element
        print(io, node)
    else
        # Escape HTML entities
        print(io, escape_html(node))
    end
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

function render_html!(io::IO, node::SignalGetter, ctx::SSRContext)
    # Call signal getter and render its value
    result = node()
    render_html!(io, result, ctx)
end

function render_html!(io::IO, node::MemoAnalysisGetter, ctx::SSRContext)
    # Call memo getter and render its cached value
    result = node()
    render_html!(io, result, ctx)
end

function render_html!(io::IO, node::SignalSetter, ctx::SSRContext)
    # Setters shouldn't be rendered as content, but handle gracefully
    # This shouldn't normally happen in well-formed templates
end

function render_html!(io::IO, node::Vector, ctx::SSRContext)
    for child in node
        render_html!(io, child, ctx)
    end
end

function render_html!(io::IO, node::ForNode, ctx::SSRContext)
    # Get the items (could be a signal getter or a vector)
    items = node.items isa Function ? node.items() : node.items

    # Render each item
    for (index, item) in enumerate(items)
        # Try to call with (item, index), fall back to just (item)
        rendered = try
            node.render(item, index)
        catch
            node.render(item)
        end
        render_html!(io, rendered, ctx)
    end
end

function render_html!(io::IO, node::SuspenseNode, ctx::SSRContext)
    # Render a Suspense boundary
    # During SSR, we render either the fallback (if loading) or children (if ready)
    hk = next_hydration_key!(ctx)

    # Wrap in a span with data-suspense marker for client-side hydration
    print(io, "<span data-hk=\"", hk, "\" data-suspense=\"true\">")

    if node.initial_loading
        # Render fallback content while loading
        if node.fallback !== nothing
            fallback_content = node.fallback isa Function ? node.fallback() : node.fallback
            render_html!(io, fallback_content, ctx)
        end
    else
        # Render children when ready
        if node.children !== nothing
            render_html!(io, node.children, ctx)
        end
    end

    print(io, "</span>")
end

function render_html!(io::IO, node::ErrorBoundaryNode, ctx::SSRContext)
    # Render an ErrorBoundary
    # During SSR, we render either the children (if no error) or fallback (if error)
    hk = next_hydration_key!(ctx)

    # Wrap in a span with data-error-boundary marker for client-side hydration
    print(io, "<span data-hk=\"", hk, "\" data-error-boundary=\"true\"")

    if node.error !== nothing
        # Add error info as data attribute for debugging
        print(io, " data-error=\"", escape_html(string(typeof(node.error))), "\"")
    end
    print(io, ">")

    if node.error !== nothing
        # Render fallback with error info
        if node.fallback !== nothing
            # Create a no-op reset function for SSR (real reset happens on client)
            reset_fn = () -> nothing
            fallback_content = if node.fallback isa Function
                # Fallback expects (error, reset) arguments
                try
                    node.fallback(node.error, reset_fn)
                catch
                    # Fallback might only take error, try that
                    try
                        node.fallback(node.error)
                    catch
                        # Last resort - just return text
                        "Error: $(node.error)"
                    end
                end
            else
                node.fallback
            end
            render_html!(io, fallback_content, ctx)
        else
            # No fallback, render generic error message
            print(io, "<div class=\"error\">Error: ", escape_html(string(node.error)), "</div>")
        end
    else
        # Render children when no error
        if node.children !== nothing
            render_html!(io, node.children, ctx)
        end
    end

    print(io, "</span>")
end

function render_html!(io::IO, node::OutletNode, ctx::SSRContext)
    # Render an Outlet placeholder
    # The Outlet is resolved to child content by the router's render_with_layouts function
    # By the time we get here, the OutletNode should have been resolved to actual content
    hk = next_hydration_key!(ctx)

    # Render the resolved content from the outlet context
    content = render_outlet(node)

    if content !== nothing
        # Wrap in a span with data-outlet marker for client-side navigation
        print(io, "<span data-hk=\"", hk, "\" data-outlet=\"true\">")
        render_html!(io, content, ctx)
        print(io, "</span>")
    else
        # Render empty outlet placeholder
        print(io, "<span data-hk=\"", hk, "\" data-outlet=\"empty\"></span>")
    end
end

"""
Render props as HTML attributes.

Event handler normalization:
- :on_click with String value → renders as onclick="value" (SSR pattern)
- :on_click with Function/closure → skipped (islands compile to Wasm)
- :onclick (raw) → renders as onclick="value" (legacy, deprecated)

This allows unified syntax: always use :on_click => "action()" or :on_click => () -> julia_code()
"""
function render_props!(io::IO, props::Dict{Symbol, Any}, ctx::SSRContext)
    for (key, value) in props
        key_str = string(key)

        # Handle event handlers with unified :on_click syntax
        if startswith(key_str, "on_")
            if value isa AbstractString
                # String handler: :on_click => "jsFunc()" → onclick="jsFunc()"
                # Convert on_click to onclick (remove underscore)
                html_event = replace(key_str, "_" => "")  # on_click → onclick
                print(io, " ", html_event, "=\"", escape_html(value), "\"")
            end
            # Skip closures/functions - islands compile these to Wasm
            continue
        end

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
Simple JSON serialization for island props (no external dependency).
Handles: String, Number, Bool, Nothing, Vector, Dict.
"""
function _props_to_json(props::Dict{Symbol, Any})::String
    io = IOBuffer()
    _json_value(io, props)
    return String(take!(io))
end

function _json_value(io::IO, d::Dict)
    print(io, "{")
    # Sort keys alphabetically for deterministic prop ordering.
    # Wasm accesses props by index matching compile-time alphabetical order.
    sorted_keys = sort(collect(keys(d)), by=string)
    first = true
    for k in sorted_keys
        first || print(io, ",")
        first = false
        _json_value(io, string(k))
        print(io, ":")
        _json_value(io, d[k])
    end
    print(io, "}")
end

function _json_value(io::IO, v::AbstractVector)
    print(io, "[")
    for (i, x) in enumerate(v)
        i > 1 && print(io, ",")
        _json_value(io, x)
    end
    print(io, "]")
end

function _json_value(io::IO, s::AbstractString)
    print(io, "\"")
    for c in s
        if c == '"'
            print(io, "\\\"")
        elseif c == '\\'
            print(io, "\\\\")
        elseif c == '\n'
            print(io, "\\n")
        elseif c == '\r'
            print(io, "\\r")
        elseif c == '\t'
            print(io, "\\t")
        else
            print(io, c)
        end
    end
    print(io, "\"")
end

function _json_value(io::IO, nt::NamedTuple)
    print(io, "{")
    ks = keys(nt)
    for (i, k) in enumerate(ks)
        i > 1 && print(io, ",")
        _json_value(io, string(k))
        print(io, ":")
        _json_value(io, nt[k])
    end
    print(io, "}")
end

_json_value(io::IO, n::Number) = print(io, n)
_json_value(io::IO, b::Bool) = print(io, b ? "true" : "false")
_json_value(io::IO, ::Nothing) = print(io, "null")
_json_value(io::IO, s::Symbol) = _json_value(io, string(s))

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
