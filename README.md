# Therapy.jl

<div align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="logo/therapy_dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="logo/therapy_light.svg">
    <img alt="Therapy.jl" src="logo/logo_light.svg" height="60">
  </picture>
</div>

A reactive web framework for Julia inspired by [Leptos](https://leptos.dev) and [SolidJS](https://solidjs.com).

[![Live Demo](https://img.shields.io/badge/demo-live-brightgreen)](https://grouptherapyorg.github.io/Therapy.jl/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE.md)

---

## The Three Tiers

Every component in Therapy.jl falls into one of three tiers. This is the core mental model:

### Tier 1: Static Functions — server-rendered HTML

Plain Julia functions that return HTML. No JavaScript, no Wasm. They run once on the server during rendering.

```julia
function Greeting(; name="World")
    Div(:class => "p-4",
        H1("Hello, ", name, "!"),
        P("Welcome to Therapy.jl")
    )
end
```

**Use for:** layouts, headers, footers, cards, badges — anything that doesn't need to respond to user interaction.

### Tier 2: `@island` — interactive WebAssembly on the client

Islands compile to WebAssembly and hydrate in the browser. They have reactive signals, event handlers, and fine-grained DOM updates — all written in Julia, compiled to Wasm.

```julia
@island function Counter(; initial=0)
    count, set_count = create_signal(initial)

    Div(:class => "flex items-center gap-4",
        Button(:on_click => () -> set_count(count() - 1), "-"),
        Span(:class => "text-2xl font-bold", count),
        Button(:on_click => () -> set_count(count() + 1), "+")
    )
end
```

**What happens:**
1. Server renders the HTML (SSR)
2. Julia compiles the signal logic and event handlers to Wasm via [WasmTarget.jl](https://github.com/GroupTherapyOrg/WasmTarget.jl)
3. Browser loads the Wasm, hydrates the island, and attaches event listeners
4. User clicks a button — Wasm updates only the affected DOM nodes (fine-grained, no VDOM)

**Use for:** buttons, forms, toggles, sliders, modals, tabs — anything interactive.

### Tier 3: `@server` — server-side functions callable from the client

Server functions run on the server but can be called from the browser via WebSocket RPC. They never leave the server — only JSON goes over the wire.

```julia
@server function get_user(id::Int)
    DB.query("SELECT * FROM users WHERE id = ?", id)
end

@server function create_post(title::String, body::String)
    DB.insert("posts", title=title, body=body)
end
```

Call from Julia (via Resources):
```julia
user = create_resource(() -> get_user(user_id()))
```

Call from JavaScript:
```javascript
const user = await TherapyWS.callServer("get_user", [123]);
```

**Use for:** database queries, authentication, file operations — anything that needs server access.

### How They Compose

The three tiers work together naturally:

```julia
# Tier 3: server function
@server function search_users(query::String)
    DB.query("SELECT * FROM users WHERE name LIKE ?", "%$query%")
end

# Tier 2: interactive island
@island function UserSearch()
    query, set_query = create_signal("")
    results = create_resource(() -> search_users(query()))

    Div(
        Input(:on_input => (e) -> set_query(e.target.value),
              :placeholder => "Search users..."),
        Suspense(
            fallback = () -> P("Loading..."),
            children = () -> UserList(users=results())  # Tier 1 static component
        )
    )
end

# Tier 1: static component
function UserList(; users=[])
    Ul(map(u -> Li(u.name), users)...)
end
```

---

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

Therapy.jl uses fine-grained reactivity (like SolidJS/Leptos), not virtual DOM diffing (like React). When a signal changes, only the specific DOM nodes that depend on it update.

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

## Async Data

```julia
user = create_resource(
    () -> user_id(),        # Reactive source
    (id) -> fetch_user(id)  # Fetcher
)

Suspense(
    fallback = () -> P("Loading..."),
    children = () -> UserCard(user=user())
)

# Or the simpler Await
Await(user_resource) do user
    UserCard(user)
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

Client-side navigation with `NavLink` — layout persists, only content swaps:

```julia
NavLink("/about", "About"; active_class="text-accent-700")
```

## WebSocket & Real-Time

### Server Signals

```julia
visitors = create_server_signal("visitors", 0)

on_ws_connect() do conn
    update_server_signal!(visitors, v -> v + 1)
end
```

```julia
Span(:data_server_signal => "visitors", "0")  # Auto-updates
```

### Bidirectional Signals

```julia
shared_doc = create_bidirectional_signal("shared_doc", "")
```

### Message Channels

```julia
chat = create_channel("chat")
on_channel_message("chat") do conn, data
    broadcast_channel!("chat", Dict("text" => data["text"], "from" => conn.id[1:8]))
end
```

## Compilation Pipeline

```
@island function Counter(; initial=0) ... end
    |
    v
Analysis ── discover signals, extract handler closures
    |
    v
WasmGen ─── compile Julia IR to WebAssembly via WasmTarget.jl
    |
    v
Hydration ── generate JS to load Wasm + connect DOM events
    |
    v
Output: HTML + .wasm binary + hydration JS
```

Therapy.jl uses **WasmGC** (garbage-collected WebAssembly), not linear memory. This means automatic GC, smaller binaries, and direct mapping to browser types. Stable in all major browsers since late 2024.

## Feature Status

| Category | Status |
|----------|--------|
| Signals, Effects, Memos, Batching | Complete |
| Components, Islands, `@island` | Complete |
| SSR + Hydration | Complete |
| File-based Routing, SPA, Nested Layouts | Complete |
| Server Functions (`@server`) | Complete |
| Resources, Suspense, Await | Complete |
| Context API | Complete |
| ErrorBoundary | Complete |
| WebSocket, Server Signals, Channels | Complete |
| Tailwind CSS (CDN + CLI) | Complete |
| Streaming SSR | Planned |
| Code Splitting / Lazy Loading | Planned |

## Related Projects

- [WasmTarget.jl](https://github.com/GroupTherapyOrg/WasmTarget.jl) — Julia-to-WebAssembly compiler
- [Suite.jl](https://github.com/GroupTherapyOrg/Suite.jl) — 54-component UI library (shadcn/ui for Julia)
- [Sessions.jl](https://github.com/GroupTherapyOrg/Sessions.jl) — Reactive notebook IDE

## License

MIT
