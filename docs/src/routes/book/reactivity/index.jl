# Reactivity - Part 2 of the Therapy.jl Book
#
# Core reactive primitives: signals, effects, and memos.

function ReactivityIndex()
    BookLayout("/book/reactivity/",
        # Header
        Div(:class => "py-8 border-b border-warm-200 dark:border-warm-900",
            Span(:class => "text-sm text-accent-700 dark:text-accent-400 font-medium", "Part 2"),
            H1(:class => "text-4xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-2 mb-4",
                "Reactivity"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 max-w-3xl",
                "Master signals, effects, and memos—the building blocks of Therapy.jl's fine-grained reactivity system."
            )
        ),

        # Introduction
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "The Reactive Graph"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 mb-6",
                "Therapy.jl uses a reactive graph to track dependencies between values. ",
                "When a signal changes, only the parts of your application that depend on it update. ",
                "This fine-grained approach is more efficient than re-rendering entire component trees."
            ),
            Div(:class => "bg-warm-50 dark:bg-warm-900 rounded-lg p-8 font-mono text-sm text-warm-800 dark:text-warm-200 text-center",
                Pre(:class => "inline-block text-left", """     Signals (source of truth)
          ↓ read by
      Memos (cached derived values)
          ↓ read by
     Effects (side effects → DOM)""")
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "This section covers each reactive primitive in depth."
            )
        ),

        # Chapter Links
        Section(:class => "py-12 bg-warm-100 dark:bg-warm-800 rounded-lg border border-warm-200 dark:border-warm-900 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-8",
                "In This Section"
            ),
            Div(:class => "grid md:grid-cols-3 gap-6",
                ChapterCard("Signals", "./signals",
                    "Reactive state containers that notify subscribers when they change. The foundation of all reactivity.",
                    "M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"
                ),
                ChapterCard("Effects", "./effects",
                    "Side effects that automatically re-run when dependencies change. Connect reactive state to the outside world.",
                    "M13 10V3L4 14h7v7l9-11h-7z"
                ),
                ChapterCard("Memos", "./memos",
                    "Cached computations that only recalculate when needed. Efficient derived state without redundant work.",
                    "M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z"
                )
            )
        ),

        # Quick Overview Code
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Quick Overview"
            ),
            Div(:class => "bg-warm-800 dark:bg-warm-950 rounded border border-warm-900 p-6 overflow-x-auto",
                Pre(:class => "text-sm text-warm-50",
                    Code(:class => "language-julia", """# Signals: reactive state
count, set_count = create_signal(0)
count()        # Read: 0
set_count(5)   # Write: updates all subscribers

# Effects: automatic side effects
create_effect() do
    println("Count changed to: ", count())
end
# Prints immediately, then on every change

# Memos: cached computations
doubled = create_memo(() -> count() * 2)
doubled()  # 10 (computed once, then cached)
doubled()  # 10 (no recomputation)

# Batching: group updates
batch() do
    set_count(1)
    set_count(2)
    set_count(3)
end  # Effect runs once with final value""")
                )
            )
        ),

        # Core Concepts
        Section(:class => "py-12 bg-warm-100 dark:bg-warm-800 rounded-lg border border-warm-200 dark:border-warm-900 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Core Concepts"
            ),
            Dl(:class => "space-y-6",
                ConceptItem("Automatic Dependency Tracking",
                    "You don't need to manually specify what depends on what. Therapy.jl tracks dependencies " *
                    "automatically when you read signals inside effects or memos."
                ),
                ConceptItem("Fine-Grained Updates",
                    "When a signal changes, only the specific effects and memos that read it are updated. " *
                    "Other parts of your application remain untouched."
                ),
                ConceptItem("Lazy Evaluation",
                    "Memos don't recompute until they're actually read. This avoids unnecessary work when " *
                    "derived values aren't needed immediately."
                ),
                ConceptItem("Batching",
                    "Multiple signal updates within a batch() block trigger effects only once, with the final values. " *
                    "This prevents intermediate state flicker."
                )
            )
        ),

        # Why Fine-Grained
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Why Fine-Grained Reactivity?"
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-200 mb-4",
                        "VDOM Diffing (React-style)"
                    ),
                    Ul(:class => "space-y-2 text-warm-600 dark:text-warm-400",
                        Li("Re-renders entire component subtrees"),
                        Li("Computes full VDOM on every update"),
                        Li("Diffs old vs new to find changes"),
                        Li("Requires manual memoization to optimize")
                    )
                ),
                Div(:class => "bg-warm-50 dark:bg-warm-900/30 rounded-lg p-6 border border-warm-200 dark:border-warm-800",
                    H3(:class => "text-lg font-serif font-semibold text-accent-800 dark:text-accent-300 mb-4",
                        "Fine-Grained (Therapy.jl)"
                    ),
                    Ul(:class => "space-y-2 text-accent-700 dark:text-accent-400",
                        Li("Updates only specific DOM nodes"),
                        Li("No intermediate representation"),
                        Li("Direct updates—no diffing needed"),
                        Li("Efficient by default, no manual work")
                    )
                )
            )
        ),

        # Interactive Demo
        Section(:class => "py-12 bg-gradient-to-br from-warm-50 to-warm-100 dark:from-warm-900 dark:to-warm-950 rounded-lg border border-warm-200 dark:border-warm-900",
            Div(:class => "text-center px-8",
                H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-4",
                    "Try It Live"
                ),
                P(:class => "text-warm-600 dark:text-warm-200 mb-8 max-w-xl mx-auto",
                    "See fine-grained reactivity in action. This counter updates only the number display—not the entire component—when you click."
                ),
                Div(:class => "bg-warm-50/70 dark:bg-warm-800/70 backdrop-blur rounded border border-warm-200 dark:border-warm-800 p-8 max-w-md mx-auto",
                    InteractiveCounter()
                ),
                P(:class => "text-sm text-warm-600 dark:text-warm-600 mt-4",
                    "Running as WebAssembly compiled from Julia."
                )
            )
        ),

    )
end

function ChapterCard(title, href, description, icon_path)
    A(:href => href, :class => "block p-6 bg-warm-50 dark:bg-warm-900 rounded-lg border border-warm-200 dark:border-warm-800 hover:border-accent-500 dark:hover:border-accent-600 transition-colors group",
        Div(:class => "flex items-start gap-4",
            Div(:class => "flex-shrink-0 w-12 h-12 bg-warm-100 dark:bg-warm-800 rounded-lg flex items-center justify-center group-hover:bg-warm-200 dark:group-hover:bg-warm-700 transition-colors",
                Svg(:class => "w-6 h-6 text-accent-700 dark:text-accent-400", :fill => "none", :viewBox => "0 0 24 24", :stroke_width => "1.5", :stroke => "currentColor",
                    Path(:stroke_linecap => "round", :stroke_linejoin => "round", :d => icon_path)
                )
            ),
            Div(
                H3(:class => "text-lg font-serif font-semibold text-warm-800 dark:text-warm-50 mb-2 group-hover:text-accent-700 dark:group-hover:text-accent-400 transition-colors", title),
                P(:class => "text-warm-600 dark:text-warm-400 text-sm", description)
            )
        )
    )
end

function ConceptItem(term, definition)
    Div(
        Dt(:class => "font-serif font-semibold text-warm-800 dark:text-warm-50", term),
        Dd(:class => "mt-1 text-warm-600 dark:text-warm-400", definition)
    )
end

# Export the page component
ReactivityIndex
