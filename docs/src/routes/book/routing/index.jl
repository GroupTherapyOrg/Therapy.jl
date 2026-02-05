# Routing - Part 6 of the Therapy.jl Book
#
# Overview hub for file-based routing, dynamic routes, client navigation, and nested layouts.

function RoutingIndex()
    BookLayout("/book/routing/",
        # Header
        Div(:class => "py-8 border-b border-warm-200 dark:border-warm-900",
            Span(:class => "text-sm text-accent-700 dark:text-accent-400 font-medium", "Part 6"),
            H1(:class => "text-4xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-2 mb-4",
                "Routing"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 max-w-3xl",
                "Therapy.jl provides a complete routing solution: file-based routing like Next.js, ",
                "dynamic parameters, client-side navigation without page reloads, and nested layouts ",
                "with ", Code(:class => "text-accent-700 dark:text-accent-400", "Outlet"), "."
            )
        ),

        # The Routing Story
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "The Routing Story"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 mb-6",
                "Traditional web frameworks require you to manually configure routes. Therapy.jl takes a ",
                "different approach: your file structure ", Em("is"), " your routing configuration. ",
                "Place a file at ", Code(:class => "text-accent-700 dark:text-accent-400", "routes/about.jl"),
                " and you get a ", Code(:class => "text-accent-700 dark:text-accent-400", "/about"),
                " route automatically."
            ),
            Div(:class => "grid md:grid-cols-4 gap-6 mt-8",
                RoutingIconCard("📁", "File-Based", "routes/about.jl → /about"),
                RoutingIconCard("🔗", "Dynamic", "[id].jl → /users/:id"),
                RoutingIconCard("⚡", "SPA", "No page reloads"),
                RoutingIconCard("📦", "Nested", "Layouts + Outlet")
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "Combined with reactive route hooks like ", Code(:class => "text-accent-700 dark:text-accent-400", "use_params()"),
                " and ", Code(:class => "text-accent-700 dark:text-accent-400", "use_query()"),
                ", you get a complete navigation solution."
            )
        ),

        # Chapters in This Section
        Section(:class => "py-12 bg-warm-100 dark:bg-warm-800 rounded-lg border border-warm-200 dark:border-warm-900 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Chapters in This Section"
            ),
            Div(:class => "grid md:grid-cols-2 gap-6",
                ChapterCard(
                    "./file-routing",
                    "File-Based Routing",
                    "create_router()",
                    "Map your directory structure directly to URL paths. No configuration needed."
                ),
                ChapterCard(
                    "./dynamic-routes",
                    "Dynamic Routes",
                    "[id].jl  [...slug].jl",
                    "Handle dynamic parameters and catch-all routes for flexible URL patterns."
                ),
                ChapterCard(
                    "./client-navigation",
                    "Client-Side Navigation",
                    "NavLink()",
                    "SPA-style navigation with active link styling and no page reloads."
                ),
                ChapterCard(
                    "./nested-routes",
                    "Nested Routes & Hooks",
                    "Outlet() / use_params()",
                    "Build complex layouts with nested routing and reactive route access."
                )
            )
        ),

        # Quick Overview: File-Based Routing
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "File-Based Routing at a Glance"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 mb-6",
                "Your file structure directly maps to URL paths:"
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-200 mb-4",
                        "File Structure"
                    ),
                    CodeBlock("""routes/
├── index.jl          # /
├── about.jl          # /about
├── users/
│   ├── index.jl      # /users
│   ├── [id].jl       # /users/:id
│   └── [id]/
│       └── posts.jl  # /users/:id/posts
└── docs/
    └── [...slug].jl  # /docs/* (catch-all)""", "neutral")
                ),
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-200 mb-4",
                        "Usage"
                    ),
                    CodeBlock("""# Create router from directory
router = create_router("routes";
    layout = Layout
)

# Handle incoming requests
html, route, params = handle_request(
    router,
    "/users/123"
)

# Access matched parameters
params[:id]  # "123\"""")
                )
            )
        ),

        # Quick Overview: Dynamic Routes
        Section(:class => "py-12 bg-warm-100 dark:bg-warm-800 rounded-lg border border-warm-200 dark:border-warm-900 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Dynamic Routes at a Glance"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 mb-6",
                "Square brackets in filenames create dynamic segments:"
            ),
            Div(:class => "overflow-x-auto",
                Table(:class => "w-full text-left",
                    Thead(
                        Tr(:class => "border-b border-warm-200 dark:border-warm-800",
                            Th(:class => "py-3 px-4 text-warm-600 dark:text-warm-400 font-medium", "File"),
                            Th(:class => "py-3 px-4 text-warm-600 dark:text-warm-400 font-medium", "Matches"),
                            Th(:class => "py-3 px-4 text-warm-600 dark:text-warm-400 font-medium", "Params")
                        )
                    ),
                    Tbody(
                        Tr(:class => "border-b border-warm-200 dark:border-warm-900",
                            Td(:class => "py-3 px-4", Code(:class => "text-accent-700 dark:text-accent-400", "[id].jl")),
                            Td(:class => "py-3 px-4 text-warm-600 dark:text-warm-400", "/users/123"),
                            Td(:class => "py-3 px-4", Code(:class => "text-sm", "params[:id] = \"123\""))
                        ),
                        Tr(:class => "border-b border-warm-200 dark:border-warm-900",
                            Td(:class => "py-3 px-4", Code(:class => "text-accent-700 dark:text-accent-400", "[...slug].jl")),
                            Td(:class => "py-3 px-4 text-warm-600 dark:text-warm-400", "/docs/api/signals"),
                            Td(:class => "py-3 px-4", Code(:class => "text-sm", "params[:slug] = \"api/signals\""))
                        ),
                        Tr(
                            Td(:class => "py-3 px-4", Code(:class => "text-accent-700 dark:text-accent-400", "[category]/[id].jl")),
                            Td(:class => "py-3 px-4 text-warm-600 dark:text-warm-400", "/electronics/42"),
                            Td(:class => "py-3 px-4", Code(:class => "text-sm", ":category, :id"))
                        )
                    )
                )
            )
        ),

        # Quick Overview: Client Navigation
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Client-Side Navigation at a Glance"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 mb-6",
                Code(:class => "text-accent-700 dark:text-accent-400", "NavLink"),
                " provides SPA-style navigation with automatic active link styling:"
            ),
            CodeBlock("""# NavLink with active state styling
Nav(:class => "flex gap-4",
    NavLink("/", "Home";
        class = "text-warm-600",
        active_class = "text-accent-700 font-semibold",
        exact = true  # Only active on exact match
    ),
    NavLink("/users/", "Users";
        class = "text-warm-600",
        active_class = "text-accent-700 font-semibold"
        # Matches /users/ and /users/123
    ),
    NavLink("/about/", "About";
        class = "text-warm-600",
        active_class = "text-accent-700 font-semibold"
    )
)

# How it works:
# 1. Full page load: Layout wraps content (nav + main + footer)
# 2. Click NavLink: Fetch with X-Therapy-Partial header
# 3. Server returns just the route content (no layout)
# 4. Client swaps #page-content, re-hydrates islands
# Result: Nav/footer persist, only content changes"""),
            InfoBox("No Page Reloads",
                "Navigation happens entirely client-side. The server only sends the new page content, " *
                "not the entire HTML document. This makes navigation feel instant."
            )
        ),

        # Quick Overview: Nested Routes
        Section(:class => "py-12 bg-warm-100 dark:bg-warm-800 rounded-lg border border-warm-200 dark:border-warm-900 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Nested Routes at a Glance"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 mb-6",
                "Use ", Code(:class => "text-accent-700 dark:text-accent-400", "_layout.jl"),
                " files and ", Code(:class => "text-accent-700 dark:text-accent-400", "Outlet()"),
                " for nested layouts:"
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-200 mb-4",
                        "_layout.jl File"
                    ),
                    CodeBlock("""# routes/users/_layout.jl
(params) -> Div(:class => "users-section",
    Nav(:class => "sidebar",
        NavLink("/users/", "All Users"),
        NavLink("/users/new", "Create")
    ),
    Main(:class => "content",
        Outlet()  # Child renders here
    )
)""", "neutral")
                ),
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-200 mb-4",
                        "Route Hooks"
                    ),
                    CodeBlock("""# In routes/users/[id].jl
function UserProfile()
    # Reactive access to route params
    params = use_params()
    user_id = params[:id]

    # Query string access
    tab = use_query(:tab, "profile")

    # Current path
    path = use_location()

    Div(H1("User ", user_id),
        P("Tab: ", tab))
end""", "neutral")
                )
            )
        ),

        # Route Hooks Reference
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Route Hooks Reference"
            ),
            Div(:class => "space-y-4",
                HookCard("use_params()", "Get all route parameters as a Dict",
                    "params = use_params()  # Dict(:id => \"123\")"),
                HookCard("use_params(:key)", "Get a specific parameter (or nothing)",
                    "id = use_params(:id)  # \"123\" or nothing"),
                HookCard("use_params(:key, default)", "Get parameter with default",
                    "id = use_params(:id, \"0\")  # \"123\" or \"0\""),
                HookCard("use_query()", "Get all query parameters",
                    "query = use_query()  # Dict(:page => \"2\")"),
                HookCard("use_query(:key, default)", "Get query param with default",
                    "page = use_query(:page, \"1\")"),
                HookCard("use_location()", "Get current path",
                    "path = use_location()  # \"/users/123\"")
            )
        ),

        # The Complete Picture
        Section(:class => "py-12 bg-warm-50 dark:bg-warm-900/30 rounded-lg border border-warm-200 dark:border-warm-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-accent-900 dark:text-accent-200 mb-6",
                "The Complete Picture"
            ),
            Div(:class => "space-y-4 text-accent-800 dark:text-accent-300",
                FlowStep("1", "Define routes as files: routes/users/[id].jl"),
                FlowStep("2", "Create router: create_router(\"routes\"; layout=Layout)"),
                FlowStep("3", "Handle requests: html, _, params = handle_request(router, path)"),
                FlowStep("4", "Navigate with NavLink for SPA experience"),
                FlowStep("5", "Access params reactively with use_params(), use_query()"),
                FlowStep("6", "Build complex UIs with nested layouts and Outlet()")
            ),
            P(:class => "mt-6 text-accent-700 dark:text-accent-400 font-medium",
                "This gives you a modern routing experience: file-based configuration, type-safe parameters, ",
                "SPA navigation, and nested layouts—all in pure Julia."
            )
        ),

    )
end

# Helper Components

function RoutingIconCard(icon, title, description)
    Div(:class => "bg-warm-50 dark:bg-warm-900 rounded-lg border border-warm-200 dark:border-warm-800 p-6 text-center",
        Div(:class => "text-3xl mb-3", icon),
        H3(:class => "text-lg font-serif font-semibold text-warm-800 dark:text-warm-50 mb-2", title),
        P(:class => "text-warm-600 dark:text-warm-400 text-sm", description)
    )
end

function ChapterCard(href, title, code_preview, description)
    A(:href => href,
      :class => "block bg-warm-50 dark:bg-warm-900 rounded-lg border border-warm-200 dark:border-warm-800 p-6 hover:border-accent-400 dark:hover:border-accent-600 transition-colors group",
        H3(:class => "text-xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-2 group-hover:text-accent-700 dark:group-hover:text-accent-400", title),
        Code(:class => "text-sm text-accent-700 dark:text-accent-400", code_preview),
        P(:class => "text-warm-600 dark:text-warm-400 mt-3 text-sm", description)
    )
end

function HookCard(signature, description, example)
    Div(:class => "bg-warm-50 dark:bg-warm-900 rounded-lg border border-warm-200 dark:border-warm-800 p-4",
        Div(:class => "flex items-start justify-between gap-4",
            Div(
                Code(:class => "text-accent-700 dark:text-accent-400 font-semibold", signature),
                P(:class => "text-warm-600 dark:text-warm-400 text-sm mt-1", description)
            ),
            Code(:class => "text-xs text-warm-600 dark:text-warm-600 bg-warm-50 dark:bg-warm-800 px-2 py-1 rounded whitespace-nowrap", example)
        )
    )
end

function CodeBlock(code, style="default")
    bg_class = if style == "emerald"
        "bg-warm-900 dark:bg-warm-950 border-warm-700"
    elseif style == "neutral"
        "bg-warm-800 dark:bg-warm-900 border-warm-600"
    else
        "bg-warm-800 dark:bg-warm-950 border-warm-900"
    end

    Div(:class => "$bg_class rounded border p-6 overflow-x-auto",
        Pre(:class => "text-sm text-warm-50",
            Code(:class => "language-julia", code)
        )
    )
end

function InfoBox(title, content)
    Div(:class => "mt-8 bg-blue-50 dark:bg-blue-950/30 rounded-lg border border-blue-200 dark:border-blue-900 p-6",
        H3(:class => "text-lg font-serif font-semibold text-blue-900 dark:text-blue-200 mb-2", title),
        P(:class => "text-blue-800 dark:text-blue-300", content)
    )
end

function FlowStep(number, text)
    Div(:class => "flex items-start gap-4",
        Span(:class => "flex-shrink-0 w-8 h-8 bg-accent-700 dark:bg-accent-600 text-white rounded-full flex items-center justify-center font-semibold text-sm", number),
        P(:class => "pt-1", text)
    )
end

# Export the page component
RoutingIndex
