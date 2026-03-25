# WebSocket.jl - WebSocket connection handling for real-time features
#
# Provides WebSocket server functionality for Therapy.jl apps.
# Handles connection lifecycle, message routing, and broadcast.

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
