# API route tests — real HTTP requests, Oxygen-style route dispatch

using Test
using HTTP
using JSON3
using Sockets
using Therapy

function find_free_port()
    server = Sockets.listen(Sockets.IPv4("127.0.0.1"), 0)
    _, port = Sockets.getsockname(server)
    close(server)
    return Int(port)
end

const API_HOST = "127.0.0.1"

@testset "API-001: API Route Support" begin

    @testset "json_response basic" begin
        resp = json_response(["a", "b", "c"])
        @test resp.status == 200
        @test HTTP.header(resp, "Content-Type") == "application/json"
        @test JSON3.read(String(resp.body)) == ["a", "b", "c"]
    end

    @testset "json_response with status" begin
        resp = json_response(Dict("error" => "not found"); status=404)
        @test resp.status == 404
        data = JSON3.read(String(resp.body), Dict{String,Any})
        @test data["error"] == "not found"
    end

    @testset "json_response with custom headers" begin
        resp = json_response("ok"; headers=["X-Custom" => "value"])
        @test HTTP.header(resp, "X-Custom") == "value"
        @test HTTP.header(resp, "Content-Type") == "application/json"
    end

    @testset "json_response with Dict" begin
        resp = json_response(Dict("name" => "Julia", "version" => 1.12))
        data = JSON3.read(String(resp.body), Dict{String,Any})
        @test data["name"] == "Julia"
    end

    @testset "create_api_router: basic GET" begin
        api = create_api_router([
            "/api/hello" => Dict(
                "GET" => (req, params) -> Dict("message" => "hello")
            )
        ])

        resp = api(HTTP.Request("GET", "/api/hello"))
        @test resp.status == 200
        data = JSON3.read(String(resp.body), Dict{String,Any})
        @test data["message"] == "hello"
    end

    @testset "create_api_router: multiple methods" begin
        api = create_api_router([
            "/api/items" => Dict(
                "GET" => (req, params) -> ["item1", "item2"],
                "POST" => (req, params) -> Dict("created" => true)
            )
        ])

        resp = api(HTTP.Request("GET", "/api/items"))
        @test JSON3.read(String(resp.body)) == ["item1", "item2"]

        resp = api(HTTP.Request("POST", "/api/items"))
        data = JSON3.read(String(resp.body), Dict{String,Any})
        @test data["created"] == true
    end

    @testset "create_api_router: 405 for unsupported method" begin
        api = create_api_router([
            "/api/readonly" => Dict(
                "GET" => (req, params) -> "data"
            )
        ])

        resp = api(HTTP.Request("DELETE", "/api/readonly"))
        @test resp.status == 405
        @test occursin("GET", HTTP.header(resp, "Allow"))
    end

    @testset "create_api_router: 404 for unknown path" begin
        api = create_api_router([
            "/api/exists" => Dict("GET" => (req, params) -> "ok")
        ])

        resp = api(HTTP.Request("GET", "/api/nope"))
        @test resp.status == 404
    end

    @testset "create_api_router: dynamic params" begin
        api = create_api_router([
            "/api/users/:id" => Dict(
                "GET" => (req, params) -> Dict("id" => params[:id])
            )
        ])

        resp = api(HTTP.Request("GET", "/api/users/42"))
        data = JSON3.read(String(resp.body), Dict{String,Any})
        @test data["id"] == "42"
    end

    @testset "create_api_router: multiple dynamic params" begin
        api = create_api_router([
            "/api/users/:user_id/posts/:post_id" => Dict(
                "GET" => (req, params) -> Dict(
                    "user" => params[:user_id],
                    "post" => params[:post_id]
                )
            )
        ])

        resp = api(HTTP.Request("GET", "/api/users/5/posts/99"))
        data = JSON3.read(String(resp.body), Dict{String,Any})
        @test data["user"] == "5"
        @test data["post"] == "99"
    end

    @testset "create_api_router: handler returns HTTP.Response directly" begin
        api = create_api_router([
            "/api/custom" => Dict(
                "GET" => (req, params) -> HTTP.Response(
                    201,
                    ["Content-Type" => "text/plain", "X-Custom" => "yes"],
                    body="Created"
                )
            )
        ])

        resp = api(HTTP.Request("GET", "/api/custom"))
        @test resp.status == 201
        @test HTTP.header(resp, "Content-Type") == "text/plain"
        @test String(resp.body) == "Created"
    end

    @testset "create_api_router: handler returns nothing → 204" begin
        api = create_api_router([
            "/api/void" => Dict(
                "DELETE" => (req, params) -> nothing
            )
        ])

        resp = api(HTTP.Request("DELETE", "/api/void"))
        @test resp.status == 204
    end

    @testset "create_api_router: handler can read request body" begin
        api = create_api_router([
            "/api/echo" => Dict(
                "POST" => (req, params) -> begin
                    body = JSON3.read(String(req.body), Dict{String,Any})
                    Dict("echoed" => body["input"])
                end
            )
        ])

        req = HTTP.Request("POST", "/api/echo",
            ["Content-Type" => "application/json"],
            JSON3.write(Dict("input" => "hello")))
        resp = api(req)
        data = JSON3.read(String(resp.body), Dict{String,Any})
        @test data["echoed"] == "hello"
    end

    @testset "create_api_router: route priority (specific before dynamic)" begin
        api = create_api_router([
            "/api/users/me" => Dict(
                "GET" => (req, params) -> Dict("type" => "current_user")
            ),
            "/api/users/:id" => Dict(
                "GET" => (req, params) -> Dict("type" => "user_by_id", "id" => params[:id])
            )
        ])

        resp = api(HTTP.Request("GET", "/api/users/me"))
        data = JSON3.read(String(resp.body), Dict{String,Any})
        @test data["type"] == "current_user"

        resp = api(HTTP.Request("GET", "/api/users/42"))
        data = JSON3.read(String(resp.body), Dict{String,Any})
        @test data["type"] == "user_by_id"
        @test data["id"] == "42"
    end

    @testset "real HTTP server: API router" begin
        port = find_free_port()

        api = create_api_router([
            "/api/users" => Dict(
                "GET" => (req, params) -> [
                    Dict("id" => 1, "name" => "Alice"),
                    Dict("id" => 2, "name" => "Bob")
                ],
                "POST" => (req, params) -> begin
                    body = JSON3.read(String(req.body), Dict{String,Any})
                    json_response(Dict("id" => 3, "name" => body["name"]); status=201)
                end
            ),
            "/api/users/:id" => Dict(
                "GET" => (req, params) -> Dict("id" => parse(Int, params[:id]), "name" => "User"),
                "DELETE" => (req, params) -> nothing
            )
        ])

        server = HTTP.serve!(api, API_HOST, port)

        try
            # GET /api/users
            resp = HTTP.get("http://$API_HOST:$port/api/users")
            @test resp.status == 200
            @test HTTP.header(resp, "Content-Type") == "application/json"
            data = JSON3.read(String(resp.body))
            @test length(data) == 2

            # GET /api/users/42
            resp = HTTP.get("http://$API_HOST:$port/api/users/42")
            data = JSON3.read(String(resp.body), Dict{String,Any})
            @test data["id"] == 42

            # POST /api/users
            resp = HTTP.post("http://$API_HOST:$port/api/users",
                ["Content-Type" => "application/json"],
                JSON3.write(Dict("name" => "Charlie")))
            @test resp.status == 201
            data = JSON3.read(String(resp.body), Dict{String,Any})
            @test data["name"] == "Charlie"

            # DELETE /api/users/1 → 204
            resp = HTTP.request("DELETE", "http://$API_HOST:$port/api/users/1"; status_exception=false)
            @test resp.status == 204

            # PUT /api/users → 405
            resp = HTTP.request("PUT", "http://$API_HOST:$port/api/users"; status_exception=false)
            @test resp.status == 405

            # GET /api/nonexistent → 404
            resp = HTTP.get("http://$API_HOST:$port/api/nonexistent"; status_exception=false)
            @test resp.status == 404
        finally
            close(server)
        end
    end

    @testset "real HTTP server: API with middleware (CORS + auth)" begin
        port = find_free_port()

        function validate(token::String)
            token == "secret" ? Dict("role" => "admin") : nothing
        end

        api = create_api_router([
            "/api/protected" => Dict(
                "GET" => (req, params) -> Dict("data" => "secret stuff", "user" => req.context[:user])
            )
        ])

        cors = CorsMiddleware()
        auth = BearerAuthMiddleware(validate)
        pipeline = compose_middleware(api, [cors, auth])
        server = HTTP.serve!(pipeline, API_HOST, port)

        try
            # Preflight works without auth
            resp = HTTP.request("OPTIONS", "http://$API_HOST:$port/api/protected"; status_exception=false)
            @test resp.status == 200
            @test HTTP.header(resp, "Access-Control-Allow-Origin") == "*"

            # Without auth → 401
            resp = HTTP.get("http://$API_HOST:$port/api/protected"; status_exception=false)
            @test resp.status == 401

            # With auth → 200 + CORS + JSON
            resp = HTTP.get("http://$API_HOST:$port/api/protected";
                headers=["Authorization" => "Bearer secret"])
            @test resp.status == 200
            @test HTTP.header(resp, "Access-Control-Allow-Origin") == "*"
            data = JSON3.read(String(resp.body), Dict{String,Any})
            @test data["data"] == "secret stuff"
            @test data["user"]["role"] == "admin"
        finally
            close(server)
        end
    end

end
