# Home page
#
# Uses Suite.jl components for visual presentation.
# Keeps all existing content — only changes visual styling.

import Suite

function Index()
    # Content only - Layout applied at app level for true SPA navigation
    Fragment(
        # Hero Section
        Div(:class => "py-20 sm:py-28",
            Div(:class => "text-center",
                H1(:class => "text-4xl sm:text-6xl font-serif font-semibold text-warm-800 dark:text-warm-50 tracking-tight leading-tight",
                    "Reactive Web Apps",
                    Br(),
                    Span(:class => "text-accent-700 dark:text-accent-400", "in Pure Julia")
                ),
                P(:class => "mt-8 text-xl text-warm-600 dark:text-warm-300 max-w-2xl mx-auto leading-relaxed",
                    "Build interactive web applications with fine-grained reactivity, server-side rendering, and JavaScript compilation. Inspired by SolidJS and Leptos."
                ),
                Div(:class => "mt-8 flex justify-center gap-3 flex-wrap",
                    Suite.Badge("Fine-Grained Reactivity"),
                    Suite.Badge("SSR + Hydration", variant="secondary"),
                    Suite.Badge("JavaScript", variant="outline"),
                ),
                Div(:class => "mt-10 flex justify-center gap-4",
                    A(:href => "./getting-started/",
                        Suite.Button(variant="default", size="lg", "Get Started")
                    ),
                    A(:href => "https://github.com/GroupTherapyOrg/Therapy.jl",
                      :target => "_blank",
                        Suite.Button(variant="outline", size="lg", "View on GitHub")
                    )
                )
            )
        ),

        # Feature Grid
        Div(:class => "py-16",
            H2(:class => "text-3xl font-serif font-semibold text-center text-warm-800 dark:text-warm-50 mb-12",
                "Why Therapy.jl?"
            ),
            Div(:class => "grid md:grid-cols-3 gap-6",
                _FeatureCard(
                    "Fine-Grained Reactivity",
                    "SolidJS-style signals and effects that update only what changes. No virtual DOM diffing.",
                    "M13 10V3L4 14h7v7l9-11h-7z"
                ),
                _FeatureCard(
                    "Server-Side Rendering",
                    "Full SSR support with hydration. Fast initial page loads with interactive client-side updates.",
                    "M5 12h14M12 5l7 7-7 7"
                ),
                _FeatureCard(
                    "JavaScript Compilation",
                    "Compile Julia directly to JavaScript for seamless interactivity in the browser.",
                    "M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4"
                )
            )
        ),

        # Code Example
        Div(:class => "py-20",
            H2(:class => "text-3xl font-serif font-semibold text-center text-warm-800 dark:text-warm-50 mb-10",
                "Simple, Familiar API"
            ),
            Div(:class => "max-w-3xl mx-auto",
                Suite.CodeBlock("""using Therapy

# @island marks this component as interactive (compiles to JS)
@island function Counter()
    count, set_count = create_signal(0)

    Div(:class => "flex gap-4 items-center",
        Button(:on_click => () -> set_count(count() - 1), "-"),
        Span(:class => "text-2xl", count),
        Button(:on_click => () -> set_count(count() + 1), "+")
    )
end

# Islands auto-discovered - no manual config needed!
app = App(routes_dir = "routes", components_dir = "components")
Therapy.run(app)  # julia app.jl dev""", language="julia")
            )
        ),

        # Interactive Demo Section
        Div(:class => "py-16",
            Suite.Card(class="bg-gradient-to-br from-warm-50 to-warm-100 dark:from-warm-900 dark:to-warm-950",
                Suite.CardHeader(class="text-center",
                    Suite.CardTitle(class="text-3xl font-serif",
                        "Try It Live"
                    ),
                    Suite.CardDescription(class="max-w-xl mx-auto leading-relaxed",
                        "This counter is running in your browser as JavaScript compiled from Julia using Therapy.jl. Click the buttons to see it in action!"
                    ),
                ),
                Suite.CardContent(class="flex justify-center",
                    Div(:class => "bg-warm-50/70 dark:bg-warm-900/70 backdrop-blur rounded-md border border-warm-200 dark:border-warm-800 p-8 max-w-md w-full",
                        InteractiveCounter()
                    )
                )
            )
        )
    )
end

function _FeatureCard(title, description, icon_path)
    Suite.Card(class="text-center",
        Suite.CardHeader(
            Div(:class => "w-12 h-12 bg-warm-100 dark:bg-warm-800 rounded-md flex items-center justify-center mx-auto mb-2",
                Svg(:class => "w-6 h-6 text-accent-700 dark:text-accent-400", :fill => "none", :viewBox => "0 0 24 24", :stroke => "currentColor", :stroke_width => "2",
                    Path(:stroke_linecap => "round", :stroke_linejoin => "round", :d => icon_path)
                )
            ),
            Suite.CardTitle(class="font-serif", title),
        ),
        Suite.CardContent(
            P(:class => "text-warm-600 dark:text-warm-400 leading-relaxed", description)
        )
    )
end

# Export the page component
Index
