# Therapy.jl Server Layer Port — Progress

## Stories

| ID | Title | Status |
|----|-------|--------|
| MW-001 | Core Middleware Pipeline | done |
| MW-002 | CorsMiddleware | open |
| MW-003 | RateLimiterMiddleware | open |
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
