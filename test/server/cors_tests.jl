# CORS middleware tests — ported from Oxygen.jl's CORS test patterns

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

const CORS_HOST = "127.0.0.1"

@testset "MW-002: CorsMiddleware" begin

    function test_handler(req::HTTP.Request)
        HTTP.Response(200, ["Content-Type" => "text/plain"], body="OK")
    end

    @testset "default config adds wildcard CORS headers" begin
        cors = CorsMiddleware()
        pipeline = compose_middleware(test_handler, [cors])

        resp = pipeline(HTTP.Request("GET", "/"))
        @test resp.status == 200
        @test HTTP.header(resp, "Access-Control-Allow-Origin") == "*"
        @test occursin("GET", HTTP.header(resp, "Access-Control-Allow-Methods"))
        @test HTTP.header(resp, "Access-Control-Allow-Headers") == "*"
    end

    @testset "OPTIONS preflight returns 200 with CORS headers" begin
        cors = CorsMiddleware()
        pipeline = compose_middleware(test_handler, [cors])

        resp = pipeline(HTTP.Request("OPTIONS", "/api/users"))
        @test resp.status == 200
        @test HTTP.header(resp, "Access-Control-Allow-Origin") == "*"
        @test occursin("POST", HTTP.header(resp, "Access-Control-Allow-Methods"))
        # Body should be empty for preflight
        @test isempty(resp.body)
    end

    @testset "custom allowed_origins" begin
        cors = CorsMiddleware(allowed_origins=["https://example.com", "https://app.example.com"])
        pipeline = compose_middleware(test_handler, [cors])

        resp = pipeline(HTTP.Request("GET", "/"))
        @test HTTP.header(resp, "Access-Control-Allow-Origin") == "https://example.com, https://app.example.com"
    end

    @testset "custom allowed_methods" begin
        cors = CorsMiddleware(allowed_methods=["GET", "POST"])
        pipeline = compose_middleware(test_handler, [cors])

        resp = pipeline(HTTP.Request("GET", "/"))
        @test HTTP.header(resp, "Access-Control-Allow-Methods") == "GET, POST"
    end

    @testset "custom allowed_headers" begin
        cors = CorsMiddleware(allowed_headers=["Content-Type", "Authorization"])
        pipeline = compose_middleware(test_handler, [cors])

        resp = pipeline(HTTP.Request("GET", "/"))
        @test HTTP.header(resp, "Access-Control-Allow-Headers") == "Content-Type, Authorization"
    end

    @testset "allow_credentials" begin
        cors = CorsMiddleware(allow_credentials=true)
        pipeline = compose_middleware(test_handler, [cors])

        resp = pipeline(HTTP.Request("GET", "/"))
        @test HTTP.header(resp, "Access-Control-Allow-Credentials") == "true"
    end

    @testset "no credentials header when allow_credentials=false" begin
        cors = CorsMiddleware(allow_credentials=false)
        pipeline = compose_middleware(test_handler, [cors])

        resp = pipeline(HTTP.Request("GET", "/"))
        @test HTTP.header(resp, "Access-Control-Allow-Credentials") == ""
    end

    @testset "max_age" begin
        cors = CorsMiddleware(max_age=3600)
        pipeline = compose_middleware(test_handler, [cors])

        resp = pipeline(HTTP.Request("OPTIONS", "/"))
        @test HTTP.header(resp, "Access-Control-Max-Age") == "3600"
    end

    @testset "no max_age header when not specified" begin
        cors = CorsMiddleware()
        pipeline = compose_middleware(test_handler, [cors])

        resp = pipeline(HTTP.Request("GET", "/"))
        @test HTTP.header(resp, "Access-Control-Max-Age") == ""
    end

    @testset "handler response preserved with CORS headers added" begin
        function json_handler(req::HTTP.Request)
            HTTP.Response(201, ["Content-Type" => "application/json"], body="""{"created":true}""")
        end

        cors = CorsMiddleware()
        pipeline = compose_middleware(json_handler, [cors])

        resp = pipeline(HTTP.Request("POST", "/api/items"))
        @test resp.status == 201
        @test HTTP.header(resp, "Content-Type") == "application/json"
        @test HTTP.header(resp, "Access-Control-Allow-Origin") == "*"
        @test String(resp.body) == """{"created":true}"""
    end

    @testset "real HTTP server: CORS on GET request" begin
        port = find_free_port()
        cors = CorsMiddleware(allowed_origins=["https://myapp.com"])
        pipeline = compose_middleware(test_handler, [cors])
        server = HTTP.serve!(pipeline, CORS_HOST, port)

        try
            resp = HTTP.get("http://$CORS_HOST:$port/api/data")
            @test resp.status == 200
            @test HTTP.header(resp, "Access-Control-Allow-Origin") == "https://myapp.com"
        finally
            close(server)
        end
    end

    @testset "real HTTP server: CORS preflight" begin
        port = find_free_port()
        cors = CorsMiddleware(
            allowed_origins=["https://myapp.com"],
            allowed_methods=["GET", "POST"],
            allow_credentials=true,
            max_age=86400
        )
        pipeline = compose_middleware(test_handler, [cors])
        server = HTTP.serve!(pipeline, CORS_HOST, port)

        try
            resp = HTTP.request("OPTIONS", "http://$CORS_HOST:$port/api/data"; status_exception=false)
            @test resp.status == 200
            @test HTTP.header(resp, "Access-Control-Allow-Origin") == "https://myapp.com"
            @test HTTP.header(resp, "Access-Control-Allow-Methods") == "GET, POST"
            @test HTTP.header(resp, "Access-Control-Allow-Credentials") == "true"
            @test HTTP.header(resp, "Access-Control-Max-Age") == "86400"
        finally
            close(server)
        end
    end

end
