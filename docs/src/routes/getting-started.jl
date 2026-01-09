# Getting Started page
#
# Muted color scheme with warm stone backgrounds
# Accents: orange-200/300 (light mode), yellow-600/950 (dark mode)

function GettingStarted()
    Layout(
        Div(:class => "max-w-4xl mx-auto",
            # Page Header
            Div(:class => "mb-12",
                H1(:class => "text-4xl font-bold text-stone-800 dark:text-stone-100 mb-4",
                    "Getting Started"
                ),
                P(:class => "text-xl text-stone-500 dark:text-stone-400",
                    "Get up and running with Therapy.jl in minutes."
                )
            ),

            # Installation
            Section(:class => "mb-12",
                H2(:class => "text-2xl font-bold text-stone-800 dark:text-stone-100 mb-4",
                    "Installation"
                ),
                P(:class => "text-stone-600 dark:text-stone-300 mb-4",
                    "Therapy.jl requires Julia 1.9 or later. Install it from the Julia REPL:"
                ),
                CodeBlock("""julia> using Pkg
julia> Pkg.add(url="https://github.com/TherapeuticJulia/Therapy.jl")""")
            ),

            # Quick Start
            Section(:class => "mb-12",
                H2(:class => "text-2xl font-bold text-stone-800 dark:text-stone-100 mb-4",
                    "Quick Start"
                ),
                P(:class => "text-stone-600 dark:text-stone-300 mb-4",
                    "Create your first reactive component:"
                ),
                CodeBlock("""using Therapy

# Create a simple counter component
function Counter()
    # Create a reactive signal with initial value 0
    count, set_count = create_signal(0)

    # Return a VNode tree (like JSX)
    Div(:class => "counter",
        Button(:on_click => () -> set_count(count() - 1), "-"),
        Span(count),  # Automatically updates when count changes
        Button(:on_click => () -> set_count(count() + 1), "+")
    )
end

# Render to HTML string
html = render_to_string(Counter())
println(html)"""),
                P(:class => "text-stone-600 dark:text-stone-300 mt-4",
                    "That's it! You've created a reactive component that can be rendered to HTML."
                )
            ),

            # Core Concepts
            Section(:class => "mb-12",
                H2(:class => "text-2xl font-bold text-stone-800 dark:text-stone-100 mb-6",
                    "Core Concepts"
                ),

                # Signals
                Div(:class => "mb-8",
                    H3(:class => "text-xl font-semibold text-stone-800 dark:text-stone-100 mb-3",
                        "Signals"
                    ),
                    P(:class => "text-stone-600 dark:text-stone-300 mb-4",
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
                Div(:class => "mb-8",
                    H3(:class => "text-xl font-semibold text-stone-800 dark:text-stone-100 mb-3",
                        "Effects"
                    ),
                    P(:class => "text-stone-600 dark:text-stone-300 mb-4",
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
                Div(:class => "mb-8",
                    H3(:class => "text-xl font-semibold text-stone-800 dark:text-stone-100 mb-3",
                        "Memos"
                    ),
                    P(:class => "text-stone-600 dark:text-stone-300 mb-4",
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
            Section(:class => "mb-12 bg-orange-100/50 dark:bg-yellow-950/30 rounded-xl p-8 transition-colors duration-200",
                H2(:class => "text-2xl font-bold text-stone-800 dark:text-stone-100 mb-4",
                    "Next Steps"
                ),
                Ul(:class => "space-y-3",
                    Li(:class => "flex items-center gap-3",
                        Span(:class => "text-orange-400 dark:text-yellow-600", "→"),
                        A(:href => "/api/", :class => "text-orange-400 dark:text-yellow-600 hover:text-orange-500 dark:hover:text-yellow-500",
                            "Read the full Signals API documentation"
                        )
                    ),
                    Li(:class => "flex items-center gap-3",
                        Span(:class => "text-orange-400 dark:text-yellow-600", "→"),
                        A(:href => "/examples/", :class => "text-orange-400 dark:text-yellow-600 hover:text-orange-500 dark:hover:text-yellow-500",
                            "Explore interactive examples"
                        )
                    ),
                    Li(:class => "flex items-center gap-3",
                        Span(:class => "text-orange-400 dark:text-yellow-600", "→"),
                        A(:href => "/api/", :class => "text-orange-400 dark:text-yellow-600 hover:text-orange-500 dark:hover:text-yellow-500",
                            "Learn about Components and SSR"
                        )
                    )
                )
            )
        )
    )
end

function CodeBlock(code)
    Div(:class => "bg-stone-800 dark:bg-stone-950 rounded-lg overflow-x-auto shadow-lg",
        Pre(:class => "p-4 text-sm text-stone-100",
            Code(:class => "language-julia", code)
        )
    )
end

GettingStarted
