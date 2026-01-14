# Getting Started page
#
# Parchment theme with sage and amber accents

function GettingStarted()
    # Content only - Layout applied at app level for true SPA navigation
    Div(:class => "max-w-4xl mx-auto",
            # Page Header
            Div(:class => "mb-14",
                H1(:class => "text-4xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-4",
                    "Getting Started"
                ),
                P(:class => "text-xl text-neutral-600 dark:text-neutral-400 leading-relaxed",
                    "Get up and running with Therapy.jl in minutes."
                )
            ),

            # Installation
            Section(:class => "mb-14",
                H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-5",
                    "Installation"
                ),
                P(:class => "text-neutral-700 dark:text-neutral-300 mb-5 leading-relaxed",
                    "Therapy.jl requires Julia 1.11 or later. Install it from the Julia REPL:"
                ),
                CodeBlock("""julia> using Pkg
julia> Pkg.add(url="https://github.com/TherapeuticJulia/Therapy.jl")""")
            ),

            # Quick Start
            Section(:class => "mb-14",
                H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-5",
                    "Quick Start"
                ),
                P(:class => "text-neutral-700 dark:text-neutral-300 mb-5 leading-relaxed",
                    "Create your first reactive component:"
                ),
                CodeBlock("""using Therapy

# island() marks components as interactive (compiled to Wasm)
Counter = island(:Counter) do
    count, set_count = create_signal(0)

    Div(:class => "counter",
        Button(:on_click => () -> set_count(count() - 1), "-"),
        Span(count),  # Automatically updates when count changes
        Button(:on_click => () -> set_count(count() + 1), "+")
    )
end

# Islands auto-discovered - no manual config needed!
app = App(routes_dir = "routes", components_dir = "components")
Therapy.run(app)  # dev server or static build"""),
                P(:class => "text-neutral-700 dark:text-neutral-300 mt-5 leading-relaxed",
                    "Run with ", Code(:class => "bg-neutral-200 dark:bg-neutral-800 px-1.5 py-0.5 rounded text-sm", "julia --project=. app.jl dev"),
                    " for development or ", Code(:class => "bg-neutral-200 dark:bg-neutral-800 px-1.5 py-0.5 rounded text-sm", "build"), " for static output."
                )
            ),

            # Core Concepts
            Section(:class => "mb-14",
                H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-8",
                    "Core Concepts"
                ),

                # Signals
                Div(:class => "mb-10",
                    H3(:class => "text-xl font-serif font-medium text-neutral-900 dark:text-neutral-100 mb-4",
                        "Signals"
                    ),
                    P(:class => "text-neutral-700 dark:text-neutral-300 mb-5 leading-relaxed",
                        "Signals are the foundation of Therapy.jl's reactivity. They hold values that can change over time and automatically track dependencies."
                    ),
                    CodeBlock("""# Create a signal
count, set_count = create_signal(0)

# Read the value (tracks dependency)
current = count()  # => 0

# Update the value (triggers updates)
set_count(5)
count()  # => 5""")
                ),

                # Effects
                Div(:class => "mb-10",
                    H3(:class => "text-xl font-serif font-medium text-neutral-900 dark:text-neutral-100 mb-4",
                        "Effects"
                    ),
                    P(:class => "text-neutral-700 dark:text-neutral-300 mb-5 leading-relaxed",
                        "Effects run code when their signal dependencies change. Perfect for side effects like logging or API calls."
                    ),
                    CodeBlock("""count, set_count = create_signal(0)

# This runs immediately and whenever count changes
create_effect() do
    println("Count is now: ", count())
end

set_count(1)  # Prints: "Count is now: 1"
set_count(2)  # Prints: "Count is now: 2\"""")
                ),

                # Memos
                Div(:class => "mb-10",
                    H3(:class => "text-xl font-serif font-medium text-neutral-900 dark:text-neutral-100 mb-4",
                        "Memos"
                    ),
                    P(:class => "text-neutral-700 dark:text-neutral-300 mb-5 leading-relaxed",
                        "Memos are cached computed values that only recalculate when their dependencies change."
                    ),
                    CodeBlock("""count, set_count = create_signal(2)

# Only recomputes when count changes
doubled = create_memo(() -> count() * 2)

doubled()  # => 4
set_count(5)
doubled()  # => 10""")
                )
            ),

            # Next Steps
            Section(:class => "mb-14 bg-emerald-50/50 dark:bg-emerald-950/20 rounded border border-neutral-300 dark:border-neutral-800 p-8 transition-colors duration-200",
                H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-5",
                    "Next Steps"
                ),
                Ul(:class => "space-y-4",
                    Li(:class => "flex items-center gap-3",
                        Span(:class => "text-emerald-600 dark:text-emerald-400", "→"),
                        A(:href => "api/", :class => "text-emerald-700 dark:text-emerald-400 hover:text-emerald-800 dark:hover:text-emerald-300",
                            "Read the full Signals API documentation"
                        )
                    ),
                    Li(:class => "flex items-center gap-3",
                        Span(:class => "text-emerald-600 dark:text-emerald-400", "→"),
                        A(:href => "examples/", :class => "text-emerald-700 dark:text-emerald-400 hover:text-emerald-800 dark:hover:text-emerald-300",
                            "Explore interactive examples"
                        )
                    ),
                    Li(:class => "flex items-center gap-3",
                        Span(:class => "text-emerald-600 dark:text-emerald-400", "→"),
                        A(:href => "api/", :class => "text-emerald-700 dark:text-emerald-400 hover:text-emerald-800 dark:hover:text-emerald-300",
                            "Learn about Components and SSR"
                        )
                    )
                )
            )
        )
end

GettingStarted
