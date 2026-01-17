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
│   │   ├── Types.jl            # Signal, Effect, Memo, TrackingContext
│   │   ├── Context.jl          # Effect stack, batching mode, dependency tracking
│   │   ├── Signal.jl           # create_signal, batch, handler tracing
│   │   ├── Effect.jl           # create_effect, dispose!, dependency tracking
│   │   ├── Memo.jl             # create_memo with lazy evaluation
│   │   ├── ServerSignal.jl     # Server-controlled signals (WebSocket broadcast)
│   │   ├── BidirectionalSignal.jl  # Two-way signals (client ↔ server)
│   │   └── Channel.jl          # Message channels for discrete events
│   ├── DOM/
│   │   ├── VNode.jl            # VNode, Fragment, Show, For conditionals
│   │   ├── Elements.jl         # All HTML element factory functions
│   │   └── Events.jl           # Event name mappings (30+ event types)
│   ├── Components/
│   │   ├── Component.jl        # component(), render_component
│   │   ├── Island.jl           # island(), interactive island registry
│   │   ├── Props.jl            # Props container with typed access
│   │   └── Lifecycle.jl        # on_mount, on_cleanup hooks
│   ├── SSR/
│   │   └── Render.jl           # render_to_string, render_page, hydration keys
│   ├── Router/
│   │   ├── Router.jl           # File-path routing (Next.js style)
│   │   └── ClientRouter.jl     # Client-side SPA navigation (Leptos-style)
│   ├── Styles/
│   │   └── Tailwind.jl         # Tailwind CSS integration (CDN + CLI)
│   ├── Compiler/
│   │   ├── Analysis.jl         # Component analysis, signal/handler discovery
│   │   ├── WasmGen.jl          # WebAssembly generation via WasmTarget.jl
│   │   ├── Hydration.jl        # JavaScript hydration code generation
│   │   └── Compile.jl          # compile_component main API
│   ├── Server/
│   │   ├── DevServer.jl        # Development HTTP server
│   │   ├── WebSocket.jl        # WebSocket connection handling
│   │   ├── WebSocketClient.jl  # Client-side JS generation
│   │   └── JSONPatch.jl        # RFC 6902 JSON Patch implementation
│   ├── App/
│   │   └── App.jl              # High-level app framework
│   └── SSG/
│       └── StaticSite.jl       # Static site generation
├── test/
│   └── runtests.jl             # 58 tests
├── docs/                       # Documentation site (built with Therapy.jl)
│   ├── app.jl
│   └── src/
│       ├── components/         # TicTacToe, ThemeToggle, InteractiveCounter
│       ├── routes/             # Tutorial pages
│       └── Layout.jl
└── examples/
    ├── counter.jl              # Basic SSR demo
    ├── counter_wasm.jl         # Manual Wasm compilation demo
    └── todo/
        └── app.jl              # Full reactive app with auto-compilation
```

---

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

### Event Handlers (IMPORTANT: Unified Syntax)

**ALWAYS use `:on_click` syntax, NEVER `:onclick`**

Therapy.jl provides a unified event handler syntax that works for both SSR components and islands:

```julia
# ✅ CORRECT - Unified Therapy.jl syntax
Button(:on_click => () -> set_count(count() + 1), "+")  # Island - compiles to Wasm
Button(:on_click => "executeCell('abc')", "Run")        # SSR - renders as onclick="..."

# ❌ WRONG - Raw HTML attribute (don't use)
Button(:onclick => "doSomething()", "Click")
```

**How it works:**
- **SSR components**: `:on_click => "string"` → renders as `onclick="string"` in HTML
- **Islands**: `:on_click => () -> julia_code()` → compiles closure to WebAssembly
- **The same `:on_click` syntax works everywhere**

**Available events:**
```julia
# Mouse: :on_click, :on_dblclick, :on_mousedown, :on_mouseup, :on_mouseenter, :on_mouseleave
# Keyboard: :on_keydown, :on_keyup, :on_keypress
# Form: :on_submit, :on_input, :on_change, :on_focus, :on_blur
# Touch: :on_touchstart, :on_touchend, :on_touchmove
# Drag: :on_drag, :on_dragstart, :on_dragend, :on_drop
# Media: :on_play, :on_pause, :on_ended
# Other: :on_scroll, :on_resize, :on_load, :on_error
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

### Components

```julia
Greeting = component(:Greeting) do props
    name = get_prop(props, :name, "World")
    P("Hello, ", name, "!")
end

# Usage
render_to_string(Greeting(:name => "Julia"))
```

### Islands (Interactive Components)

```julia
Counter = island(:Counter) do
    count, set_count = create_signal(0)

    Div(
        Button(:on_click => () -> set_count(count() - 1), "-"),
        Span(count),
        Button(:on_click => () -> set_count(count() + 1), "+")
    )
end

# Islands are:
# - Auto-discovered and registered
# - Compiled to WebAssembly
# - Hydrated on the client
# - Static HTML rendered on server
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

### Client-Side Routing (SPA)

Leptos-style client-side navigation without page reloads:

```julia
# App-level layout (persists during navigation)
app = App(
    routes_dir = "src/routes",
    layout = :Layout  # Applied at app level, not per-route
)

# Routes return just content (no Layout wrapper)
function GettingStarted()
    Div(:class => "max-w-4xl",
        H1("Getting Started"),
        P("Content here...")
    )
end

# NavLink for navigation with active states
NavLink("getting-started/", "Getting Started";
    class = "text-neutral-700",
    active_class = "text-emerald-700",
    exact = true  # Only match exact path
)
```

**How it works:**
- Full page load: Layout wraps route content (nav + main + footer)
- SPA navigation: Fetch with `X-Therapy-Partial: 1` header
- Response: Just route content (no Layout)
- Client: Swap `#page-content`, re-hydrate islands
- Result: Nav/footer persist, only content changes

**JavaScript API:**
```javascript
// Programmatic navigation
window.TherapyRouter.navigate('/new-page');

// Re-hydrate islands after dynamic content
window.TherapyRouter.hydrateIslands();

// Update active link styling
window.TherapyRouter.updateActiveLinks();
```

### WebSocket & Server Signals

Server signals enable real-time updates from server to all connected clients:

```julia
# Server-side: Create a server signal
visitors = create_server_signal("visitors", 0)

# Update it - automatically broadcasts to all subscribed clients
set_server_signal!(visitors, 42)
# or with a function
update_server_signal!(visitors, v -> v + 1)

# Lifecycle hooks
on_ws_connect() do conn
    update_server_signal!(visitors, v -> v + 1)
    println("Client connected: ", conn.id)
end

on_ws_disconnect() do conn
    update_server_signal!(visitors, v -> v - 1)
end
```

Client-side, use `data-server-signal` attribute for auto-binding:

```julia
# This element auto-updates when server broadcasts "visitors" signal
Span(:data_server_signal => "visitors", "0")

# Mark container for static hosting warning
Div(:data_ws_example => "true",
    Span(:data_server_signal => "visitors", "0")
)
```

**Features:**
- Auto-reconnect with exponential backoff
- Auto-discover `data-server-signal` elements on page load and SPA navigation
- Graceful degradation: shows warning on static hosting (GitHub Pages)
- wss:// on HTTPS, ws:// on HTTP
- JSON patches (RFC 6902) for efficient updates

### Bidirectional Signals (Collaborative)

Bidirectional signals can be modified by both server AND clients:

```julia
# Create a bidirectional signal for collaborative editing
shared_doc = create_bidirectional_signal("shared_doc", "")

# Add validation handler (optional)
on_bidirectional_update("shared_doc") do conn, new_value
    if length(new_value) > 50000
        return false  # Reject updates over 50KB
    end
    return true  # Accept
end

# Server can also update (broadcasts to all clients)
set_bidirectional_signal!(shared_doc, "Hello from server!")
```

Client-side with `data-bidirectional-signal`:

```julia
# Textarea that syncs with server and other clients
Textarea(
    :data_bidirectional_signal => "shared_doc",
    :oninput => "TherapyWS.setBidirectional('shared_doc', this.value)"
)
```

Changes sync using JSON patches (RFC 6902) - only diffs are sent, not full values.

### Message Channels (Chat)

Channels are for discrete messages (events), not continuous state:

```julia
# Create a chat channel
chat = create_channel("chat")

# Handle incoming messages from clients
on_channel_message("chat") do conn, data
    message = Dict(
        "text" => data["text"],
        "from" => conn.id[1:8],
        "timestamp" => time()
    )
    broadcast_channel!("chat", message)
end

# Server can also send messages
broadcast_channel!("chat", Dict("text" => "Server announcement!"))

# Send to specific connection
send_channel!("private", conn_id, Dict("text" => "Hello!"))

# Broadcast except sender (avoid echo)
broadcast_channel_except!("chat", message, sender_conn_id)
```

Client-side listening:

```javascript
// Send a message
TherapyWS.sendMessage('chat', { text: 'Hello!' });

// Listen for messages
TherapyWS.onChannelMessage('chat', function(data) {
    console.log('Message:', data.text, 'from', data.from);
});

// Or use DOM events
window.addEventListener('therapy:channel:chat', function(e) {
    console.log('Message:', e.detail);
});
```

### WebSocket JavaScript API

```javascript
// Connection status
TherapyWS.isConnected()
TherapyWS.getConnectionId()

// Server signals (read-only)
TherapyWS.subscribe("signal_name")
TherapyWS.unsubscribe("signal_name")
TherapyWS.discoverAndSubscribe()  // Auto-scan DOM

// Bidirectional signals
TherapyWS.setBidirectional("signal_name", newValue)
TherapyWS.getSignalValue("signal_name")

// Channel messaging
TherapyWS.sendMessage("channel_name", { data: "here" })
TherapyWS.onChannelMessage("channel_name", callback)

// Events
window.addEventListener('therapy:ws:connected', () => { ... })
window.addEventListener('therapy:ws:disconnected', () => { ... })
window.addEventListener('therapy:signal:visitors', (e) => {
    console.log('New value:', e.detail.value)
})
window.addEventListener('therapy:channel:chat', (e) => {
    console.log('Message:', e.detail)
})
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

---

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

# Documentation site
cd docs && julia --project=.. app.jl dev
```

---

## Architecture Overview

### Fine-Grained Reactivity

Unlike React's VDOM diffing, Therapy.jl tracks signal dependencies precisely. When a signal changes, only the specific DOM nodes that depend on it are updated. This is the same model as SolidJS and Leptos.

**Reactive Graph:**
```
Signals (root nodes)
    ↓ read by
Memos (derived/cached)
    ↓ read by
Effects (leaf nodes / side effects)
```

### Islands Architecture

Therapy.jl follows Leptos's islands pattern: **static by default, opt-in interactivity**.

- Static components render to HTML only (no JavaScript)
- Interactive `island()` components compile to WebAssembly and hydrate on the client
- Islands are auto-discovered and auto-hydrated via `data-hk` attributes

### VNode is Compile-Time Only

VNodes are used for SSR and analysis, not runtime diffing. At runtime, Wasm directly updates DOM nodes by hydration key (`data-hk`).

### Direct IR Compilation

Event handlers are compiled directly from Julia IR to WebAssembly:

1. `compile_component()` analyzes the component to find signals and handlers
2. Handler closures are inspected via `Base.code_typed()` to get their IR
3. Signal getters/setters in closures are substituted with Wasm `global.get`/`global.set`
4. DOM update calls are automatically injected after signal writes
5. Type conversions (e.g., Int64 to f64) are handled automatically

This enables compiling **arbitrary Julia code** to Wasm, not just simple patterns.

### Compilation Pipeline

```
Island Component
    ↓
Analysis Phase (src/Compiler/Analysis.jl)
├─ Execute component in analysis mode
├─ Discover all signals created
├─ Extract handler closures
├─ Build DOM structure with hydration keys
    ↓
WasmGen Phase (src/Compiler/WasmGen.jl)
├─ Create Wasm globals for each signal
├─ Compile handler IR to Wasm bytecode
├─ Inject DOM update calls (update_text, set_visible)
├─ Use WasmTarget.jl for binary generation
    ↓
Hydration Phase (src/Compiler/Hydration.jl)
├─ Generate JavaScript to load Wasm module
├─ Connect event listeners to exported handlers
├─ Set up input bindings
    ↓
Output: HTML + Wasm binary + Hydration JS
```

### f64 DOM Values

All numeric values passed to DOM imports use f64 (JavaScript's number type). Type conversion is handled automatically by WasmTarget.jl, so users can write regular Julia code with `Int`, `Int32`, `Float64`, etc.

---

## TherapeuticJulia Ecosystem

Therapy.jl is part of the TherapeuticJulia organization:

- **Therapy.jl** - Reactive web framework (this project)
- **WasmTarget.jl** - Julia-to-WebAssembly compiler (foundation)
- **Sessions.jl** - Reactive notebook IDE (pure Therapy.jl component, Pluto.jl alternative)

### WasmTarget.jl Integration

Therapy.jl depends on WasmTarget.jl for Wasm compilation. The separation of concerns is intentional:

**WasmTarget.jl handles (generic Wasm compiler):**
- `compile_closure_body()` - IR extraction and WasmGC code generation
- Type registry, function registry, SSA analysis
- Control flow compilation (loops, branches, phis)
- All intrinsic mappings (arithmetic, comparisons, etc.)
- 305+ passing tests, structs, arrays, strings, closures, exceptions

**Therapy.jl handles (web framework concerns only):**
- DOM-specific imports:
  - `dom.update_text(hk, value)` - Update text content
  - `dom.set_visible(hk, visible)` - Show/hide element
  - `dom.set_dark_mode(enabled)` - Toggle dark mode
  - `dom.get_editor_code(cell_hk)` - Get code from external editor (placeholder)
- Channel imports:
  - `channel.send(channel_id, cell_id)` - Send message to Therapy.jl channel
- Mapping reactive signals → Wasm globals
- `dom_bindings` specification - tells WasmTarget.jl what DOM calls to inject after signal writes
- Thin wrappers for signal getters/setters and input handlers

**Key integration pattern:**
```julia
# Therapy.jl builds the DOM bindings specification
dom_bindings = Dict{UInt32, Vector{Tuple{UInt32, Vector{Int32}}}}()
# Maps: global_idx -> [(import_idx, const_args), ...]
# Example: signal global 0 -> [(0, [42])] means "after writing global 0, call import 0 with arg 42"

# Then delegates compilation to WasmTarget.jl
body, locals = compile_closure_body(
    handler_closure,
    captured_signal_fields,  # Maps closure fields to Wasm globals
    mod,
    type_registry;
    dom_bindings = dom_bindings,  # WasmTarget injects these calls automatically
    void_return = true
)
```

This design means Therapy.jl never touches Wasm opcodes for business logic - it only specifies *what* DOM side effects to inject, and WasmTarget.jl handles *how* to compile and inject them.

---

## Leptos Feature Parity Analysis

Therapy.jl aims for feature parity with Leptos.rs. Current status as of January 2026:

### ✅ Complete - Core Reactivity

| Feature | Leptos | Therapy.jl | Notes |
|---------|--------|------------|-------|
| Signals (getter/setter) | `signal()` | `create_signal()` | ✅ Identical API |
| Effects | `Effect` | `create_effect()` | ✅ Auto-tracking |
| Memos | `Memo` | `create_memo()` | ✅ Cached computed |
| Batching | `batch()` | `batch()` | ✅ Deferred updates |

### ✅ Complete - Components & View

| Feature | Leptos | Therapy.jl | Notes |
|---------|--------|------------|-------|
| Components | `#[component]` | `component()` | ✅ Reusable |
| Props with defaults | `#[prop]` | `get_prop()` | ✅ Type-safe |
| Children slot | `children` | `get_children()` | ✅ Slot pattern |
| Show conditional | `<Show>` | `Show()` | ✅ Reactive visibility |
| For list rendering | `<For>` | `For()` | ✅ Keyed iteration |
| Lifecycle hooks | `on_mount`, `on_cleanup` | `on_mount`, `on_cleanup` | ✅ Mount/cleanup |

### ✅ Complete - SSR & Hydration

| Feature | Leptos | Therapy.jl | Notes |
|---------|--------|------------|-------|
| Server-side rendering | `ssr` feature | `render_to_string()` | ✅ Full HTML |
| Hydration keys | `data-hk` | `data-hk` | ✅ Same approach |
| Islands architecture | `#[island]` | `island()` | ✅ Opt-in interactivity |
| Wasm compilation | trunk/wasm-pack | WasmTarget.jl | ✅ Direct IR→Wasm |

### ✅ Complete - Routing

| Feature | Leptos | Therapy.jl | Notes |
|---------|--------|------------|-------|
| File-based routing | leptos_router | `create_router()` | ✅ `[id].jl`, `[...slug].jl` |
| Client-side navigation | `<A>` component | `NavLink()` + `TherapyRouter` | ✅ SPA with hydration |
| Active link styling | `active_class` | `active_class` | ✅ Prefix/exact matching |
| History API | Built-in | `ClientRouter.jl` | ✅ pushState/popState |

### ✅ Complete - WebSocket & Real-Time

| Feature | Leptos | Therapy.jl | Notes |
|---------|--------|------------|-------|
| WebSocket connection | `provide_websocket()` | `websocket_client_script()` | ✅ Auto-connect |
| Server signals | `leptos_server_signal` | `create_server_signal()` | ✅ Read-only client |
| Bidirectional signals | `leptos_ws` | `create_bidirectional_signal()` | ✅ Collaborative |
| Channel signals | `ChannelSignal` | `create_channel()` | ✅ Discrete messages |
| JSON patches | RFC 6902 | `JSONPatch.jl` | ✅ Efficient sync |
| Auto-reconnect | Manual | ✅ Exponential backoff | **Ahead of Leptos** |
| Auto-discover bindings | Manual JS | `data-server-signal` attr | **Ahead of Leptos** |
| Static hosting fallback | ❌ | ✅ Warning UI | **Ahead of Leptos** |

### ⚠️ Partial - Forms & Input

| Feature | Leptos | Therapy.jl | Notes |
|---------|--------|------------|-------|
| Two-way input binding | Built-in | ✅ Auto-generated handlers | Works for number inputs |
| ActionForm | `<ActionForm>` | ❌ | Progressive enhancement |
| Form validation | Via actions | ❌ | Client-side validation |

### ❌ Missing - Async & Data (Priority 1)

| Feature | Leptos | Therapy.jl | Priority |
|---------|--------|------------|----------|
| Resource | `Resource` | ❌ | **P1** - Async data loading |
| Suspense | `<Suspense>` | ❌ | **P1** - Loading boundaries |
| Transition | `<Transition>` | ❌ | P2 - Stale content |
| Action | `Action` | ❌ | P2 - Mutations |

### ❌ Missing - Server Functions (Priority 1)

| Feature | Leptos | Therapy.jl | Priority |
|---------|--------|------------|----------|
| Server functions | `#[server]` | ❌ | **P1** - RPC to server |
| Extractors | `extract()` | ❌ | P2 - Request data |
| Server responses | `Redirect`, `ErrorResponse` | ❌ | P2 - Response types |

### ❌ Missing - Context (Priority 1)

| Feature | Leptos | Therapy.jl | Priority |
|---------|--------|------------|----------|
| provide_context | `provide_context()` | ❌ | **P1** |
| use_context | `use_context()` | ❌ | **P1** |

### ❌ Missing - Advanced Routing (Priority 2)

| Feature | Leptos | Therapy.jl | Priority |
|---------|--------|------------|----------|
| Nested routes | `<Route><Route>` | ❌ | P2 |
| Outlet | `<Outlet>` | ❌ | P2 |
| use_params() | `use_params()` | ❌ | P2 - Reactive params |
| use_query() | `use_query()` | ❌ | P2 - Reactive query |

### ❌ Missing - Error Handling (Priority 2)

| Feature | Leptos | Therapy.jl | Priority |
|---------|--------|------------|----------|
| ErrorBoundary | `<ErrorBoundary>` | ❌ | P2 |
| Error recovery | `<ErrorBoundary fallback>` | ❌ | P2 |

### ❌ Missing - Advanced SSR (Priority 3)

| Feature | Leptos | Therapy.jl | Priority |
|---------|--------|------------|----------|
| Streaming SSR | HTTP streaming | ❌ | P3 |
| Out-of-order streaming | `<Suspense>` streaming | ❌ | P3 |
| Partial hydration | Islands subset | ❌ | P3 |

### ❌ Missing - Optimization (Priority 3)

| Feature | Leptos | Therapy.jl | Priority |
|---------|--------|------------|----------|
| Code splitting | `#[lazy]` | ❌ | P3 |
| Dynamic styles | Reactive `class:` | ⚠️ Partial | P3 |
| Portal/Teleport | `<Portal>` | ❌ | P3 |

---

## Parity Summary

**Overall: ~70% Leptos parity**

| Category | Status | Completion |
|----------|--------|------------|
| Core Reactivity | ✅ Complete | 100% |
| Components & View | ✅ Complete | 100% |
| SSR & Hydration | ✅ Complete | 100% |
| Routing (basic) | ✅ Complete | 80% |
| WebSocket/Real-Time | ✅ Complete | 100% (ahead in some areas) |
| Async/Data | ❌ Missing | 0% |
| Server Functions | ❌ Missing | 0% |
| Context | ❌ Missing | 0% |
| Error Handling | ❌ Missing | 0% |
| Advanced SSR | ❌ Missing | 0% |

**Next priorities to reach 90% parity:**
1. Resource + Suspense (async data)
2. Server functions (@server macro)
3. Context API (provide_context/use_context)
4. use_params()/use_query() reactive hooks

---

## Implementation Roadmap

### Phase 1: Context API (Priority 1)

**Goal:** Enable component tree data sharing

```julia
# Provider component
function App()
    provide_context(:theme, create_signal("light"))
    provide_context(:user, current_user)

    Div(Header(), MainContent(), Footer())
end

# Consumer component (any depth)
function ThemeToggle()
    theme, set_theme = use_context(:theme)
    Button(:on_click => () -> set_theme(theme() == "light" ? "dark" : "light"))
end
```

**Files:** `src/Reactivity/Context.jl`

### Phase 2: Async & Data Fetching (Priority 1)

**Goal:** Enable async data loading patterns

1. **Resource Type**
   ```julia
   user = create_resource(
       () -> user_id(),           # Source signal (reactive dependency)
       (id) -> fetch_user(id)     # Async fetcher
   )

   # Access states
   user.loading    # true while fetching
   user.error      # error if failed
   user()          # data when ready
   ```

2. **Suspense Component**
   ```julia
   Suspense(
       fallback = () -> P("Loading..."),
       children = () -> UserProfile(user = user())
   )
   ```

3. **Await Component** (simpler alternative)
   ```julia
   Await(user_resource) do user
       UserCard(user)
   end
   ```

**Files:** `src/Reactivity/Resource.jl`, `src/Components/Suspense.jl`

### Phase 3: Server Functions (Priority 1)

**Goal:** Seamless server-client RPC

```julia
@server function get_user(id::Int)::User
    DB.query("SELECT * FROM users WHERE id = ?", id)
end

@server function create_post(title::String, body::String)::Post
    DB.insert("posts", title=title, body=body)
end

# Client calls same function - auto-generates HTTP request
user = create_resource(() -> get_user(user_id()))
```

**Implementation:**
- `@server` macro registers function and generates client stub
- Client stub makes POST to `/_server/function_name`
- Server routes to registered function
- JSON serialization for arguments and return value

**Files:** `src/Server/ServerFunctions.jl`, `src/Server/Serialization.jl`

### Phase 4: Advanced Routing (Priority 2)

**Goal:** Reactive route access and nested layouts

1. **Reactive Route Hooks**
   ```julia
   function UserProfile()
       params = use_params()  # Reactive - reruns when route changes
       query = use_query()

       user = create_resource(() -> fetch_user(params[:id]))

       Div("User: ", user().name)
   end
   ```

2. **Nested Routes & Outlet**
   ```julia
   # In router config
   Route("/users", UsersLayout,
       Route("/", UsersList),
       Route("/:id", UserDetail),
       Route("/:id/posts", UserPosts)
   )

   # UsersLayout.jl
   function UsersLayout()
       Div(:class => "users-container",
           Sidebar(),
           Outlet()  # Child route renders here
       )
   end
   ```

**Files:** `src/Router/Hooks.jl`, `src/Router/Outlet.jl`

### Phase 5: Error Handling (Priority 2)

**Goal:** Graceful error recovery

```julia
ErrorBoundary(
    fallback = (err, reset) -> Div(
        P("Something went wrong: ", err.message),
        Button(:on_click => reset, "Try again")
    ),
    children = () -> RiskyComponent()
)
```

**Files:** `src/Components/ErrorBoundary.jl`

### Phase 6: Production Features (Priority 3)

1. **Streaming SSR** - Progressive HTML delivery
2. **Code Splitting** - `@lazy` for on-demand loading
3. **Dynamic Styles** - Reactive `class:` and `style:` bindings
4. **Transitions** - Keep stale content during loading

---

## Known Limitations

### WasmTarget.jl Constraints

1. **Complex Control Flow in Void Handlers**
   - TicTacToe winner checking has edge cases
   - Nested conditionals in void-returning functions
   - Workaround: Return dummy value or restructure logic

2. **Array Resize**
   - WasmGC arrays have fixed size at creation
   - `push!`, `pop!` cannot be compiled
   - Workaround: Pre-allocate or use SimpleDict

3. **String Indexing**
   - UTF-8 complexity in Julia IR
   - Use character iteration instead

4. **Math Functions**
   - `sin()`, `cos()` compile but may have value errors
   - Use lookup tables for critical precision

### Therapy.jl Constraints

1. **No Async Data Handling**
   - No Resource/Suspense yet
   - Roadmap Phase 2

2. **No Server Functions**
   - Manual fetch() calls required
   - Roadmap Phase 3

---

## Architectural Advantages

### WasmGC-First Approach

Unlike Leptos (linear memory + manual management), Therapy.jl uses WasmGC:

- **Automatic GC** - No manual memory management
- **Simpler structs/arrays** - Direct mapping to WasmGC types
- **Better browser integration** - WasmGC now stable in all major browsers
- **Smaller binaries** - No runtime overhead for memory management

### Julia's Type System

- Full type inference via `Base.code_typed()`
- No runtime type checks in compiled Wasm
- Seamless f64 conversion for DOM values

### Direct IR Compilation

- No interpretation or tracing
- Clean typed IR → Wasm bytecode
- Arbitrary Julia code compiles (not just patterns)

---

## Development Workflow

```bash
# Development with hot reload (planned)
julia app.jl dev

# Build static site
julia app.jl build

# Output to dist/ (GitHub Pages ready)
```

### Testing Wasm Compilation

```julia
using Therapy

# Define island
Counter = island(:Counter) do
    count, set_count = create_signal(0)
    Div(
        Button(:on_click => () -> set_count(count() + 1), "+"),
        Span(count)
    )
end

# Compile
html, wasm_bytes, hydration_js = compile_component(Counter)

# Inspect
println("HTML: ", html)
println("Wasm size: ", length(wasm_bytes), " bytes")
println("JS: ", hydration_js)
```

---

## Dependencies

- **WasmTarget.jl** - Julia-to-WebAssembly compiler (local path)
- **HTTP.jl** - Dev server and request handling
- **Sockets.jl** - Network utilities

Minimal dependencies by design.

---

## Contributing

### Key Files to Read First

1. `src/Reactivity/Signal.jl` - Core reactive primitive
2. `src/Components/Island.jl` - Interactive component definition
3. `src/Compiler/Compile.jl` - Main compilation pipeline
4. `src/SSR/Render.jl` - Server-side rendering

### Adding a New Feature

1. Check roadmap priority
2. Write tests first (`test/runtests.jl`)
3. Implement in appropriate module
4. Update this CLAUDE.md
5. Add example if user-facing

### Code Style

- Julia conventions (4-space indent)
- Descriptive function names
- Document public API with docstrings
- Keep modules focused and small
