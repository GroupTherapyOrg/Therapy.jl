# API route tests — real HTTP requests, Oxygen-style route dispatch

using Test
using HTTP
using JSON
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
        @test JSON.parse(String(resp.body)) == ["a", "b", "c"]
    end

    @testset "json_response with status" begin
        resp = json_response(Dict("error" => "not found"); status=404)
        @test resp.status == 404
        data = JSON.parse(String(resp.body))
        @test data["error"] == "not found"
    end

    @testset "json_response with custom headers" begin
        resp = json_response("ok"; headers=["X-Custom" => "value"])
        @test HTTP.header(resp, "X-Custom") == "value"
        @test HTTP.header(resp, "Content-Type") == "application/json"
    end

    @testset "json_response with Dict" begin
        resp = json_response(Dict("name" => "Julia", "version" => 1.12))
        data = JSON.parse(String(resp.body))
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
        data = JSON.parse(String(resp.body))
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
        @test JSON.parse(String(resp.body)) == ["item1", "item2"]

        resp = api(HTTP.Request("POST", "/api/items"))
        data = JSON.parse(String(resp.body))
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
        data = JSON.parse(String(resp.body))
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
        data = JSON.parse(String(resp.body))
        @test data["user"] == "5"
        @test data["post"] == "99"
    end

    @testset "create_api_router: nested param extraction (/items/:item/reviews)" begin
        api = create_api_router([
            "/api/items/:item/reviews" => Dict(
                "GET" => (req, params) -> Dict(
                    "item" => params[:item],
                    "reviews" => ["great", "good"]
                )
            )
        ])

        resp = api(HTTP.Request("GET", "/api/items/abc/reviews"))
        data = JSON.parse(String(resp.body))
        @test data["item"] == "abc"
        @test length(data["reviews"]) == 2

        # Non-matching path returns 404
        resp = api(HTTP.Request("GET", "/api/items/abc"))
        @test resp.status == 404
    end

    @testset "create_api_router: typed param parsing in handler" begin
        api = create_api_router([
            "/api/users/:id" => Dict(
                "GET" => (req, params) -> begin
                    id = parse(Int, params[:id])
                    Dict("id" => id, "doubled" => id * 2)
                end
            )
        ])

        resp = api(HTTP.Request("GET", "/api/users/42"))
        data = JSON.parse(String(resp.body))
        @test data["id"] == 42
        @test data["doubled"] == 84
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
                    body = JSON.parse(String(req.body))
                    Dict("echoed" => body["input"])
                end
            )
        ])

        req = HTTP.Request("POST", "/api/echo",
            ["Content-Type" => "application/json"],
            JSON.json(Dict("input" => "hello")))
        resp = api(req)
        data = JSON.parse(String(resp.body))
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
        data = JSON.parse(String(resp.body))
        @test data["type"] == "current_user"

        resp = api(HTTP.Request("GET", "/api/users/42"))
        data = JSON.parse(String(resp.body))
        @test data["type"] == "user_by_id"
        @test data["id"] == "42"
    end

    # ── Request body extractors (Oxygen bodyparsers pattern) ───────────

    @testset "json_body: parses JSON request body" begin
        req = HTTP.Request("POST", "/api/test",
            ["Content-Type" => "application/json"],
            JSON.json(Dict("name" => "Julia", "version" => 1.12)))
        data = json_body(req)
        @test data["name"] == "Julia"
        @test data["version"] == 1.12
    end

    @testset "json_body: empty body returns nothing" begin
        req = HTTP.Request("POST", "/api/test", [], UInt8[])
        @test json_body(req) === nothing
    end

    @testset "json_body: typed parsing" begin
        req = HTTP.Request("POST", "/api/test",
            ["Content-Type" => "application/json"],
            JSON.json(["a", "b", "c"]))
        data = json_body(req, Vector{String})
        @test data == ["a", "b", "c"]
    end

    @testset "text_body: reads body as string" begin
        req = HTTP.Request("POST", "/api/test",
            ["Content-Type" => "text/plain"],
            "hello world")
        @test text_body(req) == "hello world"
    end

    @testset "text_body: empty body returns nothing" begin
        req = HTTP.Request("POST", "/api/test", [], UInt8[])
        @test text_body(req) === nothing
    end

    @testset "form_body: parses URL-encoded form data" begin
        req = HTTP.Request("POST", "/api/test",
            ["Content-Type" => "application/x-www-form-urlencoded"],
            "name=Julia&version=1.12")
        data = form_body(req)
        @test data["name"] == "Julia"
        @test data["version"] == "1.12"
    end

    @testset "form_body: empty body returns nothing" begin
        req = HTTP.Request("POST", "/api/test", [], UInt8[])
        @test form_body(req) === nothing
    end

    @testset "query_params: parses query string" begin
        req = HTTP.Request("GET", "/api/test?page=2&limit=10")
        params = query_params(req)
        @test params["page"] == "2"
        @test params["limit"] == "10"
    end

    @testset "query_params: no query string returns empty Dict" begin
        req = HTTP.Request("GET", "/api/test")
        params = query_params(req)
        @test isempty(params)
    end

    @testset "extractors in API handler via real HTTP" begin
        port = find_free_port()

        api = create_api_router([
            "/api/echo" => Dict(
                "POST" => (req, params) -> begin
                    body = json_body(req)
                    qp = query_params(req)
                    Dict("body" => body, "query" => qp)
                end
            )
        ])

        server = HTTP.serve!(api, API_HOST, port)
        try
            resp = HTTP.post("http://$API_HOST:$port/api/echo?sort=name",
                ["Content-Type" => "application/json"],
                JSON.json(Dict("input" => "data")))
            data = JSON.parse(String(resp.body))
            @test data["body"]["input"] == "data"
            @test data["query"]["sort"] == "name"
        finally
            close(server)
        end
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
                    body = JSON.parse(String(req.body))
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
            data = JSON.parse(String(resp.body))
            @test length(data) == 2

            # GET /api/users/42
            resp = HTTP.get("http://$API_HOST:$port/api/users/42")
            data = JSON.parse(String(resp.body))
            @test data["id"] == 42

            # POST /api/users
            resp = HTTP.post("http://$API_HOST:$port/api/users",
                ["Content-Type" => "application/json"],
                JSON.json(Dict("name" => "Charlie")))
            @test resp.status == 201
            data = JSON.parse(String(resp.body))
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

    # ── Per-route middleware (Oxygen pattern) ──────────────────────────

    @testset "per-route middleware: auth on specific route" begin
        function test_validate(token::String)
            token == "valid" ? Dict("user" => "admin") : nothing
        end

        api = create_api_router([
            "/api/public" => Dict(
                "GET" => (req, params) -> Dict("public" => true)
            ),
            "/api/private" => Dict(
                "GET" => (req, params) -> Dict("private" => true, "user" => req.context[:user]),
                :middleware => [BearerAuthMiddleware(test_validate)]
            )
        ])

        # Public route works without auth
        resp = api(HTTP.Request("GET", "/api/public"))
        @test resp.status == 200
        data = JSON.parse(String(resp.body))
        @test data["public"] == true

        # Private route without auth → 401
        resp = api(HTTP.Request("GET", "/api/private"))
        @test resp.status == 401

        # Private route with valid auth → 200
        req = HTTP.Request("GET", "/api/private", ["Authorization" => "Bearer valid"])
        resp = api(req)
        @test resp.status == 200
        data = JSON.parse(String(resp.body))
        @test data["private"] == true
        @test data["user"]["user"] == "admin"
    end

    @testset "per-route middleware: composes with app-level middleware" begin
        port = find_free_port()

        function test_validate2(token::String)
            token == "secret" ? Dict("role" => "admin") : nothing
        end

        api = create_api_router([
            "/api/open" => Dict(
                "GET" => (req, params) -> Dict("open" => true)
            ),
            "/api/guarded" => Dict(
                "GET" => (req, params) -> Dict("guarded" => true),
                :middleware => [BearerAuthMiddleware(test_validate2)]
            )
        ])

        # App-level CORS + per-route auth
        cors = CorsMiddleware()
        pipeline = compose_middleware(api, [cors])
        server = HTTP.serve!(pipeline, API_HOST, port)

        try
            # Open route: has CORS, no auth needed
            resp = HTTP.get("http://$API_HOST:$port/api/open")
            @test resp.status == 200
            @test HTTP.header(resp, "Access-Control-Allow-Origin") == "*"

            # Guarded route without auth: has CORS, but 401
            resp = HTTP.get("http://$API_HOST:$port/api/guarded"; status_exception=false)
            @test resp.status == 401

            # Guarded route with auth: has CORS + 200
            resp = HTTP.get("http://$API_HOST:$port/api/guarded";
                headers=["Authorization" => "Bearer secret"])
            @test resp.status == 200
            @test HTTP.header(resp, "Access-Control-Allow-Origin") == "*"
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
            data = JSON.parse(String(resp.body))
            @test data["data"] == "secret stuff"
            @test data["user"]["role"] == "admin"
        finally
            close(server)
        end
    end

end
