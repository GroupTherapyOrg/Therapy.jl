# WebSocket.jl - WebSocket connection handling for real-time features
#
# Provides WebSocket server functionality for Therapy.jl apps.
# Enables server signals, bidirectional communication, and real-time updates.

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
"""
function handle_ws_message(conn::WSConnection, msg::Dict{String, Any})
    msg_type = get(msg, "type", nothing)

    if msg_type == "subscribe"
        # Subscribe to a signal
        signal_name = get(msg, "signal", nothing)
        if signal_name !== nothing
            push!(conn.subscriptions, signal_name)
            # Send current value if available
            if haskey(SERVER_SIGNALS, signal_name)
                signal = SERVER_SIGNALS[signal_name]
                send_ws_message(conn, Dict(
                    "type" => "signal_update",
                    "signal" => signal_name,
                    "value" => signal.value
                ))
            end
        end

    elseif msg_type == "unsubscribe"
        # Unsubscribe from a signal
        signal_name = get(msg, "signal", nothing)
        if signal_name !== nothing
            delete!(conn.subscriptions, signal_name)
        end

    elseif msg_type == "action"
        # Client action (for custom actions)
        handle_client_action(conn, msg)

    elseif msg_type == "bidirectional_update"
        # Client updating a bidirectional signal
        signal_name = get(msg, "signal", nothing)
        patch = get(msg, "patch", [])
        if signal_name !== nothing
            # handle_client_signal_update is defined in BidirectionalSignal.jl
            handle_client_signal_update(conn, signal_name, patch)
        end

    elseif msg_type == "channel_message"
        # Client sending a message on a channel
        channel_name = get(msg, "channel", nothing)
        data = get(msg, "data", nothing)
        if channel_name !== nothing
            # handle_channel_message is defined in Channel.jl
            handle_channel_message(conn, channel_name, data)
        end

    elseif msg_type == "server_function_call"
        # Server function RPC call
        # handle_server_function_call is defined in ServerFunctions.jl
        handle_server_function_call(conn, msg)

    elseif msg_type == "ping"
        # Keepalive ping
        send_ws_message(conn, Dict("type" => "pong"))

    else
        send_ws_error(conn, "Unknown message type: $msg_type")
    end
end

"""
Handle a client action (for bidirectional signals).
"""
function handle_client_action(conn::WSConnection, msg::Dict{String, Any})
    # Override in application code to handle custom actions
    signal_name = get(msg, "signal", nothing)
    action = get(msg, "action", nothing)
    payload = get(msg, "payload", nothing)

    # Default implementation: log and ignore
    @info "Client action" connection=conn.id signal=signal_name action=action payload=payload
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
Broadcast a signal update (full value) to all subscribed connections.
"""
function broadcast_signal_update(signal_name::String, value)
    msg = Dict(
        "type" => "signal_update",
        "signal" => signal_name,
        "value" => value
    )

    for (_, conn) in WS_CONNECTIONS
        if signal_name in conn.subscriptions
            send_ws_message(conn, msg)
        end
    end
end

"""
Broadcast a signal patch (RFC 6902) to all subscribed connections.
More efficient than full updates for complex values.
"""
function broadcast_signal_patch(signal_name::String, patch::Vector)
    msg = Dict(
        "type" => "signal_patch",
        "signal" => signal_name,
        "patch" => patch
    )

    for (_, conn) in WS_CONNECTIONS
        if signal_name in conn.subscriptions
            send_ws_message(conn, msg)
        end
    end
end

"""
Broadcast a signal patch to all subscribed connections EXCEPT one.
Used for bidirectional signals to avoid echoing back to sender.
"""
function broadcast_signal_patch_except(signal_name::String, patch::Vector, exclude_conn_id::String)
    msg = Dict(
        "type" => "signal_patch",
        "signal" => signal_name,
        "patch" => patch
    )

    for (id, conn) in WS_CONNECTIONS
        if id != exclude_conn_id && signal_name in conn.subscriptions
            send_ws_message(conn, msg)
        end
    end
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

# Reference to SERVER_SIGNALS from ServerSignal.jl (will be defined there)
# This avoids circular dependency
const SERVER_SIGNALS = Dict{String, Any}()
