# API Documentation Index
#
# Placeholder for API reference documentation

function ApiIndex()
    # Content only - Layout applied at app level for true SPA navigation
    Div(:class => "max-w-4xl mx-auto",
            # Page Header
            Div(:class => "mb-12",
                H1(:class => "text-4xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-4",
                    "API Reference"
                ),
                P(:class => "text-xl text-warm-600 dark:text-warm-400",
                    "Complete reference documentation for Therapy.jl's API."
                )
            ),

            # Coming Soon Notice
            Div(:class => "bg-accent-100/50 dark:bg-accent-950/30 rounded-lg p-8 mb-8",
                Div(:class => "flex items-center gap-4 mb-4",
                    Div(:class => "w-12 h-12 bg-accent-200 dark:bg-accent-950/50 rounded flex items-center justify-center",
                        Svg(:class => "w-6 h-6 text-accent-500 dark:text-accent-600", :fill => "none", :viewBox => "0 0 24 24", :stroke => "currentColor", :stroke_width => "2",
                            Path(:stroke_linecap => "round", :stroke_linejoin => "round", :d => "M12 6v6m0 0v6m0-6h6m-6 0H6")
                        )
                    ),
                    H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50",
                        "Documentation Coming Soon"
                    )
                ),
                P(:class => "text-warm-800 dark:text-warm-200 mb-4",
                    "We're working on comprehensive API documentation. In the meantime, explore these sections:"
                )
            ),

            # API Sections Preview
            Div(:class => "grid md:grid-cols-2 gap-6",
                ApiSection(
                    "Signals",
                    "Reactive primitives for state management",
                    "api/signals/",
                    ["create_signal", "batch", "untrack"]
                ),
                ApiSection(
                    "Effects",
                    "Side effects and subscriptions",
                    "api/effects/",
                    ["create_effect", "dispose!", "on_cleanup"]
                ),
                ApiSection(
                    "Memos",
                    "Cached computed values",
                    "api/memos/",
                    ["create_memo"]
                ),
                ApiSection(
                    "Components & Props",
                    "Reusable components with props",
                    "api/components/",
                    ["component", "get_prop", "get_children", "Props"]
                ),
                ApiSection(
                    "Islands",
                    "Interactive components (compile to Wasm)",
                    "api/islands/",
                    ["island", "IslandDef", "get_islands"]
                ),
                ApiSection(
                    "DOM Elements",
                    "HTML element constructors",
                    "api/elements/",
                    ["Div", "Span", "Button", "Input", "..."]
                ),
                ApiSection(
                    "App Framework",
                    "Application setup and build tools",
                    "api/app/",
                    ["App", "Therapy.run", "dev", "build"]
                )
            ),

            # Quick Reference
            Section(:class => "mt-12",
                H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                    "Quick Reference"
                ),
                Div(:class => "bg-warm-900 dark:bg-warm-950 rounded-lg overflow-x-auto shadow-lg",
                    Pre(:class => "p-4 text-sm text-warm-50",
                        Code(:class => "language-julia", """using Therapy

# Signals - reactive state
count, set_count = create_signal(0)
count()           # Read: 0
set_count(5)      # Write

# Effects - side effects
create_effect(() -> println("Count: ", count()))

# Memos - cached computations
doubled = create_memo(() -> count() * 2)

# Components with props - parent passes data to child
Square = component(:Square) do props
    value = get_prop(props, :value)           # Get prop
    on_click = get_prop(props, :on_click)     # Functions too!
    Button(:on_click => on_click, value)
end

# Islands - interactive components (compile to Wasm)
Counter = island(:Counter) do
    count, set_count = create_signal(0)
    Div(
        Button(:on_click => () -> set_count(count() - 1), "-"),
        Span(count),
        Button(:on_click => () -> set_count(count() + 1), "+")
    )
end

# App setup - islands auto-discovered
app = App(routes_dir = "routes", components_dir = "components")
Therapy.run(app)""")
                    )
                )
            )
        )
end

function ApiSection(title, description, href, functions)
    A(:href => href, :class => "block",
        Div(:class => "bg-warm-100 dark:bg-warm-800 rounded-lg p-6 border border-warm-200 dark:border-warm-900 hover:border-accent-200 dark:hover:border-accent-900 transition-colors",
            H3(:class => "text-lg font-serif font-semibold text-warm-800 dark:text-warm-50 mb-2",
                title
            ),
            P(:class => "text-warm-600 dark:text-warm-400 text-sm mb-4",
                description
            ),
            Div(:class => "flex flex-wrap gap-2",
                [Span(:class => "text-xs bg-warm-200 dark:bg-warm-900 text-warm-800 dark:text-warm-200 px-2 py-1 rounded", fn) for fn in functions]...
            )
        )
    )
end

ApiIndex
