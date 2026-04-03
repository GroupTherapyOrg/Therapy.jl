<div align="center">

# Therapy.jl

### Signals-Based Web Apps. Pure Julia.

Build interactive web applications with fine-grained signals, server-side rendering, and WebAssembly compilation. Inspired by [SolidJS](https://solidjs.com) (signals), [Leptos](https://leptos.dev) (signals + WASM), and [Astro](https://astro.build) (islands architecture).

[![CI](https://github.com/GroupTherapyOrg/Therapy.jl/actions/workflows/ci.yml/badge.svg)](https://github.com/GroupTherapyOrg/Therapy.jl/actions/workflows/ci.yml)
[![Docs](https://img.shields.io/badge/docs-stable-blue.svg)](https://grouptherapyorg.github.io/Therapy.jl/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE.md)

</div>

<div align="center">

## SolidJS in Julia

| Therapy.jl | SolidJS |
|:-----------|:--------|
| `count, set_count = create_signal(0)` | `const [count, setCount] = createSignal(0)` |
| `query, set_query = create_signal("")` | `const [query, setQuery] = createSignal("")` |
| `create_effect(() -> ...)` | `createEffect(() => ...)` |
| `create_memo(() -> ...)` | `createMemo(() => ...)` |
| `Show(condition) do ... end` | `<Show when={...}>` |
| `For(items) do item ... end` | `<For each={...}>` |
| `on_cleanup(() -> ...)` | `onCleanup(() => ...)` |
| `Div(:class => "...")` | `<div class="...">` |
| `:on_click => () -> ...` | `onClick={() => ...}` |

</div>

## Architecture: SSR + Islands

If you've used React, SolidJS, or Vue --- Therapy.jl will feel familiar. You write components with signals, effects, memos, and event handlers. The difference is where things run.

Therapy.jl uses **SSR with islands** (like [Astro](https://astro.build) or [Fresh](https://fresh.deno.dev)): pages render on the server, and only the interactive parts (`@island` components) ship WebAssembly to the browser. You still get the same component model and reactivity you're used to --- just with Julia instead of JavaScript, and WASM instead of a JS bundle.

| | SSR Components | `@island` Components |
|---|---|---|
| **Runs on** | Server (Julia) | Browser (WebAssembly) |
| **Ships to browser** | HTML only | Tiny WASM module (1--5 KB) |
| **Has access to** | Julia packages, DB, filesystem | Signals, DOM events, memos |
| **Use for** | Pages, layouts, data fetching | Search, counters, toggles, forms |

**How it works:**

1. **Server renders pages** using Julia (full package ecosystem, data access, templates)
2. **`@island` components compile** to WebAssembly via [WasmTarget.jl](https://github.com/GroupTherapyOrg/WasmTarget.jl)
3. **Browser hydrates islands** with fine-grained reactivity (SolidJS-style, no VDOM)

Each `@island` produces a self-contained WASM module with its signals, handlers, effects, and memos. Static prop data (like a list of items) is embedded as constants in the WASM module at build time.

**If you're coming from React/SolidJS:** The component model is the same --- signals instead of `useState`, memos instead of `useMemo`, effects instead of `useEffect`, `For()` instead of `.map()`, `Show()` instead of ternaries. The main difference is that Therapy.jl doesn't do client-side routing or full SPAs. Each page is server-rendered, and islands handle the interactive bits. For most Julia use cases (dashboards, documentation, data apps, tools), this is the right architecture --- and it's significantly faster than shipping a JS framework bundle.

**If you need a full SPA:** Use SolidJS or React for the frontend and Julia for the backend API. Therapy.jl is designed for content-rich sites with targeted interactivity, not single-page applications.

## SSR Components

Plain Julia functions that return HTML. Zero JavaScript shipped. Full access to Julia packages.

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

`@island` components compile to WebAssembly via [WasmTarget.jl](https://github.com/GroupTherapyOrg/WasmTarget.jl). Signal reads/writes become WASM global operations. Handlers, effects, and memos compile to exported WASM functions.

```julia
@island function Counter(; initial::Int = 0)
    count, set_count = create_signal(initial)
    doubled = create_memo(() -> count() * 2)
    create_effect(() -> println("count: ", count(), " doubled: ", doubled()))

    return Div(
        Button(:on_click => () -> set_count(count() - 1), "-"),
        Span(count),
        Button(:on_click => () -> set_count(count() + 1), "+"),
        P("doubled ", doubled)
    )
end
```

**How it works:**

1. Server renders HTML with `<therapy-island data-component="counter" data-props='{"initial":0}'>`
2. WasmTarget.jl compiles signals, handlers, effects, and memos to a WASM module
3. A thin JS loader (generated, not hand-written) instantiates the WASM and wires DOM events
4. Browser hydrates --- clicks update only affected DOM nodes via SolidJS-style fine-grained reactivity

**What compiles to WASM:**
- Integer signal reads/writes (WASM i64 globals)
- String signal reads/writes (WasmGC ref globals via `create_signal("")`)
- Handler closures (exported WASM functions)
- Effect closures (WASM functions called by `__t.effect`)
- Memo closures including string operations (`lowercase`, `startswith`, `contains`)
- `Show()` closure conditions (e.g., `() -> count() > 5`)
- `For()` loops building `Vector{String}` results
- Owner/scope system for effect and memo cleanup
- Constant prop data embedded via `array.new_fixed`

**What stays in JS:**
- DOM manipulation (via thin `__t` reactive runtime, ~1KB)
- Owner/scope tree management and disposal
- `For()` keyed reconciliation with per-item scopes (cleanup on removal)
- `Show()` DOM insertion/removal
- Event delegation and listener management

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

## Related

- [WasmTarget.jl](https://github.com/GroupTherapyOrg/WasmTarget.jl) --- Julia-to-WebAssembly compiler (WasmGC)
- [Sessions.jl](https://github.com/GroupTherapyOrg/Sessions.jl) --- Notebook IDE built with Therapy.jl

## License

MIT
