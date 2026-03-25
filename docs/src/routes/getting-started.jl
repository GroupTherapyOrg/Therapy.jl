# Getting Started page
#
# Uses Suite.jl components for visual presentation.
# Keeps all existing content — only changes visual styling.

import Suite

function GettingStarted()
    # Content only - Layout applied at app level for true SPA navigation
    Div(:class => "max-w-4xl mx-auto",
            # Page Header
            Div(:class => "mb-14",
                H1(:class => "text-4xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-4",
                    "Getting Started"
                ),
                P(:class => "text-xl text-warm-600 dark:text-warm-400 leading-relaxed",
                    "Get up and running with Therapy.jl in minutes."
                )
            ),

            # Installation
            Section(:class => "mb-14",
                H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-5",
                    "Installation"
                ),
                P(:class => "text-warm-800 dark:text-warm-300 mb-5 leading-relaxed",
                    "Therapy.jl requires Julia 1.11 or later. Install it from the Julia REPL:"
                ),
                Suite.CodeBlock("""julia> using Pkg
julia> Pkg.add(url="https://github.com/GroupTherapyOrg/Therapy.jl")""", language="julia")
            ),

            # Quick Start
            Section(:class => "mb-14",
                H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-5",
                    "Quick Start"
                ),
                P(:class => "text-warm-800 dark:text-warm-300 mb-5 leading-relaxed",
                    "Create your first reactive component:"
                ),
                Suite.CodeBlock("""using Therapy

# @island marks components as interactive (compiled to JS)
@island function Counter()
    count, set_count = create_signal(0)

    Div(:class => "counter",
        Button(:on_click => () -> set_count(count() - 1), "-"),
        Span(count),  # Automatically updates when count changes
        Button(:on_click => () -> set_count(count() + 1), "+")
    )
end

# Islands auto-discovered - no manual config needed!
app = App(routes_dir = "routes", components_dir = "components")
Therapy.run(app)  # dev server or static build""", language="julia"),
                P(:class => "text-warm-800 dark:text-warm-300 mt-5 leading-relaxed",
                    "Run with ", Code(:class => "bg-warm-200 dark:bg-warm-900 px-1.5 py-0.5 rounded text-sm", "julia --project=. app.jl dev"),
                    " for development or ", Code(:class => "bg-warm-200 dark:bg-warm-900 px-1.5 py-0.5 rounded text-sm", "build"), " for static output."
                )
            ),

            # Core Concepts
            Section(:class => "mb-14",
                H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-8",
                    "Core Concepts"
                ),

                # Signals
                Suite.Card(class="mb-6",
                    Suite.CardHeader(
                        Suite.CardTitle(class="font-serif", "Signals"),
                    ),
                    Suite.CardContent(
                        P(:class => "text-warm-800 dark:text-warm-300 mb-5 leading-relaxed",
                            "Signals are the foundation of Therapy.jl's reactivity. They hold values that can change over time and automatically track dependencies."
                        ),
                        Suite.CodeBlock("""# Create a signal
count, set_count = create_signal(0)

# Read the value (tracks dependency)
current = count()  # => 0

# Update the value (triggers updates)
set_count(5)
count()  # => 5""", language="julia")
                    )
                ),

                # Effects
                Suite.Card(class="mb-6",
                    Suite.CardHeader(
                        Suite.CardTitle(class="font-serif", "Effects"),
                    ),
                    Suite.CardContent(
                        P(:class => "text-warm-800 dark:text-warm-300 mb-5 leading-relaxed",
                            "Effects run code when their signal dependencies change. Perfect for side effects like logging or API calls."
                        ),
                        Suite.CodeBlock("""count, set_count = create_signal(0)

# This runs immediately and whenever count changes
create_effect() do
    println("Count is now: ", count())
end

set_count(1)  # Prints: "Count is now: 1"
set_count(2)  # Prints: "Count is now: 2\"""", language="julia")
                    )
                ),

                # Memos
                Suite.Card(
                    Suite.CardHeader(
                        Suite.CardTitle(class="font-serif", "Memos"),
                    ),
                    Suite.CardContent(
                        P(:class => "text-warm-800 dark:text-warm-300 mb-5 leading-relaxed",
                            "Memos are cached computed values that only recalculate when their dependencies change."
                        ),
                        Suite.CodeBlock("""count, set_count = create_signal(2)

# Only recomputes when count changes
doubled = create_memo(() -> count() * 2)

doubled()  # => 4
set_count(5)
doubled()  # => 10""", language="julia")
                    )
                )
            ),

        )
end

GettingStarted
