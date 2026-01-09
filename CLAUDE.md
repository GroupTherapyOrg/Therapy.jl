# CLAUDE.md - Therapy.jl Development Guide

A reactive web framework for Julia with SolidJS/Leptos-inspired fine-grained reactivity, SSR support, and compilation to WebAssembly.

## Quick Start

```julia
using Therapy

# Create a reactive counter
function Counter()
    count, set_count = create_signal(0)

    Div(:class => "flex gap-4 items-center",
        Button(:on_click => () -> set_count(count() - 1), "-"),
        Span(:class => "text-2xl", count),
        Button(:on_click => () -> set_count(count() + 1), "+")
    )
end

# Render to HTML
html = render_to_string(Counter())
```

## Project Structure

```
Therapy.jl/
├── src/
│   ├── Therapy.jl              # Main module, exports
│   ├── Reactivity/
│   │   ├── Types.jl            # Signal, Effect types
│   │   ├── Context.jl          # Effect stack, batching
│   │   ├── Signal.jl           # create_signal, batch
│   │   ├── Effect.jl           # create_effect, dispose!
│   │   └── Memo.jl             # create_memo
│   ├── DOM/
│   │   ├── VNode.jl            # VNode, Fragment, Show
│   │   ├── Elements.jl         # Div, Button, Span, etc.
│   │   └── Events.jl           # Event mappings
│   ├── Components/
│   │   ├── Component.jl        # component(), render_component
│   │   ├── Props.jl            # Props container
│   │   └── Lifecycle.jl        # on_mount, on_cleanup
│   ├── SSR/
│   │   └── Render.jl           # render_to_string, render_page
│   ├── Router/
│   │   └── Router.jl           # File-path routing
│   ├── Styles/
│   │   └── Tailwind.jl         # Tailwind CSS integration
│   ├── Compiler/
│   │   ├── Analysis.jl         # Component analysis
│   │   ├── WasmGen.jl          # WebAssembly generation
│   │   ├── Hydration.jl        # Hydration JS
│   │   └── Compile.jl          # compile_component
│   └── Server/
│       └── DevServer.jl        # Development server
├── test/
│   └── runtests.jl             # 58 tests
└── examples/
    ├── counter.jl              # Basic SSR demo
    ├── counter_wasm.jl         # Manual Wasm compilation demo
    └── todo/
        └── app.jl              # Full reactive app with auto-compilation
```

## Core API

### Signals (Reactive State)

```julia
# Basic signal
count, set_count = create_signal(0)
count()           # Read: 0
set_count(5)      # Write
count()           # Read: 5

# With transform
upper, set_upper = create_signal("hello", uppercase)
upper()  # "HELLO"
```

### Effects (Side Effects)

```julia
# Runs immediately and re-runs when dependencies change
create_effect() do
    println("Count is: ", count())
end

# Cleanup
effect = create_effect(() -> println(count()))
dispose!(effect)
```

### Memos (Computed Values)

```julia
doubled = create_memo(() -> count() * 2)
doubled()  # Cached, only recomputes when count changes
```

### Batching

```julia
batch() do
    set_a(1)
    set_b(2)
    set_c(3)
end
# Effects only run once after batch
```

### DOM Elements (JSX-style)

```julia
# Capitalized like JSX/React
Div(:class => "container",
    H1("Title"),
    P("Paragraph"),
    Button(:on_click => handler, "Click me")
)

# Available elements:
# Layout: Div, Span, P, Br, Hr
# Text: H1-H6, Strong, Em, Code, Pre, Blockquote
# Lists: Ul, Ol, Li, Dl, Dt, Dd
# Tables: Table, Thead, Tbody, Tr, Th, Td
# Forms: Form, Input, Button, Textarea, Select, Option, Label
# Media: Img, Video, Audio, Iframe
# Semantic: Header, Footer, Nav, Main, Section, Article, Aside
# SVG: Svg, Path, Circle, Rect, Line, G, etc.
```

### Conditional Rendering

```julia
visible, set_visible = create_signal(true)

Show(visible) do
    Div("I'm visible!")
end
```

### Components

```julia
Greeting = component(:Greeting) do props
    name = get_prop(props, :name, "World")
    P("Hello, ", name, "!")
end

# Usage
render_to_string(Greeting(:name => "Julia"))
```

### File-Path Routing

```
routes/
  index.jl        -> /
  about.jl        -> /about
  users/[id].jl   -> /users/:id
  posts/[...slug].jl -> /posts/*
```

```julia
router = create_router("routes"; layout=Layout)
html, route, params = handle_request(router, "/users/123")
# params[:id] == "123"
```

### Tailwind CSS

```julia
# Development (CDN)
render_page(App(); head_extra=tailwind_cdn())

# Production config
write("tailwind.config.js", tailwind_config(
    content = ["src/**/*.jl", "routes/**/*.jl"]
))

# Class helper
Div(:class => tw("flex", "items-center", is_active && "bg-blue-500"))
```

### SSR

```julia
# Simple
html = render_to_string(Div("Hello"))

# Full page
html = render_page(App();
    title = "My App",
    head_extra = tailwind_cdn()
)
```

## Running Tests

```bash
julia --project=. test/runtests.jl
```

## Running Examples

```bash
# Basic SSR demo
julia --project=. examples/counter.jl

# Manual Wasm compilation demo
julia --project=. examples/counter_wasm.jl

# Full reactive app (compile_component + serve)
cd examples/todo && julia --project=../.. app.jl
# Then open http://127.0.0.1:8080
```

## Current Status

### Implemented
- [x] Signals, Effects, Memos
- [x] JSX-style elements (Div, Button, etc.)
- [x] SSR with hydration keys
- [x] Show conditional rendering
- [x] File-path routing
- [x] Tailwind CSS integration
- [x] Event handler compilation to Wasm
- [x] Two-way input binding
- [x] Handler operation tracing (increment, decrement, toggle, etc.)

### In Progress / Planned
- [ ] Resources (async data fetching)
- [ ] Context API
- [ ] More DOM operations in Wasm (class/style bindings)
- [ ] Server functions
- [ ] Streaming SSR

## Architecture Notes

### Fine-Grained Reactivity
Unlike React's VDOM diffing, Therapy.jl tracks signal dependencies precisely. When a signal changes, only the specific DOM nodes that depend on it are updated.

### VNode is Compile-Time Only
VNodes are used for SSR and analysis, not runtime diffing. At runtime, Wasm directly updates DOM nodes by hydration key.

### Handler Tracing
Event handlers are traced with multiple test values to detect operations:
- `set_count(count() + 1)` → OP_INCREMENT
- `set_count(count() - 1)` → OP_DECREMENT
- `set_visible(visible() == 0 ? 1 : 0)` → OP_TOGGLE

This enables generating efficient Wasm without parsing Julia code.

## Dependencies

- WasmTarget.jl (for Wasm compilation)
