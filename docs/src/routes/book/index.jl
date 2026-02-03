# Book Index - Introduction to Therapy.jl
#
# The comprehensive guide to building reactive web applications with Julia.
# Follows the Leptos book structure with Julia-native conventions.

function Index()
    Fragment(
        # Header
        Div(:class => "py-12 border-b border-neutral-300 dark:border-neutral-800",
            H1(:class => "text-4xl sm:text-5xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "The Therapy.jl Book"
            ),
            P(:class => "text-xl text-neutral-600 dark:text-neutral-300 max-w-3xl leading-relaxed",
                "A comprehensive guide to building reactive web applications with Julia. ",
                "Learn fine-grained reactivity, server-side rendering, and WebAssembly compilation."
            )
        ),

        # What is Therapy.jl
        Section(:class => "py-12",
            H2(:class => "text-3xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "What is Therapy.jl?"
            ),
            Div(:class => "prose dark:prose-invert max-w-none",
                P(:class => "text-lg text-neutral-600 dark:text-neutral-300 leading-relaxed mb-6",
                    "Therapy.jl is a reactive web framework for Julia inspired by SolidJS and Leptos. ",
                    "It provides fine-grained reactivity, server-side rendering, and the ability to compile Julia code directly to WebAssembly."
                ),
                P(:class => "text-lg text-neutral-600 dark:text-neutral-300 leading-relaxed mb-6",
                    "Unlike virtual DOM frameworks like React, Therapy.jl tracks dependencies at the signal level. ",
                    "When a signal changes, only the specific DOM nodes that depend on it are updated\u2014no diffing required."
                ),
                P(:class => "text-lg text-neutral-600 dark:text-neutral-300 leading-relaxed",
                    "This book will teach you everything you need to know to build production-ready web applications with Therapy.jl."
                )
            )
        ),

        # Book Structure
        Section(:class => "py-12 bg-neutral-50 dark:bg-neutral-900 rounded-lg border border-neutral-300 dark:border-neutral-800 px-8",
            H2(:class => "text-3xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-8",
                "What You'll Learn"
            ),
            Div(:class => "grid md:grid-cols-2 lg:grid-cols-3 gap-6",
                BookSection("1. Getting Started", "./getting-started/",
                    "Set up your first Therapy.jl project and build a simple interactive application."
                ),
                BookSection("2. Reactivity", "./reactivity/",
                    "Master signals, effects, and memos\u2014the building blocks of fine-grained reactivity."
                ),
                BookSection("3. Components", "./components/",
                    "Learn to build reusable components with props, children, and conditional rendering."
                ),
                BookSection("4. Async Patterns", "./async/",
                    "Handle async data with Resources and Suspense boundaries."
                ),
                BookSection("5. Server Features", "./server/",
                    "Explore SSR, server functions, and real-time WebSocket communication."
                ),
                BookSection("6. Routing", "./routing/",
                    "Navigate between pages with file-based routing and client-side navigation."
                )
            )
        ),

        # Why Fine-Grained Reactivity
        Section(:class => "py-12",
            H2(:class => "text-3xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Why Fine-Grained Reactivity?"
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(
                    H3(:class => "text-xl font-serif font-semibold text-neutral-800 dark:text-neutral-200 mb-4",
                        "Traditional Virtual DOM"
                    ),
                    Ul(:class => "space-y-3 text-neutral-600 dark:text-neutral-400",
                        Li("Re-renders entire component trees on state change"),
                        Li("Requires expensive diffing to find what changed"),
                        Li("Components re-execute even when their props haven't changed"),
                        Li("Optimization requires manual memoization (useMemo, React.memo)")
                    )
                ),
                Div(:class => "bg-emerald-50 dark:bg-emerald-950/30 rounded-lg p-6 border border-emerald-200 dark:border-emerald-900",
                    H3(:class => "text-xl font-serif font-semibold text-emerald-800 dark:text-emerald-300 mb-4",
                        "Therapy.jl (Fine-Grained)"
                    ),
                    Ul(:class => "space-y-3 text-emerald-700 dark:text-emerald-400",
                        Li("Updates only the specific DOM nodes that depend on changed signals"),
                        Li("No diffing needed\u2014direct DOM updates"),
                        Li("Components run once to set up subscriptions"),
                        Li("Reactive by default, no manual optimization needed")
                    )
                )
            )
        ),

        # Quick Example
        Section(:class => "py-12",
            H2(:class => "text-3xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "A Quick Example"
            ),
            Div(:class => "bg-neutral-900 dark:bg-neutral-950 rounded border border-neutral-800 p-6 max-w-3xl overflow-x-auto",
                Pre(:class => "text-sm text-neutral-100",
                    Code(:class => "language-julia", """using Therapy

# Create a reactive signal
count, set_count = create_signal(0)

# Create an effect that runs when count changes
create_effect() do
    println("Count is now: ", count())
end

# Update the signal - effect automatically re-runs
set_count(1)  # Prints: "Count is now: 1"
set_count(2)  # Prints: "Count is now: 2"

# Build a component with reactive state
function Counter()
    count, set_count = create_signal(0)

    Div(:class => "flex gap-4 items-center",
        Button(:on_click => () -> set_count(count() - 1), "-"),
        Span(count),  # Only this Span updates when count changes!
        Button(:on_click => () -> set_count(count() + 1), "+")
    )
end""")
                )
            ),
            P(:class => "mt-6 text-neutral-600 dark:text-neutral-400",
                "Notice how the ", Code(:class => "text-emerald-700 dark:text-emerald-400", "Span(count)"),
                " automatically updates when ", Code(:class => "text-emerald-700 dark:text-emerald-400", "count"),
                " changes. The buttons and other elements don't re-render."
            )
        ),

        # Prerequisites
        Section(:class => "py-12 bg-amber-50 dark:bg-amber-950/20 rounded-lg border border-amber-200 dark:border-amber-900 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-amber-900 dark:text-amber-200 mb-4",
                "Prerequisites"
            ),
            P(:class => "text-amber-800 dark:text-amber-300 mb-4",
                "This book assumes you have:"
            ),
            Ul(:class => "space-y-2 text-amber-700 dark:text-amber-400",
                Li("Basic familiarity with Julia (functions, types, macros)"),
                Li("Understanding of HTML and CSS (we use Tailwind CSS for styling)"),
                Li("Julia 1.10+ installed (Julia 1.12 recommended for Wasm compilation)")
            )
        ),

        # Navigation
        Div(:class => "py-12 flex justify-end",
            A(:href => "./getting-started/",
              :class => "inline-flex items-center px-6 py-3 bg-emerald-700 hover:bg-emerald-800 dark:bg-emerald-600 dark:hover:bg-emerald-500 text-white rounded font-medium transition-colors",
                "Start Learning",
                Svg(:class => "ml-2 w-5 h-5", :fill => "none", :viewBox => "0 0 24 24", :stroke => "currentColor",
                    Path(:stroke_linecap => "round", :stroke_linejoin => "round", :stroke_width => "2", :d => "M13 7l5 5m0 0l-5 5m5-5H6")
                )
            )
        )
    )
end

function BookSection(title, href, description)
    A(:href => href, :class => "block p-6 bg-white dark:bg-neutral-800 rounded-lg border border-neutral-200 dark:border-neutral-700 hover:border-emerald-500 dark:hover:border-emerald-600 transition-colors",
        H3(:class => "text-lg font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-2", title),
        P(:class => "text-neutral-600 dark:text-neutral-400 text-sm", description)
    )
end

# Export the page component
Index
