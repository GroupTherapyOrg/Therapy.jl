# Channel/room subscription tests — making Sessions.jl's pattern first-class

using Test
using HTTP
using HTTP.WebSockets
using JSON3
using Sockets
using UUIDs
using Therapy

function find_free_port()
    server = Sockets.listen(Sockets.IPv4("127.0.0.1"), 0)
    _, port = Sockets.getsockname(server)
    close(server)
    return Int(port)
end

const CH_HOST = "127.0.0.1"

# Helper: create a mock WSConnection in the registry
function mock_connection(id=string(uuid4()))
    ws = nothing  # Can't easily create a real WebSocket without a connection
    conn = WSConnection(id, ws, Set{String}(), Dict{String, Any}())
    WS_CONNECTIONS[id] = conn
    return conn
end

function cleanup_connections()
    empty!(WS_CONNECTIONS)
    empty!(Therapy.ON_CHANNEL_MESSAGE_CALLBACKS)
end

@testset "WS-003: Channel/Room Subscriptions" begin

    @testset "subscribe adds channel to connection" begin
        cleanup_connections()
        conn = mock_connection("test-1")

        subscribe(conn, "general")
        @test "general" in get_subscriptions(conn)
        @test length(get_subscriptions(conn)) == 1

        subscribe(conn, "random")
        @test "random" in get_subscriptions(conn)
        @test length(get_subscriptions(conn)) == 2
        cleanup_connections()
    end

    @testset "unsubscribe removes channel" begin
        cleanup_connections()
        conn = mock_connection("test-2")

        subscribe(conn, "general")
        subscribe(conn, "random")
        @test length(get_subscriptions(conn)) == 2

        unsubscribe(conn, "general")
        @test !("general" in get_subscriptions(conn))
        @test "random" in get_subscriptions(conn)
        cleanup_connections()
    end

    @testset "unsubscribe non-existent channel is no-op" begin
        cleanup_connections()
        conn = mock_connection("test-3")
        unsubscribe(conn, "nonexistent")  # Should not error
        @test isempty(get_subscriptions(conn))
        cleanup_connections()
    end

    @testset "channel_connections returns subscribers" begin
        cleanup_connections()
        conn1 = mock_connection("c1")
        conn2 = mock_connection("c2")
        conn3 = mock_connection("c3")

        subscribe(conn1, "general")
        subscribe(conn2, "general")
        subscribe(conn3, "random")

        conns = channel_connections("general")
        @test length(conns) == 2
        @test any(c -> c.id == "c1", conns)
        @test any(c -> c.id == "c2", conns)

        conns = channel_connections("random")
        @test length(conns) == 1
        @test conns[1].id == "c3"

        @test isempty(channel_connections("nonexistent"))
        cleanup_connections()
    end

    @testset "channel_count" begin
        cleanup_connections()
        conn1 = mock_connection("c1")
        conn2 = mock_connection("c2")

        subscribe(conn1, "general")
        subscribe(conn2, "general")
        subscribe(conn1, "random")

        @test channel_count("general") == 2
        @test channel_count("random") == 1
        @test channel_count("nonexistent") == 0
        cleanup_connections()
    end

    @testset "on_channel_message registers callback" begin
        cleanup_connections()
        received = []

        on_channel_message() do channel, conn, msg
            push!(received, (channel, conn.id, get(msg, "data", nothing)))
        end

        @test length(Therapy.ON_CHANNEL_MESSAGE_CALLBACKS) == 1
        cleanup_connections()
    end

    @testset "real WebSocket: subscribe/unsubscribe via message protocol" begin
        cleanup_connections()
        port = find_free_port()

        function stream_handler(stream::HTTP.Stream)
            if handle_ws_upgrade(stream)
                return
            end
            HTTP.setstatus(stream, 404)
            HTTP.startwrite(stream)
        end

        server = HTTP.listen!(stream_handler, CH_HOST, port)

        try
            WebSockets.open("ws://$CH_HOST:$port/ws") do ws
                # Receive the "connected" ack
                ack = JSON3.read(String(WebSockets.receive(ws)), Dict{String,Any})
                @test ack["type"] == "connected"
                conn_id = ack["connection_id"]

                # Subscribe
                WebSockets.send(ws, JSON3.write(Dict("type" => "subscribe", "channel" => "room1")))
                resp = JSON3.read(String(WebSockets.receive(ws)), Dict{String,Any})
                @test resp["type"] == "subscribed"
                @test resp["channel"] == "room1"

                # Verify subscription on server side
                @test "room1" in get_subscriptions(WS_CONNECTIONS[conn_id])

                # Unsubscribe
                WebSockets.send(ws, JSON3.write(Dict("type" => "unsubscribe", "channel" => "room1")))
                resp = JSON3.read(String(WebSockets.receive(ws)), Dict{String,Any})
                @test resp["type"] == "unsubscribed"
                @test resp["channel"] == "room1"

                # Verify unsubscription
                @test !("room1" in get_subscriptions(WS_CONNECTIONS[conn_id]))
            end
        finally
            cleanup_connections()
            close(server)
        end
    end

    @testset "real WebSocket: channel_message triggers callbacks" begin
        cleanup_connections()
        port = find_free_port()

        received_messages = []
        on_channel_message() do channel, conn, msg
            push!(received_messages, (channel, get(msg, "data", nothing)))
        end

        function stream_handler(stream::HTTP.Stream)
            if handle_ws_upgrade(stream)
                return
            end
            HTTP.setstatus(stream, 404)
            HTTP.startwrite(stream)
        end

        server = HTTP.listen!(stream_handler, CH_HOST, port)

        try
            WebSockets.open("ws://$CH_HOST:$port/ws") do ws
                # Receive ack
                WebSockets.receive(ws)

                # Subscribe to channel
                WebSockets.send(ws, JSON3.write(Dict("type" => "subscribe", "channel" => "chat")))
                WebSockets.receive(ws)  # subscribed ack

                # Send channel message
                WebSockets.send(ws, JSON3.write(Dict(
                    "type" => "channel_message",
                    "channel" => "chat",
                    "data" => "hello world"
                )))

                # Give server a moment to process
                sleep(0.1)

                @test length(received_messages) == 1
                @test received_messages[1][1] == "chat"
                @test received_messages[1][2] == "hello world"
            end
        finally
            cleanup_connections()
            close(server)
        end
    end

    @testset "real WebSocket: channel_message rejected when not subscribed" begin
        cleanup_connections()
        port = find_free_port()

        function stream_handler(stream::HTTP.Stream)
            if handle_ws_upgrade(stream)
                return
            end
            HTTP.setstatus(stream, 404)
            HTTP.startwrite(stream)
        end

        server = HTTP.listen!(stream_handler, CH_HOST, port)

        try
            WebSockets.open("ws://$CH_HOST:$port/ws") do ws
                # Receive ack
                WebSockets.receive(ws)

                # Try to send channel message without subscribing
                WebSockets.send(ws, JSON3.write(Dict(
                    "type" => "channel_message",
                    "channel" => "secret",
                    "data" => "sneaky"
                )))

                # Should get error response
                resp = JSON3.read(String(WebSockets.receive(ws)), Dict{String,Any})
                @test resp["type"] == "error"
                @test occursin("Not subscribed", resp["message"])
            end
        finally
            cleanup_connections()
            close(server)
        end
    end

    @testset "real WebSocket: broadcast_channel to multiple subscribers" begin
        cleanup_connections()
        port = find_free_port()

        function stream_handler(stream::HTTP.Stream)
            if handle_ws_upgrade(stream)
                return
            end
            HTTP.setstatus(stream, 404)
            HTTP.startwrite(stream)
        end

        server = HTTP.listen!(stream_handler, CH_HOST, port)

        try
            # Connect two clients and subscribe both to "room"
            messages_1 = []
            messages_2 = []

            # Client 1
            ws1_task = @async WebSockets.open("ws://$CH_HOST:$port/ws") do ws
                WebSockets.receive(ws)  # ack
                WebSockets.send(ws, JSON3.write(Dict("type" => "subscribe", "channel" => "room")))
                WebSockets.receive(ws)  # subscribed ack

                # Wait for broadcast
                try
                    msg = JSON3.read(String(WebSockets.receive(ws)), Dict{String,Any})
                    push!(messages_1, msg)
                catch; end
            end

            # Client 2
            ws2_task = @async WebSockets.open("ws://$CH_HOST:$port/ws") do ws
                WebSockets.receive(ws)  # ack
                WebSockets.send(ws, JSON3.write(Dict("type" => "subscribe", "channel" => "room")))
                WebSockets.receive(ws)  # subscribed ack

                # Wait for broadcast
                try
                    msg = JSON3.read(String(WebSockets.receive(ws)), Dict{String,Any})
                    push!(messages_2, msg)
                catch; end
            end

            # Poll until both clients are subscribed (up to 5 seconds)
            for _ in 1:50
                channel_count("room") >= 2 && break
                sleep(0.1)
            end

            @test channel_count("room") == 2

            # Server-side broadcast to the channel
            broadcast_channel("room", Dict("type" => "announcement", "text" => "Hello room!"))

            # Wait for async tasks to complete
            for _ in 1:50
                (length(messages_1) >= 1 && length(messages_2) >= 1) && break
                sleep(0.1)
            end

            @test length(messages_1) == 1
            @test messages_1[1]["text"] == "Hello room!"
            @test length(messages_2) == 1
            @test messages_2[1]["text"] == "Hello room!"
        finally
            cleanup_connections()
            close(server)
        end
    end

end
