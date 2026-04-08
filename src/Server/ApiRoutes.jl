# ApiRoutes.jl - API route handling for Therapy.jl
#
# Adapted from Oxygen.jl's route registration pattern (the functions behind @get/@post).
# Therapy uses file-based routing, so API routes are registered programmatically
# via create_api_router() and work with the middleware pipeline.
#
# Route files in routes/api/ return Dict{String, Function} mapping HTTP methods
# to handlers. Each handler receives (req::HTTP.Request, params::Dict{Symbol,String}).

using HTTP
using JSON3

"""
    json_response(data; status=200, headers=Pair{String,String}[]) -> HTTP.Response

Create an HTTP.Response with JSON-serialized body.

# Example
```julia
json_response(["a", "b"])                    # 200 + JSON
json_response(Dict("error" => "nope"); status=400)  # 400 + JSON
```
"""
function json_response(data; status::Int=200, headers::Vector{Pair{String,String}}=Pair{String,String}[])
    body = JSON3.write(data)
    all_headers = Pair{String,String}["Content-Type" => "application/json"; headers...]
    HTTP.Response(status, all_headers, body=body)
end

# ── Internal route matching ──────────────────────────────────────────────────

struct ApiRoute
    pattern::String
    segments::Vector{String}
    param_names::Vector{Symbol}
    is_catch_all::Bool
    handlers::Dict{String, Function}
end

function _parse_api_route(pattern::String, handlers::Dict)
    segments = collect(String, split(pattern, "/"; keepempty=false))
    param_names = Symbol[]
    is_catch_all = false
    for seg in segments
        if startswith(seg, ":")
            push!(param_names, Symbol(seg[2:end]))
        elseif seg == "*"
            is_catch_all = true
        end
    end
    normalized = Dict{String,Function}(uppercase(String(k)) => v for (k, v) in handlers)
    ApiRoute(pattern, segments, param_names, is_catch_all, normalized)
end

function _try_match_api(route::ApiRoute, path_parts::Vector{<:AbstractString})
    route_parts = route.segments

    if isempty(route_parts) && isempty(path_parts)
        return Dict{Symbol, String}()
    end

    params = Dict{Symbol, String}()
    param_idx = 1

    for (i, rp) in enumerate(route_parts)
        if rp == "*"
            if param_idx <= length(route.param_names)
                params[route.param_names[param_idx]] = join(path_parts[i:end], "/")
            end
            return params
        elseif startswith(rp, ":")
            i > length(path_parts) && return nothing
            if param_idx <= length(route.param_names)
                params[route.param_names[param_idx]] = path_parts[i]
                param_idx += 1
            end
        else
            (i > length(path_parts) || path_parts[i] != rp) && return nothing
        end
    end

    !route.is_catch_all && length(path_parts) != length(route_parts) && return nothing
    return params
end

# ── Public API ───────────────────────────────────────────────────────────────

"""
    create_api_router(routes) -> Function

Create a request handler from a vector of API route definitions.
Returns a function with signature `(req::HTTP.Request) -> HTTP.Response`
suitable for use with `compose_middleware`.

Each route is a Pair: `"/path/:param" => Dict("GET" => handler, ...)`.
Handlers receive `(req::HTTP.Request, params::Dict{Symbol,String})` and return:
- Any Julia value → auto-serialized to JSON (200)
- `HTTP.Response` → returned as-is
- `nothing` → 204 No Content

# Example
```julia
api = create_api_router([
    "/api/users" => Dict(
        "GET" => (req, params) -> ["user1", "user2"],
        "POST" => (req, params) -> json_response(Dict("id" => 1); status=201)
    ),
    "/api/users/:id" => Dict(
        "GET" => (req, params) -> Dict("id" => params[:id])
    )
])

pipeline = compose_middleware(api, [CorsMiddleware()])
server = HTTP.serve!(pipeline, "127.0.0.1", 8080)
```
"""
function create_api_router(routes::Vector)
    api_routes = [_parse_api_route(String(p), h) for (p, h) in routes]

    # Sort: specific routes before dynamic (same logic as Router.jl)
    sort!(api_routes, by = r -> begin
        score = 0
        r.is_catch_all && (score += 1000)
        score += count(s -> startswith(s, ":"), r.segments) * 10
        score += length(r.segments)
        score
    end)

    return function(req::HTTP.Request)
        path = HTTP.URI(req.target).path
        method = uppercase(req.method)
        path_parts = split(path, "/"; keepempty=false)

        for route in api_routes
            params = _try_match_api(route, path_parts)
            if params !== nothing
                handler = get(route.handlers, method, nothing)
                if handler === nothing
                    allowed = join(sort(collect(keys(route.handlers))), ", ")
                    return HTTP.Response(405, ["Allow" => allowed, "Content-Type" => "text/plain"], body="Method Not Allowed")
                end

                result = handler(req, params)

                # Auto-serialize based on return type
                if result isa HTTP.Response
                    return result
                elseif result === nothing
                    return HTTP.Response(204)
                else
                    return json_response(result)
                end
            end
        end

        return HTTP.Response(404, ["Content-Type" => "text/plain"], body="Not Found")
    end
end
