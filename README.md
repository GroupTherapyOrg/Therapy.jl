# Therapy.jl

Signals-based web framework for Julia. Inspired by [SolidJS](https://solidjs.com) and [SolidStart](https://start.solidjs.com).

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE.md)

## SolidJS in Julia

| SolidJS | Therapy.jl |
|---------|------------|
| `const [count, setCount] = createSignal(0)` | `count, set_count = create_signal(0)` |
| `createEffect(() => ...)` | `create_effect(() -> ...)` |
| `createMemo(() => ...)` | `create_memo(() -> ...)` |
| `batch(() => ...)` | `batch(() -> ...)` |
| `<div class="...">` | `Div(:class => "...")` |
| `onClick={() => ...}` | `:on_click => () -> ...` |
| `<Show when={...}>` | `Show(condition) do ... end` |
| `<For each={...}>` | `For(items) do item ... end` |

## How It Works

```julia
@island function Counter(; initial::Int = 0)
    count, set_count = create_signal(initial)
    doubled = create_memo(() -> count() * 2)
    create_effect(() -> println("count: ", count(), " doubled: ", doubled()))

    Div(
        Button(:on_click => () -> set_count(count() - 1), "-"),
        Span(count),
        Button(:on_click => () -> set_count(count() + 1), "+"),
        P("doubled ", doubled)
    )
end
```

1. Server renders HTML with `<therapy-island>` wrapper
2. [JavaScriptTarget.jl](https://github.com/GroupTherapyOrg/JavaScriptTarget.jl) compiles signals, handlers, effects, and memos to an inline `<script>` (~500-2000 bytes)
3. Browser hydrates the island and attaches event listeners
4. Clicks update only the affected DOM nodes — fine-grained, no VDOM

Plain functions (no `@island`) render as static HTML with zero JavaScript. Use `js()` inside handlers or effects to call browser APIs like `document` or `localStorage` directly.

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
julia --project=. app.jl dev    # Development server
julia --project=. app.jl build  # Static site generation
```

## Related

- [JavaScriptTarget.jl](https://github.com/GroupTherapyOrg/JavaScriptTarget.jl) — Julia-to-JavaScript compiler
- [Sessions.jl](https://github.com/GroupTherapyOrg/Sessions.jl) — Notebook IDE built with Therapy.jl

## License

MIT
