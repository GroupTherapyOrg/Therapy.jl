# Examples Index
#
# Interactive examples showcasing Therapy.jl features
# Uses Suite.jl components for visual presentation.

import Suite

function ExamplesIndex()
    # Content only - Layout applied at app level for true SPA navigation
    Div(:class => "max-w-4xl mx-auto",
            # Page Header
            Div(:class => "mb-12",
                H1(:class => "text-4xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-4",
                    "Examples"
                ),
                P(:class => "text-xl text-warm-600 dark:text-warm-400",
                    "Interactive examples demonstrating Therapy.jl's capabilities."
                )
            ),

            # Coming Soon Notice
            Suite.Alert(
                Suite.AlertTitle("Examples Coming Soon"),
                Suite.AlertDescription("We're building a collection of interactive examples. Check back soon!")
            ),

            Div(:class => "mb-8"),

            # Example Categories
            Div(:class => "grid md:grid-cols-2 gap-6 mb-12",
                _ExampleCard(
                    "Counter",
                    "The classic reactive counter demonstrating signals and event handlers.",
                    "/",
                    true
                ),
                _ExampleCard(
                    "WebSocket",
                    "Real-time server signals with live visitor counter.",
                    "examples/websocket/",
                    true
                ),
                _ExampleCard(
                    "Todo List",
                    "A full-featured todo application with add, complete, and delete.",
                    "#",
                    false
                ),
                _ExampleCard(
                    "Form Validation",
                    "Real-time form validation with reactive error messages.",
                    "#",
                    false
                ),
                _ExampleCard(
                    "Theme Switcher",
                    "Dark/light mode toggle with persistence.",
                    "/",
                    true
                ),
                _ExampleCard(
                    "Data Fetching",
                    "Async data loading with loading states and error handling.",
                    "#",
                    false
                ),
                _ExampleCard(
                    "Tic-Tac-Toe",
                    "Interactive game tutorial (coming soon).",
                    "#",
                    false
                )
            ),

            # View on GitHub
            Section(:class => "text-center",
                P(:class => "text-warm-600 dark:text-warm-400 mb-4",
                    "Want to see more? Check out the examples directory in our repository."
                ),
                A(:href => "https://github.com/GroupTherapyOrg/Therapy.jl/tree/main/examples",
                  :target => "_blank",
                    Suite.Button(variant="outline", size="lg",
                        Svg(:class => "w-5 h-5 mr-2", :fill => "currentColor", :viewBox => "0 0 24 24",
                            Path(:d => "M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z")
                        ),
                        "View on GitHub"
                    )
                )
            )
        )
end

function _ExampleCard(title, description, href, available)
    if available
        A(:href => href, :class => "block",
            Suite.Card(class="hover:border-accent-200 dark:hover:border-accent-900 transition-colors",
                Suite.CardHeader(
                    Div(:class => "flex justify-between items-start",
                        Suite.CardTitle(title),
                        Suite.Badge("Live")
                    )
                ),
                Suite.CardContent(
                    P(:class => "text-warm-600 dark:text-warm-400 text-sm", description)
                ),
                Suite.CardFooter(
                    Span(:class => "text-accent-600 dark:text-accent-400 text-sm font-medium", "View example →")
                )
            )
        )
    else
        Div(:class => "opacity-60",
            Suite.Card(
                Suite.CardHeader(
                    Div(:class => "flex justify-between items-start",
                        Suite.CardTitle(title),
                        Suite.Badge("Soon", variant="secondary")
                    )
                ),
                Suite.CardContent(
                    P(:class => "text-warm-600 dark:text-warm-400 text-sm", description)
                ),
                Suite.CardFooter(
                    Span(:class => "text-warm-400 dark:text-warm-600 text-sm", "Coming soon")
                )
            )
        )
    end
end

ExamplesIndex
