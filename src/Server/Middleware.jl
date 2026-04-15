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

"""
    RateLimiterMiddleware(; kwargs...) -> Function

Fixed-window rate limiter ported from Oxygen.jl's `RateLimiter()`.

Tracks requests per client IP. Returns 429 Too Many Requests when the limit is
exceeded, with standard rate-limit headers.

# Keywords
- `rate_limit::Int`: Maximum requests per window (default: `100`)
- `window::Int`: Window duration in seconds (default: `60`)

# Headers set
- `X-RateLimit-Limit`: Maximum requests allowed per window
- `X-RateLimit-Remaining`: Requests remaining in current window
- `X-RateLimit-Reset`: Unix timestamp when the window resets
- `Retry-After`: Seconds until the window resets (only on 429)

# Example
```julia
limiter = RateLimiterMiddleware(rate_limit=10, window=60)
pipeline = compose_middleware(handler, [limiter])
```
"""
function RateLimiterMiddleware(;
    rate_limit::Int = 100,
    window::Int = 60
)
    # Oxygen pattern: Dict{IP, Tuple{count, window_start}} with ReentrantLock
    clients = Dict{String, Tuple{Int, Float64}}()
    lock = ReentrantLock()

    function get_client_ip(req::HTTP.Request)
        # Oxygen's ExtractIP checks proxy headers in order:
        # CF-Connecting-IP > True-Client-IP > X-Forwarded-For > X-Real-IP
        for header_name in ("CF-Connecting-IP", "True-Client-IP", "X-Real-IP")
            val = HTTP.header(req, header_name)
            if !isempty(val)
                return val
            end
        end
        # X-Forwarded-For: take first entry (client IP)
        xff = HTTP.header(req, "X-Forwarded-For")
        if !isempty(xff)
            return strip(first(split(xff, ",")))
        end
        # Fallback: use a default (in real server, would be socket IP)
        return "127.0.0.1"
    end

    function set_rate_headers!(response::HTTP.Response, remaining::Int, reset_time::Float64)
        HTTP.setheader(response, "X-RateLimit-Limit" => string(rate_limit))
        HTTP.setheader(response, "X-RateLimit-Remaining" => string(max(0, remaining)))
        HTTP.setheader(response, "X-RateLimit-Reset" => string(round(Int, reset_time)))
    end

    return function(handler::Function)
        return function(req::HTTP.Request)
            ip = get_client_ip(req)
            now_ts = time()

            local count::Int
            local window_start::Float64
            local remaining::Int
            local reset_time::Float64

            Base.@lock lock begin
                if haskey(clients, ip)
                    count, window_start = clients[ip]
                    if now_ts - window_start >= window
                        # Window expired, reset
                        count = 1
                        window_start = now_ts
                    else
                        count += 1
                    end
                else
                    count = 1
                    window_start = now_ts
                end
                clients[ip] = (count, window_start)
                remaining = rate_limit - count
                reset_time = window_start + window
            end

            # Over limit → 429
            if count > rate_limit
                retry_after = max(0, round(Int, reset_time - now_ts))
                response = HTTP.Response(429, body="Too Many Requests")
                set_rate_headers!(response, 0, reset_time)
                HTTP.setheader(response, "Retry-After" => string(retry_after))
                return response
            end

            # Under limit → call handler, add rate headers
            response = handler(req)
            set_rate_headers!(response, remaining, reset_time)
            return response
        end
    end
end

"""
    BearerAuthMiddleware(validate_token::Function; header="Authorization", scheme="Bearer") -> Function

Bearer token authentication middleware ported from Oxygen.jl's `BearerAuth()`.

Extracts a bearer token from the request header, validates it using the
provided function, and either passes through (on success) or returns 401.

# Arguments
- `validate_token::Function`: Called with the token string. Must return user
  info (any truthy value) on success, or `nothing` on failure.

# Keywords
- `header::String`: Header to extract token from (default: `"Authorization"`)
- `scheme::String`: Auth scheme prefix (default: `"Bearer"`)

On success, stores the user info in `req.context[:user]` so downstream
handlers can access the authenticated user.

# Example
```julia
function validate(token::String)
    token == "secret-token" ? Dict("id" => 1, "role" => "admin") : nothing
end

auth = BearerAuthMiddleware(validate)
pipeline = compose_middleware(handler, [auth])
```
"""
function BearerAuthMiddleware(
    validate_token::Function;
    header::String = "Authorization",
    scheme::String = "Bearer"
)
    prefix = scheme * " "

    return function(handler::Function)
        return function(req::HTTP.Request)
            auth_value = HTTP.header(req, header)

            # Missing header → 401
            if isempty(auth_value)
                return HTTP.Response(401, ["Content-Type" => "text/plain"], body="Unauthorized: missing $header header")
            end

            # Wrong scheme → 401
            if !startswith(auth_value, prefix)
                return HTTP.Response(401, ["Content-Type" => "text/plain"], body="Unauthorized: expected $scheme scheme")
            end

            # Extract token (Oxygen uses SubString for zero-copy)
            token = SubString(auth_value, length(prefix) + 1)

            # Validate
            user_info = validate_token(String(token))
            if user_info === nothing
                return HTTP.Response(401, ["Content-Type" => "text/plain"], body="Unauthorized: invalid token")
            end

            # Store user info in request context (Oxygen pattern: req.context[:user])
            req.context[:user] = user_info

            return handler(req)
        end
    end
end
