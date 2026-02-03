# Async Patterns - Part 4 of the Therapy.jl Book
#
# Overview hub for handling async data with Resources, Suspense, and Await.

function Index()
    Fragment(
        # Header
        Div(:class => "py-8 border-b border-neutral-300 dark:border-neutral-800",
            Span(:class => "text-sm text-emerald-700 dark:text-emerald-400 font-medium", "Part 4"),
            H1(:class => "text-4xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mt-2 mb-4",
                "Async Patterns"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 max-w-3xl",
                "Modern applications need to load data from servers, databases, and APIs. ",
                "Therapy.jl provides reactive primitives that make async data loading feel ",
                "as natural as working with local state."
            )
        ),

        # The Async Challenge
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "The Async Challenge"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "Loading data asynchronously introduces complexity that doesn't exist with synchronous code. ",
                "You need to handle multiple states: loading, success, and error. You need to show appropriate ",
                "UI during each state. And you need to refetch data when dependencies change."
            ),
            Div(:class => "grid md:grid-cols-3 gap-6 mt-8",
                StateCard("⏳", "Loading", "What do you show while waiting?"),
                StateCard("✓", "Success", "How do you display the data?"),
                StateCard("✗", "Error", "How do you handle failures?")
            ),
            P(:class => "text-neutral-600 dark:text-neutral-400 mt-6",
                "Therapy.jl's async primitives—", Strong("Resources"), ", ", Strong("Suspense"),
                ", and ", Strong("Await"), "—provide a declarative way to handle all these states ",
                "while keeping your components clean and focused on what matters: displaying data."
            )
        ),

        # Chapters in This Section
        Section(:class => "py-12 bg-neutral-50 dark:bg-neutral-900 rounded-lg border border-neutral-300 dark:border-neutral-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
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
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Quick Overview"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
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

            P(:class => "text-neutral-600 dark:text-neutral-400 mt-6",
                "The key insight is that ", Strong("Resources"),
                " make async data reactive, and ", Strong("Suspense"),
                " handles the loading states declaratively. You don't need manual ",
                Code(:class => "text-emerald-700 dark:text-emerald-400", "isLoading"),
                " flags or explicit state management."
            )
        ),

        # Resource at a Glance
        Section(:class => "py-12 bg-neutral-50 dark:bg-neutral-900 rounded-lg border border-neutral-300 dark:border-neutral-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Resource at a Glance"
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-neutral-800 dark:text-neutral-200 mb-4",
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
                    H3(:class => "text-lg font-serif font-semibold text-neutral-800 dark:text-neutral-200 mb-4",
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
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Suspense at a Glance"
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-neutral-800 dark:text-neutral-200 mb-4",
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
                    H3(:class => "text-lg font-serif font-semibold text-neutral-800 dark:text-neutral-200 mb-4",
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
        Section(:class => "py-12 bg-emerald-50 dark:bg-emerald-950/30 rounded-lg border border-emerald-200 dark:border-emerald-900 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-emerald-900 dark:text-emerald-200 mb-6",
                "How It All Connects"
            ),
            Div(:class => "space-y-4 text-emerald-800 dark:text-emerald-300",
                FlowStep("1", "You create a Resource with a fetcher function"),
                FlowStep("2", "The Resource tracks a source signal for dependencies"),
                FlowStep("3", "When the source changes, the Resource refetches automatically"),
                FlowStep("4", "Suspense boundaries display fallback UI during loading"),
                FlowStep("5", "When data arrives, Suspense shows the actual content"),
                FlowStep("6", "Errors can be caught and displayed gracefully")
            ),
            P(:class => "mt-6 text-emerald-700 dark:text-emerald-400 font-medium",
                "This reactive flow means your UI always reflects the current state of your data, ",
                "without manual orchestration."
            )
        ),

        # Navigation
        Div(:class => "py-8 flex justify-between border-t border-neutral-300 dark:border-neutral-800",
            A(:href => "../components/",
              :class => "inline-flex items-center text-neutral-600 dark:text-neutral-400 hover:text-emerald-700 dark:hover:text-emerald-400 transition-colors",
                Svg(:class => "mr-2 w-5 h-5", :fill => "none", :viewBox => "0 0 24 24", :stroke => "currentColor",
                    Path(:stroke_linecap => "round", :stroke_linejoin => "round", :stroke_width => "2", :d => "M11 17l-5-5m0 0l5-5m-5 5h12")
                ),
                "Components"
            ),
            A(:href => "./resources",
              :class => "inline-flex items-center text-neutral-600 dark:text-neutral-400 hover:text-emerald-700 dark:hover:text-emerald-400 transition-colors",
                "Resources",
                Svg(:class => "ml-2 w-5 h-5", :fill => "none", :viewBox => "0 0 24 24", :stroke => "currentColor",
                    Path(:stroke_linecap => "round", :stroke_linejoin => "round", :stroke_width => "2", :d => "M13 7l5 5m0 0l-5 5m5-5H6")
                )
            )
        )
    )
end

# Helper Components

function StateCard(icon, title, description)
    Div(:class => "bg-white dark:bg-neutral-800 rounded-lg border border-neutral-300 dark:border-neutral-700 p-6 text-center",
        Div(:class => "text-3xl mb-3", icon),
        H3(:class => "text-lg font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-2", title),
        P(:class => "text-neutral-600 dark:text-neutral-400 text-sm", description)
    )
end

function ChapterCard(href, title, code_preview, description)
    A(:href => href,
      :class => "block bg-white dark:bg-neutral-800 rounded-lg border border-neutral-300 dark:border-neutral-700 p-6 hover:border-emerald-400 dark:hover:border-emerald-600 transition-colors group",
        H3(:class => "text-xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-2 group-hover:text-emerald-700 dark:group-hover:text-emerald-400", title),
        Code(:class => "text-sm text-emerald-700 dark:text-emerald-400", code_preview),
        P(:class => "text-neutral-600 dark:text-neutral-400 mt-3 text-sm", description)
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

function FlowStep(number, text)
    Div(:class => "flex items-start gap-4",
        Span(:class => "flex-shrink-0 w-8 h-8 bg-emerald-700 dark:bg-emerald-600 text-white rounded-full flex items-center justify-center font-semibold text-sm", number),
        P(:class => "pt-1", text)
    )
end

# Export the page component
Index
