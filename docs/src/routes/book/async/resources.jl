# Resources - Reactive Async Data Loading
#
# Deep dive into create_resource and reactive data fetching patterns.

import Suite

function Resources()
    BookLayout("/book/async/resources/",
        # Header
        Div(:class => "py-8 border-b border-warm-200 dark:border-warm-700",
            Suite.Badge(variant="outline", "Part 4 · Async"),
            H1(:class => "text-4xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-2 mb-4",
                "Resources"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 max-w-3xl",
                "Resources are Therapy.jl's reactive primitive for async data. They track loading states, ",
                "handle errors, and automatically refetch when their dependencies change."
            )
        ),

        # What is a Resource?
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "What is a Resource?"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "A Resource wraps an async data fetch and makes it reactive. Think of it as a signal ",
                "for data that needs to be loaded—it has a value, but that value might be loading, ",
                "might have an error, or might be ready to use."
            ),
            Suite.CodeBlock(
                code="""# Basic resource creation
user = create_resource(
    () -> user_id(),        # Source: reactive dependency
    id -> fetch_user(id)    # Fetcher: function that loads data
)

# Reading the resource
user()          # Returns data or nothing
user.loading    # true while fetching
user.error      # Exception if fetch failed""",
                language="julia"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "Unlike regular signals, resources manage the async lifecycle for you. ",
                "You don't need to manually track loading states or trigger refetches—it's all automatic."
            )
        ),

        Suite.Separator(),

        # create_resource API
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "The create_resource API"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "There are two ways to create a resource, depending on whether you need reactive dependencies."
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-300 mb-4",
                        "With Reactive Source"
                    ),
                    Suite.CodeBlock(
                        code="""# Source + Fetcher
user = create_resource(
    () -> user_id(),     # Source function
    id -> fetch_user(id) # Fetcher receives source
)

# When user_id() changes, the resource
# automatically refetches with the new id""",
                        language="julia",
                        show_copy=false
                    ),
                    P(:class => "text-warm-600 dark:text-warm-400 mt-4 text-sm",
                        "Use this when your fetch depends on reactive values."
                    )
                ),
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-300 mb-4",
                        "One-Time Fetch"
                    ),
                    Suite.CodeBlock(
                        code="""# Just a fetcher (no source)
config = create_resource(
    () -> load_config()
)

# Fetches once on creation
# No automatic refetching""",
                        language="julia",
                        show_copy=false
                    ),
                    P(:class => "text-warm-600 dark:text-warm-400 mt-4 text-sm",
                        "Use this for data that only needs to load once."
                    )
                )
            )
        ),

        Suite.Separator(),

        # Resource States
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Resource States"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "A resource can be in one of four states. Understanding these is key to building ",
                "responsive async UIs."
            ),
            Suite.Tabs(default_value="lifecycle",
                Suite.TabsList(
                    Suite.TabsTrigger("Lifecycle", value="lifecycle"),
                    Suite.TabsTrigger("Code Example", value="code")
                ),
                Suite.TabsContent(value="lifecycle",
                    Div(:class => "space-y-4 mt-4",
                        Suite.Card(class="flex items-center gap-4 p-4",
                            Suite.Badge(variant="secondary", "PENDING"),
                            Div(
                                P(:class => "text-sm text-warm-600 dark:text-warm-400", "Initial state before any fetch has started")
                            )
                        ),
                        Suite.Card(class="flex items-center gap-4 p-4",
                            Suite.Badge(variant="outline", "LOADING"),
                            Div(
                                P(:class => "text-sm text-warm-600 dark:text-warm-400", "Fetcher is currently running")
                            )
                        ),
                        Suite.Card(class="flex items-center gap-4 p-4",
                            Suite.Badge(variant="default", "READY"),
                            Div(
                                P(:class => "text-sm text-warm-600 dark:text-warm-400", "Data is available and can be read")
                            )
                        ),
                        Suite.Card(class="flex items-center gap-4 p-4",
                            Suite.Badge(variant="destructive", "ERROR"),
                            Div(
                                P(:class => "text-sm text-warm-600 dark:text-warm-400", "Fetch failed, error is available")
                            )
                        )
                    )
                ),
                Suite.TabsContent(value="code",
                    Suite.CodeBlock(
                        code="""user = create_resource(() -> user_id(), id -> fetch_user(id))

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
ready(user)     # true if READY""",
                        language="julia"
                    )
                )
            )
        ),

        Suite.Separator(),

        # Reading Resource Data
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Reading Resource Data"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "To read the data from a resource, call it like a function. But remember: the data ",
                "might not be ready yet!"
            ),
            Suite.CodeBlock(
                code="""user = create_resource(() -> user_id(), id -> fetch_user(id))

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
end""",
                language="julia"
            ),
            Suite.Alert(class="mt-8",
                Suite.AlertTitle("Reactive Tracking"),
                Suite.AlertDescription(
                    "Reading a resource inside an effect registers it as a dependency. " *
                    "When the resource state changes, the effect re-runs automatically."
                )
            )
        ),

        Suite.Separator(),

        # Automatic Refetching
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Automatic Refetching"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "When the source signal changes, the resource automatically refetches with the new value. ",
                "This is the magic that makes resources reactive."
            ),
            Suite.CodeBlock(
                code="""user_id, set_user_id = create_signal(1)

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
# Same process repeats with user #3""",
                language="julia"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "You don't need to call ", Code(:class => "text-accent-700 dark:text-accent-400", "refetch!()"),
                " when the source changes—it's automatic. The source function is tracked just like ",
                "any other reactive dependency."
            )
        ),

        Suite.Separator(),

        # Manual Refetching
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Manual Refetching"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Sometimes you need to reload data without changing the source. Use ",
                Code(:class => "text-accent-700 dark:text-accent-400", "refetch!()"),
                " to trigger a manual reload."
            ),
            Suite.CodeBlock(
                code="""posts = create_resource(() -> fetch_posts())

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
# - After coming back from another page""",
                language="julia"
            ),
            Suite.Alert(class="mt-8",
                Suite.AlertTitle("Refetch vs Source Change"),
                Suite.AlertDescription(
                    "refetch!() reloads with the current source value. Source changes automatically " *
                    "refetch with the new value. Use refetch! for \"reload same data\", use source " *
                    "changes for \"load different data\"."
                )
            )
        ),

        Suite.Separator(),

        # Error Handling
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Error Handling"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "When a fetch fails, the error is captured in the resource. You can check ",
                Code(:class => "text-accent-700 dark:text-accent-400", "user.error"),
                " to see what went wrong."
            ),
            Suite.CodeBlock(
                code="""user = create_resource(() -> user_id(), id -> fetch_user(id))

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
end""",
                language="julia"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "The error is an ", Code(:class => "text-accent-700 dark:text-accent-400", "Exception"),
                " object. You can inspect its message, type, or other properties to show ",
                "appropriate error UI."
            )
        ),

        Suite.Separator(),

        # Multiple Resources
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Multiple Resources"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Components often need multiple pieces of data. Create separate resources for each, ",
                "and they'll load independently."
            ),
            Suite.CodeBlock(
                code="""user = create_resource(() -> user_id(), id -> fetch_user(id))
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
end""",
                language="julia"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "With granular Suspense boundaries, faster-loading data appears first while ",
                "slower data is still loading. This improves perceived performance."
            )
        ),

        Suite.Separator(),

        # Dependent Resources
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Dependent Resources"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Sometimes one resource depends on data from another. Chain them by reading the ",
                "first resource in the second's source function."
            ),
            Suite.CodeBlock(
                code="""# First: load the user
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
end""",
                language="julia"
            ),
            Suite.Alert(class="mt-8", variant="destructive",
                Suite.AlertTitle("Waterfall Warning"),
                Suite.AlertDescription(
                    "Dependent resources create a waterfall—the second can't start until the first " *
                    "finishes. This is unavoidable when data truly depends on another fetch, but " *
                    "avoid it for independent data by using parallel resources instead."
                )
            )
        ),

        Suite.Separator(),

        # Cleanup and Disposal
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Cleanup and Disposal"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "When a component unmounts or you no longer need a resource, dispose of it to stop ",
                "tracking and free memory."
            ),
            Suite.CodeBlock(
                code="""user = create_resource(() -> user_id(), id -> fetch_user(id))

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
end""",
                language="julia"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "Resources created at module scope typically don't need disposal. But resources ",
                "created dynamically in components should be cleaned up when the component unmounts."
            )
        ),

        # Key Takeaways
        Suite.Alert(class="mt-12",
            Suite.AlertTitle("Key Takeaways"),
            Suite.AlertDescription(
                Ul(:class => "space-y-2 list-disc pl-5 mt-2",
                    Li(Strong("Resources wrap async data"), " — they track loading, error, and ready states automatically"),
                    Li(Strong("Source changes trigger refetch"), " — when the source signal changes, the resource reloads"),
                    Li(Strong("Read with resource()"), " — returns the data or nothing if not ready"),
                    Li(Strong("Check loading/error first"), " — or use Suspense for declarative loading UI"),
                    Li(Strong("Use refetch!() for manual reload"), " — after mutations or for refresh buttons"),
                    Li(Strong("Chain resources carefully"), " — dependent fetches create waterfalls")
                )
            )
        ),

    )
end

# Export the page component
Resources
