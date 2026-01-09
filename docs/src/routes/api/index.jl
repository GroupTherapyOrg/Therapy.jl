# API Documentation Index
#
# Placeholder for API reference documentation

function ApiIndex()
    Layout(
        Div(:class => "max-w-4xl mx-auto",
            # Page Header
            Div(:class => "mb-12",
                H1(:class => "text-4xl font-bold text-stone-800 dark:text-stone-100 mb-4",
                    "API Reference"
                ),
                P(:class => "text-xl text-stone-500 dark:text-stone-400",
                    "Complete reference documentation for Therapy.jl's API."
                )
            ),

            # Coming Soon Notice
            Div(:class => "bg-orange-100/50 dark:bg-yellow-950/30 rounded-xl p-8 mb-8",
                Div(:class => "flex items-center gap-4 mb-4",
                    Div(:class => "w-12 h-12 bg-orange-200 dark:bg-yellow-950/50 rounded-lg flex items-center justify-center",
                        Svg(:class => "w-6 h-6 text-orange-500 dark:text-yellow-600", :fill => "none", :viewBox => "0 0 24 24", :stroke => "currentColor", :stroke_width => "2",
                            Path(:stroke_linecap => "round", :stroke_linejoin => "round", :d => "M12 6v6m0 0v6m0-6h6m-6 0H6")
                        )
                    ),
                    H2(:class => "text-2xl font-bold text-stone-800 dark:text-stone-100",
                        "Documentation Coming Soon"
                    )
                ),
                P(:class => "text-stone-600 dark:text-stone-300 mb-4",
                    "We're working on comprehensive API documentation. In the meantime, explore these sections:"
                )
            ),

            # API Sections Preview
            Div(:class => "grid md:grid-cols-2 gap-6",
                ApiSection(
                    "Signals",
                    "Reactive primitives for state management",
                    "/api/signals/",
                    ["create_signal", "batch", "untrack"]
                ),
                ApiSection(
                    "Effects",
                    "Side effects and subscriptions",
                    "/api/effects/",
                    ["create_effect", "dispose!", "on_cleanup"]
                ),
                ApiSection(
                    "Memos",
                    "Cached computed values",
                    "/api/memos/",
                    ["create_memo"]
                ),
                ApiSection(
                    "Components",
                    "Component definition and lifecycle",
                    "/api/components/",
                    ["component", "render_component", "on_mount"]
                ),
                ApiSection(
                    "DOM Elements",
                    "HTML element constructors",
                    "/api/elements/",
                    ["Div", "Span", "Button", "Input", "..."]
                ),
                ApiSection(
                    "SSR",
                    "Server-side rendering utilities",
                    "/api/ssr/",
                    ["render_to_string", "render_page"]
                )
            ),

            # Quick Reference
            Section(:class => "mt-12",
                H2(:class => "text-2xl font-bold text-stone-800 dark:text-stone-100 mb-6",
                    "Quick Reference"
                ),
                Div(:class => "bg-stone-800 dark:bg-stone-950 rounded-lg overflow-x-auto shadow-lg",
                    Pre(:class => "p-4 text-sm text-stone-100",
                        Code(:class => "language-julia", """using Therapy

# Signals - reactive state
count, set_count = create_signal(0)
count()           # Read: 0
set_count(5)      # Write

# Effects - side effects
create_effect(() -> println("Count: ", count()))

# Memos - cached computations
doubled = create_memo(() -> count() * 2)

# DOM Elements
Div(:class => "container",
    Button(:on_click => () -> set_count(count() + 1), "+")
)

# SSR
html = render_to_string(MyComponent())""")
                    )
                )
            )
        )
    )
end

function ApiSection(title, description, href, functions)
    A(:href => href, :class => "block",
        Div(:class => "bg-white dark:bg-stone-800 rounded-xl p-6 border border-stone-200 dark:border-stone-700 hover:border-orange-200 dark:hover:border-yellow-900 transition-colors",
            H3(:class => "text-lg font-semibold text-stone-800 dark:text-stone-100 mb-2",
                title
            ),
            P(:class => "text-stone-500 dark:text-stone-400 text-sm mb-4",
                description
            ),
            Div(:class => "flex flex-wrap gap-2",
                [Span(:class => "text-xs bg-stone-100 dark:bg-stone-700 text-stone-600 dark:text-stone-300 px-2 py-1 rounded", fn) for fn in functions]...
            )
        )
    )
end

ApiIndex
