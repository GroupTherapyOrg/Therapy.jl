# Home page
#
# Parchment/paper theme with sage and amber accents
# Serif headings for scholarly aesthetic

function Index()
    # Content only - Layout applied at app level for true SPA navigation
    Fragment(
        # Hero Section
        Div(:class => "py-20 sm:py-28",
            Div(:class => "text-center",
                H1(:class => "text-4xl sm:text-6xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 tracking-tight leading-tight",
                    "Reactive Web Apps",
                    Br(),
                    Span(:class => "text-emerald-700 dark:text-emerald-400", "in Pure Julia")
                ),
                P(:class => "mt-8 text-xl text-neutral-600 dark:text-neutral-300 max-w-2xl mx-auto leading-relaxed",
                    "Build interactive web applications with fine-grained reactivity, server-side rendering, and WebAssembly compilation. Inspired by SolidJS and Leptos."
                ),
                Div(:class => "mt-12 flex justify-center gap-4",
                    A(:href => "getting-started/",
                      :class => "bg-emerald-700 hover:bg-emerald-800 dark:bg-emerald-600 dark:hover:bg-emerald-500 text-white px-8 py-3 rounded font-medium transition-colors shadow-sm",
                      "Get Started"
                    ),
                    A(:href => "https://github.com/TherapeuticJulia/Therapy.jl",
                      :class => "bg-neutral-200 dark:bg-neutral-800 text-neutral-700 dark:text-neutral-200 px-8 py-3 rounded font-medium hover:bg-neutral-300 dark:hover:bg-neutral-700 transition-colors",
                      :target => "_blank",
                      "View on GitHub"
                    )
                )
            )
        ),

        # Feature Grid
        Div(:class => "py-16 bg-neutral-50 dark:bg-neutral-900 rounded-lg border border-neutral-300 dark:border-neutral-800 transition-colors duration-200",
            H2(:class => "text-3xl font-serif font-semibold text-center text-neutral-900 dark:text-neutral-100 mb-12",
                "Why Therapy.jl?"
            ),
            Div(:class => "grid md:grid-cols-3 gap-10 px-10",
                FeatureCard(
                    "Fine-Grained Reactivity",
                    "SolidJS-style signals and effects that update only what changes. No virtual DOM diffing.",
                    "M13 10V3L4 14h7v7l9-11h-7z"
                ),
                FeatureCard(
                    "Server-Side Rendering",
                    "Full SSR support with hydration. Fast initial page loads with interactive client-side updates.",
                    "M5 12h14M12 5l7 7-7 7"
                ),
                FeatureCard(
                    "WebAssembly Compilation",
                    "Compile Julia directly to Wasm for near-native performance in the browser.",
                    "M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4"
                )
            )
        ),

        # Code Example
        Div(:class => "py-20",
            H2(:class => "text-3xl font-serif font-semibold text-center text-neutral-900 dark:text-neutral-100 mb-10",
                "Simple, Familiar API"
            ),
            Div(:class => "bg-neutral-900 dark:bg-neutral-950 rounded border border-neutral-800 p-6 max-w-3xl mx-auto overflow-x-auto shadow-lg",
                Pre(:class => "text-sm text-neutral-100",
                    Code(:class => "language-julia", """using Therapy

# island() marks this component as interactive (compiles to Wasm)
Counter = island(:Counter) do
    count, set_count = create_signal(0)

    Div(:class => "flex gap-4 items-center",
        Button(:on_click => () -> set_count(count() - 1), "-"),
        Span(:class => "text-2xl", count),
        Button(:on_click => () -> set_count(count() + 1), "+")
    )
end

# Islands auto-discovered - no manual config needed!
app = App(routes_dir = "routes", components_dir = "components")
Therapy.run(app)  # julia app.jl dev""")
                )
            )
        ),

        # Interactive Demo Section
        Div(:class => "py-16 bg-gradient-to-br from-emerald-50 to-amber-50 dark:from-emerald-950/20 dark:to-amber-950/20 rounded-lg border border-neutral-300 dark:border-neutral-800",
            Div(:class => "text-center px-8",
                H2(:class => "text-3xl font-serif font-semibold mb-4 text-neutral-900 dark:text-neutral-100",
                    "Try It Live"
                ),
                P(:class => "text-neutral-600 dark:text-neutral-300 mb-10 max-w-xl mx-auto leading-relaxed",
                    "This counter is running in your browser as WebAssembly compiled from Julia using Therapy.jl. Click the buttons to see it in action!"
                ),
                # Island renders directly - no placeholder needed!
                Div(:class => "bg-white/70 dark:bg-neutral-900/70 backdrop-blur rounded border border-neutral-300 dark:border-neutral-700 p-8 max-w-md mx-auto",
                    InteractiveCounter()
                )
            )
        )
    )
end

function FeatureCard(title, description, icon_path)
    Div(:class => "text-center p-6",
        Div(:class => "w-12 h-12 bg-emerald-100 dark:bg-emerald-950/40 rounded border border-emerald-200 dark:border-emerald-900 flex items-center justify-center mx-auto mb-5",
            Svg(:class => "w-6 h-6 text-emerald-700 dark:text-emerald-400", :fill => "none", :viewBox => "0 0 24 24", :stroke => "currentColor", :stroke_width => "2",
                Path(:stroke_linecap => "round", :stroke_linejoin => "round", :d => icon_path)
            )
        ),
        H3(:class => "text-lg font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-3", title),
        P(:class => "text-neutral-600 dark:text-neutral-400 leading-relaxed", description)
    )
end

# Export the page component
Index
