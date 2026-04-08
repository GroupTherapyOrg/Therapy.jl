# Middleware tests — real HTTP requests, ported from Oxygen's test patterns
#
# Each test spins up a real HTTP server, makes requests, verifies responses.

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

const MW_HOST = "127.0.0.1"

@testset "MW-001: Core Middleware Pipeline" begin

    # Base handler used across tests
    function test_handler(req::HTTP.Request)
        HTTP.Response(200, ["Content-Type" => "text/plain"], body="Hello World")
    end

    @testset "no middleware returns handler unchanged" begin
        pipeline = compose_middleware(test_handler, [])
        @test pipeline === test_handler
    end

    @testset "single middleware modifies response" begin
        function add_header_mw(handler)
            return function(req::HTTP.Request)
                response = handler(req)
                HTTP.setheader(response, "X-Custom" => "test-value")
                return response
            end
        end

        pipeline = compose_middleware(test_handler, [add_header_mw])
        resp = pipeline(HTTP.Request("GET", "/"))
        @test resp.status == 200
        @test HTTP.header(resp, "X-Custom") == "test-value"
        @test String(resp.body) == "Hello World"
    end

    @testset "middleware execution order (left-to-right)" begin
        invocations = String[]

        function mw1(handler)
            return function(req::HTTP.Request)
                push!(invocations, "mw1-pre")
                resp = handler(req)
                push!(invocations, "mw1-post")
                return resp
            end
        end

        function mw2(handler)
            return function(req::HTTP.Request)
                push!(invocations, "mw2-pre")
                resp = handler(req)
                push!(invocations, "mw2-post")
                return resp
            end
        end

        function mw3(handler)
            return function(req::HTTP.Request)
                push!(invocations, "mw3-pre")
                resp = handler(req)
                push!(invocations, "mw3-post")
                return resp
            end
        end

        pipeline = compose_middleware(test_handler, [mw1, mw2, mw3])
        pipeline(HTTP.Request("GET", "/"))

        # Oxygen pattern: first middleware in vector runs first (outermost)
        @test invocations == [
            "mw1-pre", "mw2-pre", "mw3-pre",
            "mw3-post", "mw2-post", "mw1-post"
        ]
    end

    @testset "middleware can short-circuit" begin
        function auth_mw(handler)
            return function(req::HTTP.Request)
                auth = HTTP.header(req, "Authorization")
                if isempty(auth)
                    return HTTP.Response(401, ["Content-Type" => "text/plain"], body="Unauthorized")
                end
                return handler(req)
            end
        end

        pipeline = compose_middleware(test_handler, [auth_mw])

        # Without auth header → 401
        resp = pipeline(HTTP.Request("GET", "/"))
        @test resp.status == 401
        @test String(resp.body) == "Unauthorized"

        # With auth header → passes through to handler
        resp = pipeline(HTTP.Request("GET", "/", ["Authorization" => "Bearer token"]))
        @test resp.status == 200
        @test String(resp.body) == "Hello World"
    end

    @testset "middleware can modify request before handler" begin
        function path_handler(req::HTTP.Request)
            HTTP.Response(200, body=HTTP.URI(req.target).path)
        end

        function prefix_mw(handler)
            return function(req::HTTP.Request)
                # Rewrite path
                new_req = HTTP.Request(req.method, "/api" * req.target, req.headers, req.body)
                return handler(new_req)
            end
        end

        pipeline = compose_middleware(path_handler, [prefix_mw])
        resp = pipeline(HTTP.Request("GET", "/users"))
        @test String(resp.body) == "/api/users"
    end

    @testset "real HTTP server with middleware" begin
        port = find_free_port()

        function uppercase_mw(handler)
            return function(req::HTTP.Request)
                resp = handler(req)
                return HTTP.Response(resp.status, resp.headers, body=uppercase(String(resp.body)))
            end
        end

        pipeline = compose_middleware(test_handler, [uppercase_mw])
        server = HTTP.serve!(pipeline, MW_HOST, port)

        try
            resp = HTTP.get("http://$MW_HOST:$port/test")
            @test resp.status == 200
            @test String(resp.body) == "HELLO WORLD"
        finally
            close(server)
        end
    end

    @testset "real HTTP server with multiple middleware" begin
        port = find_free_port()

        handler_called = Ref(false)
        function tracked_handler(req::HTTP.Request)
            handler_called[] = true
            HTTP.Response(200, ["Content-Type" => "text/plain"], body="OK")
        end

        function header_mw(handler)
            return function(req::HTTP.Request)
                resp = handler(req)
                HTTP.setheader(resp, "X-Middleware" => "applied")
                return resp
            end
        end

        function timing_mw(handler)
            return function(req::HTTP.Request)
                t0 = time()
                resp = handler(req)
                HTTP.setheader(resp, "X-Time-Ms" => string(round(Int, (time() - t0) * 1000)))
                return resp
            end
        end

        pipeline = compose_middleware(tracked_handler, [timing_mw, header_mw])
        server = HTTP.serve!(pipeline, MW_HOST, port)

        try
            resp = HTTP.get("http://$MW_HOST:$port/")
            @test resp.status == 200
            @test handler_called[]
            @test HTTP.header(resp, "X-Middleware") == "applied"
            @test !isempty(HTTP.header(resp, "X-Time-Ms"))
        finally
            close(server)
        end
    end

    @testset "real HTTP server: middleware short-circuit returns early" begin
        port = find_free_port()
        handler_reached = Ref(false)

        function guarded_handler(req::HTTP.Request)
            handler_reached[] = true
            HTTP.Response(200, body="OK")
        end

        function gate_mw(handler)
            return function(req::HTTP.Request)
                if HTTP.URI(req.target).path == "/blocked"
                    return HTTP.Response(403, body="Forbidden")
                end
                return handler(req)
            end
        end

        pipeline = compose_middleware(guarded_handler, [gate_mw])
        server = HTTP.serve!(pipeline, MW_HOST, port)

        try
            # Blocked path
            resp = HTTP.get("http://$MW_HOST:$port/blocked"; status_exception=false)
            @test resp.status == 403
            @test String(resp.body) == "Forbidden"
            @test !handler_reached[]

            # Allowed path
            handler_reached[] = false
            resp = HTTP.get("http://$MW_HOST:$port/allowed")
            @test resp.status == 200
            @test handler_reached[]
        finally
            close(server)
        end
    end

end
