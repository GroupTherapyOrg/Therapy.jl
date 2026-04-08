# WebSocket.jl - WebSocket connection handling for real-time features
#
# Provides WebSocket server functionality for Therapy.jl apps.
# Handles connection lifecycle, message routing, and broadcast.
#
# Two modes:
# 1. Managed connections (existing): handle_websocket() with WSConnection,
#    lifecycle callbacks, JSON message dispatch — used by default /ws endpoint.
# 2. Route-based (new, Oxygen pattern): websocket(path, handler) for custom
#    WebSocket endpoints with raw WebSocket access.

using HTTP
using JSON3
using UUIDs

# WebSocket connection wrapper
mutable struct WSConnection
    id::String
    socket::HTTP.WebSockets.WebSocket
    subscriptions::Set{String}  # Signal names this connection is subscribed to
    metadata::Dict{String, Any}  # Custom data (e.g., user info)
end

# Global connection registry
const WS_CONNECTIONS = Dict{String, WSConnection}()

# Callbacks for connection lifecycle
const ON_CONNECT_CALLBACKS = Function[]
const ON_DISCONNECT_CALLBACKS = Function[]

"""
Register a callback to run when a WebSocket connects.
"""
function on_ws_connect(fn::Function)
    push!(ON_CONNECT_CALLBACKS, fn)
end

"""
Register a callback to run when a WebSocket disconnects.
"""
function on_ws_disconnect(fn::Function)
    push!(ON_DISCONNECT_CALLBACKS, fn)
end

"""
Handle an HTTP stream that should be upgraded to WebSocket.
"""
function handle_websocket(stream::HTTP.Stream)
    HTTP.WebSockets.upgrade(stream) do ws
        conn_id = string(uuid4())
        conn = WSConnection(conn_id, ws, Set{String}(), Dict{String, Any}())
        WS_CONNECTIONS[conn_id] = conn

        # Run connect callbacks
        for cb in ON_CONNECT_CALLBACKS
            try
                cb(conn)
            catch e
                @warn "WebSocket on_connect callback error" exception=e
            end
        end

        try
            # Send initial connection acknowledgment
            send_ws_message(conn, Dict(
                "type" => "connected",
                "connection_id" => conn_id
            ))

            # Message loop
            while !HTTP.WebSockets.isclosed(ws)
                try
                    data = HTTP.WebSockets.receive(ws)
                    if !isempty(data)
                        msg_str = String(data)
                        try
                            msg = JSON3.read(msg_str, Dict{String, Any})
                            handle_ws_message(conn, msg)
                        catch e
                            @warn "WebSocket message parse error" exception=e message=msg_str
                            send_ws_error(conn, "Invalid JSON message")
                        end
                    end
                catch e
                    if e isa HTTP.WebSockets.WebSocketError
                        break  # Clean close
                    end
                    rethrow(e)
                end
            end
        catch e
            if !(e isa EOFError || e isa HTTP.WebSockets.WebSocketError)
                @warn "WebSocket error" exception=e
            end
        finally
            # Run disconnect callbacks
            for cb in ON_DISCONNECT_CALLBACKS
                try
                    cb(conn)
                catch e
                    @warn "WebSocket on_disconnect callback error" exception=e
                end
            end
            delete!(WS_CONNECTIONS, conn_id)
        end
    end
end

"""
Handle an incoming WebSocket message.
Dispatches by message type. Extensible via custom action handlers.
"""
function handle_ws_message(conn::WSConnection, msg::Dict{String, Any})
    msg_type = get(msg, "type", nothing)

    if msg_type == "action"
        # Custom client action (extensible by application code)
        handle_client_action(conn, msg)

    elseif msg_type == "ping"
        # Keepalive ping
        send_ws_message(conn, Dict("type" => "pong"))

    else
        # Dispatch as custom event for application-level handling
        send_ws_error(conn, "Unknown message type: $msg_type")
    end
end

"""
Handle a client action.
"""
function handle_client_action(conn::WSConnection, msg::Dict{String, Any})
    action = get(msg, "action", nothing)
    payload = get(msg, "payload", nothing)

    # Default implementation: log and ignore
    @info "Client action" connection=conn.id action=action payload=payload
end

"""
Send a message to a specific WebSocket connection.
"""
function send_ws_message(conn::WSConnection, msg::Dict)
    try
        json_msg = JSON3.write(msg)
        HTTP.WebSockets.send(conn.socket, json_msg)
    catch e
        @warn "Failed to send WebSocket message" exception=e connection=conn.id
    end
end

"""
Send an error message to a WebSocket connection.
"""
function send_ws_error(conn::WSConnection, error_msg::String)
    send_ws_message(conn, Dict(
        "type" => "error",
        "message" => error_msg
    ))
end

"""
Broadcast a message to all connected WebSockets.
"""
function broadcast_all(msg::Dict)
    for (_, conn) in WS_CONNECTIONS
        send_ws_message(conn, msg)
    end
end

"""
Get the number of active WebSocket connections.
"""
function ws_connection_count()
    length(WS_CONNECTIONS)
end

"""
Get all active connection IDs.
"""
function ws_connection_ids()
    collect(keys(WS_CONNECTIONS))
end

# =============================================================================
# WebSocket Route Registration — ported from Oxygen.jl's @websocket pattern
# =============================================================================
#
# Oxygen registers WebSocket routes via route(["WEBSOCKET"], path, func).
# The handler receives (ws::WebSocket) or (ws::WebSocket, params...).
# We port this as plain functions: websocket(path, handler).

struct WSRoute
    pattern::String
    segments::Vector{String}
    param_names::Vector{Symbol}
    handler::Function
end

# Global route registry
const WS_ROUTE_REGISTRY = WSRoute[]

"""
    websocket(path::String, handler::Function)

Register a WebSocket route. Ported from Oxygen.jl's underlying websocket
registration function (what `@websocket` expands to).

The handler receives a `HTTP.WebSockets.WebSocket` object (and optionally
a `Dict{Symbol,String}` of path params for parameterized routes).

# Examples
```julia
# Simple echo server
websocket("/ws/echo") do ws
    for msg in ws
        HTTP.WebSockets.send(ws, "Echo: \$msg")
    end
end

# With path parameters (WS-002)
websocket("/ws/room/:id") do ws, params
    room_id = params[:id]
    for msg in ws
        HTTP.WebSockets.send(ws, "[\$room_id] \$msg")
    end
end
```
"""
function websocket(path::String, handler::Function)
    segments = collect(String, split(path, "/"; keepempty=false))
    param_names = Symbol[]
    for seg in segments
        if startswith(seg, ":")
            push!(param_names, Symbol(seg[2:end]))
        end
    end
    push!(WS_ROUTE_REGISTRY, WSRoute(path, segments, param_names, handler))
end

# do-block support (Julia convention)
websocket(handler::Function, path::String) = websocket(path, handler)

"""
    ws_routes() -> Vector{String}

Return registered WebSocket route patterns. Useful for debugging.
"""
ws_routes() = [r.pattern for r in WS_ROUTE_REGISTRY]

"""
    clear_ws_routes!()

Clear all registered WebSocket routes. Used in tests.
"""
clear_ws_routes!() = empty!(WS_ROUTE_REGISTRY)

"""
    match_ws_route(path::String) -> Union{Tuple{Function, Dict{Symbol,String}}, Nothing}

Match a URL path against registered WebSocket routes.
Returns (handler, params) on match, nothing otherwise.
"""
function match_ws_route(path::AbstractString)
    path_parts = split(path, "/"; keepempty=false)

    for route in WS_ROUTE_REGISTRY
        params = _try_match_ws(route, path_parts)
        if params !== nothing
            return (route.handler, params)
        end
    end
    return nothing
end

function _try_match_ws(route::WSRoute, path_parts)
    route_parts = route.segments

    if isempty(route_parts) && isempty(path_parts)
        return Dict{Symbol, String}()
    end

    length(path_parts) != length(route_parts) && return nothing

    params = Dict{Symbol, String}()
    param_idx = 1

    for (i, rp) in enumerate(route_parts)
        if startswith(rp, ":")
            if param_idx <= length(route.param_names)
                params[route.param_names[param_idx]] = String(path_parts[i])
                param_idx += 1
            end
        else
            path_parts[i] != rp && return nothing
        end
    end

    return params
end

"""
    handle_ws_upgrade(stream::HTTP.Stream) -> Bool

Try to handle a WebSocket upgrade on the given stream. Checks if the request
is a WebSocket upgrade, matches against registered WS routes, and if matched,
upgrades and invokes the handler.

Returns `true` if the upgrade was handled, `false` otherwise.

Also handles the default managed `/ws` endpoint via `handle_websocket(stream)`.

# Usage in stream handlers
```julia
function my_stream_handler(stream::HTTP.Stream)
    if handle_ws_upgrade(stream)
        return  # WebSocket handled
    end
    # ... normal HTTP handling ...
end
```
"""
function handle_ws_upgrade(stream::HTTP.Stream)
    request = stream.message
    path = HTTP.URI(request.target).path

    # Check if this is a WebSocket upgrade request
    is_upgrade = any(
        h -> lowercase(String(h.first)) == "upgrade" &&
             lowercase(String(h.second)) == "websocket",
        request.headers
    )
    !is_upgrade && return false

    # Check registered WS routes first
    match = match_ws_route(path)
    if match !== nothing
        handler, params = match
        HTTP.WebSockets.upgrade(stream) do ws
            if isempty(params)
                handler(ws)
            else
                handler(ws, params)
            end
        end
        return true
    end

    # Fall back to managed WebSocket on /ws (backward compatibility)
    if path == "/ws"
        handle_websocket(stream)
        return true
    end

    return false
end
