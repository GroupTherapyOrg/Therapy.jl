# Integration tests — all server features working together
#
# Single server with:
# - API routes with middleware (CORS + rate limiter + auth)
# - WebSocket routes (static + parameterized)
# - Channel subscriptions
# - Real HTTP and WebSocket connections

using Test
using HTTP
using HTTP.WebSockets
using JSON
using Sockets
using Therapy

function find_free_port()
    server = Sockets.listen(Sockets.IPv4("127.0.0.1"), 0)
    _, port = Sockets.getsockname(server)
    close(server)
    return Int(port)
end

const INT_HOST = "127.0.0.1"

@testset "INT-001: Full Integration" begin

    clear_ws_routes!()
    port = find_free_port()

    # ── Token validator ──────────────────────────────────────────────────
    function validate_token(token::String)
        tokens = Dict(
            "admin-token" => Dict("id" => 1, "role" => "admin"),
            "user-token" => Dict("id" => 2, "role" => "user")
        )
        get(tokens, token, nothing)
    end

    # ── API routes ───────────────────────────────────────────────────────
    api = create_api_router([
        "/api/health" => Dict(
            "GET" => (req, params) -> Dict("status" => "ok")
        ),
        "/api/protected" => Dict(
            "GET" => (req, params) -> begin
                user = get(req.context, :user, nothing)
                Dict("message" => "secret", "user" => user)
            end
        ),
        "/api/users" => Dict(
            "GET" => (req, params) -> [
                Dict("id" => 1, "name" => "Alice"),
                Dict("id" => 2, "name" => "Bob")
            ],
            "POST" => (req, params) -> begin
                body = JSON.parse(String(req.body))
                json_response(Dict("id" => 3, "name" => body["name"]); status=201)
            end
        ),
        "/api/users/:id" => Dict(
            "GET" => (req, params) -> Dict("id" => parse(Int, params[:id]), "name" => "User $(params[:id])")
        )
    ])

    # ── Middleware stack ─────────────────────────────────────────────────
    cors = CorsMiddleware(
        allowed_origins=["https://myapp.com"],
        allow_credentials=true,
        max_age=86400
    )
    limiter = RateLimiterMiddleware(rate_limit=50, window=60)
    auth = BearerAuthMiddleware(validate_token)

    # Public API: CORS + rate limiter (no auth)
    public_pipeline = compose_middleware(api, [cors, limiter])

    # Protected API: CORS + rate limiter + auth
    protected_api = create_api_router([
        "/api/protected" => Dict(
            "GET" => (req, params) -> begin
                user = get(req.context, :user, nothing)
                Dict("message" => "secret", "user" => user)
            end
        )
    ])
    protected_pipeline = compose_middleware(protected_api, [cors, limiter, auth])

    # ── WebSocket routes ─────────────────────────────────────────────────
    websocket("/ws/echo") do ws
        for msg in ws
            WebSockets.send(ws, "echo: " * String(msg))
        end
    end

    websocket("/ws/room/:id") do ws, params
        for msg in ws
            WebSockets.send(ws, "[$(params[:id])] " * String(msg))
        end
    end

    # ── Combined stream handler ──────────────────────────────────────────
    function stream_handler(stream::HTTP.Stream)
        # WebSocket upgrades first
        if handle_ws_upgrade(stream)
            return
        end

        # Read request body from stream (needed for POST/PUT/PATCH in stream mode)
        request = stream.message
        request.body = read(stream)

        path = HTTP.URI(request.target).path

        # Route to the appropriate pipeline
        response = if startswith(path, "/api/protected")
            protected_pipeline(request)
        else
            public_pipeline(request)
        end

        write_response(stream, response)
    end

    server = HTTP.listen!(stream_handler, INT_HOST, port)

    try
        # ── API Tests ────────────────────────────────────────────────────

        @testset "health check (public)" begin
            resp = HTTP.get("http://$INT_HOST:$port/api/health")
            @test resp.status == 200
            data = JSON.parse(String(resp.body))
            @test data["status"] == "ok"

            # Has CORS headers
            @test HTTP.header(resp, "Access-Control-Allow-Origin") == "https://myapp.com"
            # Has rate limit headers
            @test !isempty(HTTP.header(resp, "X-RateLimit-Limit"))
        end

        @testset "CORS preflight" begin
            resp = HTTP.request("OPTIONS", "http://$INT_HOST:$port/api/users"; status_exception=false)
            @test resp.status == 200
            @test HTTP.header(resp, "Access-Control-Allow-Origin") == "https://myapp.com"
            @test HTTP.header(resp, "Access-Control-Allow-Credentials") == "true"
            @test HTTP.header(resp, "Access-Control-Max-Age") == "86400"
        end

        @testset "GET /api/users (public)" begin
            resp = HTTP.get("http://$INT_HOST:$port/api/users")
            @test resp.status == 200
            data = JSON.parse(String(resp.body))
            @test length(data) == 2
        end

        @testset "POST /api/users (public)" begin
            resp = HTTP.post("http://$INT_HOST:$port/api/users",
                ["Content-Type" => "application/json"],
                JSON.json(Dict("name" => "Charlie")))
            @test resp.status == 201
            data = JSON.parse(String(resp.body))
            @test data["name"] == "Charlie"
        end

        @testset "GET /api/users/:id (dynamic param)" begin
            resp = HTTP.get("http://$INT_HOST:$port/api/users/42")
            data = JSON.parse(String(resp.body))
            @test data["id"] == 42
            @test data["name"] == "User 42"
        end

        @testset "405 for unsupported method" begin
            resp = HTTP.request("DELETE", "http://$INT_HOST:$port/api/users"; status_exception=false)
            @test resp.status == 405
        end

        @testset "protected endpoint requires auth" begin
            # No auth → 401
            resp = HTTP.get("http://$INT_HOST:$port/api/protected"; status_exception=false)
            @test resp.status == 401

            # Bad token → 401
            resp = HTTP.get("http://$INT_HOST:$port/api/protected";
                headers=["Authorization" => "Bearer bad"],
                status_exception=false)
            @test resp.status == 401

            # Valid token → 200
            resp = HTTP.get("http://$INT_HOST:$port/api/protected";
                headers=["Authorization" => "Bearer admin-token"])
            @test resp.status == 200
            data = JSON.parse(String(resp.body))
            @test data["message"] == "secret"
            @test data["user"]["role"] == "admin"

            # CORS headers present even on protected endpoint
            @test HTTP.header(resp, "Access-Control-Allow-Origin") == "https://myapp.com"
        end

        # ── WebSocket Tests ──────────────────────────────────────────────

        @testset "WebSocket echo" begin
            WebSockets.open("ws://$INT_HOST:$port/ws/echo") do ws
                WebSockets.send(ws, "hello")
                @test String(WebSockets.receive(ws)) == "echo: hello"
            end
        end

        @testset "WebSocket parameterized room" begin
            WebSockets.open("ws://$INT_HOST:$port/ws/room/lobby") do ws
                WebSockets.send(ws, "hi")
                @test String(WebSockets.receive(ws)) == "[lobby] hi"
            end
        end

        @testset "managed WS with channels" begin
            WebSockets.open("ws://$INT_HOST:$port/ws") do ws
                # Receive connection ack
                ack = JSON.parse(String(WebSockets.receive(ws)))
                @test ack["type"] == "connected"

                # Subscribe to channel
                WebSockets.send(ws, JSON.json(Dict("type" => "subscribe", "channel" => "alerts")))
                resp = JSON.parse(String(WebSockets.receive(ws)))
                @test resp["type"] == "subscribed"

                # Verify server-side subscription
                conn_id = ack["connection_id"]
                @test "alerts" in get_subscriptions(WS_CONNECTIONS[conn_id])

                # Ping/pong still works
                WebSockets.send(ws, JSON.json(Dict("type" => "ping")))
                pong = JSON.parse(String(WebSockets.receive(ws)))
                @test pong["type"] == "pong"
            end
        end

        @testset "HTTP and WS coexist on same port" begin
            # HTTP works
            resp = HTTP.get("http://$INT_HOST:$port/api/health")
            @test resp.status == 200

            # WS works at the same time
            WebSockets.open("ws://$INT_HOST:$port/ws/echo") do ws
                WebSockets.send(ws, "test")
                @test String(WebSockets.receive(ws)) == "echo: test"
            end

            # HTTP still works after WS
            resp = HTTP.get("http://$INT_HOST:$port/api/health")
            @test resp.status == 200
        end

    finally
        clear_ws_routes!()
        empty!(WS_CONNECTIONS)
        empty!(Therapy.ON_CHANNEL_MESSAGE_CALLBACKS)
        close(server)
    end

end
