# Therapy.jl

A reactive web framework for Julia inspired by [Leptos](https://leptos.dev) and [SolidJS](https://solidjs.com).

## Features

- **Fine-grained Reactivity** - Signals, effects, and memos for precise DOM updates (no virtual DOM diffing)
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

```julia
using Therapy

function Counter()
    count, set_count = create_signal(0)

    Div(:class => "flex items-center gap-4",
        Button(
            :class => "px-4 py-2 bg-blue-500 text-white rounded",
            :on_click => () -> set_count(count() - 1),
            "-"
        ),
        Span(:class => "text-2xl font-bold", count),
        Button(
            :class => "px-4 py-2 bg-blue-500 text-white rounded",
            :on_click => () -> set_count(count() + 1),
            "+"
        )
    )
end

# Render to HTML
html = render_to_string(Counter())
```

## File-Path Routing

```
routes/
  index.jl        -> /
  about.jl        -> /about
  users/[id].jl   -> /users/:id
```

```julia
router = create_router("routes")
html, route, params = handle_request(router, "/users/123")
# params[:id] == "123"
```

## Tailwind CSS

```julia
# Development (CDN)
render_page(App(); head_extra=tailwind_cdn())

# Conditional classes
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

### Components

```julia
Greeting = component(:Greeting) do props
    name = get_prop(props, :name, "World")
    P("Hello, ", name, "!")
end

html = render_to_string(Greeting(:name => "Julia"))
```

### Conditional Rendering

```julia
Show(visible) do
    Div("I'm visible!")
end
```

## Examples

```bash
# Basic SSR demo
julia --project=. examples/counter.jl

# Full reactive app (Julia → Wasm)
cd examples/todo && julia --project=../.. app.jl
# Then open http://127.0.0.1:8080
```

## Current Status

| Feature | Status |
|---------|--------|
| Signals, Effects, Memos | ✅ |
| JSX-style elements | ✅ |
| SSR with hydration keys | ✅ |
| File-path routing | ✅ |
| Tailwind CSS | ✅ |
| Show conditional | ✅ |
| Event → Wasm compilation | ✅ |
| Two-way input binding | ✅ |
| Resources (async) | 🚧 |
| Context API | 🚧 |
| Server functions | 🚧 |

## Related Projects

- [WasmTarget.jl](https://github.com/TherapeuticJulia/WasmTarget.jl) - Julia to WebAssembly compiler

## License

MIT
