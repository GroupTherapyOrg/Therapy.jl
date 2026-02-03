# Book Index - Introduction to Therapy.jl
#
# The comprehensive guide to building reactive web applications with Julia.
# Follows the Leptos book structure with Julia-native conventions.
#
# Note: This page uses BookLayout to wrap content with sidebar navigation.
# BookLayout is auto-discovered from docs/src/components/BookLayout.jl

# Helper components defined first
function BookSection(title, href, description)
    A(:href => href, :class => "block p-6 bg-white dark:bg-neutral-800 rounded-lg border border-neutral-200 dark:border-neutral-700 hover:border-emerald-500 dark:hover:border-emerald-600 transition-colors",
        H3(:class => "text-lg font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-2", title),
        P(:class => "text-neutral-600 dark:text-neutral-400 text-sm", description)
    )
end

function FeatureCard(title, description, icon_path)
    Div(:class => "bg-white dark:bg-neutral-800 rounded-lg border border-neutral-200 dark:border-neutral-700 p-6",
        Div(:class => "flex items-start gap-4",
            Div(:class => "flex-shrink-0 w-10 h-10 bg-emerald-100 dark:bg-emerald-900/50 rounded-lg flex items-center justify-center",
                Svg(:class => "w-6 h-6 text-emerald-700 dark:text-emerald-400", :fill => "none", :viewBox => "0 0 24 24", :stroke_width => "1.5", :stroke => "currentColor",
                    Path(:stroke_linecap => "round", :stroke_linejoin => "round", :d => icon_path)
                )
            ),
            Div(
                H3(:class => "text-lg font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-2", title),
                P(:class => "text-neutral-600 dark:text-neutral-400 text-sm", description)
            )
        )
    )
end

# The page function - must be the last expression so `include()` returns it
() -> BookLayout("/book/",
    # Header
    Div(:class => "py-12 border-b border-neutral-300 dark:border-neutral-800",
        Span(:class => "text-sm text-emerald-700 dark:text-emerald-400 font-medium", "Introduction"),
        H1(:class => "text-4xl sm:text-5xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6 mt-2",
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
                "When a signal changes, only the specific DOM nodes that depend on it are updated—no diffing required."
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
                "Master signals, effects, and memos—the building blocks of fine-grained reactivity."
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
                    "Traditional Virtual DOM (React, Vue)"
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
                    Li("No diffing needed—direct DOM updates"),
                    Li("Components run once to set up subscriptions"),
                    Li("Reactive by default, no manual optimization needed")
                )
            )
        )
    ),

    # Comparison to Other Frameworks
    Section(:class => "py-12 bg-neutral-50 dark:bg-neutral-900 rounded-lg border border-neutral-300 dark:border-neutral-800 px-8",
        H2(:class => "text-3xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-8",
            "How Therapy.jl Compares"
        ),
        P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-8",
            "Therapy.jl takes inspiration from the best ideas across the web framework ecosystem, adapted for Julia's strengths."
        ),
        Div(:class => "overflow-x-auto",
            Table(:class => "w-full text-sm",
                Thead(
                    Tr(:class => "border-b border-neutral-300 dark:border-neutral-700",
                        Th(:class => "text-left py-3 px-4 font-serif font-semibold text-neutral-900 dark:text-neutral-100", "Feature"),
                        Th(:class => "text-left py-3 px-4 font-serif font-semibold text-neutral-900 dark:text-neutral-100", "React"),
                        Th(:class => "text-left py-3 px-4 font-serif font-semibold text-neutral-900 dark:text-neutral-100", "Vue"),
                        Th(:class => "text-left py-3 px-4 font-serif font-semibold text-neutral-900 dark:text-neutral-100", "Svelte"),
                        Th(:class => "text-left py-3 px-4 font-serif font-semibold text-emerald-700 dark:text-emerald-400", "Therapy.jl")
                    )
                ),
                Tbody(
                    Tr(:class => "border-b border-neutral-200 dark:border-neutral-800",
                        Td(:class => "py-3 px-4 text-neutral-900 dark:text-neutral-100", "Reactivity Model"),
                        Td(:class => "py-3 px-4 text-neutral-600 dark:text-neutral-400", "VDOM Diffing"),
                        Td(:class => "py-3 px-4 text-neutral-600 dark:text-neutral-400", "Proxy-based"),
                        Td(:class => "py-3 px-4 text-neutral-600 dark:text-neutral-400", "Compiler"),
                        Td(:class => "py-3 px-4 text-emerald-700 dark:text-emerald-400", "Fine-grained signals")
                    ),
                    Tr(:class => "border-b border-neutral-200 dark:border-neutral-800",
                        Td(:class => "py-3 px-4 text-neutral-900 dark:text-neutral-100", "SSR Support"),
                        Td(:class => "py-3 px-4 text-neutral-600 dark:text-neutral-400", "Next.js"),
                        Td(:class => "py-3 px-4 text-neutral-600 dark:text-neutral-400", "Nuxt"),
                        Td(:class => "py-3 px-4 text-neutral-600 dark:text-neutral-400", "SvelteKit"),
                        Td(:class => "py-3 px-4 text-emerald-700 dark:text-emerald-400", "Built-in")
                    ),
                    Tr(:class => "border-b border-neutral-200 dark:border-neutral-800",
                        Td(:class => "py-3 px-4 text-neutral-900 dark:text-neutral-100", "Islands Architecture"),
                        Td(:class => "py-3 px-4 text-neutral-600 dark:text-neutral-400", "Astro addon"),
                        Td(:class => "py-3 px-4 text-neutral-600 dark:text-neutral-400", "Nuxt Content"),
                        Td(:class => "py-3 px-4 text-neutral-600 dark:text-neutral-400", "Manual"),
                        Td(:class => "py-3 px-4 text-emerald-700 dark:text-emerald-400", "Native island()")
                    ),
                    Tr(:class => "border-b border-neutral-200 dark:border-neutral-800",
                        Td(:class => "py-3 px-4 text-neutral-900 dark:text-neutral-100", "Client Runtime"),
                        Td(:class => "py-3 px-4 text-neutral-600 dark:text-neutral-400", "JavaScript"),
                        Td(:class => "py-3 px-4 text-neutral-600 dark:text-neutral-400", "JavaScript"),
                        Td(:class => "py-3 px-4 text-neutral-600 dark:text-neutral-400", "JavaScript"),
                        Td(:class => "py-3 px-4 text-emerald-700 dark:text-emerald-400", "WebAssembly")
                    ),
                    Tr(
                        Td(:class => "py-3 px-4 text-neutral-900 dark:text-neutral-100", "Language"),
                        Td(:class => "py-3 px-4 text-neutral-600 dark:text-neutral-400", "JavaScript/TS"),
                        Td(:class => "py-3 px-4 text-neutral-600 dark:text-neutral-400", "JavaScript/TS"),
                        Td(:class => "py-3 px-4 text-neutral-600 dark:text-neutral-400", "JavaScript/TS"),
                        Td(:class => "py-3 px-4 text-emerald-700 dark:text-emerald-400", "Julia")
                    )
                )
            )
        )
    ),

    # Julia-Native Advantages
    Section(:class => "py-12",
        H2(:class => "text-3xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
            "The Julia Advantage"
        ),
        P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-8",
            "Therapy.jl isn't just a port of SolidJS to Julia—it leverages Julia's unique strengths for web development."
        ),
        Div(:class => "grid md:grid-cols-2 gap-6",
            FeatureCard("Type-Safe by Design",
                "Julia's type system catches errors at compile time. Signals, components, and props all benefit from Julia's powerful type inference.",
                "M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
            ),
            FeatureCard("One Language, Full Stack",
                "Write server logic, reactive UI, and compiled WebAssembly all in Julia. No context switching between languages.",
                "M6.429 9.75L2.25 12l4.179 2.25m0-4.5l5.571 3 5.571-3m-11.142 0L2.25 7.5 12 2.25l9.75 5.25-4.179 2.25m0 0L21.75 12l-4.179 2.25m0 0l4.179 2.25L12 21.75 2.25 16.5l4.179-2.25m11.142 0l-5.571 3-5.571-3"
            ),
            FeatureCard("Scientific Computing Ready",
                "Integrate with Julia's rich ecosystem—Plots, DataFrames, DifferentialEquations—in your web components.",
                "M3.75 3v11.25A2.25 2.25 0 006 16.5h2.25M3.75 3h-1.5m1.5 0h16.5m0 0h1.5m-1.5 0v11.25A2.25 2.25 0 0118 16.5h-2.25m-7.5 0h7.5m-7.5 0l-1 3m8.5-3l1 3m0 0l.5 1.5m-.5-1.5h-9.5m0 0l-.5 1.5m.75-9l3-3 2.148 2.148A12.061 12.061 0 0116.5 7.605"
            ),
            FeatureCard("Direct to WebAssembly",
                "Julia closures compile directly to WasmGC bytecode via WasmTarget.jl. No JavaScript runtime overhead for interactivity.",
                "M17.25 6.75L22.5 12l-5.25 5.25m-10.5 0L1.5 12l5.25-5.25m7.5-3l-4.5 16.5"
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

    # Interactive Demo
    Section(:class => "py-12 bg-gradient-to-br from-emerald-50 to-amber-50 dark:from-emerald-950/20 dark:to-amber-950/20 rounded-lg border border-neutral-300 dark:border-neutral-800",
        Div(:class => "text-center px-8",
            H2(:class => "text-3xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-4",
                "Try It Live"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-8 max-w-xl mx-auto",
                "This counter is a Therapy.jl island—an interactive component compiled to WebAssembly from pure Julia. ",
                "Click the buttons to see fine-grained reactivity in action!"
            ),
            Div(:class => "bg-white/70 dark:bg-neutral-900/70 backdrop-blur rounded border border-neutral-300 dark:border-neutral-700 p-8 max-w-md mx-auto",
                InteractiveCounter()
            ),
            P(:class => "text-sm text-neutral-500 dark:text-neutral-500 mt-4",
                "No JavaScript written. Julia code → WebAssembly → browser."
            )
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

)  # End BookLayout
