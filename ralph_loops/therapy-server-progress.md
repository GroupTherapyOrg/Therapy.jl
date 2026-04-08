# Therapy.jl Server Layer Port — Progress

## Stories

| ID | Title | Status |
|----|-------|--------|
| MW-001 | Core Middleware Pipeline | done |
| MW-002 | CorsMiddleware | done |
| MW-003 | RateLimiterMiddleware | done |
| MW-004 | BearerAuthMiddleware | done |
| API-001 | API Route Support | done |
| WS-001 | WebSocket Path Routing | done |
| WS-002 | Parameterized WebSocket Paths | done |
| WS-003 | Channel/Room Subscriptions | done |
| INT-001 | Integration Tests | done |

## Completed

### MW-001: Core Middleware Pipeline
- `src/Server/Middleware.jl`: `compose_middleware()`, `write_response()`
- Faithful port of Oxygen's `reduce(|>)` with `reverse()` for left-to-right order
- Exports: `compose_middleware`, `write_response`
- 21 tests in `test/server/middleware_tests.jl` (including 3 real HTTP server tests)

### MW-002: CorsMiddleware
- `CorsMiddleware()` in `src/Server/Middleware.jl`
- Faithful port of Oxygen's `Cors()`: preflight 200 + CORS headers on all responses
- Config: allowed_origins, allowed_headers, allowed_methods, allow_credentials, max_age
- Export: `CorsMiddleware`
- 26 tests in `test/server/cors_tests.jl` (including 2 real HTTP server tests)

### MW-003: RateLimiterMiddleware
- `RateLimiterMiddleware()` in `src/Server/Middleware.jl`
- Fixed window strategy with ReentrantLock, IP extraction from proxy headers
- Config: rate_limit, window
- Headers: X-RateLimit-Limit, X-RateLimit-Remaining, X-RateLimit-Reset, Retry-After
- Export: `RateLimiterMiddleware`
- 44 tests in `test/server/rate_limiter_tests.jl`

### MW-004: BearerAuthMiddleware
- `BearerAuthMiddleware()` in `src/Server/Middleware.jl`
- Token extraction, validation via user function, `req.context[:user]` storage
- Config: validate_token function, custom header, custom scheme
- Export: `BearerAuthMiddleware`
- 28 tests in `test/server/auth_tests.jl` (including full middleware stack test)

### API-001: API Route Support
- `src/Server/ApiRoutes.jl`: `json_response()`, `create_api_router()`
- Route matching with dynamic params (`:id`), method dispatch, auto JSON serialization
- 405 Method Not Allowed, 404 Not Found, 204 No Content
- Handlers can return data (auto-JSON), HTTP.Response, or nothing
- Exports: `json_response`, `create_api_router`
- 42 tests in `test/server/api_tests.jl` (including CORS+auth middleware stack)

### WS-001: WebSocket Path Routing
- `websocket(path, handler)`, `match_ws_route()`, `handle_ws_upgrade()` in `src/Server/WebSocket.jl`
- Multiple WS paths, coexists with existing managed `/ws` endpoint
- `ws_routes()`, `clear_ws_routes!()` for introspection/testing
- Exports: `websocket`, `handle_ws_upgrade`, `match_ws_route`, `ws_routes`, `clear_ws_routes!`
- 16 tests in `test/server/websocket_tests.jl` (real WebSocket connections)

### WS-002: Parameterized WebSocket Paths
- `:param` extraction built into WS-001's path matching
- Handler receives `(ws, params)` when params present, just `(ws)` when not
- 12 tests in `test/server/websocket_params_tests.jl` (room-based routing, multi-params)

### WS-003: Channel/Room Subscriptions
- `subscribe`, `unsubscribe`, `broadcast_channel`, `channel_connections`, `channel_count`, `on_channel_message`
- Message protocol: subscribe/unsubscribe/channel_message types in managed WS
- WSConnection.socket now `Union{WebSocket, Nothing}` for testability
- 35 tests in `test/server/channel_tests.jl` (including multi-client broadcast)

### INT-001: Integration Tests
- Single server: CORS + rate limiter + auth middleware, public + protected API routes
- WebSocket: echo + parameterized rooms, managed WS with channels
- HTTP and WS coexist on same port
- 30 tests in `test/server/integration_tests.jl`

## Totals
- **254 new server tests** across 8 test files
- **332 existing tests** — zero regressions
- **586 total tests passing**
