# Async Patterns - Part 4 of the Therapy.jl Book
#
# Overview hub for handling async data with Resources, Suspense, and Await.

function AsyncIndex()
    BookLayout("/book/async/",
        # Header
        Div(:class => "py-8 border-b border-warm-200 dark:border-warm-900",
            Span(:class => "text-sm text-accent-700 dark:text-accent-400 font-medium", "Part 4"),
            H1(:class => "text-4xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-2 mb-4",
                "Async Patterns"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 max-w-3xl",
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
            P(:class => "text-lg text-warm-600 dark:text-warm-200 mb-6",
                "Loading data asynchronously introduces complexity that doesn't exist with synchronous code. ",
                "You need to handle multiple states: loading, success, and error. You need to show appropriate ",
                "UI during each state. And you need to refetch data when dependencies change."
            ),
            Div(:class => "grid md:grid-cols-3 gap-6 mt-8",
                StateCard("⏳", "Loading", "What do you show while waiting?"),
                StateCard("✓", "Success", "How do you display the data?"),
                StateCard("✗", "Error", "How do you handle failures?")
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "Therapy.jl's async primitives—", Strong("Resources"), ", ", Strong("Suspense"),
                ", and ", Strong("Await"), "—provide a declarative way to handle all these states ",
                "while keeping your components clean and focused on what matters: displaying data."
            )
        ),

        # Chapters in This Section
        Section(:class => "py-12 bg-warm-100 dark:bg-warm-800 rounded-lg border border-warm-200 dark:border-warm-900 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Chapters in This Section"
            ),
            Div(:class => "grid md:grid-cols-2 gap-6",
                ChapterCard(
                    "./resources",
                    "Resources",
                    "create_resource",
                    "Reactive async data loading that automatically refetches when dependencies change."
                ),
                ChapterCard(
                    "./suspense",
                    "Suspense & Await",
                    "Suspense / Await",
                    "Declarative loading boundaries that show fallback UI while resources load."
                ),
                ChapterCard(
                    "./patterns",
                    "Async Patterns",
                    "Patterns",
                    "Common patterns for error handling, refetching, caching, and optimistic updates."
                )
            )
        ),

        # Quick Overview
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Quick Overview"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 mb-6",
                "Here's a glimpse of what async data loading looks like in Therapy.jl:"
            ),
            CodeBlock("""# Create a resource that fetches user data
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
set_user_id(2)  # Shows spinner, then new user"""),

            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "The key insight is that ", Strong("Resources"),
                " make async data reactive, and ", Strong("Suspense"),
                " handles the loading states declaratively. You don't need manual ",
                Code(:class => "text-accent-700 dark:text-accent-400", "isLoading"),
                " flags or explicit state management."
            )
        ),

        # Resource at a Glance
        Section(:class => "py-12 bg-warm-100 dark:bg-warm-800 rounded-lg border border-warm-200 dark:border-warm-900 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Resource at a Glance"
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-200 mb-4",
                        "Creating a Resource"
                    ),
                    CodeBlock("""# With reactive source
user = create_resource(
    () -> user_id(),      # Dependency
    id -> fetch_user(id)  # Fetcher
)

# One-time fetch (no source)
config = create_resource(
    () -> load_config()
)""", "neutral")
                ),
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-200 mb-4",
                        "Reading State"
                    ),
                    CodeBlock("""# Check loading state
user.loading    # Bool

# Check for errors
user.error      # Exception or nothing

# Read the data
user()          # Returns data or nothing

# Manual refetch
refetch!(user)""", "neutral")
                )
            )
        ),

        # Suspense at a Glance
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Suspense at a Glance"
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-200 mb-4",
                        "Basic Suspense"
                    ),
                    CodeBlock("""Suspense(
    fallback = () -> P("Loading...")
) do
    # Show when resources ready
    UserProfile(user = user())
end""")
                ),
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-200 mb-4",
                        "Await (Single Resource)"
                    ),
                    CodeBlock("""Await(user;
    fallback = () -> Spinner()
) do data
    # data is the resolved value
    P("Hello, ", data.name)
end""")
                )
            ),
            InfoBox("Suspense vs Await",
                "Use Suspense when you have multiple resources or want to define a loading boundary. " *
                "Use Await when you have a single resource and want to bind its data directly."
            )
        ),

        # How It All Connects
        Section(:class => "py-12 bg-accent-50 dark:bg-accent-950/30 rounded-lg border border-accent-200 dark:border-accent-900 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-accent-900 dark:text-accent-200 mb-6",
                "How It All Connects"
            ),
            Div(:class => "space-y-4 text-accent-800 dark:text-accent-300",
                FlowStep("1", "You create a Resource with a fetcher function"),
                FlowStep("2", "The Resource tracks a source signal for dependencies"),
                FlowStep("3", "When the source changes, the Resource refetches automatically"),
                FlowStep("4", "Suspense boundaries display fallback UI during loading"),
                FlowStep("5", "When data arrives, Suspense shows the actual content"),
                FlowStep("6", "Errors can be caught and displayed gracefully")
            ),
            P(:class => "mt-6 text-accent-700 dark:text-accent-400 font-medium",
                "This reactive flow means your UI always reflects the current state of your data, ",
                "without manual orchestration."
            )
        ),

    )
end

# Helper Components

function StateCard(icon, title, description)
    Div(:class => "bg-warm-50 dark:bg-warm-900 rounded-lg border border-warm-200 dark:border-warm-800 p-6 text-center",
        Div(:class => "text-3xl mb-3", icon),
        H3(:class => "text-lg font-serif font-semibold text-warm-800 dark:text-warm-50 mb-2", title),
        P(:class => "text-warm-600 dark:text-warm-400 text-sm", description)
    )
end

function ChapterCard(href, title, code_preview, description)
    A(:href => href,
      :class => "block bg-warm-50 dark:bg-warm-900 rounded-lg border border-warm-200 dark:border-warm-800 p-6 hover:border-accent-400 dark:hover:border-accent-600 transition-colors group",
        H3(:class => "text-xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-2 group-hover:text-accent-700 dark:group-hover:text-accent-400", title),
        Code(:class => "text-sm text-accent-700 dark:text-accent-400", code_preview),
        P(:class => "text-warm-600 dark:text-warm-400 mt-3 text-sm", description)
    )
end

function CodeBlock(code, style="default")
    bg_class = if style == "emerald"
        "bg-accent-900 dark:bg-accent-950 border-accent-700"
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

function FlowStep(number, text)
    Div(:class => "flex items-start gap-4",
        Span(:class => "flex-shrink-0 w-8 h-8 bg-accent-700 dark:bg-accent-600 text-white rounded-full flex items-center justify-center font-semibold text-sm", number),
        P(:class => "pt-1", text)
    )
end

# Export the page component
AsyncIndex
