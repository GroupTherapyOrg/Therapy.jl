# File-Based Routing - Chapter 1 of Part 6
#
# How Therapy.jl maps your directory structure to URL paths.

function FileRouting()
    BookLayout(
        # Header
        Div(:class => "py-8 border-b border-neutral-300 dark:border-neutral-800",
            Span(:class => "text-sm text-emerald-700 dark:text-emerald-400 font-medium", "Part 6 · Chapter 1"),
            H1(:class => "text-4xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mt-2 mb-4",
                "File-Based Routing"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 max-w-3xl",
                "Define routes by creating files. No configuration, no route tables—just create a Julia file ",
                "and it becomes a route automatically."
            )
        ),

        # What is File-Based Routing?
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "What is File-Based Routing?"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "File-based routing is a convention popularized by frameworks like Next.js and Nuxt. Instead of ",
                "defining routes in a central configuration file, you organize your code in a directory structure ",
                "that mirrors your URL paths."
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-neutral-800 dark:text-neutral-200 mb-4",
                        "Traditional Routing"
                    ),
                    CodeBlock("""# Manual route configuration
routes = [
    Route("/", HomePage),
    Route("/about", AboutPage),
    Route("/users", UsersPage),
    Route("/users/:id", UserPage),
    Route("/users/:id/posts", UserPostsPage),
    Route("/docs/*", DocsPage),
]

# Every new page requires:
# 1. Create the component file
# 2. Import it in your routes file
# 3. Add a Route() entry
# 4. Hope you didn't typo the path""", "neutral")
                ),
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-neutral-800 dark:text-neutral-200 mb-4",
                        "File-Based Routing"
                    ),
                    CodeBlock("""# Just create files!
routes/
├── index.jl        # /
├── about.jl        # /about
├── users/
│   ├── index.jl    # /users
│   ├── [id].jl     # /users/:id
│   └── [id]/
│       └── posts.jl # /users/:id/posts
└── docs/
    └── [...slug].jl # /docs/*

# Every new page is just:
# 1. Create the file
# Done!""")
                )
            ),
            InfoBox("Convention Over Configuration",
                "File-based routing reduces boilerplate and eliminates a whole category of routing bugs. " *
                "The file system is your source of truth."
            )
        ),

        # Setting Up the Router
        Section(:class => "py-12 bg-neutral-50 dark:bg-neutral-900 rounded-lg border border-neutral-300 dark:border-neutral-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Setting Up the Router"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "Create a router from your routes directory with ",
                Code(:class => "text-emerald-700 dark:text-emerald-400", "create_router()"), ":"
            ),
            CodeBlock("""using Therapy

# Create router pointing to your routes directory
router = create_router("src/routes";
    layout = Layout  # Optional: wrap all routes with a layout component
)

# The router scans the directory and builds a route table:
# - src/routes/index.jl       → "/"
# - src/routes/about.jl       → "/about"
# - src/routes/users/index.jl → "/users"
# etc."""),
            H3(:class => "text-xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mt-8 mb-4",
                "Handling Requests"
            ),
            CodeBlock("""# Handle an incoming HTTP request
html, route, params = handle_request(router, "/users/123")

# Returns:
# - html:   Rendered HTML string (with layout if configured)
# - route:  The matched Route struct (contains path, handler, etc.)
# - params: Dict of extracted parameters (e.g., Dict(:id => "123"))

# With query string
html, route, params = handle_request(router, "/search";
    query_string = "q=therapy&page=2"
)"""),
            H3(:class => "text-xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mt-8 mb-4",
                "Complete Dev Server Example"
            ),
            CodeBlock("""using Therapy
using HTTP

# Set up router
router = create_router("src/routes"; layout = Layout)

# Start development server
function run_server()
    HTTP.serve("127.0.0.1", 8080) do request
        path = HTTP.URI(request.target).path

        # Handle the request
        html, route, params = handle_request(router, path)

        HTTP.Response(200, ["Content-Type" => "text/html"], html)
    end
end

run_server()  # Visit http://127.0.0.1:8080""", "neutral")
        ),

        # File Naming Conventions
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "File Naming Conventions"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "Therapy.jl uses simple conventions to map files to routes:"
            ),
            Div(:class => "overflow-x-auto",
                Table(:class => "w-full text-left",
                    Thead(
                        Tr(:class => "border-b border-neutral-300 dark:border-neutral-700",
                            Th(:class => "py-3 px-4 text-neutral-600 dark:text-neutral-400 font-medium", "File"),
                            Th(:class => "py-3 px-4 text-neutral-600 dark:text-neutral-400 font-medium", "URL Path"),
                            Th(:class => "py-3 px-4 text-neutral-600 dark:text-neutral-400 font-medium", "Notes")
                        )
                    ),
                    Tbody(
                        Tr(:class => "border-b border-neutral-200 dark:border-neutral-800",
                            Td(:class => "py-3 px-4", Code(:class => "text-emerald-700 dark:text-emerald-400", "index.jl")),
                            Td(:class => "py-3 px-4", Code(:class => "text-sm", "/")),
                            Td(:class => "py-3 px-4 text-neutral-600 dark:text-neutral-400 text-sm", "Root of directory")
                        ),
                        Tr(:class => "border-b border-neutral-200 dark:border-neutral-800",
                            Td(:class => "py-3 px-4", Code(:class => "text-emerald-700 dark:text-emerald-400", "about.jl")),
                            Td(:class => "py-3 px-4", Code(:class => "text-sm", "/about")),
                            Td(:class => "py-3 px-4 text-neutral-600 dark:text-neutral-400 text-sm", "Static page")
                        ),
                        Tr(:class => "border-b border-neutral-200 dark:border-neutral-800",
                            Td(:class => "py-3 px-4", Code(:class => "text-emerald-700 dark:text-emerald-400", "users/index.jl")),
                            Td(:class => "py-3 px-4", Code(:class => "text-sm", "/users")),
                            Td(:class => "py-3 px-4 text-neutral-600 dark:text-neutral-400 text-sm", "Nested index")
                        ),
                        Tr(:class => "border-b border-neutral-200 dark:border-neutral-800",
                            Td(:class => "py-3 px-4", Code(:class => "text-emerald-700 dark:text-emerald-400", "users/[id].jl")),
                            Td(:class => "py-3 px-4", Code(:class => "text-sm", "/users/:id")),
                            Td(:class => "py-3 px-4 text-neutral-600 dark:text-neutral-400 text-sm", "Dynamic segment")
                        ),
                        Tr(:class => "border-b border-neutral-200 dark:border-neutral-800",
                            Td(:class => "py-3 px-4", Code(:class => "text-emerald-700 dark:text-emerald-400", "docs/[...slug].jl")),
                            Td(:class => "py-3 px-4", Code(:class => "text-sm", "/docs/*")),
                            Td(:class => "py-3 px-4 text-neutral-600 dark:text-neutral-400 text-sm", "Catch-all")
                        ),
                        Tr(
                            Td(:class => "py-3 px-4", Code(:class => "text-emerald-700 dark:text-emerald-400", "_layout.jl")),
                            Td(:class => "py-3 px-4 text-neutral-500 dark:text-neutral-500", "(not a route)"),
                            Td(:class => "py-3 px-4 text-neutral-600 dark:text-neutral-400 text-sm", "Layout wrapper")
                        )
                    )
                )
            ),
            WarnBox("Special Files",
                "Files starting with _ (underscore) are special. _layout.jl defines nested layouts—it's not " *
                "exposed as a route itself, but wraps child routes in that directory."
            )
        ),

        # Route Component Structure
        Section(:class => "py-12 bg-neutral-50 dark:bg-neutral-900 rounded-lg border border-neutral-300 dark:border-neutral-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Route Component Structure"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "Each route file should export a component function. There are several supported patterns:"
            ),
            H3(:class => "text-xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mt-8 mb-4",
                "Pattern 1: Named Function Export"
            ),
            CodeBlock("""# src/routes/about.jl

function About()
    Div(:class => "container mx-auto py-8",
        H1(:class => "text-4xl font-bold", "About Us"),
        P("We build reactive web applications with Julia.")
    )
end

# The last expression is the export
About"""),
            H3(:class => "text-xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mt-8 mb-4",
                "Pattern 2: Anonymous Function with Params"
            ),
            CodeBlock("""# src/routes/users/[id].jl

# Route params are passed as argument
(params) -> begin
    user_id = params[:id]

    Div(:class => "container mx-auto py-8",
        H1("User Profile"),
        P("Viewing user: ", user_id)
    )
end""", "neutral"),
            H3(:class => "text-xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mt-8 mb-4",
                "Pattern 3: Index Function"
            ),
            CodeBlock("""# src/routes/index.jl

function Index()
    BookLayout(
        Hero(),
        Features(),
        CallToAction()
    )
end

Index""", "neutral"),
            InfoBox("Function Naming",
                "While you can name your function anything, using Index for index.jl and naming " *
                "pages after their route (About for about.jl) makes code easier to navigate."
            )
        ),

        # Layouts
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Global and Section Layouts"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "Layouts wrap route content with shared UI like navigation, sidebars, and footers."
            ),
            H3(:class => "text-xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mt-8 mb-4",
                "Global Layout (router option)"
            ),
            CodeBlock("""# Define a layout component
function Layout(; children...)
    BookLayout(
        Header(),
        Nav(
            NavLink("/", "Home"),
            NavLink("/about/", "About"),
            NavLink("/users/", "Users")
        ),
        Main(:id => "page-content",
            children...  # Route content renders here
        ),
        Footer()
    )
end

# Apply to all routes
router = create_router("src/routes"; layout = Layout)"""),
            H3(:class => "text-xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mt-8 mb-4",
                "Section Layout (_layout.jl)"
            ),
            CodeBlock("""# src/routes/dashboard/_layout.jl
# Wraps all routes under /dashboard/

(params) -> Div(:class => "flex min-h-screen",
    # Sidebar (persists during navigation)
    Aside(:class => "w-64 bg-neutral-100",
        Nav(:class => "p-4",
            NavLink("/dashboard/", "Overview"; exact = true),
            NavLink("/dashboard/analytics/", "Analytics"),
            NavLink("/dashboard/settings/", "Settings")
        )
    ),

    # Main content area
    Main(:class => "flex-1 p-8",
        Outlet()  # Child routes render here
    )
)""", "neutral"),
            P(:class => "text-neutral-600 dark:text-neutral-400 mt-4",
                "Layouts can be nested. A route at ", Code(:class => "text-emerald-700 dark:text-emerald-400", "/dashboard/analytics/"),
                " would be wrapped by both the global layout and the dashboard section layout."
            )
        ),

        # Route Priority
        Section(:class => "py-12 bg-neutral-50 dark:bg-neutral-900 rounded-lg border border-neutral-300 dark:border-neutral-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Route Priority"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "When multiple routes could match a path, Therapy.jl follows this priority order:"
            ),
            Ol(:class => "list-decimal list-inside space-y-3 text-neutral-600 dark:text-neutral-400",
                Li(Strong("Exact static matches"), " — ", Code(:class => "text-emerald-700 dark:text-emerald-400", "about.jl"), " matches ", Code(:class => "text-sm", "/about"), " exactly"),
                Li(Strong("Index routes"), " — ", Code(:class => "text-emerald-700 dark:text-emerald-400", "index.jl"), " matches directory root"),
                Li(Strong("Dynamic segments"), " — ", Code(:class => "text-emerald-700 dark:text-emerald-400", "[id].jl"), " matches any single segment"),
                Li(Strong("Catch-all routes"), " — ", Code(:class => "text-emerald-700 dark:text-emerald-400", "[...slug].jl"), " matches any remaining path")
            ),
            CodeBlock("""# Given these routes:
routes/
├── users/
│   ├── index.jl      # Matches: /users
│   ├── new.jl        # Matches: /users/new (higher priority)
│   ├── [id].jl       # Matches: /users/123, /users/abc
│   └── [...rest].jl  # Matches: /users/123/posts/456

# Request priority:
# /users       → index.jl
# /users/new   → new.jl (static before dynamic)
# /users/123   → [id].jl
# /users/a/b/c → [...rest].jl""", "neutral")
        ),

        # Best Practices
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Best Practices"
            ),
            Div(:class => "space-y-6",
                BestPractice("Use index.jl for directory roots",
                    "Don't create both users.jl and users/index.jl—use just users/index.jl. " *
                    "This keeps related files together."),
                BestPractice("Keep routes thin",
                    "Route files should be thin orchestration layers. Extract reusable components " *
                    "to src/components/ and business logic to src/lib/."),
                BestPractice("Use consistent naming",
                    "Name functions after their route: Index for index.jl, About for about.jl, " *
                    "UserProfile for users/[id].jl."),
                BestPractice("Leverage layouts",
                    "Use _layout.jl for shared navigation within a section. Don't repeat " *
                    "nav/sidebar code in every route."),
                BestPractice("Handle 404s",
                    "Create a [...404].jl at the routes root to catch unmatched paths " *
                    "and show a friendly error page.")
            )
        ),

        # Key Takeaways
        Section(:class => "py-12 bg-emerald-50 dark:bg-emerald-950/30 rounded-lg border border-emerald-200 dark:border-emerald-900 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-emerald-900 dark:text-emerald-200 mb-6",
                "Key Takeaways"
            ),
            Ul(:class => "space-y-3 text-emerald-800 dark:text-emerald-300",
                Li("📁 ", Strong("File = Route"), " — Create a file, get a route automatically"),
                Li("📂 ", Strong("Directories = Path Segments"), " — Nest files for nested paths"),
                Li("🔧 ", Strong("create_router()"), " — Builds route table from your file structure"),
                Li("📄 ", Strong("handle_request()"), " — Matches path and returns rendered HTML"),
                Li("🎨 ", Strong("Layouts"), " — Global layout via router option, section layouts via _layout.jl")
            )
        ),

        # Navigation
        Div(:class => "py-8 flex justify-between border-t border-neutral-300 dark:border-neutral-800",
            A(:href => "./",
              :class => "inline-flex items-center text-neutral-600 dark:text-neutral-400 hover:text-emerald-700 dark:hover:text-emerald-400 transition-colors",
                Svg(:class => "mr-2 w-5 h-5", :fill => "none", :viewBox => "0 0 24 24", :stroke => "currentColor",
                    Path(:stroke_linecap => "round", :stroke_linejoin => "round", :stroke_width => "2", :d => "M11 17l-5-5m0 0l5-5m-5 5h12")
                ),
                "Routing Overview"
            ),
            A(:href => "./dynamic-routes",
              :class => "inline-flex items-center text-neutral-600 dark:text-neutral-400 hover:text-emerald-700 dark:hover:text-emerald-400 transition-colors",
                "Dynamic Routes",
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

function WarnBox(title, content)
    Div(:class => "mt-8 bg-amber-50 dark:bg-amber-950/30 rounded-lg border border-amber-200 dark:border-amber-900 p-6",
        H3(:class => "text-lg font-serif font-semibold text-amber-900 dark:text-amber-200 mb-2", title),
        P(:class => "text-amber-800 dark:text-amber-300", content)
    )
end

function BestPractice(title, content)
    Div(:class => "bg-white dark:bg-neutral-800 rounded-lg border border-neutral-300 dark:border-neutral-700 p-6",
        H3(:class => "text-lg font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-2", title),
        P(:class => "text-neutral-600 dark:text-neutral-400", content)
    )
end

# Export the page component
FileRouting
