# Suspense & Await - Declarative Loading Boundaries
#
# Deep dive into Suspense and Await for handling loading states.

import Suite

function Suspense_Page()
    BookLayout("/book/async/suspense/",
        # Header
        Div(:class => "py-8 border-b border-warm-200 dark:border-warm-700",
            Suite.Badge(variant="outline", "Part 4 · Async"),
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
                        "Without Suspense"
                    ),
                    Suite.CodeBlock(
                        """function UserProfile()
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
end""",
                        language="julia",
                        show_copy=false
                    )
                ),
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-accent-800 dark:text-accent-300 mb-4",
                        "With Suspense"
                    ),
                    Suite.CodeBlock(
                        """function UserProfile()
    Suspense(
        fallback = () -> P("Loading...")
    ) do
        # Just the content!
        Div(
            H2(user().name),
            PostList(posts = posts())
        )
    end
end""",
                        language="julia",
                        show_copy=false
                    )
                )
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "Suspense moves the loading logic out of your component, letting you focus on ",
                "displaying data. The fallback appears automatically while any resource inside is loading."
            )
        ),

        Suite.Separator(),

        # How Suspense Works
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "How Suspense Works"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Suspense creates a \"boundary\" that tracks all resources read within its children. ",
                "Here's the flow:"
            ),
            Div(:class => "space-y-4 mt-8",
                Div(:class => "flex items-start gap-4",
                    Suite.Badge(variant="default", "1"),
                    P(:class => "pt-0.5 text-warm-600 dark:text-warm-300", "Suspense renders its children")
                ),
                Div(:class => "flex items-start gap-4",
                    Suite.Badge(variant="default", "2"),
                    P(:class => "pt-0.5 text-warm-600 dark:text-warm-300", "As children render, they read from resources")
                ),
                Div(:class => "flex items-start gap-4",
                    Suite.Badge(variant="default", "3"),
                    P(:class => "pt-0.5 text-warm-600 dark:text-warm-300", "Each resource registers with the Suspense context")
                ),
                Div(:class => "flex items-start gap-4",
                    Suite.Badge(variant="default", "4"),
                    P(:class => "pt-0.5 text-warm-600 dark:text-warm-300", "If any resource is loading, Suspense shows the fallback")
                ),
                Div(:class => "flex items-start gap-4",
                    Suite.Badge(variant="default", "5"),
                    P(:class => "pt-0.5 text-warm-600 dark:text-warm-300", "When all resources are ready, Suspense shows the children")
                ),
                Div(:class => "flex items-start gap-4",
                    Suite.Badge(variant="default", "6"),
                    P(:class => "pt-0.5 text-warm-600 dark:text-warm-300", "If resources refetch later, the fallback appears again")
                )
            ),
            Suite.CodeBlock(
                """# Conceptually, Suspense does something like this:
function Suspense(children; fallback)
    # Track all resources read in children
    tracked_resources = discover_resources(children)

    # Check if any are loading
    if any(r -> r.loading, tracked_resources)
        return fallback()
    else
        return children()
    end
end""",
                language="julia"
            )
        ),

        Suite.Separator(),

        # Basic Suspense Usage
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Basic Suspense Usage"
            ),
            Suite.CodeBlock(
                """user = create_resource(() -> user_id(), id -> fetch_user(id))

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
end""",
                language="julia"
            ),
            Suite.Alert(class="mt-8",
                Suite.AlertTitle("Fallback is a Function"),
                Suite.AlertDescription(
                    "The fallback is a function () -> VNode, not a VNode directly. " *
                    "This ensures the fallback is only rendered when needed, not evaluated upfront."
                )
            )
        ),

        Suite.Separator(),

        # Multiple Resources in Suspense
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Multiple Resources"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "A single Suspense boundary can track multiple resources. The fallback shows until ",
                "ALL resources are ready."
            ),
            Suite.CodeBlock(
                """user = create_resource(() -> fetch_user(user_id()))
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
# 300ms - comments ready (now shows children!)""",
                language="julia"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "This \"all-or-nothing\" behavior is good for preventing jarring partial UI, ",
                "but can make slower resources bottleneck everything. See Nested Suspense below ",
                "for more granular control."
            )
        ),

        Suite.Separator(),

        # Nested Suspense
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Nested Suspense Boundaries"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Create multiple Suspense boundaries for independent loading states. Faster content ",
                "appears immediately while slower content is still loading."
            ),
            Suite.CodeBlock(
                """function Dashboard()
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
end""",
                language="julia"
            ),
            Suite.Alert(class="mt-8",
                Suite.AlertTitle("Progressive Loading"),
                Suite.AlertDescription(
                    "Nested Suspense creates a progressive loading experience. Each section " *
                    "loads independently, so users see content as soon as it's ready instead " *
                    "of waiting for everything."
                )
            )
        ),

        Suite.Separator(),

        # Await Component
        Section(:class => "py-12",
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
                    Suite.CodeBlock(
                        """Suspense(
    fallback = () -> P("Loading...")
) do
    data = user()
    if data !== nothing
        UserCard(user = data)
    end
end""",
                        language="julia",
                        show_copy=false
                    )
                ),
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-accent-800 dark:text-accent-300 mb-4",
                        "Await Pattern"
                    ),
                    Suite.CodeBlock(
                        """Await(user;
    fallback = () -> P("Loading...")
) do data
    # data is passed directly!
    UserCard(user = data)
end""",
                        language="julia",
                        show_copy=false
                    )
                )
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "Await passes the resolved resource data directly to your callback. You don't ",
                "need to call ", Code(:class => "text-accent-700 dark:text-accent-400", "resource()"),
                " yourself—it's already unwrapped."
            )
        ),

        Suite.Separator(),

        # Await Syntax Options
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Await Syntax Options"
            ),
            Suite.CodeBlock(
                """user = create_resource(() -> fetch_user(1))

# Option 1: do-block with keyword fallback
Await(user; fallback = () -> Spinner()) do data
    P("Hello, ", data.name)
end

# Option 2: Positional arguments
Await(user, data -> P("Hello, ", data.name); fallback = () -> Spinner())

# Option 3: No fallback (renders nothing while loading)
Await(user) do data
    P("Hello, ", data.name)
end""",
                language="julia"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "The do-block form is most common. The ", Code(:class => "text-accent-700 dark:text-accent-400", "data"),
                " parameter receives the resolved value from the resource when it's ready."
            )
        ),

        Suite.Separator(),

        # SSR with Suspense
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Suspense and SSR"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "During server-side rendering, Suspense evaluates the current state and renders appropriately."
            ),
            Suite.CodeBlock(
                """# On the server, render_to_string checks resource state:

# If resources are loading (async fetch in progress):
# -> Renders the fallback to HTML
html = render_to_string(MyPage())
# Output: <div class="skeleton">Loading...</div>

# If resources are already ready (sync data or cached):
# -> Renders the actual content
html = render_to_string(MyPage())
# Output: <div class="user-card"><h2>Alice</h2>...</div>

# The client then hydrates and resources may refetch
# based on whether the data is still valid""",
                language="julia"
            ),
            Suite.Alert(class="mt-8",
                Suite.AlertTitle("Hydration"),
                Suite.AlertDescription(
                    "When the page hydrates on the client, resources will check their state. " *
                    "If the server-rendered fallback is showing but data is now available, " *
                    "the content will swap in automatically."
                )
            )
        ),

        Suite.Separator(),

        # When to Use Suspense vs Await
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Suspense vs Await: When to Use Each"
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Suite.Card(
                    Suite.CardHeader(
                        Suite.CardTitle(:class => "font-serif", "Use Suspense When...")
                    ),
                    Suite.CardContent(
                        Ul(:class => "space-y-2 text-warm-600 dark:text-warm-400",
                            Li("You have ", Strong("multiple resources")),
                            Li("You want a ", Strong("loading boundary"), " around a section"),
                            Li("Children need to access ", Strong("multiple data sources")),
                            Li("You want ", Strong("nested loading states"))
                        )
                    )
                ),
                Suite.Card(
                    Suite.CardHeader(
                        Suite.CardTitle(:class => "font-serif", "Use Await When...")
                    ),
                    Suite.CardContent(
                        Ul(:class => "space-y-2 text-warm-600 dark:text-warm-400",
                            Li("You have a ", Strong("single resource")),
                            Li("You want ", Strong("data binding"), " in the callback"),
                            Li("The pattern is ", Strong("simple"), " and direct"),
                            Li("You prefer ", Strong("less nesting"))
                        )
                    )
                )
            )
        ),

        # Key Takeaways
        Suite.Alert(class="mt-12",
            Suite.AlertTitle("Key Takeaways"),
            Suite.AlertDescription(
                Ul(:class => "space-y-2 list-disc pl-5 mt-2",
                    Li(Strong("Suspense creates loading boundaries"), " — it shows fallback while any tracked resource loads"),
                    Li(Strong("Resources auto-register"), " — reading a resource inside Suspense automatically tracks it"),
                    Li(Strong("Nested Suspense enables progressive loading"), " — fast content appears first"),
                    Li(Strong("Await is sugar for single resources"), " — it passes resolved data directly to your callback"),
                    Li(Strong("SSR compatible"), " — Suspense renders fallback or content based on current state")
                )
            )
        ),

    )
end

# Export the page component
Suspense_Page
