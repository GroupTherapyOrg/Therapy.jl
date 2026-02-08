# File-Based Routing - Chapter 1 of Part 6
#
# How Therapy.jl maps your directory structure to URL paths.

import Suite

function FileRouting()
    BookLayout("/book/routing/file-routing/",
        # Header
        Div(:class => "py-8 border-b border-warm-200 dark:border-warm-700",
            Suite.Badge(variant="outline", "Part 6 · Chapter 1"),
            H1(:class => "text-4xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-2 mb-4",
                "File-Based Routing"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 max-w-3xl",
                "Define routes by creating files. No configuration, no route tables—just create a Julia file ",
                "and it becomes a route automatically."
            )
        ),

        # What is File-Based Routing?
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "What is File-Based Routing?"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "File-based routing is a convention popularized by frameworks like Next.js and Nuxt. Instead of ",
                "defining routes in a central configuration file, you organize your code in a directory structure ",
                "that mirrors your URL paths."
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-300 mb-4",
                        "Traditional Routing"
                    ),
                    Suite.CodeBlock(
                        code="""# Manual route configuration
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
# 4. Hope you didn't typo the path""",
                        language="julia",
                        show_copy=false
                    )
                ),
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-300 mb-4",
                        "File-Based Routing"
                    ),
                    Suite.CodeBlock(
                        code="""# Just create files!
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
# Done!""",
                        language="",
                        show_copy=false
                    )
                )
            ),
            Suite.Alert(class="mt-8",
                Suite.AlertTitle("Convention Over Configuration"),
                Suite.AlertDescription(
                    "File-based routing reduces boilerplate and eliminates a whole category of routing bugs. " *
                    "The file system is your source of truth."
                )
            )
        ),

        Suite.Separator(),

        # Setting Up the Router
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Setting Up the Router"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Create a router from your routes directory with ",
                Code(:class => "text-accent-700 dark:text-accent-400", "create_router()"), ":"
            ),
            Suite.CodeBlock(
                code="""using Therapy

# Create router pointing to your routes directory
router = create_router("src/routes";
    layout = Layout  # Optional: wrap all routes with a layout component
)

# The router scans the directory and builds a route table:
# - src/routes/index.jl       → "/"
# - src/routes/about.jl       → "/about"
# - src/routes/users/index.jl → "/users"
# etc.""",
                language="julia"
            ),
            H3(:class => "text-xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-8 mb-4",
                "Handling Requests"
            ),
            Suite.CodeBlock(
                code="""# Handle an incoming HTTP request
html, route, params = handle_request(router, "/users/123")

# Returns:
# - html:   Rendered HTML string (with layout if configured)
# - route:  The matched Route struct (contains path, handler, etc.)
# - params: Dict of extracted parameters (e.g., Dict(:id => "123"))

# With query string
html, route, params = handle_request(router, "/search";
    query_string = "q=therapy&page=2"
)""",
                language="julia"
            ),
            H3(:class => "text-xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-8 mb-4",
                "Complete Dev Server Example"
            ),
            Suite.CodeBlock(
                code="""using Therapy
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

run_server()  # Visit http://127.0.0.1:8080""",
                language="julia"
            )
        ),

        Suite.Separator(),

        # File Naming Conventions
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "File Naming Conventions"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Therapy.jl uses simple conventions to map files to routes:"
            ),
            Suite.Table(
                Suite.TableHeader(
                    Suite.TableRow(
                        Suite.TableHead("File"),
                        Suite.TableHead("URL Path"),
                        Suite.TableHead("Notes")
                    )
                ),
                Suite.TableBody(
                    Suite.TableRow(
                        Suite.TableCell(Code(:class => "text-accent-700 dark:text-accent-400", "index.jl")),
                        Suite.TableCell(Code(:class => "text-sm", "/")),
                        Suite.TableCell("Root of directory")
                    ),
                    Suite.TableRow(
                        Suite.TableCell(Code(:class => "text-accent-700 dark:text-accent-400", "about.jl")),
                        Suite.TableCell(Code(:class => "text-sm", "/about")),
                        Suite.TableCell("Static page")
                    ),
                    Suite.TableRow(
                        Suite.TableCell(Code(:class => "text-accent-700 dark:text-accent-400", "users/index.jl")),
                        Suite.TableCell(Code(:class => "text-sm", "/users")),
                        Suite.TableCell("Nested index")
                    ),
                    Suite.TableRow(
                        Suite.TableCell(Code(:class => "text-accent-700 dark:text-accent-400", "users/[id].jl")),
                        Suite.TableCell(Code(:class => "text-sm", "/users/:id")),
                        Suite.TableCell("Dynamic segment")
                    ),
                    Suite.TableRow(
                        Suite.TableCell(Code(:class => "text-accent-700 dark:text-accent-400", "docs/[...slug].jl")),
                        Suite.TableCell(Code(:class => "text-sm", "/docs/*")),
                        Suite.TableCell("Catch-all")
                    ),
                    Suite.TableRow(
                        Suite.TableCell(Code(:class => "text-accent-700 dark:text-accent-400", "_layout.jl")),
                        Suite.TableCell("(not a route)"),
                        Suite.TableCell("Layout wrapper")
                    )
                )
            ),
            Suite.Alert(class="mt-8", variant="destructive",
                Suite.AlertTitle("Special Files"),
                Suite.AlertDescription(
                    "Files starting with _ (underscore) are special. _layout.jl defines nested layouts—it's not " *
                    "exposed as a route itself, but wraps child routes in that directory."
                )
            )
        ),

        Suite.Separator(),

        # Route Component Structure
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Route Component Structure"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Each route file should export a component function. There are several supported patterns:"
            ),
            H3(:class => "text-xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-8 mb-4",
                "Pattern 1: Named Function Export"
            ),
            Suite.CodeBlock(
                code="""# src/routes/about.jl

function About()
    Div(:class => "container mx-auto py-8",
        H1(:class => "text-4xl font-bold", "About Us"),
        P("We build reactive web applications with Julia.")
    )
end

# The last expression is the export
About""",
                language="julia"
            ),
            H3(:class => "text-xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-8 mb-4",
                "Pattern 2: Anonymous Function with Params"
            ),
            Suite.CodeBlock(
                code="""# src/routes/users/[id].jl

# Route params are passed as argument
(params) -> begin
    user_id = params[:id]

    Div(:class => "container mx-auto py-8",
        H1("User Profile"),
        P("Viewing user: ", user_id)
    )
end""",
                language="julia"
            ),
            H3(:class => "text-xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-8 mb-4",
                "Pattern 3: Index Function"
            ),
            Suite.CodeBlock(
                code="""# src/routes/index.jl

function Index()
    BookLayout(
        Hero(),
        Features(),
        CallToAction()
    )
end

Index""",
                language="julia"
            ),
            Suite.Alert(class="mt-8",
                Suite.AlertTitle("Function Naming"),
                Suite.AlertDescription(
                    "While you can name your function anything, using Index for index.jl and naming " *
                    "pages after their route (About for about.jl) makes code easier to navigate."
                )
            )
        ),

        Suite.Separator(),

        # Layouts
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Global and Section Layouts"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Layouts wrap route content with shared UI like navigation, sidebars, and footers."
            ),
            H3(:class => "text-xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-8 mb-4",
                "Global Layout (router option)"
            ),
            Suite.CodeBlock(
                code="""# Define a layout component
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
router = create_router("src/routes"; layout = Layout)""",
                language="julia"
            ),
            H3(:class => "text-xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-8 mb-4",
                "Section Layout (_layout.jl)"
            ),
            Suite.CodeBlock(
                code="""# src/routes/dashboard/_layout.jl
# Wraps all routes under /dashboard/

(params) -> Div(:class => "flex min-h-screen",
    # Sidebar (persists during navigation)
    Aside(:class => "w-64 bg-warm-50",
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
)""",
                language="julia"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-4",
                "Layouts can be nested. A route at ", Code(:class => "text-accent-700 dark:text-accent-400", "/dashboard/analytics/"),
                " would be wrapped by both the global layout and the dashboard section layout."
            )
        ),

        Suite.Separator(),

        # Route Priority
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Route Priority"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "When multiple routes could match a path, Therapy.jl follows this priority order:"
            ),
            Ol(:class => "list-decimal list-inside space-y-3 text-warm-600 dark:text-warm-400",
                Li(Strong("Exact static matches"), " — ", Code(:class => "text-accent-700 dark:text-accent-400", "about.jl"), " matches ", Code(:class => "text-sm", "/about"), " exactly"),
                Li(Strong("Index routes"), " — ", Code(:class => "text-accent-700 dark:text-accent-400", "index.jl"), " matches directory root"),
                Li(Strong("Dynamic segments"), " — ", Code(:class => "text-accent-700 dark:text-accent-400", "[id].jl"), " matches any single segment"),
                Li(Strong("Catch-all routes"), " — ", Code(:class => "text-accent-700 dark:text-accent-400", "[...slug].jl"), " matches any remaining path")
            ),
            Suite.CodeBlock(
                code="""# Given these routes:
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
# /users/a/b/c → [...rest].jl""",
                language="",
                show_copy=false
            )
        ),

        Suite.Separator(),

        # Best Practices
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Best Practices"
            ),
            Div(:class => "space-y-6",
                Suite.Card(
                    Suite.CardHeader(Suite.CardTitle(:class => "font-serif", "Use index.jl for directory roots")),
                    Suite.CardContent(P(:class => "text-warm-600 dark:text-warm-400",
                        "Don't create both users.jl and users/index.jl—use just users/index.jl. " *
                        "This keeps related files together."))
                ),
                Suite.Card(
                    Suite.CardHeader(Suite.CardTitle(:class => "font-serif", "Keep routes thin")),
                    Suite.CardContent(P(:class => "text-warm-600 dark:text-warm-400",
                        "Route files should be thin orchestration layers. Extract reusable components " *
                        "to src/components/ and business logic to src/lib/."))
                ),
                Suite.Card(
                    Suite.CardHeader(Suite.CardTitle(:class => "font-serif", "Use consistent naming")),
                    Suite.CardContent(P(:class => "text-warm-600 dark:text-warm-400",
                        "Name functions after their route: Index for index.jl, About for about.jl, " *
                        "UserProfile for users/[id].jl."))
                ),
                Suite.Card(
                    Suite.CardHeader(Suite.CardTitle(:class => "font-serif", "Leverage layouts")),
                    Suite.CardContent(P(:class => "text-warm-600 dark:text-warm-400",
                        "Use _layout.jl for shared navigation within a section. Don't repeat " *
                        "nav/sidebar code in every route."))
                ),
                Suite.Card(
                    Suite.CardHeader(Suite.CardTitle(:class => "font-serif", "Handle 404s")),
                    Suite.CardContent(P(:class => "text-warm-600 dark:text-warm-400",
                        "Create a [...404].jl at the routes root to catch unmatched paths " *
                        "and show a friendly error page."))
                )
            )
        ),

        # Key Takeaways
        Suite.Alert(class="mt-12",
            Suite.AlertTitle("Key Takeaways"),
            Suite.AlertDescription(
                Ul(:class => "space-y-2 list-disc pl-5 mt-2",
                    Li(Strong("File = Route"), " — Create a file, get a route automatically"),
                    Li(Strong("Directories = Path Segments"), " — Nest files for nested paths"),
                    Li(Strong("create_router()"), " — Builds route table from your file structure"),
                    Li(Strong("handle_request()"), " — Matches path and returns rendered HTML"),
                    Li(Strong("Layouts"), " — Global layout via router option, section layouts via _layout.jl")
                )
            )
        ),

    )
end

# Export the page component
FileRouting
