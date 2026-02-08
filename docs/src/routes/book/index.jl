# Book Index - Introduction to Therapy.jl
#
# The comprehensive guide to building reactive web applications with Julia.
# Follows the Leptos book structure with Julia-native conventions.
#
# Note: This page uses BookLayout to wrap content with sidebar navigation.
# BookLayout is auto-discovered from docs/src/components/BookLayout.jl

import Suite

# Helper components defined first
function _BookChapterCard(number, title, href, description)
    A(:href => href, :class => "block group",
        Suite.Card(class="hover:border-accent-400 dark:hover:border-accent-500 transition-colors h-full",
            Suite.CardHeader(
                Div(:class => "flex items-center gap-2 mb-1",
                    Suite.Badge(variant="outline", number)
                ),
                Suite.CardTitle(:class => "font-serif group-hover:text-accent-700 dark:group-hover:text-accent-400 transition-colors", title),
            ),
            Suite.CardDescription(description)
        )
    )
end

function _FeatureCard(title, description, icon_path)
    Suite.Card(
        Suite.CardHeader(
            Div(:class => "flex items-start gap-4",
                Div(:class => "flex-shrink-0 w-10 h-10 bg-warm-100 dark:bg-warm-800 rounded-lg flex items-center justify-center",
                    Svg(:class => "w-6 h-6 text-accent-700 dark:text-accent-400", :fill => "none", :viewBox => "0 0 24 24", :stroke_width => "1.5", :stroke => "currentColor",
                        Path(:stroke_linecap => "round", :stroke_linejoin => "round", :d => icon_path)
                    )
                ),
                Div(
                    Suite.CardTitle(:class => "font-serif", title),
                    Suite.CardDescription(description)
                )
            )
        )
    )
end

# The page function - must be the last expression so `include()` returns it
() -> BookLayout("/book/",
    # Header
    Div(:class => "py-12 border-b border-warm-200 dark:border-warm-700",
        Suite.Badge(variant="outline", "Introduction"),
        H1(:class => "text-4xl sm:text-5xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6 mt-2",
            "The Therapy.jl Book"
        ),
        P(:class => "text-xl text-warm-600 dark:text-warm-300 max-w-3xl leading-relaxed",
            "A comprehensive guide to building reactive web applications with Julia. ",
            "Learn fine-grained reactivity, server-side rendering, and WebAssembly compilation."
        )
    ),

    # What is Therapy.jl
    Section(:class => "py-12",
        H2(:class => "text-3xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
            "What is Therapy.jl?"
        ),
        Div(:class => "prose dark:prose-invert max-w-none",
            P(:class => "text-lg text-warm-600 dark:text-warm-300 leading-relaxed mb-6",
                "Therapy.jl is a reactive web framework for Julia inspired by SolidJS and Leptos. ",
                "It provides fine-grained reactivity, server-side rendering, and the ability to compile Julia code directly to WebAssembly."
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 leading-relaxed mb-6",
                "Unlike virtual DOM frameworks like React, Therapy.jl tracks dependencies at the signal level. ",
                "When a signal changes, only the specific DOM nodes that depend on it are updated—no diffing required."
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 leading-relaxed",
                "This book will teach you everything you need to know to build production-ready web applications with Therapy.jl."
            )
        )
    ),

    # Book Structure
    Section(:class => "py-12",
        H2(:class => "text-3xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-8",
            "What You'll Learn"
        ),
        Div(:class => "grid md:grid-cols-2 lg:grid-cols-3 gap-6",
            _BookChapterCard("1", "Getting Started", "./getting-started/",
                "Set up your first Therapy.jl project and build a simple interactive application."
            ),
            _BookChapterCard("2", "Reactivity", "./reactivity/",
                "Master signals, effects, and memos—the building blocks of fine-grained reactivity."
            ),
            _BookChapterCard("3", "Components", "./components/",
                "Learn to build reusable components with props, children, and conditional rendering."
            ),
            _BookChapterCard("4", "Async Patterns", "./async/",
                "Handle async data with Resources and Suspense boundaries."
            ),
            _BookChapterCard("5", "Server Features", "./server/",
                "Explore SSR, server functions, and real-time WebSocket communication."
            ),
            _BookChapterCard("6", "Routing", "./routing/",
                "Navigate between pages with file-based routing and client-side navigation."
            )
        )
    ),

    Suite.Separator(),

    # Why Fine-Grained Reactivity
    Section(:class => "py-12",
        H2(:class => "text-3xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
            "Why Fine-Grained Reactivity?"
        ),
        Div(:class => "grid md:grid-cols-2 gap-8",
            Suite.Card(
                Suite.CardHeader(
                    Suite.CardTitle(:class => "font-serif", "Traditional Virtual DOM (React, Vue)")
                ),
                Suite.CardContent(
                    Ul(:class => "space-y-3 text-warm-600 dark:text-warm-400",
                        Li("Re-renders entire component trees on state change"),
                        Li("Requires expensive diffing to find what changed"),
                        Li("Components re-execute even when their props haven't changed"),
                        Li("Optimization requires manual memoization (useMemo, React.memo)")
                    )
                )
            ),
            Suite.Card(class="border-accent-200 dark:border-accent-700",
                Suite.CardHeader(
                    Suite.CardTitle(:class => "font-serif text-accent-800 dark:text-accent-300", "Therapy.jl (Fine-Grained)")
                ),
                Suite.CardContent(
                    Ul(:class => "space-y-3 text-accent-700 dark:text-accent-400",
                        Li("Updates only the specific DOM nodes that depend on changed signals"),
                        Li("No diffing needed—direct DOM updates"),
                        Li("Components run once to set up subscriptions"),
                        Li("Reactive by default, no manual optimization needed")
                    )
                )
            )
        )
    ),

    Suite.Separator(),

    # Comparison to Other Frameworks
    Section(:class => "py-12",
        H2(:class => "text-3xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-8",
            "How Therapy.jl Compares"
        ),
        P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-8",
            "Therapy.jl takes inspiration from the best ideas across the web framework ecosystem, adapted for Julia's strengths."
        ),
        Suite.Table(
            Suite.TableHeader(
                Suite.TableRow(
                    Suite.TableHead("Feature"),
                    Suite.TableHead("React"),
                    Suite.TableHead("Vue"),
                    Suite.TableHead("Svelte"),
                    Suite.TableHead(class="text-accent-700 dark:text-accent-400", "Therapy.jl")
                )
            ),
            Suite.TableBody(
                Suite.TableRow(
                    Suite.TableCell("Reactivity Model"),
                    Suite.TableCell("VDOM Diffing"),
                    Suite.TableCell("Proxy-based"),
                    Suite.TableCell("Compiler"),
                    Suite.TableCell(class="text-accent-700 dark:text-accent-400", "Fine-grained signals")
                ),
                Suite.TableRow(
                    Suite.TableCell("SSR Support"),
                    Suite.TableCell("Next.js"),
                    Suite.TableCell("Nuxt"),
                    Suite.TableCell("SvelteKit"),
                    Suite.TableCell(class="text-accent-700 dark:text-accent-400", "Built-in")
                ),
                Suite.TableRow(
                    Suite.TableCell("Islands Architecture"),
                    Suite.TableCell("Astro addon"),
                    Suite.TableCell("Nuxt Content"),
                    Suite.TableCell("Manual"),
                    Suite.TableCell(class="text-accent-700 dark:text-accent-400", "Native @island")
                ),
                Suite.TableRow(
                    Suite.TableCell("Client Runtime"),
                    Suite.TableCell("JavaScript"),
                    Suite.TableCell("JavaScript"),
                    Suite.TableCell("JavaScript"),
                    Suite.TableCell(class="text-accent-700 dark:text-accent-400", "WebAssembly")
                ),
                Suite.TableRow(
                    Suite.TableCell("Language"),
                    Suite.TableCell("JavaScript/TS"),
                    Suite.TableCell("JavaScript/TS"),
                    Suite.TableCell("JavaScript/TS"),
                    Suite.TableCell(class="text-accent-700 dark:text-accent-400", "Julia")
                )
            )
        )
    ),

    Suite.Separator(),

    # Julia-Native Advantages
    Section(:class => "py-12",
        H2(:class => "text-3xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
            "The Julia Advantage"
        ),
        P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-8",
            "Therapy.jl isn't just a port of SolidJS to Julia—it leverages Julia's unique strengths for web development."
        ),
        Div(:class => "grid md:grid-cols-2 gap-6",
            _FeatureCard("Type-Safe by Design",
                "Julia's type system catches errors at compile time. Signals, components, and props all benefit from Julia's powerful type inference.",
                "M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
            ),
            _FeatureCard("One Language, Full Stack",
                "Write server logic, reactive UI, and compiled WebAssembly all in Julia. No context switching between languages.",
                "M6.429 9.75L2.25 12l4.179 2.25m0-4.5l5.571 3 5.571-3m-11.142 0L2.25 7.5 12 2.25l9.75 5.25-4.179 2.25m0 0L21.75 12l-4.179 2.25m0 0l4.179 2.25L12 21.75 2.25 16.5l4.179-2.25m11.142 0l-5.571 3-5.571-3"
            ),
            _FeatureCard("Scientific Computing Ready",
                "Integrate with Julia's rich ecosystem—Plots, DataFrames, DifferentialEquations—in your web components.",
                "M3.75 3v11.25A2.25 2.25 0 006 16.5h2.25M3.75 3h-1.5m1.5 0h16.5m0 0h1.5m-1.5 0v11.25A2.25 2.25 0 0118 16.5h-2.25m-7.5 0h7.5m-7.5 0l-1 3m8.5-3l1 3m0 0l.5 1.5m-.5-1.5h-9.5m0 0l-.5 1.5m.75-9l3-3 2.148 2.148A12.061 12.061 0 0116.5 7.605"
            ),
            _FeatureCard("Direct to WebAssembly",
                "Julia closures compile directly to WasmGC bytecode via WasmTarget.jl. No JavaScript runtime overhead for interactivity.",
                "M17.25 6.75L22.5 12l-5.25 5.25m-10.5 0L1.5 12l5.25-5.25m7.5-3l-4.5 16.5"
            )
        )
    ),

    Suite.Separator(),

    # Quick Example
    Section(:class => "py-12",
        H2(:class => "text-3xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
            "A Quick Example"
        ),
        Suite.CodeBlock(
            code="""using Therapy

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
end""",
            language="julia"
        ),
        P(:class => "mt-6 text-warm-600 dark:text-warm-400",
            "Notice how the ", Code(:class => "text-accent-700 dark:text-accent-400", "Span(count)"),
            " automatically updates when ", Code(:class => "text-accent-700 dark:text-accent-400", "count"),
            " changes. The buttons and other elements don't re-render."
        )
    ),

    # Interactive Demo
    Section(:class => "py-12 bg-gradient-to-br from-warm-50 to-warm-100 dark:from-warm-900 dark:to-warm-950 rounded-lg border border-warm-200 dark:border-warm-700",
        Div(:class => "text-center px-8",
            H2(:class => "text-3xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-4",
                "Try It Live"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-8 max-w-xl mx-auto",
                "This counter is a Therapy.jl island—an interactive component compiled to WebAssembly from pure Julia. ",
                "Click the buttons to see fine-grained reactivity in action!"
            ),
            Suite.Card(class="max-w-md mx-auto",
                Suite.CardContent(class="flex justify-center p-8",
                    InteractiveCounter()
                )
            ),
            P(:class => "text-sm text-warm-600 dark:text-warm-600 mt-4",
                "No JavaScript written. Julia code → WebAssembly → browser."
            )
        )
    ),

    # Prerequisites
    Suite.Alert(
        Suite.AlertTitle("Prerequisites"),
        Suite.AlertDescription(
            Div(
                P(:class => "mb-3", "This book assumes you have:"),
                Ul(:class => "space-y-2 list-disc pl-5",
                    Li("Basic familiarity with Julia (functions, types, macros)"),
                    Li("Understanding of HTML and CSS (we use Tailwind CSS for styling)"),
                    Li("Julia 1.10+ installed (Julia 1.12 recommended for Wasm compilation)")
                )
            )
        )
    ),

)  # End BookLayout
