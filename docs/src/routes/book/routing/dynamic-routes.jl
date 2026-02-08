# Dynamic Routes - Chapter 2 of Part 6
#
# Handling dynamic parameters and catch-all routes.

import Suite

function DynamicRoutes()
    BookLayout("/book/routing/dynamic-routes/",
        # Header
        Div(:class => "py-8 border-b border-warm-200 dark:border-warm-700",
            Suite.Badge(variant="outline", "Part 6 · Chapter 2"),
            H1(:class => "text-4xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-2 mb-4",
                "Dynamic Routes"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 max-w-3xl",
                "Extract parameters from URLs using dynamic segments. Build user profiles, product pages, ",
                "and documentation sites with flexible URL patterns."
            )
        ),

        # Why Dynamic Routes?
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Why Dynamic Routes?"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Most web applications have pages where part of the URL is variable: user IDs, product slugs, ",
                "blog post dates, or documentation paths. Dynamic routes let you handle these patterns with ",
                "a single route file."
            ),
            Div(:class => "grid md:grid-cols-3 gap-6 mt-8",
                Suite.Card(class="text-center",
                    Suite.CardContent(class="pt-6",
                        Code(:class => "text-accent-700 dark:text-accent-400 font-semibold", "/users/123"),
                        P(:class => "text-warm-600 dark:text-warm-400 text-sm mt-2", "User ID"),
                        P(:class => "text-warm-600 dark:text-warm-400 text-sm mt-1", "Show user profile")
                    )
                ),
                Suite.Card(class="text-center",
                    Suite.CardContent(class="pt-6",
                        Code(:class => "text-accent-700 dark:text-accent-400 font-semibold", "/products/widget-pro"),
                        P(:class => "text-warm-600 dark:text-warm-400 text-sm mt-2", "Product slug"),
                        P(:class => "text-warm-600 dark:text-warm-400 text-sm mt-1", "Display product")
                    )
                ),
                Suite.Card(class="text-center",
                    Suite.CardContent(class="pt-6",
                        Code(:class => "text-accent-700 dark:text-accent-400 font-semibold", "/docs/api/signals"),
                        P(:class => "text-warm-600 dark:text-warm-400 text-sm mt-2", "Doc path"),
                        P(:class => "text-warm-600 dark:text-warm-400 text-sm mt-1", "Render documentation")
                    )
                )
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "Without dynamic routes, you'd need a separate file for every possible URL—impossible for data-driven pages."
            )
        ),

        Suite.Separator(),

        # Single Dynamic Segment
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Single Dynamic Segment: [param].jl"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Use square brackets to create a dynamic segment that matches any single path part:"
            ),
            Suite.CodeBlock("""# File: routes/users/[id].jl
# Matches: /users/123, /users/alice, /users/abc-def

(params) -> begin
    user_id = params[:id]  # "123", "alice", or "abc-def"

    Div(:class => "container mx-auto py-8",
        H1("User Profile"),
        P("User ID: ", user_id),

        # Fetch user data using the ID
        UserDetails(id = user_id)
    )
end""", language="julia"),
            H3(:class => "text-xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-8 mb-4",
                "Multiple Dynamic Segments"
            ),
            Suite.CodeBlock("""# File: routes/[category]/[product].jl
# Matches: /electronics/laptop, /books/julia-guide

(params) -> begin
    category = params[:category]  # "electronics", "books"
    product = params[:product]    # "laptop", "julia-guide"

    Div(
        Breadcrumb(category, product),
        ProductPage(category = category, slug = product)
    )
end""", language="julia", show_copy=false),
            H3(:class => "text-xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-8 mb-4",
                "Nested Dynamic Segments"
            ),
            Suite.CodeBlock("""# Directory structure for /users/:id/posts/:post_id
routes/
└── users/
    └── [id]/
        └── posts/
            └── [post_id].jl

# File: routes/users/[id]/posts/[post_id].jl
(params) -> begin
    user_id = params[:id]
    post_id = params[:post_id]

    Div(
        H1("Post #", post_id),
        P("By user: ", user_id),
        PostContent(user = user_id, post = post_id)
    )
end""", language="julia", show_copy=false)
        ),

        Suite.Separator(),

        # Catch-All Routes
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Catch-All Routes: [...param].jl"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "The spread syntax ", Code(:class => "text-accent-700 dark:text-accent-400", "[...param]"),
                " matches any number of path segments. Perfect for documentation, file browsers, or nested content."
            ),
            Suite.CodeBlock("""# File: routes/docs/[...slug].jl
# Matches: /docs/intro
#          /docs/api/signals
#          /docs/guides/getting-started/first-app

(params) -> begin
    slug = params[:slug]  # "intro", "api/signals", "guides/getting-started/first-app"

    # Split into path segments if needed
    segments = split(slug, "/")

    Div(:class => "docs-layout",
        DocsSidebar(current = segments),
        DocsContent(path = slug)
    )
end""", language="julia"),
            Suite.Alert(class="mt-8",
                Suite.AlertTitle("Catch-All Captures the Rest"),
                Suite.AlertDescription(
                    "The catch-all parameter captures everything after the prefix. For /docs/api/signals, " *
                    "params[:slug] is \"api/signals\" (a single string), not an array."
                )
            ),
            H3(:class => "text-xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-8 mb-4",
                "Catch-All for 404 Pages"
            ),
            Suite.CodeBlock("""# File: routes/[...404].jl
# Matches any unmatched route (lowest priority)

(params) -> begin
    path = get(params, :404, "/")

    Div(:class => "min-h-screen flex items-center justify-center",
        Div(:class => "text-center",
            H1(:class => "text-6xl font-bold text-warm-200", "404"),
            H2(:class => "text-2xl mt-4", "Page Not Found"),
            P(:class => "text-warm-600 mt-2",
                "The path ", Code(path), " doesn't exist."
            ),
            A(:href => "/", :class => "mt-4 inline-block text-accent-700 hover:underline",
                "← Return Home"
            )
        )
    )
end""", language="julia", show_copy=false)
        ),

        Suite.Separator(),

        # Accessing Parameters
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Accessing Parameters"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "There are two ways to access route parameters:"
            ),
            H3(:class => "text-xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-8 mb-4",
                "1. Function Argument (Route Files)"
            ),
            Suite.CodeBlock("""# In route files, params are passed as the first argument
(params) -> begin
    id = params[:id]           # Direct access
    id = get(params, :id, "0") # With default
    # ...
end""", language="julia"),
            H3(:class => "text-xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-8 mb-4",
                "2. use_params() Hook (Components)"
            ),
            Suite.CodeBlock("""# In any component, use the reactive hook
function UserProfile()
    # Get all params
    params = use_params()
    user_id = params[:id]

    # Or get specific param
    user_id = use_params(:id)

    # Or with default
    user_id = use_params(:id, "unknown")

    Div(H1("User: ", user_id))
end""", language="julia", show_copy=false),
            Suite.Alert(class="mt-8",
                Suite.AlertTitle("Reactive Updates"),
                Suite.AlertDescription(
                    "use_params() returns reactive values. If you navigate from /users/1 to /users/2 " *
                    "using client-side navigation, components using use_params() will automatically " *
                    "re-render with the new values."
                )
            )
        ),

        Suite.Separator(),

        # Type Conversion
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Parameter Type Conversion"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Route parameters are always strings. Convert them as needed:"
            ),
            Suite.CodeBlock("""(params) -> begin
    # String by default
    id_str = params[:id]  # "123"

    # Parse to integer
    id = parse(Int, params[:id])  # 123

    # Safe parsing with default
    id = tryparse(Int, params[:id])
    if id === nothing
        return ErrorPage("Invalid user ID")
    end

    # Parse multiple params
    page = parse(Int, get(params, :page, "1"))
    limit = parse(Int, get(params, :limit, "20"))

    UserList(page = page, limit = limit)
end""", language="julia"),
            Suite.Alert(class="mt-8", variant="destructive",
                Suite.AlertTitle("Always Validate Input"),
                Suite.AlertDescription(
                    "Never trust URL parameters. An attacker could request /users/../../secrets. " *
                    "Always validate and sanitize before using params in database queries or file paths."
                )
            )
        ),

        Suite.Separator(),

        # Common Patterns
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Common Patterns"
            ),
            H3(:class => "text-xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-8 mb-4",
                "Blog with Date URLs"
            ),
            Suite.CodeBlock("""# routes/blog/[year]/[month]/[slug].jl
# Matches: /blog/2026/01/hello-world

(params) -> begin
    year = parse(Int, params[:year])
    month = parse(Int, params[:month])
    slug = params[:slug]

    post = fetch_post(year, month, slug)

    Article(
        H1(post.title),
        Time(Dates.format(post.date, "F d, Y")),
        Div(:class => "prose", post.content)
    )
end""", language="julia"),
            H3(:class => "text-xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-8 mb-4",
                "API-Style Routes"
            ),
            Suite.CodeBlock("""# routes/api/v1/[...path].jl
# Matches: /api/v1/users, /api/v1/users/123/posts

(params) -> begin
    path = params[:path]
    segments = split(path, "/")

    # Route to appropriate handler
    if segments[1] == "users"
        if length(segments) == 1
            return UsersAPI.list()
        elseif length(segments) == 2
            return UsersAPI.get(segments[2])
        elseif length(segments) == 3 && segments[3] == "posts"
            return UsersAPI.posts(segments[2])
        end
    end

    APIError(404, "Not Found")
end""", language="julia", show_copy=false),
            H3(:class => "text-xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-8 mb-4",
                "Localized Routes"
            ),
            Suite.CodeBlock("""# routes/[locale]/products/[slug].jl
# Matches: /en/products/widget, /es/products/widget

(params) -> begin
    locale = params[:locale]
    slug = params[:slug]

    # Validate locale
    if locale ∉ ["en", "es", "fr", "de"]
        return redirect("/en/products/\$slug")
    end

    product = fetch_product(slug, locale)
    ProductPage(product = product, locale = locale)
end""", language="julia", show_copy=false)
        ),

        Suite.Separator(),

        # Route Priority Rules
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Priority Rules"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "When paths could match multiple routes, Therapy.jl uses this priority:"
            ),
            Ol(:class => "list-decimal list-inside space-y-4 text-warm-600 dark:text-warm-400",
                Li(
                    Strong("Static over dynamic"), " — ",
                    Code(:class => "text-accent-700 dark:text-accent-400", "users/new.jl"),
                    " beats ",
                    Code(:class => "text-accent-700 dark:text-accent-400", "users/[id].jl"),
                    " for ", Code(:class => "text-sm", "/users/new")
                ),
                Li(
                    Strong("Specific over general"), " — ",
                    Code(:class => "text-accent-700 dark:text-accent-400", "[id].jl"),
                    " beats ",
                    Code(:class => "text-accent-700 dark:text-accent-400", "[...slug].jl"),
                    " for single-segment paths"
                ),
                Li(
                    Strong("Deeper over shallower"), " — ",
                    Code(:class => "text-accent-700 dark:text-accent-400", "docs/api/[name].jl"),
                    " beats ",
                    Code(:class => "text-accent-700 dark:text-accent-400", "docs/[...path].jl"),
                    " for ", Code(:class => "text-sm", "/docs/api/signals")
                )
            ),
            Suite.CodeBlock("""# Given these routes:
routes/
├── users/
│   ├── new.jl        # 1. Static
│   ├── [id].jl       # 2. Single dynamic
│   └── [...rest].jl  # 3. Catch-all

# Requests resolve to:
# /users/new      → new.jl (static wins)
# /users/123      → [id].jl (single dynamic)
# /users/123/edit → [...rest].jl (catch-all for multi-segment)""", language="julia", show_copy=false)
        ),

        Suite.Separator(),

        # Key Takeaways
        Suite.Alert(class="mt-12",
            Suite.AlertTitle("Key Takeaways"),
            Suite.AlertDescription(
                Ul(:class => "space-y-3 mt-2",
                    Li(Strong("[param].jl"), " — Matches a single URL segment"),
                    Li(Strong("[...param].jl"), " — Matches any remaining path (catch-all)"),
                    Li(Strong("params[:name]"), " — Access parameters via function argument"),
                    Li(Strong("use_params()"), " — Reactive hook for components"),
                    Li(Strong("parse(Int, ...)"), " — Convert string params to proper types"),
                    Li(Strong("Static > Dynamic > Catch-All"), " — Route priority order")
                )
            )
        ),

    )
end

# Export the page component
DynamicRoutes
