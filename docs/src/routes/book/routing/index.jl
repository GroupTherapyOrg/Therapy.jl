# Routing - Part 6 of the Therapy.jl Book
#
# Overview hub for file-based routing, dynamic routes, client navigation, and nested layouts.

function Index()
    BookLayout("/book/routing/",
        # Header
        Div(:class => "py-8 border-b border-neutral-300 dark:border-neutral-800",
            Span(:class => "text-sm text-emerald-700 dark:text-emerald-400 font-medium", "Part 6"),
            H1(:class => "text-4xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mt-2 mb-4",
                "Routing"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 max-w-3xl",
                "Therapy.jl provides a complete routing solution: file-based routing like Next.js, ",
                "dynamic parameters, client-side navigation without page reloads, and nested layouts ",
                "with ", Code(:class => "text-emerald-700 dark:text-emerald-400", "Outlet"), "."
            )
        ),

        # The Routing Story
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "The Routing Story"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "Traditional web frameworks require you to manually configure routes. Therapy.jl takes a ",
                "different approach: your file structure ", Em("is"), " your routing configuration. ",
                "Place a file at ", Code(:class => "text-emerald-700 dark:text-emerald-400", "routes/about.jl"),
                " and you get a ", Code(:class => "text-emerald-700 dark:text-emerald-400", "/about"),
                " route automatically."
            ),
            Div(:class => "grid md:grid-cols-4 gap-6 mt-8",
                FeatureCard("📁", "File-Based", "routes/about.jl → /about"),
                FeatureCard("🔗", "Dynamic", "[id].jl → /users/:id"),
                FeatureCard("⚡", "SPA", "No page reloads"),
                FeatureCard("📦", "Nested", "Layouts + Outlet")
            ),
            P(:class => "text-neutral-600 dark:text-neutral-400 mt-6",
                "Combined with reactive route hooks like ", Code(:class => "text-emerald-700 dark:text-emerald-400", "use_params()"),
                " and ", Code(:class => "text-emerald-700 dark:text-emerald-400", "use_query()"),
                ", you get a complete navigation solution."
            )
        ),

        # Chapters in This Section
        Section(:class => "py-12 bg-neutral-50 dark:bg-neutral-900 rounded-lg border border-neutral-300 dark:border-neutral-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
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
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "File-Based Routing at a Glance"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "Your file structure directly maps to URL paths:"
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-neutral-800 dark:text-neutral-200 mb-4",
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
                    H3(:class => "text-lg font-serif font-semibold text-neutral-800 dark:text-neutral-200 mb-4",
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
        Section(:class => "py-12 bg-neutral-50 dark:bg-neutral-900 rounded-lg border border-neutral-300 dark:border-neutral-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Dynamic Routes at a Glance"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "Square brackets in filenames create dynamic segments:"
            ),
            Div(:class => "overflow-x-auto",
                Table(:class => "w-full text-left",
                    Thead(
                        Tr(:class => "border-b border-neutral-300 dark:border-neutral-700",
                            Th(:class => "py-3 px-4 text-neutral-600 dark:text-neutral-400 font-medium", "File"),
                            Th(:class => "py-3 px-4 text-neutral-600 dark:text-neutral-400 font-medium", "Matches"),
                            Th(:class => "py-3 px-4 text-neutral-600 dark:text-neutral-400 font-medium", "Params")
                        )
                    ),
                    Tbody(
                        Tr(:class => "border-b border-neutral-200 dark:border-neutral-800",
                            Td(:class => "py-3 px-4", Code(:class => "text-emerald-700 dark:text-emerald-400", "[id].jl")),
                            Td(:class => "py-3 px-4 text-neutral-600 dark:text-neutral-400", "/users/123"),
                            Td(:class => "py-3 px-4", Code(:class => "text-sm", "params[:id] = \"123\""))
                        ),
                        Tr(:class => "border-b border-neutral-200 dark:border-neutral-800",
                            Td(:class => "py-3 px-4", Code(:class => "text-emerald-700 dark:text-emerald-400", "[...slug].jl")),
                            Td(:class => "py-3 px-4 text-neutral-600 dark:text-neutral-400", "/docs/api/signals"),
                            Td(:class => "py-3 px-4", Code(:class => "text-sm", "params[:slug] = \"api/signals\""))
                        ),
                        Tr(
                            Td(:class => "py-3 px-4", Code(:class => "text-emerald-700 dark:text-emerald-400", "[category]/[id].jl")),
                            Td(:class => "py-3 px-4 text-neutral-600 dark:text-neutral-400", "/electronics/42"),
                            Td(:class => "py-3 px-4", Code(:class => "text-sm", ":category, :id"))
                        )
                    )
                )
            )
        ),

        # Quick Overview: Client Navigation
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Client-Side Navigation at a Glance"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                Code(:class => "text-emerald-700 dark:text-emerald-400", "NavLink"),
                " provides SPA-style navigation with automatic active link styling:"
            ),
            CodeBlock("""# NavLink with active state styling
Nav(:class => "flex gap-4",
    NavLink("/", "Home";
        class = "text-neutral-600",
        active_class = "text-emerald-700 font-semibold",
        exact = true  # Only active on exact match
    ),
    NavLink("/users/", "Users";
        class = "text-neutral-600",
        active_class = "text-emerald-700 font-semibold"
        # Matches /users/ and /users/123
    ),
    NavLink("/about/", "About";
        class = "text-neutral-600",
        active_class = "text-emerald-700 font-semibold"
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
        Section(:class => "py-12 bg-neutral-50 dark:bg-neutral-900 rounded-lg border border-neutral-300 dark:border-neutral-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Nested Routes at a Glance"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "Use ", Code(:class => "text-emerald-700 dark:text-emerald-400", "_layout.jl"),
                " files and ", Code(:class => "text-emerald-700 dark:text-emerald-400", "Outlet()"),
                " for nested layouts:"
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-neutral-800 dark:text-neutral-200 mb-4",
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
                    H3(:class => "text-lg font-serif font-semibold text-neutral-800 dark:text-neutral-200 mb-4",
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
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
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
        Section(:class => "py-12 bg-emerald-50 dark:bg-emerald-950/30 rounded-lg border border-emerald-200 dark:border-emerald-900 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-emerald-900 dark:text-emerald-200 mb-6",
                "The Complete Picture"
            ),
            Div(:class => "space-y-4 text-emerald-800 dark:text-emerald-300",
                FlowStep("1", "Define routes as files: routes/users/[id].jl"),
                FlowStep("2", "Create router: create_router(\"routes\"; layout=Layout)"),
                FlowStep("3", "Handle requests: html, _, params = handle_request(router, path)"),
                FlowStep("4", "Navigate with NavLink for SPA experience"),
                FlowStep("5", "Access params reactively with use_params(), use_query()"),
                FlowStep("6", "Build complex UIs with nested layouts and Outlet()")
            ),
            P(:class => "mt-6 text-emerald-700 dark:text-emerald-400 font-medium",
                "This gives you a modern routing experience: file-based configuration, type-safe parameters, ",
                "SPA navigation, and nested layouts—all in pure Julia."
            )
        ),

    )
end

# Helper Components

function FeatureCard(icon, title, description)
    Div(:class => "bg-white dark:bg-neutral-800 rounded-lg border border-neutral-300 dark:border-neutral-700 p-6 text-center",
        Div(:class => "text-3xl mb-3", icon),
        H3(:class => "text-lg font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-2", title),
        P(:class => "text-neutral-600 dark:text-neutral-400 text-sm", description)
    )
end

function ChapterCard(href, title, code_preview, description)
    A(:href => href,
      :class => "block bg-white dark:bg-neutral-800 rounded-lg border border-neutral-300 dark:border-neutral-700 p-6 hover:border-emerald-400 dark:hover:border-emerald-600 transition-colors group",
        H3(:class => "text-xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-2 group-hover:text-emerald-700 dark:group-hover:text-emerald-400", title),
        Code(:class => "text-sm text-emerald-700 dark:text-emerald-400", code_preview),
        P(:class => "text-neutral-600 dark:text-neutral-400 mt-3 text-sm", description)
    )
end

function HookCard(signature, description, example)
    Div(:class => "bg-white dark:bg-neutral-800 rounded-lg border border-neutral-300 dark:border-neutral-700 p-4",
        Div(:class => "flex items-start justify-between gap-4",
            Div(
                Code(:class => "text-emerald-700 dark:text-emerald-400 font-semibold", signature),
                P(:class => "text-neutral-600 dark:text-neutral-400 text-sm mt-1", description)
            ),
            Code(:class => "text-xs text-neutral-500 dark:text-neutral-500 bg-neutral-100 dark:bg-neutral-900 px-2 py-1 rounded whitespace-nowrap", example)
        )
    )
end

function CodeBlock(code, style="default")
    bg_class = if style == "emerald"
        "bg-emerald-900 dark:bg-emerald-950 border-emerald-700"
    elseif style == "neutral"
        "bg-neutral-700 dark:bg-neutral-800 border-neutral-600"
    else
        "bg-neutral-900 dark:bg-neutral-950 border-neutral-800"
    end

    Div(:class => "$bg_class rounded border p-6 overflow-x-auto",
        Pre(:class => "text-sm text-neutral-100",
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
        Span(:class => "flex-shrink-0 w-8 h-8 bg-emerald-700 dark:bg-emerald-600 text-white rounded-full flex items-center justify-center font-semibold text-sm", number),
        P(:class => "pt-1", text)
    )
end

# Export the page component
Index
