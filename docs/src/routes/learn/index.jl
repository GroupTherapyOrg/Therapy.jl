# Learn Overview - Quick Start and Tutorial Index
#
# Shows the interactive TicTacToe game at the top as a preview

function LearnIndex()
    TutorialLayout(
        Div(:class => "space-y-12",
            # Header
            Div(:class => "mb-8",
                H1(:class => "text-4xl font-bold text-stone-800 dark:text-stone-100 mb-4",
                    "Quick Start"
                ),
                P(:class => "text-xl text-stone-500 dark:text-stone-400",
                    "Learn the basics of Therapy.jl through hands-on tutorials."
                )
            ),

            # Interactive Preview
            Section(:class => "bg-gradient-to-r from-orange-100 to-orange-200 dark:from-yellow-950/30 dark:to-yellow-900/30 rounded-xl p-8",
                Div(:class => "text-center mb-6",
                    H2(:class => "text-2xl font-bold text-stone-800 dark:text-stone-100 mb-2",
                        "Build This: Tic-Tac-Toe"
                    ),
                    P(:class => "text-stone-600 dark:text-stone-300",
                        "This game is built with Therapy.jl and runs as WebAssembly in your browser."
                    )
                ),
                # TicTacToe component placeholder - will be injected
                Div(:class => "flex justify-center",
                    Div(:id => "tictactoe")
                )
            ),

            # Tutorial Cards
            Section(
                H2(:class => "text-2xl font-bold text-stone-800 dark:text-stone-100 mb-6",
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
                H2(:class => "text-2xl font-bold text-stone-800 dark:text-stone-100 mb-6",
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
        Div(:class => "bg-white dark:bg-stone-800 rounded-xl p-6 border border-stone-200 dark:border-stone-700 hover:border-orange-200 dark:hover:border-yellow-900 transition-colors",
            Div(:class => "flex justify-between items-start mb-3",
                H3(:class => "text-lg font-semibold text-stone-800 dark:text-stone-100",
                    title
                ),
                Div(:class => "flex items-center gap-2",
                    available ?
                        Span(:class => "text-xs bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400 px-2 py-1 rounded", "Ready") :
                        Span(:class => "text-xs bg-stone-100 dark:bg-stone-700 text-stone-500 dark:text-stone-400 px-2 py-1 rounded", "Soon"),
                    Span(:class => "text-xs text-stone-400 dark:text-stone-500", duration)
                )
            ),
            P(:class => "text-stone-500 dark:text-stone-400",
                description
            ),
            Div(:class => "mt-4 text-orange-400 dark:text-yellow-500 font-medium text-sm",
                available ? "Start tutorial →" : "Coming soon"
            )
        )
    )
end

function ConceptCard(title, description, href)
    A(:href => href, :class => "block",
        Div(:class => "bg-stone-50 dark:bg-stone-800/50 rounded-lg p-4 hover:bg-stone-100 dark:hover:bg-stone-800 transition-colors",
            H4(:class => "font-medium text-stone-800 dark:text-stone-100 mb-1", title),
            P(:class => "text-sm text-stone-500 dark:text-stone-400", description)
        )
    )
end

LearnIndex
