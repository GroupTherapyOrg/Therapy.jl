# Routing - Part 6 of the Therapy.jl Book
#
# Overview hub for file-based routing, dynamic routes, client navigation, and nested layouts.

import Suite

function RoutingIndex()
    BookLayout("/book/routing/",
        # Header
        Div(:class => "py-8 border-b border-warm-200 dark:border-warm-700",
            Suite.Badge(variant="outline", "Part 6"),
            H1(:class => "text-4xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-2 mb-4",
                "Routing"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 max-w-3xl",
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
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Traditional web frameworks require you to manually configure routes. Therapy.jl takes a ",
                "different approach: your file structure ", Em("is"), " your routing configuration. ",
                "Place a file at ", Code(:class => "text-accent-700 dark:text-accent-400", "routes/about.jl"),
                " and you get a ", Code(:class => "text-accent-700 dark:text-accent-400", "/about"),
                " route automatically."
            ),
            Div(:class => "grid md:grid-cols-4 gap-6 mt-8",
                Suite.Card(class="text-center",
                    Suite.CardContent(class="pt-6",
                        Div(:class => "text-3xl mb-3", "📁"),
                        H3(:class => "text-lg font-serif font-semibold text-warm-800 dark:text-warm-50 mb-2", "File-Based"),
                        P(:class => "text-warm-600 dark:text-warm-400 text-sm", "routes/about.jl → /about")
                    )
                ),
                Suite.Card(class="text-center",
                    Suite.CardContent(class="pt-6",
                        Div(:class => "text-3xl mb-3", "🔗"),
                        H3(:class => "text-lg font-serif font-semibold text-warm-800 dark:text-warm-50 mb-2", "Dynamic"),
                        P(:class => "text-warm-600 dark:text-warm-400 text-sm", "[id].jl → /users/:id")
                    )
                ),
                Suite.Card(class="text-center",
                    Suite.CardContent(class="pt-6",
                        Div(:class => "text-3xl mb-3", "⚡"),
                        H3(:class => "text-lg font-serif font-semibold text-warm-800 dark:text-warm-50 mb-2", "SPA"),
                        P(:class => "text-warm-600 dark:text-warm-400 text-sm", "No page reloads")
                    )
                ),
                Suite.Card(class="text-center",
                    Suite.CardContent(class="pt-6",
                        Div(:class => "text-3xl mb-3", "📦"),
                        H3(:class => "text-lg font-serif font-semibold text-warm-800 dark:text-warm-50 mb-2", "Nested"),
                        P(:class => "text-warm-600 dark:text-warm-400 text-sm", "Layouts + Outlet")
                    )
                )
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "Combined with reactive route hooks like ", Code(:class => "text-accent-700 dark:text-accent-400", "use_params()"),
                " and ", Code(:class => "text-accent-700 dark:text-accent-400", "use_query()"),
                ", you get a complete navigation solution."
            )
        ),

        Suite.Separator(),

        # Chapters in This Section
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Chapters in This Section"
            ),
            Div(:class => "grid md:grid-cols-2 gap-6",
                A(:href => "./file-routing", :class => "block group",
                    Suite.Card(class="h-full transition-colors hover:border-accent-400 dark:hover:border-accent-600",
                        Suite.CardHeader(
                            Suite.CardTitle(:class => "font-serif group-hover:text-accent-700 dark:group-hover:text-accent-400", "File-Based Routing"),
                            Suite.CardDescription(
                                Code(:class => "text-sm text-accent-700 dark:text-accent-400", "create_router()")
                            )
                        ),
                        Suite.CardContent(
                            P(:class => "text-warm-600 dark:text-warm-400 text-sm", "Map your directory structure directly to URL paths. No configuration needed.")
                        )
                    )
                ),
                A(:href => "./dynamic-routes", :class => "block group",
                    Suite.Card(class="h-full transition-colors hover:border-accent-400 dark:hover:border-accent-600",
                        Suite.CardHeader(
                            Suite.CardTitle(:class => "font-serif group-hover:text-accent-700 dark:group-hover:text-accent-400", "Dynamic Routes"),
                            Suite.CardDescription(
                                Code(:class => "text-sm text-accent-700 dark:text-accent-400", "[id].jl  [...slug].jl")
                            )
                        ),
                        Suite.CardContent(
                            P(:class => "text-warm-600 dark:text-warm-400 text-sm", "Handle dynamic parameters and catch-all routes for flexible URL patterns.")
                        )
                    )
                ),
                A(:href => "./client-navigation", :class => "block group",
                    Suite.Card(class="h-full transition-colors hover:border-accent-400 dark:hover:border-accent-600",
                        Suite.CardHeader(
                            Suite.CardTitle(:class => "font-serif group-hover:text-accent-700 dark:group-hover:text-accent-400", "Client-Side Navigation"),
                            Suite.CardDescription(
                                Code(:class => "text-sm text-accent-700 dark:text-accent-400", "NavLink()")
                            )
                        ),
                        Suite.CardContent(
                            P(:class => "text-warm-600 dark:text-warm-400 text-sm", "SPA-style navigation with active link styling and no page reloads.")
                        )
                    )
                ),
                A(:href => "./nested-routes", :class => "block group",
                    Suite.Card(class="h-full transition-colors hover:border-accent-400 dark:hover:border-accent-600",
                        Suite.CardHeader(
                            Suite.CardTitle(:class => "font-serif group-hover:text-accent-700 dark:group-hover:text-accent-400", "Nested Routes & Hooks"),
                            Suite.CardDescription(
                                Code(:class => "text-sm text-accent-700 dark:text-accent-400", "Outlet() / use_params()")
                            )
                        ),
                        Suite.CardContent(
                            P(:class => "text-warm-600 dark:text-warm-400 text-sm", "Build complex layouts with nested routing and reactive route access.")
                        )
                    )
                )
            )
        ),

        Suite.Separator(),

        # Quick Overview: File-Based Routing
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "File-Based Routing at a Glance"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Your file structure directly maps to URL paths:"
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-300 mb-4",
                        "File Structure"
                    ),
                    Suite.CodeBlock(
                        code="""routes/
├── index.jl          # /
├── about.jl          # /about
├── users/
│   ├── index.jl      # /users
│   ├── [id].jl       # /users/:id
│   └── [id]/
│       └── posts.jl  # /users/:id/posts
└── docs/
    └── [...slug].jl  # /docs/* (catch-all)""",
                        language="",
                        show_copy=false
                    )
                ),
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-300 mb-4",
                        "Usage"
                    ),
                    Suite.CodeBlock(
                        code="""# Create router from directory
router = create_router("routes";
    layout = Layout
)

# Handle incoming requests
html, route, params = handle_request(
    router,
    "/users/123"
)

# Access matched parameters
params[:id]  # "123\"""",
                        language="julia"
                    )
                )
            )
        ),

        Suite.Separator(),

        # Quick Overview: Dynamic Routes
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Dynamic Routes at a Glance"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Square brackets in filenames create dynamic segments:"
            ),
            Suite.Table(
                Suite.TableHeader(
                    Suite.TableRow(
                        Suite.TableHead("File"),
                        Suite.TableHead("Matches"),
                        Suite.TableHead("Params")
                    )
                ),
                Suite.TableBody(
                    Suite.TableRow(
                        Suite.TableCell(Code(:class => "text-accent-700 dark:text-accent-400", "[id].jl")),
                        Suite.TableCell("/users/123"),
                        Suite.TableCell(Code(:class => "text-sm", "params[:id] = \"123\""))
                    ),
                    Suite.TableRow(
                        Suite.TableCell(Code(:class => "text-accent-700 dark:text-accent-400", "[...slug].jl")),
                        Suite.TableCell("/docs/api/signals"),
                        Suite.TableCell(Code(:class => "text-sm", "params[:slug] = \"api/signals\""))
                    ),
                    Suite.TableRow(
                        Suite.TableCell(Code(:class => "text-accent-700 dark:text-accent-400", "[category]/[id].jl")),
                        Suite.TableCell("/electronics/42"),
                        Suite.TableCell(Code(:class => "text-sm", ":category, :id"))
                    )
                )
            )
        ),

        Suite.Separator(),

        # Quick Overview: Client Navigation
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Client-Side Navigation at a Glance"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                Code(:class => "text-accent-700 dark:text-accent-400", "NavLink"),
                " provides SPA-style navigation with automatic active link styling:"
            ),
            Suite.CodeBlock(
                code="""# NavLink with active state styling
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
# Result: Nav/footer persist, only content changes""",
                language="julia"
            ),
            Suite.Alert(class="mt-8",
                Suite.AlertTitle("No Page Reloads"),
                Suite.AlertDescription(
                    "Navigation happens entirely client-side. The server only sends the new page content, " *
                    "not the entire HTML document. This makes navigation feel instant."
                )
            )
        ),

        Suite.Separator(),

        # Quick Overview: Nested Routes
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Nested Routes at a Glance"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Use ", Code(:class => "text-accent-700 dark:text-accent-400", "_layout.jl"),
                " files and ", Code(:class => "text-accent-700 dark:text-accent-400", "Outlet()"),
                " for nested layouts:"
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-300 mb-4",
                        "_layout.jl File"
                    ),
                    Suite.CodeBlock(
                        code="""# routes/users/_layout.jl
(params) -> Div(:class => "users-section",
    Nav(:class => "sidebar",
        NavLink("/users/", "All Users"),
        NavLink("/users/new", "Create")
    ),
    Main(:class => "content",
        Outlet()  # Child renders here
    )
)""",
                        language="julia"
                    )
                ),
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-300 mb-4",
                        "Route Hooks"
                    ),
                    Suite.CodeBlock(
                        code="""# In routes/users/[id].jl
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
end""",
                        language="julia"
                    )
                )
            )
        ),

        Suite.Separator(),

        # Route Hooks Reference
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Route Hooks Reference"
            ),
            Div(:class => "space-y-4",
                Suite.Card(class="p-0",
                    Suite.CardContent(class="p-4",
                        Div(:class => "flex items-start justify-between gap-4",
                            Div(
                                Code(:class => "text-accent-700 dark:text-accent-400 font-semibold", "use_params()"),
                                P(:class => "text-warm-600 dark:text-warm-400 text-sm mt-1", "Get all route parameters as a Dict")
                            ),
                            Code(:class => "text-xs text-warm-500 dark:text-warm-500 px-2 py-1 rounded whitespace-nowrap", "params = use_params()  # Dict(:id => \"123\")")
                        )
                    )
                ),
                Suite.Card(class="p-0",
                    Suite.CardContent(class="p-4",
                        Div(:class => "flex items-start justify-between gap-4",
                            Div(
                                Code(:class => "text-accent-700 dark:text-accent-400 font-semibold", "use_params(:key)"),
                                P(:class => "text-warm-600 dark:text-warm-400 text-sm mt-1", "Get a specific parameter (or nothing)")
                            ),
                            Code(:class => "text-xs text-warm-500 dark:text-warm-500 px-2 py-1 rounded whitespace-nowrap", "id = use_params(:id)  # \"123\" or nothing")
                        )
                    )
                ),
                Suite.Card(class="p-0",
                    Suite.CardContent(class="p-4",
                        Div(:class => "flex items-start justify-between gap-4",
                            Div(
                                Code(:class => "text-accent-700 dark:text-accent-400 font-semibold", "use_params(:key, default)"),
                                P(:class => "text-warm-600 dark:text-warm-400 text-sm mt-1", "Get parameter with default")
                            ),
                            Code(:class => "text-xs text-warm-500 dark:text-warm-500 px-2 py-1 rounded whitespace-nowrap", "id = use_params(:id, \"0\")  # \"123\" or \"0\"")
                        )
                    )
                ),
                Suite.Card(class="p-0",
                    Suite.CardContent(class="p-4",
                        Div(:class => "flex items-start justify-between gap-4",
                            Div(
                                Code(:class => "text-accent-700 dark:text-accent-400 font-semibold", "use_query()"),
                                P(:class => "text-warm-600 dark:text-warm-400 text-sm mt-1", "Get all query parameters")
                            ),
                            Code(:class => "text-xs text-warm-500 dark:text-warm-500 px-2 py-1 rounded whitespace-nowrap", "query = use_query()  # Dict(:page => \"2\")")
                        )
                    )
                ),
                Suite.Card(class="p-0",
                    Suite.CardContent(class="p-4",
                        Div(:class => "flex items-start justify-between gap-4",
                            Div(
                                Code(:class => "text-accent-700 dark:text-accent-400 font-semibold", "use_query(:key, default)"),
                                P(:class => "text-warm-600 dark:text-warm-400 text-sm mt-1", "Get query param with default")
                            ),
                            Code(:class => "text-xs text-warm-500 dark:text-warm-500 px-2 py-1 rounded whitespace-nowrap", "page = use_query(:page, \"1\")")
                        )
                    )
                ),
                Suite.Card(class="p-0",
                    Suite.CardContent(class="p-4",
                        Div(:class => "flex items-start justify-between gap-4",
                            Div(
                                Code(:class => "text-accent-700 dark:text-accent-400 font-semibold", "use_location()"),
                                P(:class => "text-warm-600 dark:text-warm-400 text-sm mt-1", "Get current path")
                            ),
                            Code(:class => "text-xs text-warm-500 dark:text-warm-500 px-2 py-1 rounded whitespace-nowrap", "path = use_location()  # \"/users/123\"")
                        )
                    )
                )
            )
        ),

        Suite.Separator(),

        # The Complete Picture
        Suite.Alert(class="mt-12",
            Suite.AlertTitle("The Complete Picture"),
            Suite.AlertDescription(
                Div(:class => "space-y-4 mt-4",
                    Div(:class => "flex items-start gap-4",
                        Suite.Badge(variant="default", "1"),
                        P(:class => "pt-0.5", "Define routes as files: routes/users/[id].jl")
                    ),
                    Div(:class => "flex items-start gap-4",
                        Suite.Badge(variant="default", "2"),
                        P(:class => "pt-0.5", "Create router: create_router(\"routes\"; layout=Layout)")
                    ),
                    Div(:class => "flex items-start gap-4",
                        Suite.Badge(variant="default", "3"),
                        P(:class => "pt-0.5", "Handle requests: html, _, params = handle_request(router, path)")
                    ),
                    Div(:class => "flex items-start gap-4",
                        Suite.Badge(variant="default", "4"),
                        P(:class => "pt-0.5", "Navigate with NavLink for SPA experience")
                    ),
                    Div(:class => "flex items-start gap-4",
                        Suite.Badge(variant="default", "5"),
                        P(:class => "pt-0.5", "Access params reactively with use_params(), use_query()")
                    ),
                    Div(:class => "flex items-start gap-4",
                        Suite.Badge(variant="default", "6"),
                        P(:class => "pt-0.5", "Build complex UIs with nested layouts and Outlet()")
                    ),
                    P(:class => "mt-6 font-medium",
                        "This gives you a modern routing experience: file-based configuration, type-safe parameters, ",
                        "SPA navigation, and nested layouts—all in pure Julia."
                    )
                )
            )
        ),

    )
end

# Export the page component
RoutingIndex
