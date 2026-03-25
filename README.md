<div align="center">

# Therapy.jl

Signals-based web framework for Julia. Inspired by [SolidJS](https://solidjs.com) (signals), [SolidStart](https://start.solidjs.com) (SSR), and [Astro](https://astro.build) (islands architecture).

[![CI](https://github.com/GroupTherapyOrg/Therapy.jl/actions/workflows/ci.yml/badge.svg)](https://github.com/GroupTherapyOrg/Therapy.jl/actions/workflows/ci.yml)
[![Docs](https://img.shields.io/badge/docs-stable-blue.svg)](https://grouptherapyorg.github.io/Therapy.jl/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE.md)

</div>

## SolidJS in Julia

| SolidJS | Therapy.jl |
|---------|------------|
| `const [count, setCount] = createSignal(0)` | `count, set_count = create_signal(0)` |
| `createEffect(() => ...)` | `create_effect(() -> ...)` |
| `createMemo(() => ...)` | `create_memo(() -> ...)` |
| `<Show when={...}>` | `Show(condition) do ... end` |
| `<For each={...}>` | `For(items) do item ... end` |
| `<div class="...">` | `Div(:class => "...")` |
| `onClick={() => ...}` | `:on_click => () -> ...` |

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

`@island` components compile to inline JavaScript via [JavaScriptTarget.jl](https://github.com/GroupTherapyOrg/JavaScriptTarget.jl).

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

1. Server renders HTML with `<therapy-island>` wrapper
2. JavaScriptTarget.jl compiles signals, handlers, effects, and memos to inline JS
3. Browser hydrates — clicks update only affected DOM nodes, no VDOM

## Package Extensions

Use Julia packages inside `@island` — Therapy auto-compiles them to JS via package extensions.

```julia
using Therapy, PlotlyBase  # extension auto-loads

@island function InteractivePlot(; frequency::Int = 5)
    freq, set_freq = create_signal(frequency)

    create_effect(() -> begin
        x = [Float64(i) * 0.1 for i in 1:100]
        y = sin.(x .* Float64(freq()))
        PlotlyBase.Plot([PlotlyBase.scatter(x=x, y=y)], PlotlyBase.Layout(title="Plot"))
    end)

    return Div(
        Div(:id => "therapy-plot"),
        Input(:type => "range", :value => freq, :on_input => set_freq)
    )
end
```

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
