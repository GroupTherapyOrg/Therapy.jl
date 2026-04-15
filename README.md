<div align="center">

# Therapy.jl

### Signals-Based Web Apps. Pure Julia.

Build interactive web applications with fine-grained signals, server-side rendering, and WebAssembly islands. Signals architecture originated by [SolidJS](https://solidjs.com), compiled to WASM following [Leptos](https://leptos.dev) (Rust), with [Astro](https://astro.build)-style islands.

[![CI](https://github.com/GroupTherapyOrg/Therapy.jl/actions/workflows/ci.yml/badge.svg)](https://github.com/GroupTherapyOrg/Therapy.jl/actions/workflows/ci.yml)
[![Docs](https://img.shields.io/badge/docs-stable-blue.svg)](https://grouptherapyorg.github.io/Therapy.jl/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE.md)

</div>

## Architecture: SSR + Islands

Therapy.jl is an **islands architecture** framework. Pages render on the server as static HTML. Only the interactive parts (`@island` components) ship WebAssembly to the browser. Not a SPA.

| | SSR Components | `@island` Components |
|---|---|---|
| **Runs on** | Server (Julia) | Browser (WebAssembly) |
| **Ships to browser** | HTML only | Tiny WASM module (1--5 KB) |
| **Has access to** | Julia packages, DB, filesystem | Signals, DOM events, memos |
| **Use for** | Pages, layouts, data fetching | Search, counters, toggles, forms |

**How it works:**

1. **Server renders pages** using Julia (full package ecosystem, data access)
2. **`@island` components compile** to WebAssembly via [WasmTarget.jl](https://github.com/GroupTherapyOrg/WasmTarget.jl)
3. **Browser hydrates islands** with fine-grained reactivity (Leptos-style, no VDOM)

Following [Leptos](https://leptos.dev): ALL island logic runs as WASM. JS exists only as auto-generated glue for DOM API calls. No JS reactive runtime. No JS fallbacks.

## SSR Components

Plain Julia functions that return HTML. Zero JavaScript shipped.

```julia
using DataFrames

function DataTable()
    df = DataFrame(Name=["Alice","Bob"], Age=[28,35], City=["Portland","Austin"])
    return Table(
        Thead(Tr(For(names(df)) do col; Th(col); end)),
        Tbody(For(eachrow(df)) do row
            Tr(For(collect(row)) do cell; Td(string(cell)); end)
        end)
    )
end
```

## Interactive Islands

`@island` components compile to WebAssembly via [WasmTarget.jl](https://github.com/GroupTherapyOrg/WasmTarget.jl). Signals become WASM globals. Handlers, effects, and memos compile to WASM functions. DOM updates happen via `externref` imports.

```julia
@island function Counter(; initial::Int = 0)
    count, set_count = create_signal(initial)
    doubled = create_memo(() -> count() * 2)

    return Div(
        Button(:on_click => () -> set_count(count() - 1), "-"),
        Span(count),
        Button(:on_click => () -> set_count(count() + 1), "+"),
        P("doubled ", doubled)
    )
end
```

**How islands work:**

1. SSR renders: `<therapy-island data-component="Counter" data-props='{"initial":0}'>...HTML...</therapy-island>`
2. WasmTarget compiles signals, handlers, effects, and memos to a WASM module
3. Auto-generated JS glue instantiates the WASM and wires DOM events (like wasm-bindgen)
4. Browser hydrates via cursor (walks existing DOM, attaches reactivity, creates zero new nodes)

## Leptos Parity

Therapy.jl follows [Leptos](https://leptos.dev) architecture:

| Leptos (Rust) | Therapy.jl (Julia) |
|:------|:------|
| `#[component]` renders server HTML | SSR components render server HTML |
| `#[island]` compiles to WASM | `@island` compiles to WASM via WasmTarget.jl |
| `Signal<T>` | `create_signal(value)` |
| `Memo<T>` | `create_memo(() -> ...)` |
| `RenderEffect` (fine-grained DOM updates) | Effects compile to WASM functions |
| `web_sys` DOM calls via wasm-bindgen | DOM calls via `externref` imports (WasmGC) |
| Hydration cursor (child/sibling/parent) | Hydration cursor (same pattern) |
| Event delegation | Event delegation |
| Zero hand-written JS | Zero hand-written JS |

**WasmGC advantages over Leptos/wasm-bindgen:**
- `externref` for DOM nodes (no JS-side heap array needed)
- GC-managed closures (no manual `Closure<dyn FnMut>` lifetime management)
- No `TextEncoder`/`TextDecoder` or `__wbindgen_malloc` for string passing

## WasmTarget.jl Foundation

Therapy.jl's island compilation is powered by [WasmTarget.jl](https://github.com/GroupTherapyOrg/WasmTarget.jl), which provides:

- **176 core Julia functions** compile to WASM (numeric, math, strings, collections, iterators, Dict/Set)
- **Closures** — nested, mutable Ref capture, multi-type capture, all verified
- **Compositions** — 8+ deep function chains across native and overlay paths
- **Binaryen optimization** — ~85% size reduction, zero regressions
- **Method overlays** — GPUCompiler pattern for functions with complex IR
- **2409 tests**, verified across Int32/Int64/UInt32/UInt64/Float32/Float64

## Quick Start

```julia
using Pkg
Pkg.add(url="https://github.com/GroupTherapyOrg/Therapy.jl")
```

```julia
using Therapy

app = App(routes_dir="routes", components_dir="components")
Therapy.run(app)
```

```
routes/
  index.jl          -> /
  about.jl          -> /about
  users/[id].jl     -> /users/:id
```

```bash
julia +1.12 --project=. app.jl dev    # Development server with hot reload
julia +1.12 --project=. app.jl build  # Static site generation
```

**Requires Julia 1.12** (for WasmTarget.jl IR compatibility).

## Server

Middleware, API routes, and WebSocket routing ported from [Oxygen.jl](https://github.com/OxygenFramework/Oxygen.jl).

```julia
# Middleware (higher-order function composition)
app = App(middleware=[CorsMiddleware(), RateLimiterMiddleware(rate_limit=100)])

# API routes with path params and per-route middleware
api = create_api_router([
    "/api/users/:id" => Dict(
        "GET" => (req, params) -> Dict("id" => parse(Int, params[:id])),
        :middleware => [BearerAuthMiddleware(validate)]
    )
])

# WebSocket routing with channels
websocket("/ws/room/:id") do ws, params
    for msg in ws
        WebSockets.send(ws, "[$(params[:id])] " * String(msg))
    end
end
```

## HMR: Revise.jl Hot Module Replacement with State Preservation

The dev server provides automatic hot module replacement with signal state preservation.

**How it works:**
1. **FileWatching** (OS-level kqueue/inotify) detects file changes instantly (no polling)
2. **Surgical recompilation** — only the changed island recompiles (~2-3s, not all islands)
3. **WebSocket push** — new WASM bytes sent to browser automatically (zero user action)
4. **Signal state snapshot** — reads `signal_*` globals from old WASM module before swap
5. **Signal state restore** — writes old values into new module if count+types match
6. **Effects re-fire** with new logic but preserved state

**What triggers what:**

| File type | Action | Browser effect |
|-----------|--------|---------------|
| Component `.jl` | Surgical recompile + WS push | Island re-hydrates with new code, state preserved |
| CSS / Tailwind | Rebuild CSS + WS push | Stylesheet replaced, no reload, no state loss |
| Route `.jl` | Reload route + WS push | Full page reload |

**State preservation rule:** if signal count + types match between old and new module, restore values (counter stays at 7, search text stays). If signals changed (added/removed/retyped), fresh start. Same heuristic as React Fast Refresh.

## Acknowledgments

Server-side middleware, API routing, and WebSocket patterns ported from [Oxygen.jl](https://github.com/OxygenFramework/Oxygen.jl) --- Julia's mature server framework.

## Related

- [WasmTarget.jl](https://github.com/GroupTherapyOrg/WasmTarget.jl) --- Julia-to-WebAssembly compiler (WasmGC)
- [Sessions.jl](https://github.com/GroupTherapyOrg/Sessions.jl) --- Notebook IDE built with Therapy.jl

## License

MIT
