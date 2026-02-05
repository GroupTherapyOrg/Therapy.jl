# Suspense & Await - Declarative Loading Boundaries
#
# Deep dive into Suspense and Await for handling loading states.

function Suspense_Page()
    BookLayout("/book/async/suspense/",
        # Header
        Div(:class => "py-8 border-b border-warm-200 dark:border-warm-700",
            Span(:class => "text-sm text-accent-700 dark:text-accent-400 font-medium", "Part 4 · Async"),
            H1(:class => "text-4xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-2 mb-4",
                "Suspense & Await"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 max-w-3xl",
                "Suspense and Await let you declaratively handle loading states. Instead of ",
                "manually checking ", Code(:class => "text-accent-700 dark:text-accent-400", "resource.loading"),
                " everywhere, you define boundaries where fallback UI appears automatically."
            )
        ),

        # The Problem Suspense Solves
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "The Problem Suspense Solves"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Without Suspense, every component that uses async data needs to handle loading states ",
                "manually. This leads to repetitive, cluttered code."
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-300 mb-4",
                        "❌ Without Suspense"
                    ),
                    CodeBlock("""function UserProfile()
    if user.loading
        return P("Loading user...")
    end
    if user.error !== nothing
        return P("Error: ", user.error)
    end
    if posts.loading
        return P("Loading posts...")
    end
    # Finally, the actual content
    Div(
        H2(user().name),
        PostList(posts = posts())
    )
end""", "neutral")
                ),
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-accent-800 dark:text-accent-300 mb-4",
                        "✓ With Suspense"
                    ),
                    CodeBlock("""function UserProfile()
    Suspense(
        fallback = () -> P("Loading...")
    ) do
        # Just the content!
        Div(
            H2(user().name),
            PostList(posts = posts())
        )
    end
end""", "emerald")
                )
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "Suspense moves the loading logic out of your component, letting you focus on ",
                "displaying data. The fallback appears automatically while any resource inside is loading."
            )
        ),

        # How Suspense Works
        Section(:class => "py-12 bg-warm-100 dark:bg-warm-900 rounded-lg border border-warm-200 dark:border-warm-700 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "How Suspense Works"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Suspense creates a \"boundary\" that tracks all resources read within its children. ",
                "Here's the flow:"
            ),
            Div(:class => "space-y-4 mt-8",
                FlowStep("1", "Suspense renders its children"),
                FlowStep("2", "As children render, they read from resources"),
                FlowStep("3", "Each resource registers with the Suspense context"),
                FlowStep("4", "If any resource is loading, Suspense shows the fallback"),
                FlowStep("5", "When all resources are ready, Suspense shows the children"),
                FlowStep("6", "If resources refetch later, the fallback appears again")
            ),
            CodeBlock("""# Conceptually, Suspense does something like this:
function Suspense(children; fallback)
    # Track all resources read in children
    tracked_resources = discover_resources(children)

    # Check if any are loading
    if any(r -> r.loading, tracked_resources)
        return fallback()
    else
        return children()
    end
end""")
        ),

        # Basic Suspense Usage
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Basic Suspense Usage"
            ),
            CodeBlock("""user = create_resource(() -> user_id(), id -> fetch_user(id))

# Basic usage with do-block
Suspense(fallback = () -> P("Loading...")) do
    UserProfile(user = user())
end

# Or with explicit keyword syntax
Suspense(
    fallback = () -> Div(:class => "spinner"),
    children = () -> UserProfile(user = user())
)

# The fallback can be any VNode
Suspense(
    fallback = () -> Div(:class => "skeleton",
        Div(:class => "h-12 bg-warm-200 rounded"),
        Div(:class => "h-4 bg-warm-200 rounded w-3/4 mt-4"),
        Div(:class => "h-4 bg-warm-200 rounded w-1/2 mt-2")
    )
) do
    UserCard(user = user())
end"""),
            InfoBox("Fallback is a Function",
                "The fallback is a function () -> VNode, not a VNode directly. " *
                "This ensures the fallback is only rendered when needed, not evaluated upfront."
            )
        ),

        # Multiple Resources in Suspense
        Section(:class => "py-12 bg-warm-100 dark:bg-warm-900 rounded-lg border border-warm-200 dark:border-warm-700 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Multiple Resources"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "A single Suspense boundary can track multiple resources. The fallback shows until ",
                "ALL resources are ready."
            ),
            CodeBlock("""user = create_resource(() -> fetch_user(user_id()))
posts = create_resource(() -> fetch_posts(user_id()))
comments = create_resource(() -> fetch_comments(user_id()))

# All three resources must be ready before children render
Suspense(fallback = () -> PageSkeleton()) do
    Div(
        UserCard(user = user()),
        PostList(posts = posts()),
        CommentList(comments = comments())
    )
end

# Timeline:
# 0ms - All three start loading, fallback shows
# 100ms - user ready (still showing fallback)
# 200ms - posts ready (still showing fallback)
# 300ms - comments ready (now shows children!)"""),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "This \"all-or-nothing\" behavior is good for preventing jarring partial UI, ",
                "but can make slower resources bottleneck everything. See Nested Suspense below ",
                "for more granular control."
            )
        ),

        # Nested Suspense
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Nested Suspense Boundaries"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Create multiple Suspense boundaries for independent loading states. Faster content ",
                "appears immediately while slower content is still loading."
            ),
            CodeBlock("""function Dashboard()
    user = create_resource(() -> fetch_user())           # 100ms
    notifications = create_resource(() -> fetch_notifs()) # 50ms
    analytics = create_resource(() -> fetch_analytics())  # 500ms

    Div(:class => "grid grid-cols-3",
        # Fast: appears at 50ms
        Suspense(fallback = () -> NotifSkeleton()) do
            NotificationPanel(data = notifications())
        end,

        # Medium: appears at 100ms
        Suspense(fallback = () -> UserSkeleton()) do
            UserProfile(user = user())
        end,

        # Slow: appears at 500ms
        Suspense(fallback = () -> AnalyticsSkeleton()) do
            AnalyticsChart(data = analytics())
        end
    )
end"""),
            InfoBox("Progressive Loading",
                "Nested Suspense creates a progressive loading experience. Each section " *
                "loads independently, so users see content as soon as it's ready instead " *
                "of waiting for everything."
            )
        ),

        # Await Component
        Section(:class => "py-12 bg-warm-100 dark:bg-warm-900 rounded-lg border border-warm-200 dark:border-warm-700 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "The Await Component"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Await is syntactic sugar for the common case of waiting on a single resource ",
                "and binding its data directly. It's simpler than Suspense when you only have one resource."
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-300 mb-4",
                        "Suspense Pattern"
                    ),
                    CodeBlock("""Suspense(
    fallback = () -> P("Loading...")
) do
    data = user()
    if data !== nothing
        UserCard(user = data)
    end
end""", "neutral")
                ),
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-accent-800 dark:text-accent-300 mb-4",
                        "Await Pattern"
                    ),
                    CodeBlock("""Await(user;
    fallback = () -> P("Loading...")
) do data
    # data is passed directly!
    UserCard(user = data)
end""", "emerald")
                )
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "Await passes the resolved resource data directly to your callback. You don't ",
                "need to call ", Code(:class => "text-accent-700 dark:text-accent-400", "resource()"),
                " yourself—it's already unwrapped."
            )
        ),

        # Await Syntax Options
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Await Syntax Options"
            ),
            CodeBlock("""user = create_resource(() -> fetch_user(1))

# Option 1: do-block with keyword fallback
Await(user; fallback = () -> Spinner()) do data
    P("Hello, ", data.name)
end

# Option 2: Positional arguments
Await(user, data -> P("Hello, ", data.name); fallback = () -> Spinner())

# Option 3: No fallback (renders nothing while loading)
Await(user) do data
    P("Hello, ", data.name)
end"""),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "The do-block form is most common. The ", Code(:class => "text-accent-700 dark:text-accent-400", "data"),
                " parameter receives the resolved value from the resource when it's ready."
            )
        ),

        # SSR with Suspense
        Section(:class => "py-12 bg-warm-100 dark:bg-warm-900 rounded-lg border border-warm-200 dark:border-warm-700 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Suspense and SSR"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "During server-side rendering, Suspense evaluates the current state and renders appropriately."
            ),
            CodeBlock("""# On the server, render_to_string checks resource state:

# If resources are loading (async fetch in progress):
# -> Renders the fallback to HTML
html = render_to_string(MyPage())
# Output: <div class="skeleton">Loading...</div>

# If resources are already ready (sync data or cached):
# -> Renders the actual content
html = render_to_string(MyPage())
# Output: <div class="user-card"><h2>Alice</h2>...</div>

# The client then hydrates and resources may refetch
# based on whether the data is still valid"""),
            InfoBox("Hydration",
                "When the page hydrates on the client, resources will check their state. " *
                "If the server-rendered fallback is showing but data is now available, " *
                "the content will swap in automatically."
            )
        ),

        # When to Use Suspense vs Await
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Suspense vs Await: When to Use Each"
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(:class => "bg-warm-50 dark:bg-warm-900 rounded-lg border border-warm-200 dark:border-warm-800 p-6",
                    H3(:class => "text-xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-4",
                        "Use Suspense When..."
                    ),
                    Ul(:class => "space-y-2 text-warm-600 dark:text-warm-400",
                        Li("You have ", Strong("multiple resources")),
                        Li("You want a ", Strong("loading boundary"), " around a section"),
                        Li("Children need to access ", Strong("multiple data sources")),
                        Li("You want ", Strong("nested loading states"))
                    )
                ),
                Div(:class => "bg-warm-50 dark:bg-warm-900 rounded-lg border border-warm-200 dark:border-warm-800 p-6",
                    H3(:class => "text-xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-4",
                        "Use Await When..."
                    ),
                    Ul(:class => "space-y-2 text-warm-600 dark:text-warm-400",
                        Li("You have a ", Strong("single resource")),
                        Li("You want ", Strong("data binding"), " in the callback"),
                        Li("The pattern is ", Strong("simple"), " and direct"),
                        Li("You prefer ", Strong("less nesting"))
                    )
                )
            )
        ),

        # Key Takeaways
        Section(:class => "py-12 bg-warm-50 dark:bg-warm-900/30 rounded-lg border border-warm-200 dark:border-warm-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-accent-900 dark:text-accent-200 mb-6",
                "Key Takeaways"
            ),
            Ul(:class => "space-y-3 text-accent-800 dark:text-accent-300",
                Li(Strong("Suspense creates loading boundaries"), " — it shows fallback while any tracked resource loads"),
                Li(Strong("Resources auto-register"), " — reading a resource inside Suspense automatically tracks it"),
                Li(Strong("Nested Suspense enables progressive loading"), " — fast content appears first"),
                Li(Strong("Await is sugar for single resources"), " — it passes resolved data directly to your callback"),
                Li(Strong("SSR compatible"), " — Suspense renders fallback or content based on current state")
            )
        ),

    )
end

# Helper Components

function FlowStep(number, text)
    Div(:class => "flex items-start gap-4",
        Span(:class => "flex-shrink-0 w-8 h-8 bg-accent-700 dark:bg-accent-600 text-white rounded-full flex items-center justify-center font-semibold text-sm", number),
        P(:class => "pt-1 text-warm-600 dark:text-warm-300", text)
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

# Export the page component
Suspense_Page
