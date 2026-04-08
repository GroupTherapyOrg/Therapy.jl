# WebSocket parameterized path tests — Oxygen's {param} pattern adapted to :param

using Test
using HTTP
using HTTP.WebSockets
using Sockets
using Therapy

function find_free_port()
    server = Sockets.listen(Sockets.IPv4("127.0.0.1"), 0)
    _, port = Sockets.getsockname(server)
    close(server)
    return Int(port)
end

const WSP_HOST = "127.0.0.1"

@testset "WS-002: Parameterized WebSocket Paths" begin

    @testset "match_ws_route extracts single param" begin
        clear_ws_routes!()
        websocket("/ws/room/:id") do ws, params
            nothing
        end

        result = match_ws_route("/ws/room/42")
        @test result !== nothing
        _, params = result
        @test params[:id] == "42"

        # Non-matching path
        @test match_ws_route("/ws/room") === nothing
        @test match_ws_route("/ws/room/42/extra") === nothing
        clear_ws_routes!()
    end

    @testset "match_ws_route extracts multiple params" begin
        clear_ws_routes!()
        websocket("/ws/:org/:room") do ws, params
            nothing
        end

        result = match_ws_route("/ws/acme/general")
        @test result !== nothing
        _, params = result
        @test params[:org] == "acme"
        @test params[:room] == "general"
        clear_ws_routes!()
    end

    @testset "real WebSocket: room-based echo" begin
        clear_ws_routes!()
        port = find_free_port()

        websocket("/ws/room/:id") do ws, params
            room_id = params[:id]
            for msg in ws
                WebSockets.send(ws, "[Room $room_id] " * String(msg))
            end
        end

        function stream_handler(stream::HTTP.Stream)
            if handle_ws_upgrade(stream)
                return
            end
            HTTP.setstatus(stream, 404)
            HTTP.startwrite(stream)
        end

        server = HTTP.listen!(stream_handler, WSP_HOST, port)

        try
            # Room 1
            WebSockets.open("ws://$WSP_HOST:$port/ws/room/1") do ws
                WebSockets.send(ws, "hello")
                resp = String(WebSockets.receive(ws))
                @test resp == "[Room 1] hello"
            end

            # Room 42
            WebSockets.open("ws://$WSP_HOST:$port/ws/room/42") do ws
                WebSockets.send(ws, "world")
                resp = String(WebSockets.receive(ws))
                @test resp == "[Room 42] world"
            end
        finally
            clear_ws_routes!()
            close(server)
        end
    end

    @testset "real WebSocket: multiple params" begin
        clear_ws_routes!()
        port = find_free_port()

        websocket("/ws/:org/:channel") do ws, params
            for msg in ws
                WebSockets.send(ws, "$(params[:org])/$(params[:channel]): " * String(msg))
            end
        end

        function stream_handler(stream::HTTP.Stream)
            if handle_ws_upgrade(stream)
                return
            end
            HTTP.setstatus(stream, 404)
            HTTP.startwrite(stream)
        end

        server = HTTP.listen!(stream_handler, WSP_HOST, port)

        try
            WebSockets.open("ws://$WSP_HOST:$port/ws/acme/general") do ws
                WebSockets.send(ws, "hi")
                resp = String(WebSockets.receive(ws))
                @test resp == "acme/general: hi"
            end
        finally
            clear_ws_routes!()
            close(server)
        end
    end

    @testset "real WebSocket: parameterized + static routes coexist" begin
        clear_ws_routes!()
        port = find_free_port()

        # Static route
        websocket("/ws/broadcast") do ws
            for msg in ws
                WebSockets.send(ws, "broadcast: " * String(msg))
            end
        end

        # Parameterized route
        websocket("/ws/user/:id") do ws, params
            for msg in ws
                WebSockets.send(ws, "user($(params[:id])): " * String(msg))
            end
        end

        function stream_handler(stream::HTTP.Stream)
            if handle_ws_upgrade(stream)
                return
            end
            HTTP.setstatus(stream, 404)
            HTTP.startwrite(stream)
        end

        server = HTTP.listen!(stream_handler, WSP_HOST, port)

        try
            # Static route
            WebSockets.open("ws://$WSP_HOST:$port/ws/broadcast") do ws
                WebSockets.send(ws, "test")
                @test String(WebSockets.receive(ws)) == "broadcast: test"
            end

            # Parameterized route
            WebSockets.open("ws://$WSP_HOST:$port/ws/user/7") do ws
                WebSockets.send(ws, "test")
                @test String(WebSockets.receive(ws)) == "user(7): test"
            end
        finally
            clear_ws_routes!()
            close(server)
        end
    end

end
