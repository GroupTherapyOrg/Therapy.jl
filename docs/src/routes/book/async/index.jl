# Async Patterns - Part 4 of the Therapy.jl Book
#
# Overview hub for handling async data with Resources, Suspense, and Await.

import Suite

function AsyncIndex()
    BookLayout("/book/async/",
        # Header
        Div(:class => "py-8 border-b border-warm-200 dark:border-warm-700",
            Suite.Badge(variant="outline", "Part 4"),
            H1(:class => "text-4xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-2 mb-4",
                "Async Patterns"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 max-w-3xl",
                "Modern applications need to load data from servers, databases, and APIs. ",
                "Therapy.jl provides reactive primitives that make async data loading feel ",
                "as natural as working with local state."
            )
        ),

        # The Async Challenge
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "The Async Challenge"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Loading data asynchronously introduces complexity that doesn't exist with synchronous code. ",
                "You need to handle multiple states: loading, success, and error. You need to show appropriate ",
                "UI during each state. And you need to refetch data when dependencies change."
            ),
            Div(:class => "grid md:grid-cols-3 gap-6 mt-8",
                Suite.Card(class="text-center",
                    Suite.CardContent(class="pt-6",
                        Div(:class => "text-3xl mb-3", "⏳"),
                        H3(:class => "text-lg font-serif font-semibold text-warm-800 dark:text-warm-50 mb-2", "Loading"),
                        P(:class => "text-warm-600 dark:text-warm-400 text-sm", "What do you show while waiting?")
                    )
                ),
                Suite.Card(class="text-center",
                    Suite.CardContent(class="pt-6",
                        Div(:class => "text-3xl mb-3", "✓"),
                        H3(:class => "text-lg font-serif font-semibold text-warm-800 dark:text-warm-50 mb-2", "Success"),
                        P(:class => "text-warm-600 dark:text-warm-400 text-sm", "How do you display the data?")
                    )
                ),
                Suite.Card(class="text-center",
                    Suite.CardContent(class="pt-6",
                        Div(:class => "text-3xl mb-3", "✗"),
                        H3(:class => "text-lg font-serif font-semibold text-warm-800 dark:text-warm-50 mb-2", "Error"),
                        P(:class => "text-warm-600 dark:text-warm-400 text-sm", "How do you handle failures?")
                    )
                )
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "Therapy.jl's async primitives—", Strong("Resources"), ", ", Strong("Suspense"),
                ", and ", Strong("Await"), "—provide a declarative way to handle all these states ",
                "while keeping your components clean and focused on what matters: displaying data."
            )
        ),

        Suite.Separator(),

        # Chapters in This Section
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Chapters in This Section"
            ),
            Div(:class => "grid md:grid-cols-2 gap-6",
                A(:href => "./resources",
                  :class => "block group",
                    Suite.Card(class="h-full transition-colors hover:border-accent-400 dark:hover:border-accent-600",
                        Suite.CardHeader(
                            Suite.CardTitle(:class => "font-serif group-hover:text-accent-700 dark:group-hover:text-accent-400", "Resources"),
                            Suite.CardDescription(
                                Code(:class => "text-sm text-accent-700 dark:text-accent-400", "create_resource")
                            )
                        ),
                        Suite.CardContent(
                            P(:class => "text-warm-600 dark:text-warm-400 text-sm", "Reactive async data loading that automatically refetches when dependencies change.")
                        )
                    )
                ),
                A(:href => "./suspense",
                  :class => "block group",
                    Suite.Card(class="h-full transition-colors hover:border-accent-400 dark:hover:border-accent-600",
                        Suite.CardHeader(
                            Suite.CardTitle(:class => "font-serif group-hover:text-accent-700 dark:group-hover:text-accent-400", "Suspense & Await"),
                            Suite.CardDescription(
                                Code(:class => "text-sm text-accent-700 dark:text-accent-400", "Suspense / Await")
                            )
                        ),
                        Suite.CardContent(
                            P(:class => "text-warm-600 dark:text-warm-400 text-sm", "Declarative loading boundaries that show fallback UI while resources load.")
                        )
                    )
                ),
                A(:href => "./patterns",
                  :class => "block group",
                    Suite.Card(class="h-full transition-colors hover:border-accent-400 dark:hover:border-accent-600",
                        Suite.CardHeader(
                            Suite.CardTitle(:class => "font-serif group-hover:text-accent-700 dark:group-hover:text-accent-400", "Async Patterns"),
                            Suite.CardDescription(
                                Code(:class => "text-sm text-accent-700 dark:text-accent-400", "Patterns")
                            )
                        ),
                        Suite.CardContent(
                            P(:class => "text-warm-600 dark:text-warm-400 text-sm", "Common patterns for error handling, refetching, caching, and optimistic updates.")
                        )
                    )
                )
            )
        ),

        Suite.Separator(),

        # Quick Overview
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Quick Overview"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Here's a glimpse of what async data loading looks like in Therapy.jl:"
            ),
            Suite.CodeBlock(
                """# Create a resource that fetches user data
user_id, set_user_id = create_signal(1)

user = create_resource(
    () -> user_id(),           # Source: triggers refetch when changed
    id -> fetch_user(id)       # Fetcher: loads data for this id
)

# Wrap in Suspense for declarative loading states
Suspense(fallback = () -> Spinner()) do
    # This only renders when user data is ready
    UserProfile(
        name = user().name,
        email = user().email
    )
end

# Change the user_id - resource automatically refetches!
set_user_id(2)  # Shows spinner, then new user""",
                language="julia"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "The key insight is that ", Strong("Resources"),
                " make async data reactive, and ", Strong("Suspense"),
                " handles the loading states declaratively. You don't need manual ",
                Code(:class => "text-accent-700 dark:text-accent-400", "isLoading"),
                " flags or explicit state management."
            )
        ),

        Suite.Separator(),

        # Resource at a Glance
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Resource at a Glance"
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-300 mb-4",
                        "Creating a Resource"
                    ),
                    Suite.CodeBlock(
                        """# With reactive source
user = create_resource(
    () -> user_id(),      # Dependency
    id -> fetch_user(id)  # Fetcher
)

# One-time fetch (no source)
config = create_resource(
    () -> load_config()
)""",
                        language="julia",
                        show_copy=false
                    )
                ),
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-300 mb-4",
                        "Reading State"
                    ),
                    Suite.CodeBlock(
                        """# Check loading state
user.loading    # Bool

# Check for errors
user.error      # Exception or nothing

# Read the data
user()          # Returns data or nothing

# Manual refetch
refetch!(user)""",
                        language="julia",
                        show_copy=false
                    )
                )
            )
        ),

        Suite.Separator(),

        # Suspense at a Glance
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Suspense at a Glance"
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-300 mb-4",
                        "Basic Suspense"
                    ),
                    Suite.CodeBlock(
                        """Suspense(
    fallback = () -> P("Loading...")
) do
    # Show when resources ready
    UserProfile(user = user())
end""",
                        language="julia",
                        show_copy=false
                    )
                ),
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-300 mb-4",
                        "Await (Single Resource)"
                    ),
                    Suite.CodeBlock(
                        """Await(user;
    fallback = () -> Spinner()
) do data
    # data is the resolved value
    P("Hello, ", data.name)
end""",
                        language="julia",
                        show_copy=false
                    )
                )
            ),
            Suite.Alert(class="mt-8",
                Suite.AlertTitle("Suspense vs Await"),
                Suite.AlertDescription(
                    "Use Suspense when you have multiple resources or want to define a loading boundary. " *
                    "Use Await when you have a single resource and want to bind its data directly."
                )
            )
        ),

        Suite.Separator(),

        # How It All Connects
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "How It All Connects"
            ),
            Div(:class => "space-y-4",
                Div(:class => "flex items-start gap-4",
                    Suite.Badge(variant="default", "1"),
                    P(:class => "pt-0.5 text-warm-600 dark:text-warm-300", "You create a Resource with a fetcher function")
                ),
                Div(:class => "flex items-start gap-4",
                    Suite.Badge(variant="default", "2"),
                    P(:class => "pt-0.5 text-warm-600 dark:text-warm-300", "The Resource tracks a source signal for dependencies")
                ),
                Div(:class => "flex items-start gap-4",
                    Suite.Badge(variant="default", "3"),
                    P(:class => "pt-0.5 text-warm-600 dark:text-warm-300", "When the source changes, the Resource refetches automatically")
                ),
                Div(:class => "flex items-start gap-4",
                    Suite.Badge(variant="default", "4"),
                    P(:class => "pt-0.5 text-warm-600 dark:text-warm-300", "Suspense boundaries display fallback UI during loading")
                ),
                Div(:class => "flex items-start gap-4",
                    Suite.Badge(variant="default", "5"),
                    P(:class => "pt-0.5 text-warm-600 dark:text-warm-300", "When data arrives, Suspense shows the actual content")
                ),
                Div(:class => "flex items-start gap-4",
                    Suite.Badge(variant="default", "6"),
                    P(:class => "pt-0.5 text-warm-600 dark:text-warm-300", "Errors can be caught and displayed gracefully")
                )
            ),
            P(:class => "mt-6 text-warm-700 dark:text-warm-400 font-medium",
                "This reactive flow means your UI always reflects the current state of your data, ",
                "without manual orchestration."
            )
        ),

    )
end

# Export the page component
AsyncIndex
