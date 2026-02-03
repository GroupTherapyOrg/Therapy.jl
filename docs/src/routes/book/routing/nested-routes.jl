# Nested Routes & Hooks - Chapter 4 of Part 6
#
# Building complex layouts with nested routing, Outlet, and reactive route hooks.

function NestedRoutes()
    BookLayout(
        # Header
        Div(:class => "py-8 border-b border-neutral-300 dark:border-neutral-800",
            Span(:class => "text-sm text-emerald-700 dark:text-emerald-400 font-medium", "Part 6 · Chapter 4"),
            H1(:class => "text-4xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mt-2 mb-4",
                "Nested Routes & Hooks"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 max-w-3xl",
                "Build complex layouts with nested routing and access route parameters reactively. ",
                "Combine ", Code(:class => "text-emerald-700 dark:text-emerald-400", "_layout.jl"),
                ", ", Code(:class => "text-emerald-700 dark:text-emerald-400", "Outlet()"),
                ", and route hooks for powerful routing patterns."
            )
        ),

        # Why Nested Routes?
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Why Nested Routes?"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "Many UIs have layouts that persist across groups of pages: dashboards with sidebars, ",
                "admin panels with navigation, documentation with table of contents. Nested routes let ",
                "you define these layouts once and reuse them across all child routes."
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(:class => "bg-white dark:bg-neutral-800 rounded-lg border border-neutral-300 dark:border-neutral-700 p-6",
                    H3(:class => "text-lg font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-4",
                        "Without Nested Routes"
                    ),
                    CodeBlock("""# Every page repeats the layout
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
end""", "neutral")
                ),
                Div(:class => "bg-emerald-50 dark:bg-emerald-950/30 rounded-lg border border-emerald-200 dark:border-emerald-700 p-6",
                    H3(:class => "text-lg font-serif font-semibold text-emerald-900 dark:text-emerald-200 mb-4",
                        "With Nested Routes"
                    ),
                    CodeBlock("""# Layout defined once
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
() -> P(\"Settings content\")""", "emerald")
                )
            ),
            InfoBox("DRY Principle",
                "Nested routes follow the DRY (Don't Repeat Yourself) principle. Changes to the " *
                "sidebar or layout only need to happen in one place."
            )
        ),

        # _layout.jl Files
        Section(:class => "py-12 bg-neutral-50 dark:bg-neutral-900 rounded-lg border border-neutral-300 dark:border-neutral-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Layout Files: _layout.jl"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "Create a ", Code(:class => "text-emerald-700 dark:text-emerald-400", "_layout.jl"),
                " file in any directory to wrap all routes in that directory (and subdirectories) ",
                "with a layout component."
            ),
            CodeBlock("""# Directory structure
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
        └── profile.jl   # /dashboard/settings/profile"""),
            H3(:class => "text-xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mt-8 mb-4",
                "Layout File Structure"
            ),
            CodeBlock("""# routes/dashboard/_layout.jl

# Layouts receive params just like route files
(params) -> begin
    # You can use params in the layout
    Div(:class => "min-h-screen flex",
        # Sidebar navigation
        Aside(:class => "w-64 bg-neutral-100 dark:bg-neutral-900 p-4",
            H2(:class => "text-lg font-semibold mb-4", "Dashboard"),
            Nav(:class => "space-y-2",
                NavLink("/dashboard/", "Overview";
                    class = "block px-3 py-2 rounded",
                    active_class = "bg-emerald-100 text-emerald-800",
                    exact = true
                ),
                NavLink("/dashboard/analytics/", "Analytics";
                    class = "block px-3 py-2 rounded",
                    active_class = "bg-emerald-100 text-emerald-800"
                ),
                NavLink("/dashboard/settings/", "Settings";
                    class = "block px-3 py-2 rounded",
                    active_class = "bg-emerald-100 text-emerald-800"
                )
            )
        ),

        # Main content area
        Main(:class => "flex-1 p-8",
            Outlet()  # ← Child routes render here
        )
    )
end""", "neutral")
        ),

        # Outlet Component
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "The Outlet Component"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                Code(:class => "text-emerald-700 dark:text-emerald-400", "Outlet()"),
                " is a placeholder that renders the matched child route. Think of it as a slot ",
                "where nested content appears."
            ),
            CodeBlock("""# Basic usage
Outlet()

# With a fallback (shown when no child route matches)
Outlet(fallback = P("Select an item from the menu"))

# With a function fallback
Outlet(fallback = () -> Div(:class => "text-center py-12",
    P("Nothing selected"),
    P(:class => "text-sm text-neutral-500", "Choose an option from the sidebar")
))"""),
            H3(:class => "text-xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mt-8 mb-4",
                "Outlet Nesting"
            ),
            CodeBlock("""# Layouts can be nested to any depth

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
)""", "neutral")
        ),

        # Route Hooks
        Section(:class => "py-12 bg-neutral-50 dark:bg-neutral-900 rounded-lg border border-neutral-300 dark:border-neutral-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Route Hooks"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "Access route information reactively from any component using these hooks:"
            ),

            # use_params
            Div(:class => "mb-8",
                H3(:class => "text-xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-4",
                    "use_params() — Route Parameters"
                ),
                CodeBlock("""# Get all params as a Dict
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
end""")
            ),

            # use_query
            Div(:class => "mb-8",
                H3(:class => "text-xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-4",
                    "use_query() — Query String Parameters"
                ),
                CodeBlock("""# URL: /search?q=therapy&page=2&sort=date

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
end""", "neutral")
            ),

            # use_location
            Div(
                H3(:class => "text-xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-4",
                    "use_location() — Current Path"
                ),
                CodeBlock("""function Breadcrumb()
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
end""", "neutral")
            )
        ),

        # Programmatic Nested Routes
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Programmatic Nested Routes"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "For cases where file-based routing doesn't fit, you can define nested routes programmatically:"
            ),
            CodeBlock("""using Therapy

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
html = render_nested_routes(matched)"""),
            H3(:class => "text-xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mt-8 mb-4",
                "NestedRoute Struct"
            ),
            CodeBlock("""# NestedRoute constructor
NestedRoute(
    path,           # String: path segment (\":id\" for dynamic)
    component;      # Function: component to render
    children = []   # Vector{NestedRoute}: child routes
)

# Examples
NestedRoute(\"about\", AboutPage)              # Static: /about
NestedRoute(\":id\", UserPage)                 # Dynamic: /:id
NestedRoute(\"\", IndexPage)                   # Index: matches parent exactly
NestedRoute(\"*\", NotFoundPage)               # Catch-all""", "neutral")
        ),

        # Common Patterns
        Section(:class => "py-12 bg-neutral-50 dark:bg-neutral-900 rounded-lg border border-neutral-300 dark:border-neutral-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Common Patterns"
            ),
            H3(:class => "text-xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-4",
                "Admin Panel"
            ),
            CodeBlock("""# routes/admin/_layout.jl
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
            Main(:class => \"flex-1 p-6 bg-neutral-50\",
                Outlet()
            )
        )
    )
end"""),
            H3(:class => "text-xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mt-8 mb-4",
                "Master-Detail View"
            ),
            CodeBlock("""# routes/inbox/_layout.jl
(params) -> Div(:class => \"flex h-screen\",
    # Message list (always visible)
    Aside(:class => \"w-80 border-r overflow-y-auto\",
        MessageList()
    ),

    # Selected message (or placeholder)
    Main(:class => \"flex-1\",
        Outlet(fallback = () -> Div(:class => \"h-full flex items-center justify-center\",
            P(:class => \"text-neutral-500\", \"Select a message to read\")
        ))
    )
)

# routes/inbox/[id].jl
(params) -> begin
    message = fetch_message(params[:id])
    MessageDetail(message = message)
end""", "neutral"),
            H3(:class => "text-xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mt-8 mb-4",
                "Tabbed Interface"
            ),
            CodeBlock("""# routes/account/_layout.jl
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
        active_class = \"border-emerald-500 text-emerald-700\"
    )
end""", "neutral")
        ),

        # Key Takeaways
        Section(:class => "py-12 bg-emerald-50 dark:bg-emerald-950/30 rounded-lg border border-emerald-200 dark:border-emerald-900 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-emerald-900 dark:text-emerald-200 mb-6",
                "Key Takeaways"
            ),
            Ul(:class => "space-y-3 text-emerald-800 dark:text-emerald-300",
                Li("📁 ", Strong("_layout.jl"), " — Wraps all routes in the same directory"),
                Li("🔲 ", Strong("Outlet()"), " — Placeholder where child content renders"),
                Li("📚 ", Strong("Nesting"), " — Layouts can be nested to any depth"),
                Li("📍 ", Strong("use_params()"), " — Access route parameters reactively"),
                Li("❓ ", Strong("use_query()"), " — Access query string parameters"),
                Li("📌 ", Strong("use_location()"), " — Get current path"),
                Li("🔧 ", Strong("NestedRoute"), " — Programmatic route definition")
            )
        ),

        # Navigation
        Div(:class => "py-8 flex justify-between border-t border-neutral-300 dark:border-neutral-800",
            A(:href => "./client-navigation",
              :class => "inline-flex items-center text-neutral-600 dark:text-neutral-400 hover:text-emerald-700 dark:hover:text-emerald-400 transition-colors",
                Svg(:class => "mr-2 w-5 h-5", :fill => "none", :viewBox => "0 0 24 24", :stroke => "currentColor",
                    Path(:stroke_linecap => "round", :stroke_linejoin => "round", :stroke_width => "2", :d => "M11 17l-5-5m0 0l5-5m-5 5h12")
                ),
                "Client-Side Navigation"
            ),
            A(:href => "../",
              :class => "inline-flex items-center text-neutral-600 dark:text-neutral-400 hover:text-emerald-700 dark:hover:text-emerald-400 transition-colors",
                "Back to Routing Overview",
                Svg(:class => "ml-2 w-5 h-5", :fill => "none", :viewBox => "0 0 24 24", :stroke => "currentColor",
                    Path(:stroke_linecap => "round", :stroke_linejoin => "round", :stroke_width => "2", :d => "M13 7l5 5m0 0l-5 5m5-5H6")
                )
            )
        )
    )
end

# Helper Components

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

# Export the page component
NestedRoutes
