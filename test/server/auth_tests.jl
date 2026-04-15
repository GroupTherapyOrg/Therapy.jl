# BearerAuth middleware tests — ported from Oxygen.jl's auth test patterns

using Test
using HTTP
using Sockets
using Therapy

function find_free_port()
    server = Sockets.listen(Sockets.IPv4("127.0.0.1"), 0)
    _, port = Sockets.getsockname(server)
    close(server)
    return Int(port)
end

const AUTH_HOST = "127.0.0.1"

@testset "MW-004: BearerAuthMiddleware" begin

    # Simple token validator
    function validate_token(token::String)
        if token == "valid-token-123"
            return Dict("id" => 1, "name" => "Admin")
        elseif token == "user-token"
            return Dict("id" => 2, "name" => "User", "role" => "user")
        end
        return nothing
    end

    function test_handler(req::HTTP.Request)
        HTTP.Response(200, ["Content-Type" => "text/plain"], body="OK")
    end

    @testset "missing Authorization header returns 401" begin
        auth = BearerAuthMiddleware(validate_token)
        pipeline = compose_middleware(test_handler, [auth])

        resp = pipeline(HTTP.Request("GET", "/"))
        @test resp.status == 401
        @test occursin("missing", String(resp.body))
    end

    @testset "wrong scheme returns 401" begin
        auth = BearerAuthMiddleware(validate_token)
        pipeline = compose_middleware(test_handler, [auth])

        resp = pipeline(HTTP.Request("GET", "/", ["Authorization" => "Basic dXNlcjpwYXNz"]))
        @test resp.status == 401
        @test occursin("scheme", String(resp.body))
    end

    @testset "invalid token returns 401" begin
        auth = BearerAuthMiddleware(validate_token)
        pipeline = compose_middleware(test_handler, [auth])

        resp = pipeline(HTTP.Request("GET", "/", ["Authorization" => "Bearer bad-token"]))
        @test resp.status == 401
        @test occursin("invalid", String(resp.body))
    end

    @testset "valid token passes through to handler" begin
        auth = BearerAuthMiddleware(validate_token)
        pipeline = compose_middleware(test_handler, [auth])

        resp = pipeline(HTTP.Request("GET", "/", ["Authorization" => "Bearer valid-token-123"]))
        @test resp.status == 200
        @test String(resp.body) == "OK"
    end

    @testset "user info stored in req.context[:user]" begin
        user_seen = Ref{Any}(nothing)

        function context_handler(req::HTTP.Request)
            user_seen[] = get(req.context, :user, nothing)
            HTTP.Response(200, body="OK")
        end

        auth = BearerAuthMiddleware(validate_token)
        pipeline = compose_middleware(context_handler, [auth])

        pipeline(HTTP.Request("GET", "/", ["Authorization" => "Bearer valid-token-123"]))
        @test user_seen[] !== nothing
        @test user_seen[]["id"] == 1
        @test user_seen[]["name"] == "Admin"
    end

    @testset "different tokens yield different user info" begin
        user_seen = Ref{Any}(nothing)

        function context_handler(req::HTTP.Request)
            user_seen[] = get(req.context, :user, nothing)
            HTTP.Response(200, body="OK")
        end

        auth = BearerAuthMiddleware(validate_token)
        pipeline = compose_middleware(context_handler, [auth])

        pipeline(HTTP.Request("GET", "/", ["Authorization" => "Bearer user-token"]))
        @test user_seen[]["role"] == "user"
    end

    @testset "custom header and scheme" begin
        function api_key_validator(key::String)
            key == "my-api-key" ? Dict("app" => "test") : nothing
        end

        auth = BearerAuthMiddleware(api_key_validator; header="X-API-Key", scheme="Key")
        pipeline = compose_middleware(test_handler, [auth])

        # Missing custom header
        resp = pipeline(HTTP.Request("GET", "/"))
        @test resp.status == 401

        # Wrong scheme
        resp = pipeline(HTTP.Request("GET", "/", ["X-API-Key" => "Bearer something"]))
        @test resp.status == 401

        # Correct custom header + scheme
        resp = pipeline(HTTP.Request("GET", "/", ["X-API-Key" => "Key my-api-key"]))
        @test resp.status == 200
    end

    @testset "auth + CORS stacking" begin
        auth = BearerAuthMiddleware(validate_token)
        cors = CorsMiddleware()
        pipeline = compose_middleware(test_handler, [cors, auth])

        # Authenticated request gets both auth pass-through and CORS headers
        resp = pipeline(HTTP.Request("GET", "/", ["Authorization" => "Bearer valid-token-123"]))
        @test resp.status == 200
        @test HTTP.header(resp, "Access-Control-Allow-Origin") == "*"

        # OPTIONS preflight bypasses auth (CORS is outermost)
        resp = pipeline(HTTP.Request("OPTIONS", "/"))
        @test resp.status == 200
        @test HTTP.header(resp, "Access-Control-Allow-Origin") == "*"
    end

    @testset "real HTTP server: auth required" begin
        port = find_free_port()
        auth = BearerAuthMiddleware(validate_token)
        pipeline = compose_middleware(test_handler, [auth])
        server = HTTP.serve!(pipeline, AUTH_HOST, port)

        try
            # No auth → 401
            resp = HTTP.get("http://$AUTH_HOST:$port/"; status_exception=false)
            @test resp.status == 401

            # Bad token → 401
            resp = HTTP.get("http://$AUTH_HOST:$port/";
                headers=["Authorization" => "Bearer wrong"],
                status_exception=false)
            @test resp.status == 401

            # Valid token → 200
            resp = HTTP.get("http://$AUTH_HOST:$port/";
                headers=["Authorization" => "Bearer valid-token-123"])
            @test resp.status == 200
        finally
            close(server)
        end
    end

    @testset "real HTTP server: full middleware stack (CORS + rate limiter + auth)" begin
        port = find_free_port()
        cors = CorsMiddleware()
        limiter = RateLimiterMiddleware(rate_limit=10, window=60)
        auth = BearerAuthMiddleware(validate_token)

        # Order: CORS (outermost) → rate limiter → auth (innermost)
        pipeline = compose_middleware(test_handler, [cors, limiter, auth])
        server = HTTP.serve!(pipeline, AUTH_HOST, port)

        try
            # Preflight: CORS handles it, no auth needed
            resp = HTTP.request("OPTIONS", "http://$AUTH_HOST:$port/api"; status_exception=false)
            @test resp.status == 200
            @test HTTP.header(resp, "Access-Control-Allow-Origin") == "*"

            # Authenticated request: gets CORS + rate limit + auth
            resp = HTTP.get("http://$AUTH_HOST:$port/api";
                headers=["Authorization" => "Bearer valid-token-123"])
            @test resp.status == 200
            @test HTTP.header(resp, "Access-Control-Allow-Origin") == "*"
            @test !isempty(HTTP.header(resp, "X-RateLimit-Limit"))

            # Unauthenticated: CORS and rate limit process, auth rejects
            resp = HTTP.get("http://$AUTH_HOST:$port/api"; status_exception=false)
            @test resp.status == 401
        finally
            close(server)
        end
    end

end
