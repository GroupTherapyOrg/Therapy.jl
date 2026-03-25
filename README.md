# Therapy.jl

<div align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="logo/therapy_dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="logo/therapy_light.svg">
    <img alt="Therapy.jl" src="logo/logo_light.svg" height="60">
  </picture>
</div>

A reactive web framework for Julia inspired by [SolidJS](https://solidjs.com) and [Leptos](https://leptos.dev).

[![Live Demo](https://img.shields.io/badge/demo-live-brightgreen)](https://grouptherapyorg.github.io/Therapy.jl/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE.md)

---

## SolidJS Comparison

| SolidJS | Therapy.jl | Notes |
|---------|------------|-------|
| `const [count, setCount] = createSignal(0)` | `count, set_count = create_signal(0)` | Same getter/setter pattern |
| `createEffect(() => ...)` | `create_effect(() -> ...)` | Auto-tracking |
| `createMemo(() => ...)` | `create_memo(() -> ...)` | Cached derived state |
| `batch(() => ...)` | `batch(() -> ...)` | Deferred updates |
| `<Show when={...}>` | `Show(visible) do ... end` | Conditional rendering |
| `<For each={...}>` | `For(items) do item ... end` | List rendering |
| `<div class="...">` | `Div(:class => "...")` | JSX-like element functions |
| `onClick={() => ...}` | `:on_click => () -> ...` | Event handlers |

## The Two Tiers

### Tier 1: Static Functions -- server-rendered HTML

Plain Julia functions returning VNodes. Zero JavaScript shipped.

```julia
function Greeting(; name="World")
    Div(:class => "p-4",
        H1("Hello, ", name, "!"),
        P("Welcome to Therapy.jl")
    )
end
```

### Tier 2: `@island` -- interactive JavaScript on the client

Islands compile to inline JavaScript (~500-900 bytes each) and hydrate in the browser. Signals, event handlers, and fine-grained DOM updates -- all written in Julia.

```julia
@island function Counter(; initial::Int = 0)
    count, set_count = create_signal(initial)

    Div(:class => "flex items-center gap-4",
        Button(:on_click => () -> set_count(count() - 1), "-"),
        Span(:class => "text-2xl font-bold", count),
        Button(:on_click => () -> set_count(count() + 1), "+")
    )
end
```

**What happens:**
1. Server renders HTML (SSR) with `<therapy-island>` wrapper
2. Julia compiles signal logic and handlers to an inline `<script>` tag (~500 bytes)
3. Browser executes the script, hydrates the island, attaches event listeners
4. User clicks a button -- only the affected DOM nodes update (fine-grained, no VDOM)

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/GroupTherapyOrg/Therapy.jl")
```

## Quick Start

Create `app.jl`:

```julia
using Therapy

app = App(
    routes_dir = "routes",
    components_dir = "components"
)

Therapy.run(app)
```

```bash
julia --project=. app.jl dev    # Development server
julia --project=. app.jl build  # Static site generation
```

## Core Reactivity

Fine-grained reactivity (like SolidJS), not virtual DOM diffing (like React).

### Signals

```julia
count, set_count = create_signal(0)
count()           # Read: 0
set_count(5)      # Write: triggers updates
set_count(c -> c + 1)  # Update with function
```

### Effects

```julia
create_effect() do
    println("Count is: ", count())  # Re-runs when count changes
end
```

### Memos

```julia
doubled = create_memo(() -> count() * 2)  # Cached, recomputes only when count changes
```

### Batching

```julia
batch() do
    set_a(1); set_b(2); set_c(3)
end  # Effects run once after batch
```

## Conditional & List Rendering

```julia
Show(visible) do
    Div("I'm visible!")
end

For(items) do item
    Li(item)
end
```

## Routing

### File-Based Routes

```
routes/
  index.jl          -> /
  about.jl          -> /about
  users/[id].jl     -> /users/:id
  users/_layout.jl  -> Layout for /users/*
```

### Route Hooks

```julia
params = use_params()       # {:id => "123"}
page = use_query(:page, "1")
path = use_location()       # "/users/123"
```

### Nested Layouts

```julia
# routes/users/_layout.jl
(params) -> Div(
    Nav(NavLink("/users/", "All"), NavLink("/users/new", "New")),
    Main(Outlet())  # Child routes render here
)
```

### SPA Navigation

Client-side navigation with `NavLink` -- layout persists, only content swaps:

```julia
NavLink("/about", "About"; active_class="text-accent-700")
```

## Compilation Pipeline

```
@island function Counter(; initial::Int = 0) ... end
    |
    v
Analysis -- discover signals, extract handler closures
    |
    v
JS Generation -- compile to inline JavaScript (~500 bytes)
    |
    v
SSR + Hydration -- HTML + inline <script> tag
```

Each island compiles to a self-contained JavaScript IIFE. No framework runtime needed for within-island reactivity. A ~300 byte shared runtime handles cross-island signal communication.

## Feature Status

| Category | Status |
|----------|--------|
| Signals, Effects, Memos, Batching | Complete |
| Components, Islands, `@island` | Complete |
| SSR + Hydration (inline JS) | Complete |
| File-based Routing, SPA, Nested Layouts | Complete |
| Resources, Suspense, Await | Complete |
| Context API | Complete |
| ErrorBoundary | Complete |
| WebSocket Infrastructure | Complete |
| Tailwind CSS (CDN + CLI) | Complete |
| Server Functions (`@server`) | [Future](docs/FUTURE.md) |
| Server Signals, Bidirectional Signals | [Future](docs/FUTURE.md) |
| Message Channels | [Future](docs/FUTURE.md) |
| Streaming SSR | Planned |

## Related Projects

- [Sessions.jl](https://github.com/GroupTherapyOrg/Sessions.jl) -- Reactive notebook IDE built with Therapy.jl

## License

MIT
