# Learn Overview - Quick Start and Tutorial Index
#
# Parchment theme with sage and amber accents

function LearnIndex()
    TutorialLayout(
        Div(:class => "space-y-14",
            # Header
            Div(:class => "mb-10",
                H1(:class => "text-4xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-4",
                    "Quick Start"
                ),
                P(:class => "text-xl text-neutral-600 dark:text-neutral-400 leading-relaxed",
                    "Learn the basics of Therapy.jl through hands-on tutorials."
                )
            ),

            # Interactive Preview
            Section(:class => "bg-gradient-to-br from-emerald-50 to-amber-50 dark:from-emerald-950/20 dark:to-amber-950/20 rounded-lg border border-neutral-300 dark:border-neutral-800 p-8",
                Div(:class => "text-center mb-6",
                    H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-2",
                        "Build This: Tic-Tac-Toe"
                    ),
                    P(:class => "text-neutral-600 dark:text-neutral-300 leading-relaxed",
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
                H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
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
                H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
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
        Div(:class => "bg-neutral-50 dark:bg-neutral-900 rounded-lg p-6 border border-neutral-300 dark:border-neutral-800 hover:border-emerald-400 dark:hover:border-emerald-700 transition-colors",
            Div(:class => "flex justify-between items-start mb-3",
                H3(:class => "text-lg font-serif font-semibold text-neutral-900 dark:text-neutral-100",
                    title
                ),
                Div(:class => "flex items-center gap-2",
                    available ?
                        Span(:class => "text-xs bg-emerald-100 dark:bg-emerald-900/30 text-emerald-700 dark:text-emerald-400 px-2 py-1 rounded", "Ready") :
                        Span(:class => "text-xs bg-neutral-200 dark:bg-neutral-800 text-neutral-500 dark:text-neutral-400 px-2 py-1 rounded", "Soon"),
                    Span(:class => "text-xs text-neutral-500 dark:text-neutral-500", duration)
                )
            ),
            P(:class => "text-neutral-600 dark:text-neutral-400 leading-relaxed",
                description
            ),
            Div(:class => "mt-4 text-emerald-700 dark:text-emerald-400 font-medium text-sm",
                available ? "Start tutorial →" : "Coming soon"
            )
        )
    )
end

function ConceptCard(title, description, href)
    A(:href => href, :class => "block",
        Div(:class => "bg-neutral-50 dark:bg-neutral-900/50 rounded-lg p-4 border border-neutral-200 dark:border-neutral-800 hover:bg-neutral-100 dark:hover:bg-neutral-800 transition-colors",
            H4(:class => "font-serif font-medium text-neutral-900 dark:text-neutral-100 mb-1", title),
            P(:class => "text-sm text-neutral-600 dark:text-neutral-400", description)
        )
    )
end

LearnIndex
