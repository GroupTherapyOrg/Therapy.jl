# WebSocket routing tests — real WebSocket connections, Oxygen test patterns

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

const WS_HOST = "127.0.0.1"

@testset "WS-001: WebSocket Path Routing" begin

    # Clean slate for each test run
    clear_ws_routes!()

    @testset "websocket() registers a route" begin
        clear_ws_routes!()
        websocket("/ws/test") do ws
            nothing
        end
        @test length(ws_routes()) == 1
        @test ws_routes()[1] == "/ws/test"
        clear_ws_routes!()
    end

    @testset "multiple routes registered" begin
        clear_ws_routes!()
        websocket("/ws/a", ws -> nothing)
        websocket("/ws/b", ws -> nothing)
        websocket("/ws/c", ws -> nothing)
        @test length(ws_routes()) == 3
        clear_ws_routes!()
    end

    @testset "match_ws_route finds correct handler" begin
        clear_ws_routes!()
        websocket("/ws/echo", ws -> "echo")
        websocket("/ws/chat", ws -> "chat")

        result = match_ws_route("/ws/echo")
        @test result !== nothing
        handler, params, mw = result
        @test isempty(params)
        @test isempty(mw)

        result = match_ws_route("/ws/chat")
        @test result !== nothing

        @test match_ws_route("/ws/nonexistent") === nothing
        clear_ws_routes!()
    end

    @testset "clear_ws_routes! removes all routes" begin
        clear_ws_routes!()
        websocket("/ws/temp", ws -> nothing)
        @test length(ws_routes()) == 1
        clear_ws_routes!()
        @test isempty(ws_routes())
    end

    @testset "real WebSocket: echo server" begin
        clear_ws_routes!()
        port = find_free_port()

        websocket("/ws/echo") do ws
            for msg in ws
                WebSockets.send(ws, "Echo: " * String(msg))
            end
        end

        # Stream handler that delegates to WS upgrade
        function stream_handler(stream::HTTP.Stream)
            if handle_ws_upgrade(stream)
                return
            end
            HTTP.setstatus(stream, 200)
            HTTP.startwrite(stream)
            write(stream, "OK")
        end

        server = HTTP.listen!(stream_handler, WS_HOST, port)

        try
            # Connect and test echo
            WebSockets.open("ws://$WS_HOST:$port/ws/echo") do ws
                WebSockets.send(ws, "Hello")
                response = String(WebSockets.receive(ws))
                @test response == "Echo: Hello"

                WebSockets.send(ws, "World")
                response = String(WebSockets.receive(ws))
                @test response == "Echo: World"
            end
        finally
            clear_ws_routes!()
            close(server)
        end
    end

    @testset "real WebSocket: multiple paths" begin
        clear_ws_routes!()
        port = find_free_port()

        websocket("/ws/upper") do ws
            for msg in ws
                WebSockets.send(ws, uppercase(String(msg)))
            end
        end

        websocket("/ws/lower") do ws
            for msg in ws
                WebSockets.send(ws, lowercase(String(msg)))
            end
        end

        function stream_handler(stream::HTTP.Stream)
            if handle_ws_upgrade(stream)
                return
            end
            HTTP.setstatus(stream, 404)
            HTTP.startwrite(stream)
            write(stream, "Not Found")
        end

        server = HTTP.listen!(stream_handler, WS_HOST, port)

        try
            # Test /ws/upper
            WebSockets.open("ws://$WS_HOST:$port/ws/upper") do ws
                WebSockets.send(ws, "hello")
                @test String(WebSockets.receive(ws)) == "HELLO"
            end

            # Test /ws/lower
            WebSockets.open("ws://$WS_HOST:$port/ws/lower") do ws
                WebSockets.send(ws, "HELLO")
                @test String(WebSockets.receive(ws)) == "hello"
            end
        finally
            clear_ws_routes!()
            close(server)
        end
    end

    @testset "real WebSocket: HTTP requests still work alongside WS" begin
        clear_ws_routes!()
        port = find_free_port()

        websocket("/ws/ping") do ws
            for msg in ws
                WebSockets.send(ws, "pong")
            end
        end

        function stream_handler(stream::HTTP.Stream)
            if handle_ws_upgrade(stream)
                return
            end
            # Normal HTTP response
            HTTP.setstatus(stream, 200)
            HTTP.setheader(stream, "Content-Type" => "text/plain")
            HTTP.startwrite(stream)
            write(stream, "HTTP OK")
        end

        server = HTTP.listen!(stream_handler, WS_HOST, port)

        try
            # HTTP request works
            resp = HTTP.get("http://$WS_HOST:$port/hello")
            @test resp.status == 200
            @test String(resp.body) == "HTTP OK"

            # WebSocket also works
            WebSockets.open("ws://$WS_HOST:$port/ws/ping") do ws
                WebSockets.send(ws, "ping")
                @test String(WebSockets.receive(ws)) == "pong"
            end
        finally
            clear_ws_routes!()
            close(server)
        end
    end

    # ── WS-004: WebSocket middleware ─────────────────────────────────────

    @testset "websocket() accepts middleware kwarg" begin
        clear_ws_routes!()
        mw = handler -> (req -> handler(req))
        websocket("/ws/mw-test", ws -> nothing; middleware=[mw])
        result = match_ws_route("/ws/mw-test")
        @test result !== nothing
        _, _, route_mw = result
        @test length(route_mw) == 1
        clear_ws_routes!()
    end

    @testset "WS middleware: auth rejects unauthenticated upgrade" begin
        clear_ws_routes!()
        port = find_free_port()

        validate_fn = token -> token == "ws-secret" ? Dict("user" => "ok") : nothing
        auth = BearerAuthMiddleware(validate_fn)

        websocket("/ws/secure", ws -> begin
            for msg in ws
                WebSockets.send(ws, "secure: " * String(msg))
            end
        end; middleware=[auth])

        function stream_handler(stream::HTTP.Stream)
            if handle_ws_upgrade(stream)
                return
            end
            HTTP.setstatus(stream, 404)
            HTTP.startwrite(stream)
            write(stream, "Not Found")
        end

        server = HTTP.listen!(stream_handler, WS_HOST, port)

        try
            # Without auth: upgrade rejected — HTTP.jl throws on non-101
            rejected = false
            try
                WebSockets.open("ws://$WS_HOST:$port/ws/secure") do ws
                    WebSockets.send(ws, "hi")
                end
            catch e
                rejected = true
            end
            @test rejected

            # With auth: upgrade succeeds
            WebSockets.open("ws://$WS_HOST:$port/ws/secure";
                headers=["Authorization" => "Bearer ws-secret"]) do ws
                WebSockets.send(ws, "hello")
                @test String(WebSockets.receive(ws)) == "secure: hello"
            end
        finally
            clear_ws_routes!()
            close(server)
        end
    end

    @testset "WS middleware: runs before handler" begin
        clear_ws_routes!()
        port = find_free_port()

        # Middleware that adds a header to 200 (passes through)
        tracking_mw = function(handler)
            return function(req::HTTP.Request)
                resp = handler(req)
                HTTP.setheader(resp, "X-WS-Middleware" => "applied")
                return resp
            end
        end

        websocket("/ws/tracked", ws -> begin
            for msg in ws
                WebSockets.send(ws, "tracked: " * String(msg))
            end
        end; middleware=[tracking_mw])

        function stream_handler(stream::HTTP.Stream)
            if handle_ws_upgrade(stream)
                return
            end
            HTTP.setstatus(stream, 404)
            HTTP.startwrite(stream)
        end

        server = HTTP.listen!(stream_handler, WS_HOST, port)

        try
            # Connection should succeed (middleware returns 200)
            WebSockets.open("ws://$WS_HOST:$port/ws/tracked") do ws
                WebSockets.send(ws, "test")
                @test String(WebSockets.receive(ws)) == "tracked: test"
            end
        finally
            clear_ws_routes!()
            close(server)
        end
    end

end
