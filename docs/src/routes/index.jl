# Home page

include("../components/Layout.jl")

function Index()
    Layout(
        # Hero Section
        Div(:class => "py-16 sm:py-24",
            Div(:class => "text-center",
                H1(:class => "text-4xl sm:text-6xl font-bold text-gray-900 tracking-tight",
                    "Reactive Web Apps",
                    Br(),
                    Span(:class => "text-indigo-600", "in Pure Julia")
                ),
                P(:class => "mt-6 text-xl text-gray-500 max-w-2xl mx-auto",
                    "Build interactive web applications with fine-grained reactivity, server-side rendering, and WebAssembly compilation. Inspired by SolidJS and Leptos."
                ),
                Div(:class => "mt-10 flex justify-center gap-4",
                    A(:href => "/getting-started/",
                      :class => "bg-indigo-600 text-white px-6 py-3 rounded-lg font-medium hover:bg-indigo-500 transition",
                      "Get Started"
                    ),
                    A(:href => "https://github.com/daleblack/Therapy.jl",
                      :class => "bg-gray-100 text-gray-700 px-6 py-3 rounded-lg font-medium hover:bg-gray-200 transition",
                      :target => "_blank",
                      "View on GitHub"
                    )
                )
            )
        ),

        # Feature Grid
        Div(:class => "py-16 bg-white rounded-2xl shadow-sm",
            H2(:class => "text-3xl font-bold text-center text-gray-900 mb-12",
                "Why Therapy.jl?"
            ),
            Div(:class => "grid md:grid-cols-3 gap-8 px-8",
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
        Div(:class => "py-16",
            H2(:class => "text-3xl font-bold text-center text-gray-900 mb-8",
                "Simple, Familiar API"
            ),
            Div(:class => "bg-gray-900 rounded-xl p-6 max-w-3xl mx-auto overflow-x-auto",
                Pre(:class => "text-sm text-gray-100",
                    Code(:class => "language-julia", """using Therapy

function Counter()
    count, set_count = create_signal(0)

    Div(:class => "flex gap-4 items-center",
        Button(:on_click => () -> set_count(count() - 1), "-"),
        Span(:class => "text-2xl", count),
        Button(:on_click => () -> set_count(count() + 1), "+")
    )
end

# Render to HTML
html = render_to_string(Counter())""")
                )
            )
        ),

        # Interactive Demo Section
        Div(:class => "py-16 bg-gradient-to-r from-indigo-500 to-purple-600 rounded-2xl text-white",
            Div(:class => "text-center px-8",
                H2(:class => "text-3xl font-bold mb-4",
                    "Try It Live"
                ),
                P(:class => "text-indigo-100 mb-8 max-w-xl mx-auto",
                    "This counter is running in your browser as WebAssembly compiled from Julia using Therapy.jl. Click the buttons to see it in action!"
                ),
                # Placeholder - the actual compiled counter component is injected by build.jl
                Div(:class => "bg-white/10 backdrop-blur rounded-xl p-8 max-w-md mx-auto",
                    :id => "counter-demo",
                    "Loading..."
                )
            )
        )
    )
end

function FeatureCard(title, description, icon_path)
    Div(:class => "text-center p-6",
        Div(:class => "w-12 h-12 bg-indigo-100 rounded-lg flex items-center justify-center mx-auto mb-4",
            Svg(:class => "w-6 h-6 text-indigo-600", :fill => "none", :viewBox => "0 0 24 24", :stroke => "currentColor", :stroke_width => "2",
                Path(:stroke_linecap => "round", :stroke_linejoin => "round", :d => icon_path)
            )
        ),
        H3(:class => "text-lg font-semibold text-gray-900 mb-2", title),
        P(:class => "text-gray-500", description)
    )
end

# Export the page component
Index
