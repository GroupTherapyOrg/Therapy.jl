# Therapy.jl Server Layer Port — Progress

## Stories

| ID | Title | Status |
|----|-------|--------|
| MW-001 | Core Middleware Pipeline | done |
| MW-002 | CorsMiddleware | done |
| MW-003 | RateLimiterMiddleware | done |
| MW-004 | BearerAuthMiddleware | open |
| API-001 | API Route Support | open |
| WS-001 | WebSocket Path Routing | open |
| WS-002 | Parameterized WebSocket Paths | open |
| WS-003 | Channel/Room Subscriptions | open |
| INT-001 | Integration Tests | open |

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
