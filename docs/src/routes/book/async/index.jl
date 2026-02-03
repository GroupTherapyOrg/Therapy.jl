# Async Patterns - Part 4 of the Therapy.jl Book
#
# Handling async data with Resources, Suspense, and Await.

function Index()
    Fragment(
        # Header
        Div(:class => "py-8 border-b border-neutral-300 dark:border-neutral-800",
            Span(:class => "text-sm text-emerald-700 dark:text-emerald-400 font-medium", "Part 4"),
            H1(:class => "text-4xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mt-2 mb-4",
                "Async Patterns"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 max-w-3xl",
                "Handle async data loading with Resources and Suspense boundaries for a smooth user experience."
            )
        ),

        # Coming Soon Notice
        Section(:class => "py-12",
            Div(:class => "bg-amber-50 dark:bg-amber-950/20 rounded-lg border border-amber-200 dark:border-amber-900 p-8 text-center",
                H2(:class => "text-2xl font-serif font-semibold text-amber-900 dark:text-amber-200 mb-4",
                    "Coming Soon"
                ),
                P(:class => "text-amber-800 dark:text-amber-300",
                    "This section is currently being written. Check back soon for Resources, Suspense, error handling, and async patterns!"
                )
            )
        ),

        # Topics Preview
        Section(:class => "py-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "What You'll Learn"
            ),
            Ul(:class => "space-y-3 text-neutral-600 dark:text-neutral-400",
                Li(Strong("create_resource"), " - Reactive async data loading with automatic refetch"),
                Li(Strong("Suspense"), " - Display fallback content while resources load"),
                Li(Strong("Await"), " - Simpler pattern for single async values"),
                Li(Strong("Loading States"), " - resource.loading, resource.error, resource()"),
                Li(Strong("Error Handling"), " - Graceful error recovery in async flows"),
                Li(Strong("Refetching"), " - Manual and automatic data refresh patterns")
            )
        ),

        # Quick Preview
        Section(:class => "py-8 bg-neutral-50 dark:bg-neutral-900 rounded-lg border border-neutral-300 dark:border-neutral-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Quick Preview"
            ),
            Div(:class => "bg-neutral-900 dark:bg-neutral-950 rounded border border-neutral-800 p-6 overflow-x-auto",
                Pre(:class => "text-sm text-neutral-100",
                    Code(:class => "language-julia", """# Create a resource with reactive source
user_id, set_user_id = create_signal(1)

user = create_resource(
    () -> user_id(),           # Source (triggers refetch)
    id -> fetch_user(id)       # Fetcher function
)

# Check loading state
if user.loading
    "Loading..."
elseif user.error !== nothing
    "Error: \$(user.error)"
else
    "Hello, \$(user().name)"
end

# Use Suspense for declarative loading
Suspense(fallback = () -> P("Loading user...")) do
    UserCard(user = user())
end""")
                )
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
            A(:href => "../server/",
              :class => "inline-flex items-center text-neutral-600 dark:text-neutral-400 hover:text-emerald-700 dark:hover:text-emerald-400 transition-colors",
                "Server Features",
                Svg(:class => "ml-2 w-5 h-5", :fill => "none", :viewBox => "0 0 24 24", :stroke => "currentColor",
                    Path(:stroke_linecap => "round", :stroke_linejoin => "round", :stroke_width => "2", :d => "M13 7l5 5m0 0l-5 5m5-5H6")
                )
            )
        )
    )
end

Index
