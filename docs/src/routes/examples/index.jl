# Examples Index
#
# Interactive examples showcasing Therapy.jl features

function ExamplesIndex()
    # Content only - Layout applied at app level for true SPA navigation
    Div(:class => "max-w-4xl mx-auto",
            # Page Header
            Div(:class => "mb-12",
                H1(:class => "text-4xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-4",
                    "Examples"
                ),
                P(:class => "text-xl text-neutral-600 dark:text-neutral-400",
                    "Interactive examples demonstrating Therapy.jl's capabilities."
                )
            ),

            # Coming Soon Notice
            Div(:class => "bg-emerald-100/50 dark:bg-emerald-950/30 rounded-lg p-8 mb-8",
                Div(:class => "flex items-center gap-4 mb-4",
                    Div(:class => "w-12 h-12 bg-emerald-200 dark:bg-emerald-950/50 rounded flex items-center justify-center",
                        Svg(:class => "w-6 h-6 text-emerald-500 dark:text-emerald-500", :fill => "none", :viewBox => "0 0 24 24", :stroke => "currentColor", :stroke_width => "2",
                            Path(:stroke_linecap => "round", :stroke_linejoin => "round", :d => "M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z"),
                            Path(:stroke_linecap => "round", :stroke_linejoin => "round", :d => "M21 12a9 9 0 11-18 0 9 9 0 0118 0z")
                        )
                    ),
                    H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100",
                        "Examples Coming Soon"
                    )
                ),
                P(:class => "text-neutral-700 dark:text-neutral-300",
                    "We're building a collection of interactive examples. Check back soon!"
                )
            ),

            # Example Categories
            Div(:class => "grid md:grid-cols-2 gap-6 mb-12",
                ExampleCard(
                    "Counter",
                    "The classic reactive counter demonstrating signals and event handlers.",
                    "/",
                    true
                ),
                ExampleCard(
                    "Todo List",
                    "A full-featured todo application with add, complete, and delete.",
                    "#",
                    false
                ),
                ExampleCard(
                    "Form Validation",
                    "Real-time form validation with reactive error messages.",
                    "#",
                    false
                ),
                ExampleCard(
                    "Theme Switcher",
                    "Dark/light mode toggle with persistence.",
                    "/",
                    true
                ),
                ExampleCard(
                    "Data Fetching",
                    "Async data loading with loading states and error handling.",
                    "#",
                    false
                ),
                ExampleCard(
                    "Tic-Tac-Toe",
                    "Interactive game tutorial (coming soon).",
                    "#",
                    false
                )
            ),

            # View on GitHub
            Section(:class => "text-center",
                P(:class => "text-neutral-600 dark:text-neutral-400 mb-4",
                    "Want to see more? Check out the examples directory in our repository."
                ),
                A(:href => "https://github.com/TherapeuticJulia/Therapy.jl/tree/main/examples",
                  :class => "inline-flex items-center gap-2 bg-neutral-800 dark:bg-neutral-700 text-white px-6 py-3 rounded-lg hover:bg-neutral-700 dark:hover:bg-neutral-600 transition-colors",
                  :target => "_blank",
                    Svg(:class => "w-5 h-5", :fill => "currentColor", :viewBox => "0 0 24 24",
                        Path(:d => "M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z")
                    ),
                    "View on GitHub"
                )
            )
        )
end

function ExampleCard(title, description, href, available)
    Div(:class => "bg-neutral-50 dark:bg-neutral-900 rounded-lg p-6 border border-neutral-300 dark:border-neutral-800" * (available ? " hover:border-emerald-200 dark:hover:border-emerald-900" : " opacity-60"),
        Div(:class => "flex justify-between items-start mb-3",
            H3(:class => "text-lg font-serif font-semibold text-neutral-900 dark:text-neutral-100",
                title
            ),
            available ?
                Span(:class => "text-xs bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400 px-2 py-1 rounded", "Live") :
                Span(:class => "text-xs bg-neutral-200 dark:bg-neutral-800 text-neutral-600 dark:text-neutral-400 px-2 py-1 rounded", "Soon")
        ),
        P(:class => "text-neutral-600 dark:text-neutral-400 text-sm mb-4",
            description
        ),
        available ?
            A(:href => href, :class => "text-emerald-400 dark:text-emerald-500 hover:text-emerald-500 dark:hover:text-emerald-400 text-sm font-medium", "View example →") :
            Span(:class => "text-neutral-400 dark:text-neutral-500 text-sm", "Coming soon")
    )
end

ExamplesIndex
