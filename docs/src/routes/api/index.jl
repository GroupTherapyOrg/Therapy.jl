# API Documentation Index
#
# API reference documentation with Suite.jl components

import Suite

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
            Suite.Alert(
                Suite.AlertTitle("Documentation Coming Soon"),
                Suite.AlertDescription("We're working on comprehensive API documentation. In the meantime, explore these sections:")
            ),

            Div(:class => "mb-8"),

            # API Sections Preview
            Div(:class => "grid md:grid-cols-2 gap-6",
                _ApiSection(
                    "Signals",
                    "Reactive primitives for state management",
                    "api/signals/",
                    ["create_signal", "batch", "untrack"]
                ),
                _ApiSection(
                    "Effects",
                    "Side effects and subscriptions",
                    "api/effects/",
                    ["create_effect", "dispose!", "on_cleanup"]
                ),
                _ApiSection(
                    "Memos",
                    "Cached computed values",
                    "api/memos/",
                    ["create_memo"]
                ),
                _ApiSection(
                    "Islands",
                    "Interactive components (compile to JS)",
                    "api/islands/",
                    ["@island", "IslandDef", "get_islands"]
                ),
                _ApiSection(
                    "DOM Elements",
                    "HTML element constructors",
                    "api/elements/",
                    ["Div", "Span", "Button", "Input", "..."]
                ),
                _ApiSection(
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
                Suite.CodeBlock("""using Therapy

# Signals - reactive state
count, set_count = create_signal(0)
count()           # Read: 0
set_count(5)      # Write

# Effects - side effects
create_effect(() -> println("Count: ", count()))

# Memos - cached computations
doubled = create_memo(() -> count() * 2)

# Plain functions with kwargs for reusable child components
function Square(; value, on_click)
    Button(:on_click => on_click, value)
end

# Islands - interactive components (compile to JS)
@island function Counter()
    count, set_count = create_signal(0)
    Div(
        Button(:on_click => () -> set_count(count() - 1), "-"),
        Span(count),
        Button(:on_click => () -> set_count(count() + 1), "+")
    )
end

# App setup - islands auto-discovered
app = App(routes_dir = "routes", components_dir = "components")
Therapy.run(app)""", language="julia")
            )
        )
end

function _ApiSection(title, description, href, functions)
    A(:href => href, :class => "block",
        Suite.Card(class="hover:border-accent-200 dark:hover:border-accent-900 transition-colors",
            Suite.CardHeader(
                Suite.CardTitle(title),
                Suite.CardDescription(description)
            ),
            Suite.CardContent(
                Div(:class => "flex flex-wrap gap-2",
                    [Suite.Badge(fn, variant="secondary") for fn in functions]...
                )
            )
        )
    )
end

ApiIndex
