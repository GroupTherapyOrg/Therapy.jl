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
