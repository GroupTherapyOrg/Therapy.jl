# DevServer.jl - Simple development server for Therapy.jl

using HTTP
using Sockets

"""
MIME types for common file extensions.
"""
const MIME_TYPES = Dict(
    ".html" => "text/html",
    ".css" => "text/css",
    ".js" => "application/javascript",
    ".json" => "application/json",
    ".wasm" => "application/wasm",
    ".png" => "image/png",
    ".jpg" => "image/jpeg",
    ".jpeg" => "image/jpeg",
    ".gif" => "image/gif",
    ".svg" => "image/svg+xml",
    ".ico" => "image/x-icon",
)

"""
Get MIME type from file extension.
"""
function get_mime_type(path::String)::String
    ext = lowercase(splitext(path)[2])
    get(MIME_TYPES, ext, "application/octet-stream")
end

"""
    serve(app; port=8080, host="127.0.0.1", static_dir=nothing)

Start a development server for a Therapy.jl application.

# Arguments
- `app`: A function that takes a request path and returns HTML content, or a VNode
- `port`: Port to listen on (default: 8080)
- `host`: Host to bind to (default: "127.0.0.1")
- `static_dir`: Directory to serve static files from (optional)

# Examples
```julia
# Simple app
serve(8080) do path
    render_to_string(
        Div(H1("Hello from Therapy.jl!"))
    )
end

# With static files
serve(8080, static_dir="public") do path
    if path == "/"
        render_to_string(MyApp())
    else
        nothing  # Will try static files
    end
end
```
"""
function serve(app::Function; port::Int=8080, host::String="127.0.0.1", static_dir::Union{String,Nothing}=nothing)
    println("Starting Therapy.jl dev server...")
    println("Listening on http://$host:$port")
    println("Press Ctrl+C to stop\n")

    server = HTTP.serve!(host, port) do request
        path = HTTP.URI(request.target).path
        path = path == "" ? "/" : path

        # Try the app first
        try
            result = app(path)
            if result !== nothing
                content = if result isa VNode || result isa ComponentInstance || result isa Fragment
                    render_to_string(result)
                else
                    string(result)
                end
                return HTTP.Response(200, ["Content-Type" => "text/html; charset=utf-8"], content)
            end
        catch e
            if !(e isa MethodError)
                @error "App error" exception=(e, catch_backtrace())
                return HTTP.Response(500, "Internal Server Error: $e")
            end
        end

        # Try static files
        if static_dir !== nothing
            file_path = joinpath(static_dir, lstrip(path, '/'))
            if isfile(file_path)
                content = read(file_path)
                mime = get_mime_type(file_path)
                return HTTP.Response(200, ["Content-Type" => mime], content)
            end
        end

        # 404
        return HTTP.Response(404, "Not Found: $path")
    end

    # Keep running until interrupted
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

"""
    serve(port::Int, app::Function; kwargs...)

Convenience method with port as first argument.
"""
serve(port::Int, app::Function; kwargs...) = serve(app; port=port, kwargs...)

"""
    serve(app::Function, port::Int; kwargs...)

Convenience method for do-block syntax: `serve(8080, static_dir=dir) do path ... end`
"""
serve(app::Function, port::Int; kwargs...) = serve(app; port=port, kwargs...)

"""
    serve_static(dir::String; port::Int=8080, host::String="127.0.0.1")

Serve static files from a directory.
"""
function serve_static(dir::String; port::Int=8080, host::String="127.0.0.1")
    serve(port=port, host=host, static_dir=dir) do path
        # Check for index.html
        if path == "/" && isfile(joinpath(dir, "index.html"))
            return read(joinpath(dir, "index.html"), String)
        end
        nothing
    end
end
