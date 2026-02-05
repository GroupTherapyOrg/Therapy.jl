# Async Patterns - Common Patterns for Async Data
#
# Error handling, refetching, caching, and optimistic updates.

function Patterns()
    BookLayout("/book/async/patterns/",
        # Header
        Div(:class => "py-8 border-b border-warm-200 dark:border-warm-900",
            Span(:class => "text-sm text-accent-700 dark:text-accent-400 font-medium", "Part 4 · Async"),
            H1(:class => "text-4xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-2 mb-4",
                "Async Patterns"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 max-w-3xl",
                "Beyond the basics, here are patterns for error handling, refresh strategies, ",
                "optimistic updates, and combining async operations."
            )
        ),

        # Error Handling Pattern
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Error Handling"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 mb-6",
                "Async operations can fail. Here's how to handle errors gracefully and provide ",
                "retry options."
            ),
            CodeBlock("""user = create_resource(() -> user_id(), id -> fetch_user(id))

function UserWithErrorHandling()
    # Pattern 1: Check error explicitly
    if user.error !== nothing
        Div(:class => "error-panel",
            H3("Failed to load user"),
            P(string(user.error)),
            Button(:on_click => () -> refetch!(user), "Try Again")
        )
    elseif user.loading
        Spinner()
    else
        UserCard(user = user())
    end
end

# Pattern 2: ErrorBoundary + Suspense (coming soon)
# ErrorBoundary(
#     fallback = (err, reset) -> ErrorUI(err, reset)
# ) do
#     Suspense(fallback = () -> Spinner()) do
#         UserCard(user = user())
#     end
# end

# Pattern 3: Helper component for error state
function ResourceView(resource; loading_ui, error_ui, children)
    if resource.error !== nothing
        error_ui(resource.error, () -> refetch!(resource))
    elseif resource.loading
        loading_ui()
    else
        children(resource())
    end
end

# Usage:
ResourceView(user;
    loading_ui = () -> Spinner(),
    error_ui = (err, retry) -> Div(P(string(err)), Button(:on_click => retry, "Retry")),
    children = data -> UserCard(user = data)
)""")
        ),

        # Refresh Patterns
        Section(:class => "py-12 bg-warm-100 dark:bg-warm-800 rounded-lg border border-warm-200 dark:border-warm-900 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Refresh Patterns"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 mb-6",
                "Different scenarios call for different refresh strategies."
            ),
            Div(:class => "space-y-8",
                PatternBox("Manual Refresh Button", """# Add a refresh button
function PostList()
    Div(
        Div(:class => "flex justify-between",
            H2("Posts"),
            Button(
                :on_click => () -> refetch!(posts),
                :disabled => posts.loading,
                posts.loading ? "Refreshing..." : "↻ Refresh"
            )
        ),
        Suspense(fallback = () -> Spinner()) do
            For(() -> posts()) do post
                PostCard(post)
            end
        end
    )
end"""),
                PatternBox("Pull-to-Refresh Style", """# Show content while refreshing in background
function PostListWithStale()
    # Keep showing old data while new data loads
    Div(
        Show(() -> posts.loading) do
            Div(:class => "refresh-indicator", "Updating...")
        end,
        # Always show the data (even if stale during refresh)
        Show(() -> posts() !== nothing) do
            For(() -> posts()) do post
                PostCard(post)
            end
        end
    )
end"""),
                PatternBox("Auto-Refresh on Interval", """# Refresh every 30 seconds
function LiveDashboard()
    stats = create_resource(() -> fetch_stats())

    # Set up auto-refresh
    on_mount() do
        timer = Timer(30.0; repeat=true) do
            refetch!(stats)
        end
        # Clean up on unmount
        on_cleanup() do
            close(timer)
        end
    end

    Suspense(fallback = () -> Spinner()) do
        StatsDisplay(data = stats())
    end
end""")
            )
        ),

        # After Mutation Pattern
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Refetch After Mutations"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 mb-6",
                "After creating, updating, or deleting data, you usually want to refresh the ",
                "relevant resources."
            ),
            CodeBlock("""posts = create_resource(() -> fetch_posts())

# After creating a new post, refetch the list
function CreatePostForm()
    title, set_title = create_signal("")
    content, set_content = create_signal("")

    handle_submit = () -> begin
        # Call server to create post
        create_post(title(), content())

        # Refetch the posts list
        refetch!(posts)

        # Clear form
        set_title("")
        set_content("")
    end

    Form(:on_submit => handle_submit,
        Input(:value => title, :on_input => set_title, :placeholder => "Title"),
        Textarea(:value => content, :on_input => set_content),
        Button(:type => "submit", "Create Post")
    )
end

# Same pattern for updates and deletes
delete_post = (id) -> begin
    confirm_delete(id)
    refetch!(posts)  # Refresh list after deletion
end"""),
            InfoBox("Automatic Invalidation",
                "If your posts resource depends on a signal (like a filter or page number), " *
                "you don't need manual refetch when that signal changes—it's automatic. " *
                "Use refetch!() specifically for side-effect-driven refreshes."
            )
        ),

        # Optimistic Updates
        Section(:class => "py-12 bg-warm-100 dark:bg-warm-800 rounded-lg border border-warm-200 dark:border-warm-900 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Optimistic Updates"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 mb-6",
                "For better UX, update the UI immediately and assume the server will succeed. ",
                "Roll back if it fails."
            ),
            CodeBlock("""function LikeButton(; post_id)
    likes, set_likes = create_signal(0)
    liked, set_liked = create_signal(false)

    handle_like = () -> begin
        # Optimistically update UI immediately
        old_likes = likes()
        old_liked = liked()

        set_liked(!liked())
        set_likes(liked() ? likes() - 1 : likes() + 1)

        # Send to server in background
        try
            toggle_like(post_id)
            # Success! UI is already updated
        catch e
            # Failed - roll back to previous state
            set_likes(old_likes)
            set_liked(old_liked)
            show_error("Failed to update like")
        end
    end

    Button(:on_click => handle_like,
        :class => liked() ? "text-red-500" : "text-gray-500",
        liked() ? "♥" : "♡", " ", likes()
    )
end"""),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "Optimistic updates make your app feel instant. The key is to save the old state ",
                "before updating, so you can restore it if the server rejects the change."
            )
        ),

        # Parallel vs Sequential Loading
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Parallel vs Sequential Loading"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 mb-6",
                "Independent data should load in parallel. Dependent data must load sequentially. ",
                "Choose wisely to minimize total load time."
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-accent-800 dark:text-accent-300 mb-4",
                        "✓ Parallel (Independent)"
                    ),
                    CodeBlock("""# These have no dependencies on each other
user = create_resource(() -> fetch_user(id))
posts = create_resource(() -> fetch_posts(id))
stats = create_resource(() -> fetch_stats(id))

# All three start immediately
# Total time = max(user, posts, stats)

# Example: 100ms, 200ms, 150ms
# Total: 200ms""", "emerald"),
                ),
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-200 mb-4",
                        "Sequential (Dependent)"
                    ),
                    CodeBlock("""# team_id comes from user data
user = create_resource(() -> fetch_user(id))
team = create_resource(
    () -> user()?.team_id,
    team_id -> fetch_team(team_id)
)

# team waits for user to complete
# Total time = user + team

# Example: 100ms + 150ms
# Total: 250ms""", "neutral"),
                )
            ),
            InfoBox("Avoid Artificial Waterfalls",
                "If data doesn't truly depend on another fetch, load it in parallel. " *
                "Sometimes refactoring API endpoints to return combined data can eliminate " *
                "sequential loading entirely."
            )
        ),

        # Loading State Skeletons
        Section(:class => "py-12 bg-warm-100 dark:bg-warm-800 rounded-lg border border-warm-200 dark:border-warm-900 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Skeleton Loading States"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 mb-6",
                "Skeleton screens that match your actual content layout provide a better ",
                "loading experience than generic spinners."
            ),
            CodeBlock("""# Create skeleton that matches your component structure
function UserCardSkeleton()
    Div(:class => "flex gap-4 p-4 animate-pulse",
        # Avatar placeholder
        Div(:class => "w-12 h-12 bg-warm-200 dark:bg-warm-800 rounded-full"),
        Div(:class => "flex-1 space-y-2",
            # Name placeholder
            Div(:class => "h-4 bg-warm-200 dark:bg-warm-800 rounded w-1/3"),
            # Email placeholder
            Div(:class => "h-3 bg-warm-200 dark:bg-warm-800 rounded w-1/2")
        )
    )
end

# Use it as fallback
Suspense(fallback = () -> UserCardSkeleton()) do
    UserCard(user = user())
end

# For lists, repeat the skeleton
function PostListSkeleton(; count=3)
    Div(:class => "space-y-4",
        For(() -> 1:count) do _
            PostCardSkeleton()
        end
    )
end"""),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "Match the skeleton's dimensions to your actual content to prevent layout shift ",
                "when data loads. Use ", Code(:class => "text-accent-700 dark:text-accent-400", "animate-pulse"),
                " for a subtle loading animation."
            )
        ),

        # Prefetching
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Prefetching Data"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 mb-6",
                "Load data before it's needed to make navigation feel instant."
            ),
            CodeBlock("""# Prefetch on hover
function UserLink(; user_id, name)
    # Create the resource but don't read it yet
    prefetched_user = create_resource(
        () -> user_id,
        id -> fetch_user_details(id)
    )

    A(
        :href => "/users/\$user_id",
        :on_mouseenter => () -> begin
            # Start loading when user hovers
            if !ready(prefetched_user)
                refetch!(prefetched_user)
            end
        end,
        name
    )
end

# Or prefetch based on visibility
function UserList(; users)
    For(() -> users) do user
        # Intersection Observer could trigger prefetch
        # when item comes into view
        Div(:data_user_id => user.id,
            UserCard(user = user)
        )
    end
end"""),
            InfoBox("Prefetch Sparingly",
                "Don't prefetch everything—it wastes bandwidth. Prefetch for likely actions: " *
                "hover on links, first few items in a list, or the \"next\" page in pagination."
            )
        ),

        # Key Takeaways
        Section(:class => "py-12 bg-warm-50 dark:bg-warm-900/30 rounded-lg border border-warm-200 dark:border-warm-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-accent-900 dark:text-accent-200 mb-6",
                "Key Takeaways"
            ),
            Ul(:class => "space-y-3 text-accent-800 dark:text-accent-300",
                Li(Strong("Handle errors gracefully"), " — provide retry buttons and clear error messages"),
                Li(Strong("Choose the right refresh strategy"), " — manual, pull-to-refresh, or auto-interval"),
                Li(Strong("Refetch after mutations"), " — keep data in sync with server state"),
                Li(Strong("Use optimistic updates"), " — update UI immediately for better UX"),
                Li(Strong("Load independent data in parallel"), " — avoid artificial waterfalls"),
                Li(Strong("Use skeleton loading states"), " — match actual layout to prevent shift"),
                Li(Strong("Prefetch likely actions"), " — make navigation feel instant")
            )
        ),

    )
end

# Helper Components

function PatternBox(title, code)
    Div(:class => "bg-warm-50 dark:bg-warm-900 rounded-lg border border-warm-200 dark:border-warm-800 p-6",
        H3(:class => "text-lg font-serif font-semibold text-warm-800 dark:text-warm-50 mb-4", title),
        CodeBlock(code)
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
Patterns
