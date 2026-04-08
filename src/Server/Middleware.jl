# Middleware.jl - Higher-order function middleware pipeline
#
# Ported from Oxygen.jl's middleware composition pattern.
# Middleware signature: handler::Function -> (req::HTTP.Request -> HTTP.Response)
# Composition: reduce(|>, [base_handler, middleware...])
#
# Oxygen composes middleware via:
#   raw_middleware = reverse(middleware)
#   reduce(|>, [router, raw_middleware...])
# This ensures left-to-right execution order for the user-specified list.

using HTTP
using Sockets

"""
    compose_middleware(handler::Function, middleware::Vector) -> Function

Compose a base handler with a middleware pipeline using Oxygen's `reduce(|>)` pattern.

Each middleware has the signature:
    (handler::Function) -> (req::HTTP.Request -> HTTP.Response)

Middleware is applied left-to-right: the first middleware in the vector is the
outermost wrapper (runs first on request, last on response).

# Example
```julia
function my_middleware(handler)
    return function(req::HTTP.Request)
        # pre-processing
        response = handler(req)
        # post-processing
        return response
    end
end

pipeline = compose_middleware(base_handler, [mw1, mw2, mw3])
# Execution order: mw1 → mw2 → mw3 → handler → mw3 → mw2 → mw1
```
"""
function compose_middleware(handler::Function, middleware::Vector)
    isempty(middleware) && return handler
    # Oxygen pattern: reverse then reduce(|>) so first middleware is outermost
    reduce(|>, Function[handler; reverse(middleware)...])
end

"""
    write_response(stream::HTTP.Stream, response::HTTP.Response)

Write an HTTP.Response to an HTTP.Stream. Used when middleware operates on
request/response but the server uses stream-based handling.
"""
function write_response(stream::HTTP.Stream, response::HTTP.Response)
    HTTP.setstatus(stream, response.status)
    for header in response.headers
        HTTP.setheader(stream, header)
    end
    HTTP.startwrite(stream)
    write(stream, response.body)
end

# =============================================================================
# Built-in Middleware — ported from Oxygen.jl
# =============================================================================

"""
    CorsMiddleware(; kwargs...) -> Function

CORS middleware ported from Oxygen.jl's `Cors()`.

Returns a middleware function that adds CORS headers to responses and handles
OPTIONS preflight requests.

# Keywords
- `allowed_origins::Vector{String}`: Origins allowed to make requests (default: `["*"]`)
- `allowed_headers::Vector{String}`: Allowed request headers (default: `["*"]`)
- `allowed_methods::Vector{String}`: Allowed HTTP methods (default: `["GET","POST","PUT","DELETE","PATCH","OPTIONS"]`)
- `allow_credentials::Bool`: Whether to allow credentials (default: `false`)
- `max_age::Union{Int,Nothing}`: Preflight cache duration in seconds (default: `nothing`)

# Example
```julia
cors = CorsMiddleware(allowed_origins=["https://example.com"])
pipeline = compose_middleware(handler, [cors])
```
"""
function CorsMiddleware(;
    allowed_origins::Vector{String} = ["*"],
    allowed_headers::Vector{String} = ["*"],
    allowed_methods::Vector{String} = ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allow_credentials::Bool = false,
    max_age::Union{Int, Nothing} = nothing
)
    # Pre-build the CORS headers (Oxygen pattern: compute once, reuse)
    cors_headers = Pair{String,String}[
        "Access-Control-Allow-Origin" => join(allowed_origins, ", "),
        "Access-Control-Allow-Methods" => join(allowed_methods, ", "),
        "Access-Control-Allow-Headers" => join(allowed_headers, ", "),
    ]
    if allow_credentials
        push!(cors_headers, "Access-Control-Allow-Credentials" => "true")
    end
    if max_age !== nothing
        push!(cors_headers, "Access-Control-Max-Age" => string(max_age))
    end

    return function(handler::Function)
        return function(req::HTTP.Request)
            # Preflight: return 200 with CORS headers immediately
            if uppercase(req.method) == "OPTIONS"
                return HTTP.Response(200, cors_headers)
            end

            # Normal request: call handler, append CORS headers
            response = handler(req)
            for header in cors_headers
                HTTP.setheader(response, header)
            end
            return response
        end
    end
end
