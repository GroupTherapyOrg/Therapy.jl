<div align="center">

# Therapy.jl

Signals-based web framework for Julia. SSR-first with interactive islands compiled to WebAssembly.

Inspired by [SolidJS](https://solidjs.com) (reactivity), [Astro](https://astro.build) (islands), and [Leptos](https://leptos.dev) (Rust WASM).

[![CI](https://github.com/GroupTherapyOrg/Therapy.jl/actions/workflows/ci.yml/badge.svg)](https://github.com/GroupTherapyOrg/Therapy.jl/actions/workflows/ci.yml)
[![Docs](https://img.shields.io/badge/docs-stable-blue.svg)](https://grouptherapyorg.github.io/Therapy.jl/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE.md)

</div>

<div align="center">

## SolidJS in Julia

| Therapy.jl | SolidJS |
|:-----------|:--------|
| `count, set_count = create_signal(0)` | `const [count, setCount] = createSignal(0)` |
| `create_effect(() -> ...)` | `createEffect(() => ...)` |
| `create_memo(() -> ...)` | `createMemo(() => ...)` |
| `Show(condition) do ... end` | `<Show when={...}>` |
| `For(items) do item ... end` | `<For each={...}>` |
| `Div(:class => "...")` | `<div class="...">` |
| `:on_click => () -> ...` | `onClick={() => ...}` |

</div>

## Architecture: SSR + Islands

Therapy.jl is an **SSR-first** framework with **interactive islands** --- not a single-page application (SPA) framework.

| | SSR Components | `@island` Components |
|---|---|---|
| **Runs on** | Server (Julia) | Browser (WebAssembly) |
| **Ships to browser** | HTML only | Tiny WASM module (1--2 KB) |
| **Has access to** | Julia packages, DB, filesystem | Signals, DOM events, memos |
| **Use for** | Pages, layouts, data fetching | Counters, search, toggles |

**Why SSR + Islands?**

Julia runs on the server. Shipping an entire Julia runtime to the browser would be megabytes of WASM --- impractical for web apps. Instead, Therapy.jl:

1. **Renders pages on the server** using Julia (full package ecosystem, data access, templates)
2. **Compiles only the interactive bits** to WebAssembly via [WasmTarget.jl](https://github.com/GroupTherapyOrg/WasmTarget.jl)
3. **Hydrates islands in the browser** with fine-grained reactivity (SolidJS-style, no VDOM)

Each `@island` produces a self-contained WASM module with its signals, handlers, effects, and memos. Static prop data (like a list of items) is embedded as constants in the WASM module at build time --- no JS-to-WASM bridge needed for SSR props.

**What this means in practice:**
- Pages load fast (server-rendered HTML, no JS framework bundle)
- Interactivity is instant (WASM hydrates targeted islands, not the whole page)
- Julia developers write Julia (not JavaScript) for both server and interactive code
- WASM modules are tiny because they only contain the reactive logic, not a runtime

**What Therapy.jl is NOT:**
- Not an SPA framework. There is no client-side router for full-page transitions.
- Not a React/Vue replacement. If you need a complex client-side app, use SolidJS/React for the frontend and Julia for the backend API.
- Not shipping a Julia runtime to the browser. The WASM is compiled Julia, not interpreted.

For most Julia use cases (dashboards, documentation, data apps, tools), SSR + islands is the right architecture. The interactive pieces (search, filters, toggles, plots) are islands. Everything else is server-rendered HTML.

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
- Integer signal reads/writes (WASM globals)
- Handler closures (exported WASM functions)
- Effect closures (WASM functions called by `__t.effect`)
- Memo closures including string operations (`lowercase`, `startswith`, `contains`)
- `For()` loops building `Vector{String}` results
- Constant prop data embedded via `array.new_fixed`

**What stays in JS:**
- DOM manipulation (via thin `__t` reactive runtime, ~1KB)
- `For()` keyed reconciliation (SolidJS-style diff)
- `Show()` conditional rendering
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
- [Suite.jl](https://github.com/GroupTherapyOrg/Suite.jl) --- Component library built with Therapy.jl
- [Sessions.jl](https://github.com/GroupTherapyOrg/Sessions.jl) --- Notebook IDE built with Therapy.jl

## License

MIT
