# Nested Routes & Hooks - Chapter 4 of Part 6
#
# Building complex layouts with nested routing, Outlet, and reactive route hooks.

import Suite

function NestedRoutes()
    BookLayout("/book/routing/nested-routes/",
        # Header
        Div(:class => "py-8 border-b border-warm-200 dark:border-warm-700",
            Suite.Badge(variant="outline", "Part 6 · Chapter 4"),
            H1(:class => "text-4xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-2 mb-4",
                "Nested Routes & Hooks"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 max-w-3xl",
                "Build complex layouts with nested routing and access route parameters reactively. ",
                "Combine ", Code(:class => "text-accent-700 dark:text-accent-400", "_layout.jl"),
                ", ", Code(:class => "text-accent-700 dark:text-accent-400", "Outlet()"),
                ", and route hooks for powerful routing patterns."
            )
        ),

        # Why Nested Routes?
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Why Nested Routes?"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Many UIs have layouts that persist across groups of pages: dashboards with sidebars, ",
                "admin panels with navigation, documentation with table of contents. Nested routes let ",
                "you define these layouts once and reuse them across all child routes."
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Suite.Card(
                    Suite.CardHeader(
                        Suite.CardTitle("Without Nested Routes")
                    ),
                    Suite.CardContent(
                        Suite.CodeBlock(code="""# Every page repeats the layout
function DashboardOverview()
    Div(:class => "flex",
        DashboardSidebar(),  # Repeated
        Main(\"Overview content\")
    )
end

function DashboardAnalytics()
    Div(:class => "flex",
        DashboardSidebar(),  # Repeated
        Main(\"Analytics content\")
    )
end

function DashboardSettings()
    Div(:class => "flex",
        DashboardSidebar(),  # Repeated
        Main(\"Settings content\")
    )
end""", language="julia", show_copy=false)
                    )
                ),
                Suite.Card(
                    Suite.CardHeader(
                        Suite.CardTitle("With Nested Routes")
                    ),
                    Suite.CardContent(
                        Suite.CodeBlock(code="""# Layout defined once
# routes/dashboard/_layout.jl
(params) -> Div(:class => \"flex\",
    DashboardSidebar(),
    Main(Outlet())  # Child content here
)

# Child routes are simple
# routes/dashboard/index.jl
() -> P(\"Overview content\")

# routes/dashboard/analytics.jl
() -> P(\"Analytics content\")

# routes/dashboard/settings.jl
() -> P(\"Settings content\")""", language="julia")
                    )
                )
            ),
            Suite.Alert(class="mt-8",
                Suite.AlertTitle("DRY Principle"),
                Suite.AlertDescription(
                    "Nested routes follow the DRY (Don't Repeat Yourself) principle. Changes to the " *
                    "sidebar or layout only need to happen in one place."
                )
            )
        ),

        Suite.Separator(),

        # _layout.jl Files
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Layout Files: _layout.jl"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Create a ", Code(:class => "text-accent-700 dark:text-accent-400", "_layout.jl"),
                " file in any directory to wrap all routes in that directory (and subdirectories) ",
                "with a layout component."
            ),
            Suite.CodeBlock(code="""# Directory structure
routes/
├── _layout.jl           # Global layout (wraps everything)
├── index.jl             # / (wrapped by global layout)
├── about.jl             # /about (wrapped by global layout)
└── dashboard/
    ├── _layout.jl       # Dashboard layout (nested inside global)
    ├── index.jl         # /dashboard (wrapped by both layouts)
    ├── analytics.jl     # /dashboard/analytics (wrapped by both)
    └── settings/
        ├── _layout.jl   # Settings sub-layout (3 levels deep!)
        ├── index.jl     # /dashboard/settings
        └── profile.jl   # /dashboard/settings/profile""", language="julia"),
            H3(:class => "text-xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-8 mb-4",
                "Layout File Structure"
            ),
            Suite.CodeBlock(code="""# routes/dashboard/_layout.jl

# Layouts receive params just like route files
(params) -> begin
    # You can use params in the layout
    Div(:class => "min-h-screen flex",
        # Sidebar navigation
        Aside(:class => "w-64 bg-warm-50 dark:bg-warm-900 p-4",
            H2(:class => "text-lg font-semibold mb-4", "Dashboard"),
            Nav(:class => "space-y-2",
                NavLink("/dashboard/", "Overview";
                    class = "block px-3 py-2 rounded",
                    active_class = "bg-warm-100 text-accent-800",
                    exact = true
                ),
                NavLink("/dashboard/analytics/", "Analytics";
                    class = "block px-3 py-2 rounded",
                    active_class = "bg-warm-100 text-accent-800"
                ),
                NavLink("/dashboard/settings/", "Settings";
                    class = "block px-3 py-2 rounded",
                    active_class = "bg-warm-100 text-accent-800"
                )
            )
        ),

        # Main content area
        Main(:class => "flex-1 p-8",
            Outlet()  # ← Child routes render here
        )
    )
end""", language="julia", show_copy=false)
        ),

        Suite.Separator(),

        # Outlet Component
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "The Outlet Component"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                Code(:class => "text-accent-700 dark:text-accent-400", "Outlet()"),
                " is a placeholder that renders the matched child route. Think of it as a slot ",
                "where nested content appears."
            ),
            Suite.CodeBlock(code="""# Basic usage
Outlet()

# With a fallback (shown when no child route matches)
Outlet(fallback = P("Select an item from the menu"))

# With a function fallback
Outlet(fallback = () -> Div(:class => "text-center py-12",
    P("Nothing selected"),
    P(:class => "text-sm text-warm-600", "Choose an option from the sidebar")
))""", language="julia"),
            H3(:class => "text-xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-8 mb-4",
                "Outlet Nesting"
            ),
            Suite.CodeBlock(code="""# Layouts can be nested to any depth

# routes/_layout.jl (Level 1)
(params) -> BookLayout(
    Header(Nav(\"Global nav\")),
    Outlet(),  # Level 2 layouts and routes go here
    Footer()
)

# routes/dashboard/_layout.jl (Level 2)
(params) -> Div(:class => \"flex\",
    DashboardSidebar(),
    Outlet()   # Level 3 routes go here
)

# routes/dashboard/settings/_layout.jl (Level 3)
(params) -> Div(
    SettingsTabs(),
    Outlet()   # Final content goes here
)

# routes/dashboard/settings/profile.jl (Content)
# Rendered inside: Global → Dashboard → Settings layouts
() -> Form(
    H1(\"Profile Settings\"),
    # ...
)""", language="julia", show_copy=false)
        ),

        Suite.Separator(),

        # Route Hooks
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Route Hooks"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Access route information reactively from any component using these hooks:"
            ),

            # use_params
            Div(:class => "mb-8",
                H3(:class => "text-xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-4",
                    "use_params() — Route Parameters"
                ),
                Suite.CodeBlock(code="""# Get all params as a Dict
function UserProfile()
    params = use_params()

    user_id = params[:id]
    Div(H1(\"User \", user_id))
end

# Get a specific param (returns Union{String, Nothing})
function UserProfile()
    user_id = use_params(:id)

    if user_id === nothing
        return P(\"No user selected\")
    end

    Div(H1(\"User \", user_id))
end

# Get a param with default value
function UserProfile()
    user_id = use_params(:id, \"unknown\")
    Div(H1(\"User \", user_id))
end""", language="julia")
            ),

            # use_query
            Div(:class => "mb-8",
                H3(:class => "text-xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-4",
                    "use_query() — Query String Parameters"
                ),
                Suite.CodeBlock(code="""# URL: /search?q=therapy&page=2&sort=date

function SearchPage()
    # Get all query params
    query = use_query()
    # => Dict(:q => \"therapy\", :page => \"2\", :sort => \"date\")

    # Get specific param
    search_term = use_query(:q)          # \"therapy\"
    page = use_query(:page, \"1\")        # \"2\"
    sort = use_query(:sort, \"relevance\") # \"date\"

    Div(
        H1(\"Search: \", search_term),
        P(\"Page \", page, \", sorted by \", sort),
        SearchResults(q = search_term, page = parse(Int, page))
    )
end""", language="julia", show_copy=false)
            ),

            # use_location
            Div(
                H3(:class => "text-xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-4",
                    "use_location() — Current Path"
                ),
                Suite.CodeBlock(code="""function Breadcrumb()
    path = use_location()  # \"/dashboard/settings/profile\"

    # Split into segments
    segments = filter(!isempty, split(path, \"/\"))
    # => [\"dashboard\", \"settings\", \"profile\"]

    Nav(:class => \"flex items-center gap-2 text-sm\",
        A(:href => \"/\", \"Home\"),
        For(() -> segments) do (i, segment)
            path_so_far = \"/\" * join(segments[1:i], \"/\") * \"/\"
            BookLayout(
                Span(\"/\"),
                A(:href => path_so_far, titlecase(segment))
            )
        end
    )
end""", language="julia", show_copy=false)
            )
        ),

        Suite.Separator(),

        # Programmatic Nested Routes
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Programmatic Nested Routes"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "For cases where file-based routing doesn't fit, you can define nested routes programmatically:"
            ),
            Suite.CodeBlock(code="""using Therapy

# Define route hierarchy with NestedRoute
routes = [
    NestedRoute(\"/users\", UsersLayout, children = [
        NestedRoute(\"\", UsersIndex),           # /users (empty = index)
        NestedRoute(\"new\", NewUserForm),       # /users/new
        NestedRoute(\":id\", UserLayout, children = [
            NestedRoute(\"\", UserProfile),      # /users/:id
            NestedRoute(\"posts\", UserPosts),   # /users/:id/posts
            NestedRoute(\"settings\", UserSettings)  # /users/:id/settings
        ])
    ])
]

# Match a path
matched = match_nested_route(routes, \"/users/123/posts\")
# => [(UsersLayout, Dict()), (UserLayout, Dict(:id => \"123\")), (UserPosts, Dict())]

# Render with nested layouts
html = render_nested_routes(matched)""", language="julia"),
            H3(:class => "text-xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-8 mb-4",
                "NestedRoute Struct"
            ),
            Suite.CodeBlock(code="""# NestedRoute constructor
NestedRoute(
    path,           # String: path segment (\":id\" for dynamic)
    component;      # Function: component to render
    children = []   # Vector{NestedRoute}: child routes
)

# Examples
NestedRoute(\"about\", AboutPage)              # Static: /about
NestedRoute(\":id\", UserPage)                 # Dynamic: /:id
NestedRoute(\"\", IndexPage)                   # Index: matches parent exactly
NestedRoute(\"*\", NotFoundPage)               # Catch-all""", language="julia", show_copy=false)
        ),

        Suite.Separator(),

        # Common Patterns
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Common Patterns"
            ),
            H3(:class => "text-xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-4",
                "Admin Panel"
            ),
            Suite.CodeBlock(code="""# routes/admin/_layout.jl
(params) -> begin
    # Check authentication
    user = get_current_user()
    if !user.is_admin
        return redirect(\"/login\")
    end

    Div(:class => \"min-h-screen flex\",
        # Admin sidebar
        AdminSidebar(),

        # Content area with header
        Div(:class => \"flex-1 flex flex-col\",
            AdminHeader(user = user),
            Main(:class => \"flex-1 p-6 bg-warm-100\",
                Outlet()
            )
        )
    )
end""", language="julia"),
            H3(:class => "text-xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-8 mb-4",
                "Master-Detail View"
            ),
            Suite.CodeBlock(code="""# routes/inbox/_layout.jl
(params) -> Div(:class => \"flex h-screen\",
    # Message list (always visible)
    Aside(:class => \"w-80 border-r overflow-y-auto\",
        MessageList()
    ),

    # Selected message (or placeholder)
    Main(:class => \"flex-1\",
        Outlet(fallback = () -> Div(:class => \"h-full flex items-center justify-center\",
            P(:class => \"text-warm-600\", \"Select a message to read\")
        ))
    )
)

# routes/inbox/[id].jl
(params) -> begin
    message = fetch_message(params[:id])
    MessageDetail(message = message)
end""", language="julia", show_copy=false),
            H3(:class => "text-xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-8 mb-4",
                "Tabbed Interface"
            ),
            Suite.CodeBlock(code="""# routes/account/_layout.jl
(params) -> Div(:class => \"container mx-auto py-8\",
    H1(:class => \"text-2xl font-bold mb-6\", \"Account Settings\"),

    # Tab navigation
    Nav(:class => \"border-b mb-6\",
        Div(:class => \"flex gap-4 -mb-px\",
            TabLink(\"/account/profile/\", \"Profile\"),
            TabLink(\"/account/security/\", \"Security\"),
            TabLink(\"/account/billing/\", \"Billing\"),
            TabLink(\"/account/notifications/\", \"Notifications\")
        )
    ),

    # Tab content
    Outlet()
)

function TabLink(href, label)
    NavLink(href, label;
        class = \"py-2 px-4 border-b-2 border-transparent\",
        active_class = \"border-accent-500 text-accent-700\"
    )
end""", language="julia", show_copy=false)
        ),

        Suite.Separator(),

        # Key Takeaways
        Suite.Alert(class="mt-12",
            Suite.AlertTitle("Key Takeaways"),
            Suite.AlertDescription(
                Ul(:class => "space-y-3 mt-2",
                    Li(Strong("_layout.jl"), " — Wraps all routes in the same directory"),
                    Li(Strong("Outlet()"), " — Placeholder where child content renders"),
                    Li(Strong("Nesting"), " — Layouts can be nested to any depth"),
                    Li(Strong("use_params()"), " — Access route parameters reactively"),
                    Li(Strong("use_query()"), " — Access query string parameters"),
                    Li(Strong("use_location()"), " — Get current path"),
                    Li(Strong("NestedRoute"), " — Programmatic route definition")
                )
            )
        ),

    )
end

# Export the page component
NestedRoutes
