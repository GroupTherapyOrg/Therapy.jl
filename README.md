# Therapy.jl

A reactive web framework for Julia inspired by [Leptos](https://leptos.dev) and [SolidJS](https://solidjs.com).

## Features

- **Fine-grained Reactivity** - Signals, effects, and memos for precise DOM updates (no virtual DOM diffing)
- **Islands Architecture** - Static by default, opt-in interactivity with `island()`
- **JSX-style Elements** - Capitalized elements like React: `Div`, `Button`, `Span`
- **File-path Routing** - Next.js-style routing with dynamic params
- **Tailwind CSS** - Built-in integration (CDN for dev, CLI for production)
- **SSR + Hydration** - Server-side rendering with WebAssembly hydration
- **Wasm Compilation** - Event handlers compile to WebAssembly via WasmTarget.jl

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/TherapeuticJulia/Therapy.jl")
```

## Quick Start

Create an interactive counter island in `components/Counter.jl`:

```julia
using Therapy

# island() marks this component as interactive (will compile to Wasm)
Counter = island(:Counter) do
    count, set_count = create_signal(0)

    Div(:class => "flex items-center gap-4",
        Button(:on_click => () -> set_count(count() - 1), "-"),
        Span(:class => "text-2xl font-bold", count),
        Button(:on_click => () -> set_count(count() + 1), "+")
    )
end
```

Create `app.jl`:

```julia
using Therapy

# Islands are auto-discovered - no manual config needed!
app = App(
    routes_dir = "routes",
    components_dir = "components"
)

Therapy.run(app)
```

Run with:
```bash
julia --project=. app.jl dev    # Development server with HMR
julia --project=. app.jl build  # Build static site
```

## Islands Architecture

Therapy.jl follows Leptos's islands pattern - **static by default, opt-in to interactivity**:

```julia
# Static component - SSR only, no JavaScript/Wasm
function Header(title)
    Nav(:class => "flex items-center",
        H1(title),
        A(:href => "/about", "About")
    )
end

# Interactive island - compiles to Wasm, hydrates on client
Counter = island(:Counter) do
    count, set_count = create_signal(0)
    Div(
        Button(:on_click => () -> set_count(count() - 1), "-"),
        Span(count),
        Button(:on_click => () -> set_count(count() + 1), "+")
    )
end

# Use in routes - islands render wrapped in <therapy-island>
function Index()
    Layout(
        Header("My App"),
        Counter()  # Auto-discovered, auto-hydrated
    )
end
```

## File-Path Routing

```
routes/
  index.jl          -> /
  about.jl          -> /about
  users/[id].jl     -> /users/:id
  posts/[...slug].jl -> /posts/*
```

Routes are Julia files that return component functions. Dynamic params are accessible via the router.

## Tailwind CSS

Tailwind is enabled by default. Use conditional classes with `tw`:

```julia
Div(:class => tw("flex", "items-center", is_active && "bg-blue-500"))
```

## API Overview

### Reactivity

```julia
# Signals
count, set_count = create_signal(0)
count()        # read
set_count(5)   # write

# Effects (auto-track dependencies)
create_effect(() -> println("Count: ", count()))

# Memos (cached computations)
doubled = create_memo(() -> count() * 2)

# Batching
batch() do
    set_a(1)
    set_b(2)
end
```

### Elements

```julia
# JSX-style capitalized names
Div, Span, P, A, Button, Input, Form, Label
H1, H2, H3, H4, H5, H6
Ul, Ol, Li, Table, Tr, Td, Th
Img, Video, Audio
Header, Footer, Nav, Main, Section, Article
# ... and more
```

### Components with Props

Create reusable components that receive props from parents:

```julia
# Define a component that receives props
Greeting = component(:Greeting) do props
    name = get_prop(props, :name, "World")  # With default
    P("Hello, ", name, "!")
end

# Parent passes props to child
Div(
    Greeting(:name => "Julia"),
    Greeting(:name => "Therapy")
)

# Props can include signals and functions
Square = component(:Square) do props
    value = get_prop(props, :value)
    on_click = get_prop(props, :on_click)
    Button(:on_click => on_click, value)
end

# Parent passes signal and handler
Square(:value => my_signal, :on_click => () -> set_signal(1))
```

### Islands

Mark components as interactive with `island()`:

```julia
# This component will be compiled to WebAssembly
MyIsland = island(:MyIsland) do
    state, set_state = create_signal(0)

    Div(
        Button(:on_click => () -> set_state(state() + 1), "Click"),
        Span(state)
    )
end
```

### Conditional Rendering

```julia
Show(visible) do
    Div("I'm visible!")
end
```

## Live Demo

See Therapy.jl in action at [therapeuticjulia.github.io/Therapy.jl](https://therapeuticjulia.github.io/Therapy.jl/) — including an interactive Tic-Tac-Toe game with winner detection compiled entirely to WebAssembly.

## Current Status

| Feature | Status |
|---------|--------|
| Signals, Effects, Memos | done |
| JSX-style elements | done |
| SSR with hydration keys | done |
| Islands architecture | done |
| File-path routing | done |
| Tailwind CSS | done |
| Show conditional | done |
| Direct IR to Wasm compilation | done |
| Two-way input binding | done |
| Theme binding (dark mode) | done |
| Resources (async) | planned |
| Context API | planned |
| Server functions | planned |

## Related Projects

- [WasmTarget.jl](https://github.com/TherapeuticJulia/WasmTarget.jl) - Julia to WebAssembly compiler

## License

MIT
