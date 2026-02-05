# Learn Overview - Quick Start and Tutorial Index
#
# Parchment theme with sage and amber accents

function LearnIndex()
    TutorialLayout(
        Div(:class => "space-y-14",
            # Header
            Div(:class => "mb-10",
                H1(:class => "text-4xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-4",
                    "Quick Start"
                ),
                P(:class => "text-xl text-warm-600 dark:text-warm-400 leading-relaxed",
                    "Learn the basics of Therapy.jl through hands-on tutorials."
                )
            ),

            # Interactive Preview
            Section(:class => "bg-gradient-to-br from-warm-50 to-warm-100 dark:from-warm-900 dark:to-warm-950 rounded-lg border border-warm-200 dark:border-warm-900 p-8",
                Div(:class => "text-center mb-6",
                    H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-2",
                        "Build This: Tic-Tac-Toe"
                    ),
                    P(:class => "text-warm-600 dark:text-warm-200 leading-relaxed",
                        "This game is built with Therapy.jl and runs as WebAssembly in your browser."
                    )
                ),
                # Island renders directly - no placeholder needed!
                Div(:class => "flex justify-center",
                    TicTacToe()
                )
            ),

            # Tutorial Cards
            Section(
                H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                    "Start Learning"
                ),
                Div(:class => "grid gap-6",
                    TutorialCard(
                        "Tutorial: Tic-Tac-Toe",
                        "Build a complete game step-by-step. Learn signals, event handlers, and component composition.",
                        "learn/tutorial-tic-tac-toe/",
                        "~30 min",
                        true
                    ),
                    TutorialCard(
                        "Thinking in Therapy.jl",
                        "Learn the mental model behind fine-grained reactivity and how it differs from other frameworks.",
                        "learn/thinking-in-therapy/",
                        "~15 min",
                        true
                    )
                )
            ),

            # Core Concepts
            Section(
                H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                    "Core Concepts"
                ),
                Div(:class => "grid md:grid-cols-3 gap-4",
                    ConceptCard("Describing the UI", "Learn how to create and compose VNodes", "learn/describing-ui/"),
                    ConceptCard("Adding Interactivity", "Make your UI respond to user input with signals", "learn/adding-interactivity/"),
                    ConceptCard("Managing State", "Organize state and data flow in your app", "learn/managing-state/")
                )
            )
        );
        current_path="learn/"
    )
end

function TutorialCard(title, description, href, duration, available)
    A(:href => href, :class => "block",
        Div(:class => "bg-warm-100 dark:bg-warm-800 rounded-lg p-6 border border-warm-200 dark:border-warm-900 hover:border-accent-400 dark:hover:border-accent-700 transition-colors",
            Div(:class => "flex justify-between items-start mb-3",
                H3(:class => "text-lg font-serif font-semibold text-warm-800 dark:text-warm-50",
                    title
                ),
                Div(:class => "flex items-center gap-2",
                    available ?
                        Span(:class => "text-xs bg-accent-100 dark:bg-accent-900/30 text-accent-700 dark:text-accent-400 px-2 py-1 rounded", "Ready") :
                        Span(:class => "text-xs bg-warm-200 dark:bg-warm-900 text-warm-600 dark:text-warm-400 px-2 py-1 rounded", "Soon"),
                    Span(:class => "text-xs text-warm-600 dark:text-warm-600", duration)
                )
            ),
            P(:class => "text-warm-600 dark:text-warm-400 leading-relaxed",
                description
            ),
            Div(:class => "mt-4 text-accent-700 dark:text-accent-400 font-medium text-sm",
                available ? "Start tutorial →" : "Coming soon"
            )
        )
    )
end

function ConceptCard(title, description, href)
    A(:href => href, :class => "block",
        Div(:class => "bg-warm-100 dark:bg-warm-800/50 rounded-lg p-4 border border-warm-200 dark:border-warm-900 hover:bg-warm-50 dark:hover:bg-warm-900 transition-colors",
            H4(:class => "font-serif font-medium text-warm-800 dark:text-warm-50 mb-1", title),
            P(:class => "text-sm text-warm-600 dark:text-warm-400", description)
        )
    )
end

LearnIndex
