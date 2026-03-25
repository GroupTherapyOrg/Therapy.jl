# Learn Overview - Quick Start and Tutorial Index
#
# Uses Suite.jl components for visual presentation.

import Suite

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
            Suite.Card(class="bg-gradient-to-br from-warm-50 to-warm-100 dark:from-warm-900 dark:to-warm-950",
                Suite.CardHeader(class="text-center",
                    Suite.CardTitle(class="text-2xl font-serif",
                        "Build This: Tic-Tac-Toe"
                    ),
                    Suite.CardDescription(class="leading-relaxed",
                        "This game is built with Therapy.jl and runs as JavaScript in your browser."
                    ),
                ),
                Suite.CardContent(class="flex justify-center",
                    # Island renders directly - no placeholder needed!
                    TicTacToe()
                )
            ),

            # Tutorial Cards
            Section(
                H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                    "Start Learning"
                ),
                Div(:class => "grid gap-6",
                    _TutorialCard(
                        "Tutorial: Tic-Tac-Toe",
                        "Build a complete game step-by-step. Learn signals, event handlers, and component composition.",
                        "learn/tutorial-tic-tac-toe/",
                        "~30 min",
                        true
                    ),
                    _TutorialCard(
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
                    _ConceptCard("Describing the UI", "Learn how to create and compose VNodes", "learn/describing-ui/"),
                    _ConceptCard("Adding Interactivity", "Make your UI respond to user input with signals", "learn/adding-interactivity/"),
                    _ConceptCard("Managing State", "Organize state and data flow in your app", "learn/managing-state/")
                )
            )
        );
        current_path="learn/"
    )
end

function _TutorialCard(title, description, href, duration, available)
    A(:href => href, :class => "block",
        Suite.Card(class="hover:border-accent-400 dark:hover:border-accent-700 transition-colors",
            Suite.CardHeader(
                Div(:class => "flex justify-between items-start",
                    Suite.CardTitle(class="font-serif", title),
                    Div(:class => "flex items-center gap-2",
                        available ?
                            Suite.Badge("Ready") :
                            Suite.Badge("Soon", variant="secondary"),
                        Span(:class => "text-xs text-warm-600 dark:text-warm-600", duration)
                    )
                ),
            ),
            Suite.CardContent(
                P(:class => "text-warm-600 dark:text-warm-400 leading-relaxed",
                    description
                ),
                Div(:class => "mt-4 text-accent-700 dark:text-accent-400 font-medium text-sm",
                    available ? "Start tutorial →" : "Coming soon"
                )
            )
        )
    )
end

function _ConceptCard(title, description, href)
    A(:href => href, :class => "block",
        Suite.Card(class="hover:bg-warm-50 dark:hover:bg-warm-900 transition-colors",
            Suite.CardHeader(
                Suite.CardTitle(class="text-base font-serif", title),
            ),
            Suite.CardContent(
                P(:class => "text-sm text-warm-600 dark:text-warm-400", description)
            )
        )
    )
end

LearnIndex
