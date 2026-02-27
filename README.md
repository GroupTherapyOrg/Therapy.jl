# Therapy.jl

<div align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="logo/therapy_dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="logo/therapy_light.svg">
    <img alt="Therapy.jl" src="logo/logo_light.svg" height="60">
  </picture>
</div>

A reactive web framework for Julia inspired by [Leptos](https://leptos.dev) and [SolidJS](https://solidjs.com), with **90% Leptos feature parity**.

[![Live Demo](https://img.shields.io/badge/demo-live-brightgreen)](https://grouptherapyorg.github.io/Therapy.jl/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE.md)

## Features

- **Fine-grained Reactivity** - Signals, effects, memos, and resources for precise DOM updates
- **Islands Architecture** - Static by default, opt-in interactivity with `@island`
- **SSR + Hydration** - Server-side rendering with WebAssembly hydration
- **File-path Routing** - Next.js-style routing with dynamic params and nested layouts
- **SPA Navigation** - Client-side routing with partial page updates
- **Real-time WebSocket** - Server signals, bidirectional signals, and message channels
- **Server Functions** - RPC via `@server` macro
- **Context API** - Type-based component data sharing
- **Async Data** - Resources, Suspense, and Await for loading states
- **Error Handling** - ErrorBoundary with reset capability
- **Tailwind CSS** - Built-in integration (CDN for dev, CLI for production)

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/GroupTherapyOrg/Therapy.jl")
```

## Quick Start

Create an interactive counter in `components/Counter.jl`:

```julia
using Therapy

@island function Counter(; initial=0)
    count, set_count = create_signal(initial)

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

app = App(
    routes_dir = "routes",
    components_dir = "components"
)

Therapy.run(app)
```

Run:
```bash
julia --project=. app.jl dev    # Development server
julia --project=. app.jl build  # Static site generation
```

## Core Concepts

### Signals (Reactive State)

```julia
# Create a signal with initial value
count, set_count = create_signal(0)

# Read the value (tracks dependencies)
current = count()  # 0

# Write a new value (triggers updates)
set_count(5)

# Update with a function
set_count(c -> c + 1)

# Signal with transform
upper, set_upper = create_signal("hello", uppercase)
upper()  # "HELLO"
```

### Effects (Side Effects)

```julia
# Runs immediately and re-runs when dependencies change
create_effect() do
    println("Count is: ", count())
end

# With cleanup
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

## Components

### Static Components

```julia
function Header(title)
    Nav(:class => "flex items-center",
        H1(title),
        A(:href => "/about", "About")
    )
end
```

### Components with Props

```julia
function Greeting(; name="World")
    P("Hello, ", name, "!")
end

# Usage — keyword arguments
Greeting(name="Julia")
```

### Islands (Interactive Components)

Islands compile to WebAssembly and hydrate on the client:

```julia
@island function Counter(; initial=0)
    count, set_count = create_signal(initial)

    Div(
        Button(:on_click => () -> set_count(count() - 1), "-"),
        Span(count),
        Button(:on_click => () -> set_count(count() + 1), "+")
    )
end
```

### Conditional Rendering

```julia
visible, set_visible = create_signal(true)

Show(visible) do
    Div("I'm visible!")
end
```

### List Rendering

```julia
items, set_items = create_signal(["a", "b", "c"])

For(items) do item
    Li(item)
end
```

## Async Data

### Resources

```julia
# Create a resource with source signal and fetcher
user = create_resource(
    () -> user_id(),           # Reactive source
    (id) -> fetch_user(id)     # Async fetcher
)

# Access states
user.loading    # true while fetching
user.error      # error if failed
user()          # data when ready

# Manual refetch
refetch!(user)
```

### Suspense

```julia
Suspense(
    fallback = () -> P("Loading..."),
    children = () -> UserProfile(user = user())
)
```

### Await (Convenience Wrapper)

```julia
Await(user_resource) do user
    UserCard(user)
end
```

## Context API

Share data across the component tree:

```julia
# Provider (any ancestor component)
function App()
    theme = create_signal("light")
    provide_context(typeof(theme), theme)

    Div(Header(), MainContent(), Footer())
end

# Consumer (any descendant)
function ThemeToggle()
    theme = use_context(typeof(theme))
    # Use theme signal...
end
```

## Error Handling

```julia
ErrorBoundary(
    fallback = (err, reset) -> Div(
        P("Something went wrong: ", string(err)),
        Button(:on_click => reset, "Try again")
    ),
    children = () -> RiskyComponent()
)
```

## Routing

### File-Based Routes

```
routes/
  index.jl          -> /
  about.jl          -> /about
  users/[id].jl     -> /users/:id
  posts/[...slug].jl -> /posts/*
  users/_layout.jl  -> Nested layout for /users/*
```

### Route Hooks

```julia
function UserPage()
    # Get route parameters
    params = use_params()
    user_id = params[:id]

    # Or get single param with default
    user_id = use_params(:id, "unknown")

    Div(H1("User ", user_id))
end

# Query parameters (?page=2&sort=name)
function SearchPage()
    page = use_query(:page, "1")
    sort = use_query(:sort, "date")

    Div(P("Page ", page, ", sorted by ", sort))
end

# Current path
path = use_location()  # e.g., "/users/123"
```

### Nested Layouts with Outlet

```julia
# In routes/users/_layout.jl
(params) -> Div(:class => "users-section",
    Nav(
        NavLink("/users/", "All Users"),
        NavLink("/users/new", "New User")
    ),
    Main(
        Outlet()  # Child routes render here
    )
)
```

### Client-Side Navigation

```julia
NavLink("/about", "About";
    class = "text-warm-700",
    active_class = "text-accent-700",
    exact = true
)
```

JavaScript API:
```javascript
TherapyRouter.navigate('/new-page');
TherapyRouter.hydrateIslands();
```

## Server Functions

Define functions that run on the server, callable from client:

```julia
@server function get_user(id::Int)::User
    DB.query("SELECT * FROM users WHERE id = ?", id)
end

@server function create_post(title::String, body::String)::Post
    DB.insert("posts", title=title, body=body)
end

# Client calls same function - auto-generates RPC
user = create_resource(() -> get_user(user_id()))
```

JavaScript API:
```javascript
const result = await TherapyWS.callServer("get_user", [123]);
```

## WebSocket & Real-Time

### Server Signals (Push from Server)

```julia
# Server-side: Create a signal that broadcasts to all clients
visitors = create_server_signal("visitors", 0)

# Update it - automatically broadcasts
update_server_signal!(visitors, v -> v + 1)

# Lifecycle hooks
on_ws_connect() do conn
    update_server_signal!(visitors, v -> v + 1)
end

on_ws_disconnect() do conn
    update_server_signal!(visitors, v -> v - 1)
end
```

Client-side binding:
```julia
Span(:data_server_signal => "visitors", "0")
```

### Bidirectional Signals (Collaborative)

```julia
# Create a signal that can be modified by server AND clients
shared_doc = create_bidirectional_signal("shared_doc", "")

# Optional validation
on_bidirectional_update("shared_doc") do conn, new_value
    length(new_value) <= 50000  # Reject if too large
end
```

Client-side:
```julia
Textarea(
    :data_bidirectional_signal => "shared_doc",
    :oninput => "TherapyWS.setBidirectional('shared_doc', this.value)"
)
```

### Message Channels

```julia
# Create a channel for discrete messages
chat = create_channel("chat")

# Handle incoming messages
on_channel_message("chat") do conn, data
    message = Dict(
        "text" => data["text"],
        "from" => conn.id[1:8],
        "timestamp" => time()
    )
    broadcast_channel!("chat", message)
end
```

JavaScript API:
```javascript
TherapyWS.sendMessage('chat', { text: 'Hello!' });

TherapyWS.onChannelMessage('chat', function(data) {
    console.log('Message:', data.text);
});
```

## Tailwind CSS

```julia
# Development (CDN)
render_page(App(); head_extra=tailwind_cdn())

# Production - automatic CLI integration
# Generates tree-shaken CSS during build

# Class helper
Div(:class => tw("flex", "items-center", is_active && "bg-blue-500"))
```

## SSR

```julia
# Simple
html = render_to_string(Div("Hello"))

# Full page
html = render_page(App();
    title = "My App",
    head_extra = tailwind_cdn()
)
```

## HTML Elements

All standard HTML elements with JSX-style capitalization:

```julia
# Layout
Div, Span, P, Br, Hr

# Text
H1, H2, H3, H4, H5, H6, Strong, Em, Code, Pre, Blockquote

# Lists
Ul, Ol, Li, Dl, Dt, Dd

# Tables
Table, Thead, Tbody, Tr, Th, Td

# Forms
Form, Input, Button, Textarea, Select, Option, Label

# Media
Img, Video, Audio, Iframe

# Semantic
Header, Footer, Nav, Main, Section, Article, Aside

# SVG
Svg, Path, Circle, Rect, Line, G, etc.
```

## Event Handlers

Use `:on_click` syntax (Therapy.jl normalizes to HTML):

```julia
# Island - compiles to Wasm
Button(:on_click => () -> set_count(count() + 1), "+")

# SSR - renders as onclick attribute
Button(:on_click => "doSomething()", "Click")
```

Available events:
- Mouse: `:on_click`, `:on_dblclick`, `:on_mousedown`, `:on_mouseup`, `:on_mouseenter`, `:on_mouseleave`
- Keyboard: `:on_keydown`, `:on_keyup`, `:on_keypress`
- Form: `:on_submit`, `:on_input`, `:on_change`, `:on_focus`, `:on_blur`
- Touch: `:on_touchstart`, `:on_touchend`, `:on_touchmove`
- Drag: `:on_drag`, `:on_dragstart`, `:on_dragend`, `:on_drop`
- Media: `:on_play`, `:on_pause`, `:on_ended`
- Other: `:on_scroll`, `:on_resize`, `:on_load`, `:on_error`

## Feature Status

| Category | Status | Features |
|----------|--------|----------|
| Core Reactivity | **Complete** | Signals, Effects, Memos, Batching |
| Components | **Complete** | Props, Children, Islands, Lifecycle hooks |
| Async | **Complete** | Resources, Suspense, Await |
| Context | **Complete** | provide_context, use_context |
| Error Handling | **Complete** | ErrorBoundary with reset |
| Routing | **Complete** | File-based, Dynamic params, Nested layouts, Outlet, SPA navigation |
| Route Hooks | **Complete** | use_params, use_query, use_location |
| WebSocket | **Complete** | Server signals, Bidirectional signals, Channels |
| Server Functions | **Complete** | @server macro, RPC |
| SSR | **Complete** | render_to_string, hydration keys |
| Tailwind | **Complete** | CDN (dev), CLI (build) |
| Streaming SSR | Planned | Progressive HTML delivery |
| Code Splitting | Planned | Lazy loading of islands |

## Live Demo

See Therapy.jl in action at [grouptherapyorg.github.io/Therapy.jl](https://grouptherapyorg.github.io/Therapy.jl/) — including:
- Interactive counters demonstrating fine-grained reactivity
- Tic-Tac-Toe game compiled entirely to WebAssembly
- Theme toggle (dark mode) with client-side state
- Full documentation book with 24 pages

## Comparison with Other Frameworks

| Feature | Therapy.jl | Leptos (Rust) | React | Genie.jl |
|---------|------------|---------------|-------|----------|
| Fine-grained reactivity | Yes | Yes | No (VDOM) | No |
| Islands architecture | Yes | Yes | No | No |
| SSR + Hydration | Yes | Yes | Yes | Limited |
| WebAssembly | Yes (WasmGC) | Yes (wasm32) | No | No |
| File-based routing | Yes | Via leptos_router | Via Next.js | No |
| Server functions | @server macro | #[server] | Server Actions | Manual |
| Single language | Yes (Julia) | Yes (Rust) | No (JS+backend) | Yes (Julia) |

## Architecture

### WasmGC-First Approach

Unlike Leptos (linear memory + manual management), Therapy.jl uses WasmGC:
- Automatic garbage collection
- Direct mapping to WasmGC types
- Smaller binaries (no runtime overhead)
- Stable in all major browsers since late 2024

### Compilation Pipeline

```
Island Component
    ↓
Analysis Phase (discover signals, extract handlers)
    ↓
WasmGen Phase (compile IR to Wasm via WasmTarget.jl)
    ↓
Hydration Phase (generate JS to load Wasm + connect events)
    ↓
Output: HTML + Wasm binary + Hydration JS
```

## Related Projects

- [WasmTarget.jl](https://github.com/GroupTherapyOrg/WasmTarget.jl) - Julia to WebAssembly compiler
- [Sessions.jl](https://github.com/GroupTherapyOrg/Sessions.jl) - Reactive notebook IDE (Pluto alternative) built with Therapy.jl

## Contributing

See the [documentation](https://grouptherapyorg.github.io/Therapy.jl/) for guides, API reference, and examples.

## License

MIT
