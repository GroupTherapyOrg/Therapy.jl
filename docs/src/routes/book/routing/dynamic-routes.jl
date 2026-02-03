# Dynamic Routes - Chapter 2 of Part 6
#
# Handling dynamic parameters and catch-all routes.

function DynamicRoutes()
    BookLayout(
        # Header
        Div(:class => "py-8 border-b border-neutral-300 dark:border-neutral-800",
            Span(:class => "text-sm text-emerald-700 dark:text-emerald-400 font-medium", "Part 6 · Chapter 2"),
            H1(:class => "text-4xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mt-2 mb-4",
                "Dynamic Routes"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 max-w-3xl",
                "Extract parameters from URLs using dynamic segments. Build user profiles, product pages, ",
                "and documentation sites with flexible URL patterns."
            )
        ),

        # Why Dynamic Routes?
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Why Dynamic Routes?"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "Most web applications have pages where part of the URL is variable: user IDs, product slugs, ",
                "blog post dates, or documentation paths. Dynamic routes let you handle these patterns with ",
                "a single route file."
            ),
            Div(:class => "grid md:grid-cols-3 gap-6 mt-8",
                ExampleCard("/users/123", "User ID", "Show user profile"),
                ExampleCard("/products/widget-pro", "Product slug", "Display product"),
                ExampleCard("/docs/api/signals", "Doc path", "Render documentation")
            ),
            P(:class => "text-neutral-600 dark:text-neutral-400 mt-6",
                "Without dynamic routes, you'd need a separate file for every possible URL—impossible for data-driven pages."
            )
        ),

        # Single Dynamic Segment
        Section(:class => "py-12 bg-neutral-50 dark:bg-neutral-900 rounded-lg border border-neutral-300 dark:border-neutral-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Single Dynamic Segment: [param].jl"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "Use square brackets to create a dynamic segment that matches any single path part:"
            ),
            CodeBlock("""# File: routes/users/[id].jl
# Matches: /users/123, /users/alice, /users/abc-def

(params) -> begin
    user_id = params[:id]  # "123", "alice", or "abc-def"

    Div(:class => "container mx-auto py-8",
        H1("User Profile"),
        P("User ID: ", user_id),

        # Fetch user data using the ID
        UserDetails(id = user_id)
    )
end"""),
            H3(:class => "text-xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mt-8 mb-4",
                "Multiple Dynamic Segments"
            ),
            CodeBlock("""# File: routes/[category]/[product].jl
# Matches: /electronics/laptop, /books/julia-guide

(params) -> begin
    category = params[:category]  # "electronics", "books"
    product = params[:product]    # "laptop", "julia-guide"

    Div(
        Breadcrumb(category, product),
        ProductPage(category = category, slug = product)
    )
end""", "neutral"),
            H3(:class => "text-xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mt-8 mb-4",
                "Nested Dynamic Segments"
            ),
            CodeBlock("""# Directory structure for /users/:id/posts/:post_id
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
end""", "neutral")
        ),

        # Catch-All Routes
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Catch-All Routes: [...param].jl"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "The spread syntax ", Code(:class => "text-emerald-700 dark:text-emerald-400", "[...param]"),
                " matches any number of path segments. Perfect for documentation, file browsers, or nested content."
            ),
            CodeBlock("""# File: routes/docs/[...slug].jl
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
end"""),
            InfoBox("Catch-All Captures the Rest",
                "The catch-all parameter captures everything after the prefix. For /docs/api/signals, " *
                "params[:slug] is \"api/signals\" (a single string), not an array."
            ),
            H3(:class => "text-xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mt-8 mb-4",
                "Catch-All for 404 Pages"
            ),
            CodeBlock("""# File: routes/[...404].jl
# Matches any unmatched route (lowest priority)

(params) -> begin
    path = get(params, :404, "/")

    Div(:class => "min-h-screen flex items-center justify-center",
        Div(:class => "text-center",
            H1(:class => "text-6xl font-bold text-neutral-300", "404"),
            H2(:class => "text-2xl mt-4", "Page Not Found"),
            P(:class => "text-neutral-600 mt-2",
                "The path ", Code(path), " doesn't exist."
            ),
            A(:href => "/", :class => "mt-4 inline-block text-emerald-700 hover:underline",
                "← Return Home"
            )
        )
    )
end""", "neutral")
        ),

        # Accessing Parameters
        Section(:class => "py-12 bg-neutral-50 dark:bg-neutral-900 rounded-lg border border-neutral-300 dark:border-neutral-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Accessing Parameters"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "There are two ways to access route parameters:"
            ),
            H3(:class => "text-xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mt-8 mb-4",
                "1. Function Argument (Route Files)"
            ),
            CodeBlock("""# In route files, params are passed as the first argument
(params) -> begin
    id = params[:id]           # Direct access
    id = get(params, :id, "0") # With default
    # ...
end"""),
            H3(:class => "text-xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mt-8 mb-4",
                "2. use_params() Hook (Components)"
            ),
            CodeBlock("""# In any component, use the reactive hook
function UserProfile()
    # Get all params
    params = use_params()
    user_id = params[:id]

    # Or get specific param
    user_id = use_params(:id)

    # Or with default
    user_id = use_params(:id, "unknown")

    Div(H1("User: ", user_id))
end""", "neutral"),
            InfoBox("Reactive Updates",
                "use_params() returns reactive values. If you navigate from /users/1 to /users/2 " *
                "using client-side navigation, components using use_params() will automatically " *
                "re-render with the new values."
            )
        ),

        # Type Conversion
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Parameter Type Conversion"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "Route parameters are always strings. Convert them as needed:"
            ),
            CodeBlock("""(params) -> begin
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
end"""),
            WarnBox("Always Validate Input",
                "Never trust URL parameters. An attacker could request /users/../../secrets. " *
                "Always validate and sanitize before using params in database queries or file paths."
            )
        ),

        # Common Patterns
        Section(:class => "py-12 bg-neutral-50 dark:bg-neutral-900 rounded-lg border border-neutral-300 dark:border-neutral-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Common Patterns"
            ),
            H3(:class => "text-xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mt-8 mb-4",
                "Blog with Date URLs"
            ),
            CodeBlock("""# routes/blog/[year]/[month]/[slug].jl
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
end"""),
            H3(:class => "text-xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mt-8 mb-4",
                "API-Style Routes"
            ),
            CodeBlock("""# routes/api/v1/[...path].jl
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
end""", "neutral"),
            H3(:class => "text-xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mt-8 mb-4",
                "Localized Routes"
            ),
            CodeBlock("""# routes/[locale]/products/[slug].jl
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
end""", "neutral")
        ),

        # Route Priority Rules
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Priority Rules"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "When paths could match multiple routes, Therapy.jl uses this priority:"
            ),
            Ol(:class => "list-decimal list-inside space-y-4 text-neutral-600 dark:text-neutral-400",
                Li(
                    Strong("Static over dynamic"), " — ",
                    Code(:class => "text-emerald-700 dark:text-emerald-400", "users/new.jl"),
                    " beats ",
                    Code(:class => "text-emerald-700 dark:text-emerald-400", "users/[id].jl"),
                    " for ", Code(:class => "text-sm", "/users/new")
                ),
                Li(
                    Strong("Specific over general"), " — ",
                    Code(:class => "text-emerald-700 dark:text-emerald-400", "[id].jl"),
                    " beats ",
                    Code(:class => "text-emerald-700 dark:text-emerald-400", "[...slug].jl"),
                    " for single-segment paths"
                ),
                Li(
                    Strong("Deeper over shallower"), " — ",
                    Code(:class => "text-emerald-700 dark:text-emerald-400", "docs/api/[name].jl"),
                    " beats ",
                    Code(:class => "text-emerald-700 dark:text-emerald-400", "docs/[...path].jl"),
                    " for ", Code(:class => "text-sm", "/docs/api/signals")
                )
            ),
            CodeBlock("""# Given these routes:
routes/
├── users/
│   ├── new.jl        # 1. Static
│   ├── [id].jl       # 2. Single dynamic
│   └── [...rest].jl  # 3. Catch-all

# Requests resolve to:
# /users/new      → new.jl (static wins)
# /users/123      → [id].jl (single dynamic)
# /users/123/edit → [...rest].jl (catch-all for multi-segment)""", "neutral")
        ),

        # Key Takeaways
        Section(:class => "py-12 bg-emerald-50 dark:bg-emerald-950/30 rounded-lg border border-emerald-200 dark:border-emerald-900 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-emerald-900 dark:text-emerald-200 mb-6",
                "Key Takeaways"
            ),
            Ul(:class => "space-y-3 text-emerald-800 dark:text-emerald-300",
                Li("🔗 ", Strong("[param].jl"), " — Matches a single URL segment"),
                Li("📚 ", Strong("[...param].jl"), " — Matches any remaining path (catch-all)"),
                Li("📥 ", Strong("params[:name]"), " — Access parameters via function argument"),
                Li("⚡ ", Strong("use_params()"), " — Reactive hook for components"),
                Li("🔢 ", Strong("parse(Int, ...)"), " — Convert string params to proper types"),
                Li("📊 ", Strong("Static > Dynamic > Catch-All"), " — Route priority order")
            )
        ),

        # Navigation
        Div(:class => "py-8 flex justify-between border-t border-neutral-300 dark:border-neutral-800",
            A(:href => "./file-routing",
              :class => "inline-flex items-center text-neutral-600 dark:text-neutral-400 hover:text-emerald-700 dark:hover:text-emerald-400 transition-colors",
                Svg(:class => "mr-2 w-5 h-5", :fill => "none", :viewBox => "0 0 24 24", :stroke => "currentColor",
                    Path(:stroke_linecap => "round", :stroke_linejoin => "round", :stroke_width => "2", :d => "M11 17l-5-5m0 0l5-5m-5 5h12")
                ),
                "File-Based Routing"
            ),
            A(:href => "./client-navigation",
              :class => "inline-flex items-center text-neutral-600 dark:text-neutral-400 hover:text-emerald-700 dark:hover:text-emerald-400 transition-colors",
                "Client-Side Navigation",
                Svg(:class => "ml-2 w-5 h-5", :fill => "none", :viewBox => "0 0 24 24", :stroke => "currentColor",
                    Path(:stroke_linecap => "round", :stroke_linejoin => "round", :stroke_width => "2", :d => "M13 7l5 5m0 0l-5 5m5-5H6")
                )
            )
        )
    )
end

# Helper Components

function ExampleCard(url, param_name, description)
    Div(:class => "bg-white dark:bg-neutral-800 rounded-lg border border-neutral-300 dark:border-neutral-700 p-6 text-center",
        Code(:class => "text-emerald-700 dark:text-emerald-400 font-semibold", url),
        P(:class => "text-neutral-500 dark:text-neutral-500 text-sm mt-2", param_name),
        P(:class => "text-neutral-600 dark:text-neutral-400 text-sm mt-1", description)
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

function WarnBox(title, content)
    Div(:class => "mt-8 bg-amber-50 dark:bg-amber-950/30 rounded-lg border border-amber-200 dark:border-amber-900 p-6",
        H3(:class => "text-lg font-serif font-semibold text-amber-900 dark:text-amber-200 mb-2", title),
        P(:class => "text-amber-800 dark:text-amber-300", content)
    )
end

# Export the page component
DynamicRoutes
