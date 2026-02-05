# Resources - Reactive Async Data Loading
#
# Deep dive into create_resource and reactive data fetching patterns.

function Resources()
    BookLayout("/book/async/resources/",
        # Header
        Div(:class => "py-8 border-b border-warm-200 dark:border-warm-900",
            Span(:class => "text-sm text-accent-700 dark:text-accent-400 font-medium", "Part 4 · Async"),
            H1(:class => "text-4xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-2 mb-4",
                "Resources"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 max-w-3xl",
                "Resources are Therapy.jl's reactive primitive for async data. They track loading states, ",
                "handle errors, and automatically refetch when their dependencies change."
            )
        ),

        # What is a Resource?
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "What is a Resource?"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 mb-6",
                "A Resource wraps an async data fetch and makes it reactive. Think of it as a signal ",
                "for data that needs to be loaded—it has a value, but that value might be loading, ",
                "might have an error, or might be ready to use."
            ),
            CodeBlock("""# Basic resource creation
user = create_resource(
    () -> user_id(),        # Source: reactive dependency
    id -> fetch_user(id)    # Fetcher: function that loads data
)

# Reading the resource
user()          # Returns data or nothing
user.loading    # true while fetching
user.error      # Exception if fetch failed"""),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "Unlike regular signals, resources manage the async lifecycle for you. ",
                "You don't need to manually track loading states or trigger refetches—it's all automatic."
            )
        ),

        # create_resource API
        Section(:class => "py-12 bg-warm-100 dark:bg-warm-800 rounded-lg border border-warm-200 dark:border-warm-900 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "The create_resource API"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 mb-6",
                "There are two ways to create a resource, depending on whether you need reactive dependencies."
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-200 mb-4",
                        "With Reactive Source"
                    ),
                    CodeBlock("""# Source + Fetcher
user = create_resource(
    () -> user_id(),     # Source function
    id -> fetch_user(id) # Fetcher receives source
)

# When user_id() changes, the resource
# automatically refetches with the new id""", "neutral"),
                    P(:class => "text-warm-600 dark:text-warm-400 mt-4 text-sm",
                        "Use this when your fetch depends on reactive values."
                    )
                ),
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-200 mb-4",
                        "One-Time Fetch"
                    ),
                    CodeBlock("""# Just a fetcher (no source)
config = create_resource(
    () -> load_config()
)

# Fetches once on creation
# No automatic refetching""", "neutral"),
                    P(:class => "text-warm-600 dark:text-warm-400 mt-4 text-sm",
                        "Use this for data that only needs to load once."
                    )
                )
            )
        ),

        # Resource States
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Resource States"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 mb-6",
                "A resource can be in one of four states. Understanding these is key to building ",
                "responsive async UIs."
            ),
            Div(:class => "space-y-4 mt-8",
                ResourceStateRow("PENDING", "⏸", "Initial state before any fetch has started", "gray"),
                ResourceStateRow("LOADING", "⏳", "Fetcher is currently running", "blue"),
                ResourceStateRow("READY", "✓", "Data is available and can be read", "emerald"),
                ResourceStateRow("ERROR", "✗", "Fetch failed, error is available", "red")
            ),
            CodeBlock("""user = create_resource(() -> user_id(), id -> fetch_user(id))

# Check the current state
if user.state == RESOURCE_PENDING
    "Not started yet"
elseif user.state == RESOURCE_LOADING
    "Fetching..."
elseif user.state == RESOURCE_READY
    "Hello, \$(user().name)"
elseif user.state == RESOURCE_ERROR
    "Failed: \$(user.error)"
end

# Or use the convenience properties
user.loading    # true if LOADING
ready(user)     # true if READY""")
        ),

        # Reading Resource Data
        Section(:class => "py-12 bg-warm-100 dark:bg-warm-800 rounded-lg border border-warm-200 dark:border-warm-900 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Reading Resource Data"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 mb-6",
                "To read the data from a resource, call it like a function. But remember: the data ",
                "might not be ready yet!"
            ),
            CodeBlock("""user = create_resource(() -> user_id(), id -> fetch_user(id))

# Option 1: Direct read (returns data or nothing)
data = user()
if data !== nothing
    println("User: ", data.name)
end

# Option 2: Check loading first
if !user.loading && user.error === nothing
    println("User: ", user().name)
end

# Option 3: Use Suspense (recommended)
Suspense(fallback = () -> P("Loading...")) do
    # Only executes when resource is ready
    P("User: ", user().name)
end"""),
            InfoBox("Reactive Tracking",
                "Reading a resource inside an effect registers it as a dependency. " *
                "When the resource state changes, the effect re-runs automatically."
            )
        ),

        # Automatic Refetching
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Automatic Refetching"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 mb-6",
                "When the source signal changes, the resource automatically refetches with the new value. ",
                "This is the magic that makes resources reactive."
            ),
            CodeBlock("""user_id, set_user_id = create_signal(1)

user = create_resource(
    () -> user_id(),        # Tracks user_id as a dependency
    id -> fetch_user(id)    # Called whenever user_id changes
)

# Initial fetch happens immediately
# user() will be user #1's data when ready

# Later: change the user_id
set_user_id(2)
# Resource automatically:
# 1. Sets state to LOADING
# 2. Calls fetch_user(2)
# 3. Updates data when fetch completes
# 4. Sets state to READY (or ERROR)

set_user_id(3)
# Same process repeats with user #3"""),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "You don't need to call ", Code(:class => "text-accent-700 dark:text-accent-400", "refetch!()"),
                " when the source changes—it's automatic. The source function is tracked just like ",
                "any other reactive dependency."
            )
        ),

        # Manual Refetching
        Section(:class => "py-12 bg-warm-100 dark:bg-warm-800 rounded-lg border border-warm-200 dark:border-warm-900 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Manual Refetching"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 mb-6",
                "Sometimes you need to reload data without changing the source. Use ",
                Code(:class => "text-accent-700 dark:text-accent-400", "refetch!()"),
                " to trigger a manual reload."
            ),
            CodeBlock("""posts = create_resource(() -> fetch_posts())

# Create a refresh button
function PostList()
    Div(
        Button(
            :on_click => () -> refetch!(posts),
            "↻ Refresh"
        ),
        For(() -> posts()) do post
            PostCard(post)
        end
    )
end

# Common use cases for manual refetch:
# - User clicks a refresh button
# - After a mutation (create/update/delete)
# - On a timer for real-time data
# - After coming back from another page"""),
            InfoBox("Refetch vs Source Change",
                "refetch!() reloads with the current source value. Source changes automatically " *
                "refetch with the new value. Use refetch! for \"reload same data\", use source " *
                "changes for \"load different data\"."
            )
        ),

        # Error Handling
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Error Handling"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 mb-6",
                "When a fetch fails, the error is captured in the resource. You can check ",
                Code(:class => "text-accent-700 dark:text-accent-400", "user.error"),
                " to see what went wrong."
            ),
            CodeBlock("""user = create_resource(() -> user_id(), id -> fetch_user(id))

function UserDisplay()
    # Handle all three cases
    if user.loading
        Div(:class => "spinner", "Loading...")
    elseif user.error !== nothing
        Div(:class => "error",
            P("Failed to load user"),
            P(:class => "text-sm", string(user.error)),
            Button(:on_click => () -> refetch!(user), "Try Again")
        )
    else
        data = user()
        Div(
            H2(data.name),
            P(data.email)
        )
    end
end"""),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "The error is an ", Code(:class => "text-accent-700 dark:text-accent-400", "Exception"),
                " object. You can inspect its message, type, or other properties to show ",
                "appropriate error UI."
            )
        ),

        # Multiple Resources
        Section(:class => "py-12 bg-warm-100 dark:bg-warm-800 rounded-lg border border-warm-200 dark:border-warm-900 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Multiple Resources"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 mb-6",
                "Components often need multiple pieces of data. Create separate resources for each, ",
                "and they'll load independently."
            ),
            CodeBlock("""user = create_resource(() -> user_id(), id -> fetch_user(id))
posts = create_resource(() -> user_id(), id -> fetch_user_posts(id))
stats = create_resource(() -> user_id(), id -> fetch_user_stats(id))

function UserProfile()
    # Wrap all in a single Suspense
    Suspense(fallback = () -> PageSkeleton()) do
        Div(:class => "grid grid-cols-2",
            # Left column
            Div(
                UserCard(user = user()),
                UserStats(stats = stats())
            ),
            # Right column
            Div(
                PostList(posts = posts())
            )
        )
    end
end

# Or use separate Suspense for granular loading
function UserProfileGranular()
    Div(:class => "grid grid-cols-2",
        Suspense(fallback = () -> UserCardSkeleton()) do
            UserCard(user = user())
        end,
        Suspense(fallback = () -> PostListSkeleton()) do
            PostList(posts = posts())
        end
    )
end"""),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "With granular Suspense boundaries, faster-loading data appears first while ",
                "slower data is still loading. This improves perceived performance."
            )
        ),

        # Dependent Resources
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Dependent Resources"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 mb-6",
                "Sometimes one resource depends on data from another. Chain them by reading the ",
                "first resource in the second's source function."
            ),
            CodeBlock("""# First: load the user
user = create_resource(() -> user_id(), id -> fetch_user(id))

# Second: load their team (depends on user data)
team = create_resource(
    () -> begin
        u = user()
        u !== nothing ? u.team_id : nothing
    end,
    team_id -> team_id !== nothing ? fetch_team(team_id) : nothing
)

# team won't fetch until user is ready
# When user loads, team automatically starts loading

function UserWithTeam()
    Suspense(fallback = () -> P("Loading...")) do
        Div(
            H2("User: ", user().name),
            H3("Team: ", team()?.name)
        )
    end
end"""),
            InfoBox("Waterfall Warning",
                "Dependent resources create a waterfall—the second can't start until the first " *
                "finishes. This is unavoidable when data truly depends on another fetch, but " *
                "avoid it for independent data by using parallel resources instead."
            )
        ),

        # Cleanup and Disposal
        Section(:class => "py-12 bg-warm-100 dark:bg-warm-800 rounded-lg border border-warm-200 dark:border-warm-900 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Cleanup and Disposal"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 mb-6",
                "When a component unmounts or you no longer need a resource, dispose of it to stop ",
                "tracking and free memory."
            ),
            CodeBlock("""user = create_resource(() -> user_id(), id -> fetch_user(id))

# When done with the resource
dispose!(user)

# The resource will:
# - Stop tracking the source signal
# - Clear all subscribers
# - Allow garbage collection

# In a component with cleanup:
function TemporaryUser()
    user = create_resource(() -> user_id(), id -> fetch_user(id))

    on_cleanup() do
        dispose!(user)
    end

    Suspense(fallback = () -> P("Loading...")) do
        P("User: ", user().name)
    end
end"""),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "Resources created at module scope typically don't need disposal. But resources ",
                "created dynamically in components should be cleaned up when the component unmounts."
            )
        ),

        # Key Takeaways
        Section(:class => "py-12 bg-warm-50 dark:bg-warm-900/30 rounded-lg border border-warm-200 dark:border-warm-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-accent-900 dark:text-accent-200 mb-6",
                "Key Takeaways"
            ),
            Ul(:class => "space-y-3 text-accent-800 dark:text-accent-300",
                Li(Strong("Resources wrap async data"), " — they track loading, error, and ready states automatically"),
                Li(Strong("Source changes trigger refetch"), " — when the source signal changes, the resource reloads"),
                Li(Strong("Read with resource()"), " — returns the data or nothing if not ready"),
                Li(Strong("Check loading/error first"), " — or use Suspense for declarative loading UI"),
                Li(Strong("Use refetch!() for manual reload"), " — after mutations or for refresh buttons"),
                Li(Strong("Chain resources carefully"), " — dependent fetches create waterfalls")
            )
        ),

    )
end

# Helper Components

function ResourceStateRow(name, icon, description, color)
    color_classes = Dict(
        "gray" => "bg-warm-50 dark:bg-warm-900 border-warm-200 dark:border-warm-800",
        "blue" => "bg-blue-50 dark:bg-blue-950/30 border-blue-200 dark:border-blue-900",
        "emerald" => "bg-warm-50 dark:bg-warm-900/30 border-warm-200 dark:border-warm-800",
        "red" => "bg-red-50 dark:bg-red-950/30 border-red-200 dark:border-red-900"
    )
    text_classes = Dict(
        "gray" => "text-warm-800 dark:text-warm-200",
        "blue" => "text-blue-700 dark:text-blue-300",
        "emerald" => "text-accent-700 dark:text-accent-300",
        "red" => "text-red-700 dark:text-red-300"
    )

    Div(:class => "flex items-center gap-4 p-4 rounded-lg border $(color_classes[color])",
        Span(:class => "text-2xl", icon),
        Div(
            Code(:class => "font-semibold $(text_classes[color])", name),
            P(:class => "text-sm $(text_classes[color]) opacity-80", description)
        )
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
Resources
