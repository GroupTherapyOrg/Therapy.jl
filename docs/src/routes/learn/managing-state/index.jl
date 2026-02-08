# Managing State
#
# How to organize state in your Therapy.jl application
# Uses Suite.jl components for visual presentation.

import Suite

function ManagingState()
    TutorialLayout(
        Div(:class => "space-y-8",
            # Header
            Div(:class => "mb-8",
                H1(:class => "text-3xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Managing State"
                ),
                P(:class => "text-lg text-warm-800 dark:text-warm-300",
                    "Keep state minimal, derive everything else, and place signals where they belong."
                )
            ),

            # Minimal State
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Keep State Minimal"
                ),
                P(:class => "text-warm-800 dark:text-warm-300 mb-4",
                    "Only store what can't be computed. Everything else should be derived:"
                ),
                Suite.CodeBlock(code="""# Bad: storing derived data
items, set_items = create_signal([...])
count, set_count = create_signal(0)  # Redundant!

# Good: derive from source of truth
items, set_items = create_signal([...])
count = () -> length(items())  # Derived function""", language="julia"),
                Suite.Alert(
                    Suite.AlertTitle("DRY principle"),
                    Suite.AlertDescription(
                        "If you can compute it from existing state, don't store it separately."
                    )
                )
            ),

            Suite.Separator(),

            # Memos
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Memos: Cached Derived Values"
                ),
                P(:class => "text-warm-800 dark:text-warm-300 mb-4",
                    "For expensive computations, use ",
                    Code(:class => "bg-warm-200 dark:bg-warm-900 px-1 rounded", "create_memo"),
                    " to cache the result:"
                ),
                Suite.CodeBlock(code="""items, set_items = create_signal([...])

# Simple derivation (recomputes every access)
count = () -> length(items())

# Memoized (only recomputes when items changes)
filtered = create_memo() do
    filter(item -> item.active, items())
end

# Use like a signal
Span("Active: ", length(filtered()))""", language="julia"),
                P(:class => "text-warm-800 dark:text-warm-300 mt-4",
                    "Memos track their dependencies automatically. They only recompute when those dependencies change."
                )
            ),

            Suite.Separator(),

            # Where State Lives
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Where State Should Live"
                ),
                P(:class => "text-warm-800 dark:text-warm-300 mb-4",
                    "Place signals in the nearest common ancestor of all components that need them:"
                ),
                Suite.CodeBlock(code="""# State lives in the parent that needs to share it
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
end""", language="julia"),
                Suite.Alert(
                    Suite.AlertTitle("Pass setters directly"),
                    Suite.AlertDescription(
                        "Unlike React, you don't need callback props. Just pass the setter function."
                    )
                )
            ),

            Suite.Separator(),

            # Effects
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Side Effects"
                ),
                P(:class => "text-warm-800 dark:text-warm-300 mb-4",
                    "Use ",
                    Code(:class => "bg-warm-200 dark:bg-warm-900 px-1 rounded", "create_effect"),
                    " for side effects that run when signals change:"
                ),
                Suite.CodeBlock(code="""function SearchResults()
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
end""", language="julia"),
                P(:class => "text-warm-800 dark:text-warm-300 mt-4",
                    "Effects automatically track which signals they read and re-run when those signals change."
                )
            ),

            Suite.Separator(),

            # Batching
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Batching Updates"
                ),
                P(:class => "text-warm-800 dark:text-warm-300 mb-4",
                    "Group multiple signal updates to avoid redundant recomputation:"
                ),
                Suite.CodeBlock(code="""# Without batching: effects run 3 times
set_a(1)
set_b(2)
set_c(3)

# With batching: effects run once
batch() do
    set_a(1)
    set_b(2)
    set_c(3)
end""", language="julia")
            ),

            Suite.Separator(),

            # State Guidelines
            Suite.Card(
                Suite.CardHeader(
                    Suite.CardTitle(class="font-serif", "State Guidelines"),
                ),
                Suite.CardContent(
                    Ul(:class => "space-y-2 text-warm-800 dark:text-warm-300 text-sm",
                        Li(Strong("Minimal: "), "Only store what can't be derived"),
                        Li(Strong("Derived: "), "Use functions or memos for computed values"),
                        Li(Strong("Lifted: "), "Place state in nearest common ancestor"),
                        Li(Strong("Direct: "), "Pass setters, not callback wrappers"),
                        Li(Strong("Batched: "), "Group related updates when needed")
                    )
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
