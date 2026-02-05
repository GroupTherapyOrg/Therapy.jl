# Managing State
#
# How to organize state in your Therapy.jl application

function ManagingState()
    TutorialLayout(
        Div(:class => "space-y-8",
            # Header
            Div(:class => "mb-8",
                H1(:class => "text-3xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Managing State"
                ),
                P(:class => "text-lg text-warm-800 dark:text-warm-200",
                    "Keep state minimal, derive everything else, and place signals where they belong."
                )
            ),

            # Minimal State
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Keep State Minimal"
                ),
                P(:class => "text-warm-800 dark:text-warm-200 mb-4",
                    "Only store what can't be computed. Everything else should be derived:"
                ),
                CodeBlock("""# Bad: storing derived data
items, set_items = create_signal([...])
count, set_count = create_signal(0)  # Redundant!

# Good: derive from source of truth
items, set_items = create_signal([...])
count = () -> length(items())  # Derived function"""),
                Div(:class => "bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 rounded p-4 mt-4",
                    P(:class => "text-amber-800 dark:text-amber-200 text-sm",
                        Strong("DRY principle: "),
                        "If you can compute it from existing state, don't store it separately."
                    )
                )
            ),

            Hr(:class => "border-warm-200 dark:border-warm-900"),

            # Memos
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Memos: Cached Derived Values"
                ),
                P(:class => "text-warm-800 dark:text-warm-200 mb-4",
                    "For expensive computations, use ",
                    Code(:class => "bg-warm-200 dark:bg-warm-900 px-1 rounded", "create_memo"),
                    " to cache the result:"
                ),
                CodeBlock("""items, set_items = create_signal([...])

# Simple derivation (recomputes every access)
count = () -> length(items())

# Memoized (only recomputes when items changes)
filtered = create_memo() do
    filter(item -> item.active, items())
end

# Use like a signal
Span("Active: ", length(filtered()))"""),
                P(:class => "text-warm-800 dark:text-warm-200 mt-4",
                    "Memos track their dependencies automatically. They only recompute when those dependencies change."
                )
            ),

            Hr(:class => "border-warm-200 dark:border-warm-900"),

            # Where State Lives
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Where State Should Live"
                ),
                P(:class => "text-warm-800 dark:text-warm-200 mb-4",
                    "Place signals in the nearest common ancestor of all components that need them:"
                ),
                CodeBlock("""# State lives in the parent that needs to share it
function App()
    # Both Header and Content need user info
    user, set_user = create_signal(nothing)

    Div(
        Header(user),           # Reads user
        Content(user, set_user) # Reads and writes user
    )
end

function Header(user)
    Nav(
        user() !== nothing ?
            Span("Hello, ", user().name) :
            A(:href => "/login", "Log in")
    )
end

function Content(user, set_user)
    # Can read user() and call set_user(...)
end"""),
                Div(:class => "bg-warm-50 dark:bg-warm-900/20 border border-warm-200 dark:border-warm-700 rounded p-4 mt-4",
                    P(:class => "text-warm-800 dark:text-warm-300 text-sm",
                        Strong("Pass setters directly: "),
                        "Unlike React, you don't need callback props. Just pass the setter function."
                    )
                )
            ),

            Hr(:class => "border-warm-200 dark:border-warm-900"),

            # Effects
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Side Effects"
                ),
                P(:class => "text-warm-800 dark:text-warm-200 mb-4",
                    "Use ",
                    Code(:class => "bg-warm-200 dark:bg-warm-900 px-1 rounded", "create_effect"),
                    " for side effects that run when signals change:"
                ),
                CodeBlock("""function SearchResults()
    query, set_query = create_signal("")
    results, set_results = create_signal([])

    # Effect runs when query changes
    create_effect() do
        if length(query()) >= 3
            # Fetch results (side effect)
            set_results(search_api(query()))
        end
    end

    Div(
        Input(:value => query, :on_input => ...),
        Ul([Li(r.title) for r in results()]...)
    )
end"""),
                P(:class => "text-warm-800 dark:text-warm-200 mt-4",
                    "Effects automatically track which signals they read and re-run when those signals change."
                )
            ),

            Hr(:class => "border-warm-200 dark:border-warm-900"),

            # Batching
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Batching Updates"
                ),
                P(:class => "text-warm-800 dark:text-warm-200 mb-4",
                    "Group multiple signal updates to avoid redundant recomputation:"
                ),
                CodeBlock("""# Without batching: effects run 3 times
set_a(1)
set_b(2)
set_c(3)

# With batching: effects run once
batch() do
    set_a(1)
    set_b(2)
    set_c(3)
end""")
            ),

            Hr(:class => "border-warm-200 dark:border-warm-900"),

            # State Guidelines
            Div(:class => "bg-warm-100 dark:bg-warm-800 rounded-lg p-6",
                H3(:class => "text-lg font-semibold font-serif text-warm-800 dark:text-warm-50 mb-3",
                    "State Guidelines"
                ),
                Ul(:class => "space-y-2 text-warm-800 dark:text-warm-200 text-sm",
                    Li(Strong("Minimal: "), "Only store what can't be derived"),
                    Li(Strong("Derived: "), "Use functions or memos for computed values"),
                    Li(Strong("Lifted: "), "Place state in nearest common ancestor"),
                    Li(Strong("Direct: "), "Pass setters, not callback wrappers"),
                    Li(Strong("Batched: "), "Group related updates when needed")
                )
            ),

            # Navigation
            Div(:class => "mt-8 flex justify-between",
                A(:href => "./learn/adding-interactivity/",
                  :class => "text-warm-600 dark:text-warm-400",
                    "← Adding Interactivity"
                ),
                A(:href => "./learn/tutorial-tic-tac-toe/",
                  :class => "text-accent-700 dark:text-accent-400 font-medium",
                    "Try it: Build Tic-Tac-Toe →"
                )
            )
        );
        current_path="learn/managing-state/"
    )
end

ManagingState
