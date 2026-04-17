() -> begin
    card = "border border-warm-200 dark:border-warm-800 rounded-lg p-5 space-y-3"
    code_block = "mt-2 bg-warm-900 dark:bg-warm-950 text-warm-200 p-3 rounded text-xs font-mono overflow-x-auto"

    sections = [
        ("signals", "Signals"),
        ("control-flow", "Control Flow"),
        ("components", "Components"),
        ("routing", "Routing"),
        ("html-elements", "HTML Elements"),
        ("middleware", "Middleware"),
        ("api-routes", "API Routes"),
        ("websockets", "WebSockets"),
        ("hmr", "Hot Module Replacement"),
    ]

    PageWithTOC(sections, Div(:class => "space-y-10",
        H1(:class => "text-3xl font-serif font-bold text-warm-900 dark:text-warm-100", "API Reference"),

        # ── Signals ──
        H2(:id => "signals", :class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Signals"),
        Div(:class => "space-y-4",
            Div(:class => card,
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "create_signal(initial)"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400", "Create a signal. Returns (getter, setter) tuple. Reading the getter inside effects/memos tracks it as a dependency. Supports Int64, Bool, Float64, and String — each stored as the appropriate WASM type."),
                Pre(:class => code_block, Code(:class => "language-julia", """# Integer signal — WASM i64 global
count, set_count = create_signal(0)

# Bool signal — WASM i32 global
active, set_active = create_signal(true)

# Float64 signal — WASM f64 global
temp, set_temp = create_signal(98.6)

# String signal — WasmGC ref global
query, set_query = create_signal("")"""))),

            Div(:class => card,
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "create_effect(() -> ...)"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400",
                    "Run a side effect whenever its signal dependencies change. Effects are owner-scoped — they are disposed when their parent owner is cleaned up. Use ", Code(:class => "text-accent-500", "js()"),
                    " for browser APIs like ", Code(:class => "text-accent-500", "console.log"), "."),
                Pre(:class => code_block, Code(:class => "language-julia", """create_effect(() -> js("console.log('count:', \$1)", count()))
# Runs immediately + re-runs on every count() change
# Disposed automatically when the owning scope is cleaned up"""))),

            Div(:class => card,
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "create_memo(() -> ...)"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400", "Create a cached derived value. Recomputes only when dependencies change. Memo closures compile to WASM. Return type can be Int, String, or Vector{String} — reference types use WasmGC."),
                Pre(:class => code_block, Code(:class => "language-julia", """# Int memo — cached as i64
doubled = create_memo(() -> count() * 2)
doubled()  # read derived value — cached until count() changes

# String/Vector memo — cached as WasmGC refs
filtered = create_memo(() -> begin
    q = lowercase(query())
    result = String[]
    for i in 1:length(items)
        if startswith(lowercase(items[i]), q)
            push!(result, items[i])
        end
    end
    result
end)"""))),

            Div(:class => card,
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "batch(() -> ...)"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400",
                    "Defer effect execution until all signal writes complete. DOM event handlers are auto-batched. Use explicitly in ", Code(:class => "text-accent-500", "setTimeout"), " or async code."),
                Pre(:class => code_block, Code(:class => "language-julia", """# Handlers are auto-batched — effects run once, not twice:
:on_click => () -> begin
    set_name("Alice")   # deferred
    set_count(count() + 1)  # deferred
end  # effects run here (once)

# Manual batch for async/timer code:
batch(() -> begin
    set_a(1)
    set_b(2)
end)"""))),

            Div(:class => card,
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "on_mount(() -> ...)"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400",
                    "Run a function once after the component mounts to the DOM. Unlike ", Code(:class => "text-accent-500", "create_effect"),
                    ", this does NOT track dependencies and never re-runs. Registered with the current owner. Use for one-time initialization: DOM refs, third-party libraries, focus management."),
                Pre(:class => code_block, Code(:class => "language-julia", """on_mount() do
    js("document.getElementById('my-input').focus()")
end

# Also useful for loading external scripts, initializing charts, etc."""))),

            Div(:class => card,
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "on_cleanup(() -> ...)"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400",
                    "Register a cleanup function with the current owner. Called when the owner scope is disposed (e.g., when a ", Code(:class => "text-accent-500", "For"),
                    " item is removed or a ", Code(:class => "text-accent-500", "Show"),
                    " branch toggles). Use for teardown: removing event listeners, clearing timers."),
                Pre(:class => code_block, Code(:class => "language-julia", """on_cleanup() do
    js("clearInterval(\$1)", timer_id())
end""")))
        ),

        # ── Control Flow ──
        H2(:id => "control-flow", :class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Control Flow"),
        Div(:class => "space-y-4",
            Div(:class => card,
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "Show(condition; fallback=...) do ... end"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400",
                    "Conditional rendering. Content is actually inserted/removed from the DOM, not hidden with CSS. Condition can be a bare signal getter or a closure (closures compile to WASM). Optional ",
                    Code(:class => "text-accent-500", "fallback"),
                    " renders when condition is false."),
                Pre(:class => code_block, Code(:class => "language-julia", """visible, set_visible = create_signal(1)

# Bare signal getter as condition
Show(visible) do
    P("I exist in the DOM!")
end

# Closure condition — compiled to WASM
Show(() -> count() > 5) do
    P("Count is above 5!")
end

# With fallback
Show(visible; fallback=P("Nothing to show.")) do
    P("Content is visible!")
end"""))),

            Div(:class => card,
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "For(items) do item, idx ... end"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400",
                    "List rendering with keyed reconciliation — reuses DOM nodes for items that persist across updates. Each item gets its own owner scope; effects and cleanups are disposed when the item is removed. Supports nested For for 2D data (tables, grids)."),
                Pre(:class => code_block, Code(:class => "language-julia", """items, set_items = create_signal(["a", "b", "c"])

Ul(For(items) do item, idx
    Li(item)
end)

# Nested For (table rows × cells)
Table(Tbody(For(rows) do row
    Tr(For(row) do cell; Td(cell); end)
end))""")))
        ),

        # ── Components ──
        H2(:id => "components", :class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Components"),
        Div(:class => "space-y-4",
            Div(:class => card,
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "function Name(args...) ... end"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400", "A plain Julia function that returns VNodes is an SSR component. Runs at build time with full access to Julia packages. No macro needed — just return elements."),
                Pre(:class => code_block, Code(:class => "language-julia", """using DataFrames: DataFrame, names, eachrow

function DataTable()
    df = DataFrame(Name=["Alice","Bob"], Age=[28,35])
    cols = names(df)
    rows = [string.(collect(row)) for row in eachrow(df)]
    return Table(
        Thead(Tr(For(cols) do col; Th(col); end)),
        Tbody(For(rows) do row; Tr(For(row) do c; Td(c); end); end)
    )
end"""))),

            Div(:class => card,
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "@island function Name(; kwargs...) ... end"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400",
                    "Mark a component as interactive. Handler and memo closures compile to WebAssembly via WasmTarget.jl. Browser APIs use ",
                    Code(:class => "text-accent-500", "js()"),
                    " wired as WASM imports. Kwargs must be typed — they become JSON-serializable props."),
                Pre(:class => code_block, Code(:class => "language-julia", """@island function Counter(; initial::Int = 0)
    count, set_count = create_signal(initial)
    doubled = create_memo(() -> count() * 2)
    create_effect(() -> js("console.log('count:', \$1)", count()))

    return Div(
        Button(:on_click => () -> set_count(count() + 1), "+"),
        Span(count),
        Span("doubled: ", doubled)
    )
end"""))),

            Div(:class => card,
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "js(code::String, args...)"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400",
                    "Escape hatch — call JavaScript from WASM via imports. Use ",
                    Code(:class => "text-accent-500", "\$1"), ", ", Code(:class => "text-accent-500", "\$2"),
                    " to interpolate signal/memo values. In Julia, ",
                    Code(:class => "text-accent-500", "js()"),
                    " is a no-op. In the browser, the string runs as JS."),
                Pre(:class => code_block, Code(:class => "language-julia", """# DOM manipulation
js("document.documentElement.classList.toggle('dark')")

# Logging with signal values
js("console.log('count:', \$1, 'doubled:', \$2)", count(), doubled())

# localStorage with shared variables
js("localStorage.setItem('key', \$1)", count())""")))
        ),

        # ── Routing ──
        H2(:id => "routing", :class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Routing"),
        P(:class => "text-sm text-warm-600 dark:text-warm-400 mb-4",
            "Therapy.jl uses two routing systems: ", Strong("file-based routing"), " for defining pages at build time, and ",
            Strong("client-side navigation"), " (Astro View Transitions pattern) for smooth page transitions without full reloads."),

        Div(:class => "space-y-4",
            Div(:class => card,
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "File-Based Routing"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400",
                    "Pages are Julia files in ", Code(:class => "text-accent-500", "routes/"),
                    ". Each file exports a function that returns VNodes. The file path determines the URL. This runs at ", Strong("build time"), " — every page is pre-rendered to static HTML."),
                Pre(:class => code_block, Code(:class => "language-julia", """# File structure --> URLs
routes/
  index.jl          # --> /
  about.jl          # --> /about
  getting-started.jl # --> /getting-started
  examples/
    index.jl        # --> /examples
    advanced.jl     # --> /examples/advanced

# Each file is a function returning VNodes:
# routes/about.jl
() -> begin
    Div(
        H1("About"),
        P("This page is server-rendered at build time.")
    )
end"""))),

            Div(:class => card,
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "Client Navigation (View Transitions)"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400",
                    "After the first page loads, clicking internal links does NOT trigger a full page reload. Instead, the client router (same pattern as ",
                    A(:href => "https://docs.astro.build/en/guides/view-transitions/", :class => "text-accent-500 underline", "Astro View Transitions"),
                    ") intercepts the click, fetches the next page via ", Code(:class => "text-accent-500", "fetch()"),
                    ", and swaps the content using the browser's ", Code(:class => "text-accent-500", "document.startViewTransition()"),
                    " API. Islands on the new page re-hydrate automatically."),
                Pre(:class => code_block, Code(:class => "language-julia", """# How it works (automatic — no code needed):
#
# 1. User clicks <a href=\"/examples/\">
# 2. Router intercepts click (prevents full reload)
# 3. fetch(\"/examples/\") gets the HTML
# 4. document.startViewTransition() animates the swap
# 5. <head> is diffed (title, meta tags updated)
# 6. <body> content is swapped
# 7. <therapy-island> components re-hydrate
# 8. URL updated via history.pushState()
#
# Back/forward buttons work via popstate listener.
# Older browsers fall back to instant swap (no animation).""")),
                P(:class => "text-xs text-warm-400 dark:text-warm-500 mt-2",
                    "This is NOT an SPA router — there is no client-side route table and no JS bundle containing all pages. Each page is independently pre-built HTML. The router just makes transitions smooth.")),

            Div(:class => card,
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "Nav Links"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400",
                    "Use ", Code(:class => "text-accent-500", "data-navlink"),
                    " on links to get automatic active styling. The router adds/removes CSS classes based on the current URL."),
                Pre(:class => code_block, Code(:class => "language-julia", """# Active link styling (automatic)
A(:href => \"/examples\",
  \"data-navlink\" => \"true\",
  \"data-active-class\" => \"text-accent-600 font-bold\",
  \"data-inactive-class\" => \"text-warm-500\",
  \"Examples\")

# Exact match (only active on exact path, not children)
A(:href => \"/\",
  \"data-navlink\" => \"true\",
  \"data-exact\" => \"true\",
  \"Home\")"""))),

            Div(:class => card,
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "Links & Anchor Scrolling"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400",
                    "Internal links are intercepted by the router for smooth navigation. Hash links (",
                    Code(:class => "text-accent-500", "href=\"#section\""),
                    ") are NOT intercepted — the browser scrolls natively. This follows the ",
                    A(:href => "https://docs.astro.build/en/guides/view-transitions/", :class => "text-accent-500 underline", "Astro"),
                    " pattern. Use ", Code(:class => "text-accent-500", ":id"),
                    " on heading elements to create scroll targets."),
                Pre(:class => code_block, Code(:class => "language-julia", """# Internal page link — router intercepts, fetches, swaps
A(:href => \"/examples\", \"Go to examples\")

# Hash anchor — browser scrolls natively (no router)
A(:href => \"#signals\", \"Jump to Signals\")

# External link — opens in new tab, router ignores
A(:href => \"https://github.com/...\", :target => \"_blank\", \"GitHub\")

# Heading with scroll target
H2(:id => \"signals\", \"Signals\")""")),
                P(:class => "text-xs text-warm-400 dark:text-warm-500 mt-2",
                    "Therapy.jl does not use ", Code(:class => "text-accent-500", "<base href>"),
                    " (it breaks hash links). All URLs are prefixed with the base path at build time, same as Astro."))
        ),

        # ── HTML Elements ──
        H2(:id => "html-elements", :class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "HTML Elements"),
        Div(:class => card,
            P(:class => "text-sm text-warm-600 dark:text-warm-400", "All standard HTML elements are available as capitalized functions. Props use ", Code(:class => "text-accent-500", ":symbol => value"), " syntax. Event handlers use ", Code(:class => "text-accent-500", ":on_click"), ", ", Code(:class => "text-accent-500", ":on_input"), ", etc."),
            Pre(:class => code_block, Code(:class => "language-julia", """Div(:class => "container",
    H1("Hello"),
    Button(:on_click => () -> set_count(count() + 1), "Click me"),
    Input(:type => "range", :value => freq, :on_input => set_freq),
    A(:href => "https://example.com", "Link")
)""")),
            P(:class => "text-xs text-warm-400 dark:text-warm-500 mt-2",
                "Div, Span, P, A, Button, Input, Form, Label, H1–H6, Strong, Em, Code, Pre, Ul, Ol, Li, Table, Thead, Tbody, Tr, Th, Td, Header, Footer, Nav, MainEl, Section, Article, Img, Svg, ...")),

        # ── Middleware ──
        H2(:id => "middleware", :class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Middleware"),
        P(:class => "text-sm text-warm-600 dark:text-warm-400 mb-4",
            "Higher-order function middleware pipeline ported from ",
            A(:href => "https://github.com/OxygenFramework/Oxygen.jl", :class => "text-accent-500 underline", "Oxygen.jl"),
            ". Each middleware wraps a handler: ", Code(:class => "text-accent-500", "handler -> (req -> response)"),
            ". Composed via ", Code(:class => "text-accent-500", "reduce(|>)"), "."),

        Div(:class => "space-y-4",
            Div(:class => card,
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "compose_middleware(handler, middleware)"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400", "Compose a base handler with a middleware pipeline. First middleware in the vector is outermost (runs first on request, last on response)."),
                Pre(:class => code_block, Code(:class => "language-julia", """function my_middleware(handler)
    return function(req::HTTP.Request)
        # pre-processing
        response = handler(req)
        # post-processing
        return response
    end
end

pipeline = compose_middleware(base_handler, [mw1, mw2, mw3])
# Execution: mw1 -> mw2 -> mw3 -> handler -> mw3 -> mw2 -> mw1"""))),

            Div(:class => card,
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "CorsMiddleware(; kwargs...)"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400", "CORS middleware. Handles OPTIONS preflight requests and adds CORS headers to all responses."),
                Pre(:class => code_block, Code(:class => "language-julia", """cors = CorsMiddleware(
    allowed_origins=["https://myapp.com"],
    allowed_headers=["*"],
    allowed_methods=["GET", "POST", "OPTIONS"],
    allow_credentials=true,
    max_age=86400
)"""))),

            Div(:class => card,
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "RateLimiterMiddleware(; kwargs...)"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400", "Fixed-window rate limiter per client IP. Returns 429 when exceeded. Sets ", Code(:class => "text-accent-500", "X-RateLimit-Limit"), ", ", Code(:class => "text-accent-500", "X-RateLimit-Remaining"), ", ", Code(:class => "text-accent-500", "X-RateLimit-Reset"), ", ", Code(:class => "text-accent-500", "Retry-After"), " headers."),
                Pre(:class => code_block, Code(:class => "language-julia", """limiter = RateLimiterMiddleware(rate_limit=100, window=60)"""))),

            Div(:class => card,
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "BearerAuthMiddleware(validate_token; header, scheme)"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400", "Bearer token authentication. Extracts token from Authorization header, calls ", Code(:class => "text-accent-500", "validate_token(token)"), ". Returns 401 if missing/invalid. Stores user info in ", Code(:class => "text-accent-500", "req.context[:user]"), "."),
                Pre(:class => code_block, Code(:class => "language-julia", """validate(token) = token == "secret" ? Dict("role" => "admin") : nothing
auth = BearerAuthMiddleware(validate)

# Use with App
app = App(middleware=[CorsMiddleware(), auth])""")))),

        # ── API Routes ──
        H2(:id => "api-routes", :class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "API Routes"),
        P(:class => "text-sm text-warm-600 dark:text-warm-400 mb-4",
            "JSON API endpoints with path parameters, body parsing, and per-route middleware. Adapted from Oxygen.jl's route registration pattern."),

        Div(:class => "space-y-4",
            Div(:class => card,
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "create_api_router(routes)"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400", "Create a request handler from route definitions. Each route maps HTTP methods to handlers. Handlers receive ", Code(:class => "text-accent-500", "(req, params)"), " and return data (auto-serialized to JSON), ", Code(:class => "text-accent-500", "HTTP.Response"), ", or ", Code(:class => "text-accent-500", "nothing"), " (204)."),
                Pre(:class => code_block, Code(:class => "language-julia", """api = create_api_router([
    "/api/users" => Dict(
        "GET" => (req, params) -> ["user1", "user2"],
        "POST" => (req, params) -> json_response(Dict("id" => 1); status=201)
    ),
    "/api/users/:id" => Dict(
        "GET" => (req, params) -> Dict("id" => parse(Int, params[:id]))
    ),
    "/api/protected" => Dict(
        "GET" => handler,
        :middleware => [BearerAuthMiddleware(validate)]  # per-route
    )
])"""))),

            Div(:class => card,
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "Request Extractors"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400", "Utility functions for parsing request data."),
                Pre(:class => code_block, Code(:class => "language-julia", """json_body(req)           # Parse JSON body -> Dict or nothing
json_body(req, T)        # Parse JSON body into type T
text_body(req)           # Raw body as String or nothing
form_body(req)           # URL-encoded form data -> Dict or nothing
query_params(req)        # Query string -> Dict{String,String}"""))),

            Div(:class => card,
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "json_response(data; status, headers)"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400", "Create an HTTP.Response with JSON-serialized body and Content-Type: application/json."),
                Pre(:class => code_block, Code(:class => "language-julia", """json_response(["a", "b"])                           # 200 + JSON
json_response(Dict("error" => "nope"); status=400)  # 400 + JSON""")))),

        # ── Static Files ──
        H2(:id => "static-files", :class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Static Files"),
        P(:class => "text-sm text-warm-600 dark:text-warm-400 mb-4",
            "Mount a directory of files (CSS, JS, images, fonts, …) under a URL prefix. Each file becomes its own GET route at registration time. Ported 1-1 from Oxygen.jl's ", Code(:class => "text-accent-500", "staticfiles"), " / ", Code(:class => "text-accent-500", "dynamicfiles"), ". Mounts feed the SSG too — ", Code(:class => "text-accent-500", "build(app)"), " copies them under ", Code(:class => "text-accent-500", "output_dir"), " at the same URL path."),

        Div(:class => "space-y-4",
            Div(:class => card,
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "staticfiles(app, folder, mountdir=\"static\"; headers, loadfile)"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400", "Walk ", Code(:class => "text-accent-500", "folder"), " and register every file as a GET route under ", Code(:class => "text-accent-500", "mountdir"), ". File content is read and the ", Code(:class => "text-accent-500", "HTTP.Response"), " is cached at registration — serving a request just hands back the precomputed response. ", Code(:class => "text-accent-500", "headers"), " is applied to every response (use it for ", Code(:class => "text-accent-500", "Cache-Control"), " etc.). MIME type is inferred from the file extension via ", Code(:class => "text-accent-500", "MIMEs.jl"), ". An ", Code(:class => "text-accent-500", "index.html"), " is also aliased at the bare directory path (e.g. ", Code(:class => "text-accent-500", "/docs/index.html"), " → ", Code(:class => "text-accent-500", "/docs"), ")."),
                Pre(:class => code_block, Code(:class => "language-julia", """app = App(...)

# Mount everything under ./public at /static/*
staticfiles(app, joinpath(@__DIR__, "public"), "static";
            headers = ["Cache-Control" => "public, max-age=3600"])

# /static/app.js, /static/img/logo.png, ... all served from cache.
# build(app) writes the same files under dist/static/."""))),

            Div(:class => card,
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "dynamicfiles(app, folder, mountdir=\"static\"; headers, loadfile)"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400", "Same as ", Code(:class => "text-accent-500", "staticfiles"), " but file contents are RE-READ on every request — edits on disk show up without a server restart. Use during development; prefer ", Code(:class => "text-accent-500", "staticfiles"), " in production for the cached fast-path."),
                Pre(:class => code_block, Code(:class => "language-julia", """dynamicfiles(app, "./content", "blog";
             headers = ["Cache-Control" => "no-cache"])

# /blog/post-1.md re-reads from disk every time."""))),

            Div(:class => card,
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "Conflict semantics"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400", "Page routes are matched FIRST, static mounts as a fallback — same precedence as Oxygen's HTTP.Router (explicit registrations win). WebSocket upgrades and the Tailwind ", Code(:class => "text-accent-500", "/styles.css"), " special-case both run BEFORE either table is consulted, so they always win against a colliding static path."))),

        # ── WebSockets ──
        H2(:id => "websockets", :class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "WebSockets"),
        P(:class => "text-sm text-warm-600 dark:text-warm-400 mb-4",
            "Per-path WebSocket routing with parameterized paths, channel subscriptions, and middleware on upgrade. Ported from Oxygen.jl's WebSocket pattern."),

        Div(:class => "space-y-4",
            Div(:class => card,
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "websocket(path, handler; middleware)"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400", "Register a WebSocket route. Handler receives a ", Code(:class => "text-accent-500", "WebSocket"), " object (and optional params dict for parameterized routes). Middleware runs on the HTTP upgrade request."),
                Pre(:class => code_block, Code(:class => "language-julia", """# Echo server
websocket("/ws/echo") do ws
    for msg in ws
        WebSockets.send(ws, "Echo: " * String(msg))
    end
end

# With path parameters
websocket("/ws/room/:id") do ws, params
    room_id = params[:id]
    for msg in ws
        WebSockets.send(ws, "[\$room_id] " * String(msg))
    end
end

# With auth middleware on upgrade
websocket("/ws/admin", handler; middleware=[BearerAuthMiddleware(validate)])"""))),

            Div(:class => card,
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "Channels"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400", "First-class channel/room subscriptions multiplexed over a single WebSocket connection. Connections subscribe to channels and receive targeted broadcasts."),
                Pre(:class => code_block, Code(:class => "language-julia", """# Server-side channel API
subscribe(conn, "chat")
unsubscribe(conn, "chat")
broadcast_channel("chat", Dict("type" => "message", "text" => "hello"))
broadcast_channel("chat", msg, exclude_conn)  # exclude sender

# Callbacks
on_channel_message() do channel, conn, msg
    println("[\$channel] \$(msg)")
end

# Query
channel_connections("chat")  # Vector{WSConnection}
channel_count("chat")        # Int"""))),

            Div(:class => card,
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "Connection Lifecycle"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400", "Callbacks for WebSocket connection/disconnection events."),
                Pre(:class => code_block, Code(:class => "language-julia", """on_ws_connect() do conn
    println("Connected: \$(conn.id)")
end

on_ws_disconnect() do conn
    println("Disconnected: \$(conn.id)")
end

# Broadcast to all connections
broadcast_all(Dict("type" => "announcement", "text" => "hello"))

# Connection info
ws_connection_count()  # Int
ws_connection_ids()    # Vector{String}"""))
        ),

        # ── HMR ──
        H2(:id => "hmr", :class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Hot Module Replacement"),
        P(:class => "text-sm text-warm-600 dark:text-warm-400 mb-4",
            "The dev server provides automatic hot module replacement with signal state preservation. File changes are detected instantly via OS-level file watching, only the changed island recompiles, and the browser updates automatically via WebSocket — zero user action required. All components and routes share a single application scope — declare dependencies once in app.jl, then any route or component file can reference them without per-file imports."),

        Div(:class => "space-y-4",
            Div(:class => card,
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "How It Works"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400",
                    "Save a file in your editor. The browser updates automatically. No manual refresh. Counter stays at 7."),
                Pre(:class => code_block, Code(:class => "language-julia", "# 1. FileWatching detects change (instant, OS-level, no polling)\n# 2. Only the changed island recompiles (~2-3s, not all islands)\n# 3. New WASM bytes pushed to browser via WebSocket\n# 4. Browser snapshots signal values from old WASM module\n# 5. New WASM module instantiates\n# 6. Signal values restored (if count + types match)\n# 7. Effects re-fire with new code + preserved state\n\n# Start dev server:\njulia +1.12 --project=. app.jl dev"))),
            Div(:class => card,
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "What Triggers What"),
                Pre(:class => code_block, Code(:class => "language-julia", "# Component .jl change --> surgical island recompile + WS push\n#   Browser: island re-hydrates, signal state preserved\n#\n# CSS / Tailwind change --> rebuild CSS + WS push\n#   Browser: stylesheet replaced, no reload, no state loss\n#\n# Route .jl change --> reload route + WS push\n#   Browser: full page reload (SSR content changed)"))),
            Div(:class => card,
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "Signal State Preservation"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400",
                    "Before swapping the WASM module, the browser reads all ", Code(:class => "text-accent-500", "signal_*"),
                    " globals from the old module. After instantiating the new module, it compares signal count and types. If they match, old values are restored. Same heuristic as React Fast Refresh."),
                Pre(:class => code_block, Code(:class => "language-julia", "# State PRESERVED (same signal count + types):\n#   Change effect logic, counter keeps its value\n#\n# State RESET (signals changed):\n#   Added/removed a signal, or changed type: fresh start")))
        )
    )
    ))
end
