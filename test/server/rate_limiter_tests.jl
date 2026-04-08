# RateLimiter middleware tests — ported from Oxygen.jl's rate limiter test patterns

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

const RL_HOST = "127.0.0.1"

@testset "MW-003: RateLimiterMiddleware" begin

    function test_handler(req::HTTP.Request)
        HTTP.Response(200, ["Content-Type" => "text/plain"], body="OK")
    end

    @testset "requests under limit pass through with headers" begin
        limiter = RateLimiterMiddleware(rate_limit=5, window=60)
        pipeline = compose_middleware(test_handler, [limiter])

        resp = pipeline(HTTP.Request("GET", "/"))
        @test resp.status == 200
        @test HTTP.header(resp, "X-RateLimit-Limit") == "5"
        @test HTTP.header(resp, "X-RateLimit-Remaining") == "4"
        @test !isempty(HTTP.header(resp, "X-RateLimit-Reset"))
    end

    @testset "remaining count decrements" begin
        limiter = RateLimiterMiddleware(rate_limit=5, window=60)
        pipeline = compose_middleware(test_handler, [limiter])

        for i in 1:5
            resp = pipeline(HTTP.Request("GET", "/"))
            @test resp.status == 200
            @test HTTP.header(resp, "X-RateLimit-Remaining") == string(5 - i)
        end
    end

    @testset "exceeding limit returns 429" begin
        limiter = RateLimiterMiddleware(rate_limit=3, window=60)
        pipeline = compose_middleware(test_handler, [limiter])

        # Use up the limit
        for _ in 1:3
            resp = pipeline(HTTP.Request("GET", "/"))
            @test resp.status == 200
        end

        # Next request should be 429
        resp = pipeline(HTTP.Request("GET", "/"))
        @test resp.status == 429
        @test String(resp.body) == "Too Many Requests"
        @test HTTP.header(resp, "X-RateLimit-Remaining") == "0"
        @test !isempty(HTTP.header(resp, "Retry-After"))
    end

    @testset "window reset allows new requests" begin
        limiter = RateLimiterMiddleware(rate_limit=2, window=1)
        pipeline = compose_middleware(test_handler, [limiter])

        # Exhaust limit
        pipeline(HTTP.Request("GET", "/"))
        pipeline(HTTP.Request("GET", "/"))
        resp = pipeline(HTTP.Request("GET", "/"))
        @test resp.status == 429

        # Wait for window to expire
        sleep(1.1)

        # Should be allowed again
        resp = pipeline(HTTP.Request("GET", "/"))
        @test resp.status == 200
        @test HTTP.header(resp, "X-RateLimit-Remaining") == "1"
    end

    @testset "different IPs tracked independently" begin
        limiter = RateLimiterMiddleware(rate_limit=2, window=60)
        pipeline = compose_middleware(test_handler, [limiter])

        # Client A uses up limit
        for _ in 1:2
            req = HTTP.Request("GET", "/", ["X-Real-IP" => "10.0.0.1"])
            resp = pipeline(req)
            @test resp.status == 200
        end
        req_a = HTTP.Request("GET", "/", ["X-Real-IP" => "10.0.0.1"])
        resp = pipeline(req_a)
        @test resp.status == 429

        # Client B should still have full limit
        req_b = HTTP.Request("GET", "/", ["X-Real-IP" => "10.0.0.2"])
        resp = pipeline(req_b)
        @test resp.status == 200
        @test HTTP.header(resp, "X-RateLimit-Remaining") == "1"
    end

    @testset "X-Forwarded-For uses first IP" begin
        limiter = RateLimiterMiddleware(rate_limit=1, window=60)
        pipeline = compose_middleware(test_handler, [limiter])

        req = HTTP.Request("GET", "/", ["X-Forwarded-For" => "203.0.113.50, 70.41.3.18, 150.172.238.178"])
        resp = pipeline(req)
        @test resp.status == 200

        # Same first IP, different chain → same client
        req2 = HTTP.Request("GET", "/", ["X-Forwarded-For" => "203.0.113.50, 99.99.99.99"])
        resp2 = pipeline(req2)
        @test resp2.status == 429
    end

    @testset "real HTTP server: rate limiting" begin
        port = find_free_port()
        limiter = RateLimiterMiddleware(rate_limit=3, window=60)
        pipeline = compose_middleware(test_handler, [limiter])
        server = HTTP.serve!(pipeline, RL_HOST, port)

        try
            # First 3 requests succeed
            for i in 1:3
                resp = HTTP.get("http://$RL_HOST:$port/")
                @test resp.status == 200
                @test HTTP.header(resp, "X-RateLimit-Remaining") == string(3 - i)
            end

            # 4th request → 429
            resp = HTTP.get("http://$RL_HOST:$port/"; status_exception=false)
            @test resp.status == 429
            @test HTTP.header(resp, "X-RateLimit-Remaining") == "0"
            retry_after = parse(Int, HTTP.header(resp, "Retry-After"))
            @test retry_after > 0
        finally
            close(server)
        end
    end

    @testset "real HTTP server: rate limit with CORS stacking" begin
        port = find_free_port()
        cors = CorsMiddleware()
        limiter = RateLimiterMiddleware(rate_limit=2, window=60)
        pipeline = compose_middleware(test_handler, [cors, limiter])
        server = HTTP.serve!(pipeline, RL_HOST, port)

        try
            # First request: both CORS and rate limit headers
            resp = HTTP.get("http://$RL_HOST:$port/")
            @test resp.status == 200
            @test HTTP.header(resp, "Access-Control-Allow-Origin") == "*"
            @test HTTP.header(resp, "X-RateLimit-Remaining") == "1"

            # Exhaust limit
            HTTP.get("http://$RL_HOST:$port/")
            resp = HTTP.get("http://$RL_HOST:$port/"; status_exception=false)
            @test resp.status == 429
            # 429 response should still NOT have CORS headers
            # (short-circuited before CORS post-processing in the onion model)
        finally
            close(server)
        end
    end

end
