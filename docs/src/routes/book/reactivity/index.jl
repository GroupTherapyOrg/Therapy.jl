# Reactivity - Part 2 of the Therapy.jl Book
#
# Core reactive primitives: signals, effects, and memos.

function Index()
    BookLayout(
        # Header
        Div(:class => "py-8 border-b border-neutral-300 dark:border-neutral-800",
            Span(:class => "text-sm text-emerald-700 dark:text-emerald-400 font-medium", "Part 2"),
            H1(:class => "text-4xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mt-2 mb-4",
                "Reactivity"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 max-w-3xl",
                "Master signals, effects, and memos—the building blocks of Therapy.jl's fine-grained reactivity system."
            )
        ),

        # Introduction
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "The Reactive Graph"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "Therapy.jl uses a reactive graph to track dependencies between values. ",
                "When a signal changes, only the parts of your application that depend on it update. ",
                "This fine-grained approach is more efficient than re-rendering entire component trees."
            ),
            Div(:class => "bg-neutral-100 dark:bg-neutral-800 rounded-lg p-8 font-mono text-sm text-neutral-700 dark:text-neutral-300 text-center",
                Pre(:class => "inline-block text-left", """     Signals (source of truth)
          ↓ read by
      Memos (cached derived values)
          ↓ read by
     Effects (side effects → DOM)""")
            ),
            P(:class => "text-neutral-600 dark:text-neutral-400 mt-6",
                "This section covers each reactive primitive in depth."
            )
        ),

        # Chapter Links
        Section(:class => "py-12 bg-neutral-50 dark:bg-neutral-900 rounded-lg border border-neutral-300 dark:border-neutral-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-8",
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
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Quick Overview"
            ),
            Div(:class => "bg-neutral-900 dark:bg-neutral-950 rounded border border-neutral-800 p-6 overflow-x-auto",
                Pre(:class => "text-sm text-neutral-100",
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
        Section(:class => "py-12 bg-neutral-50 dark:bg-neutral-900 rounded-lg border border-neutral-300 dark:border-neutral-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
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
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Why Fine-Grained Reactivity?"
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-neutral-800 dark:text-neutral-200 mb-4",
                        "VDOM Diffing (React-style)"
                    ),
                    Ul(:class => "space-y-2 text-neutral-600 dark:text-neutral-400",
                        Li("Re-renders entire component subtrees"),
                        Li("Computes full VDOM on every update"),
                        Li("Diffs old vs new to find changes"),
                        Li("Requires manual memoization to optimize")
                    )
                ),
                Div(:class => "bg-emerald-50 dark:bg-emerald-950/30 rounded-lg p-6 border border-emerald-200 dark:border-emerald-900",
                    H3(:class => "text-lg font-serif font-semibold text-emerald-800 dark:text-emerald-300 mb-4",
                        "Fine-Grained (Therapy.jl)"
                    ),
                    Ul(:class => "space-y-2 text-emerald-700 dark:text-emerald-400",
                        Li("Updates only specific DOM nodes"),
                        Li("No intermediate representation"),
                        Li("Direct updates—no diffing needed"),
                        Li("Efficient by default, no manual work")
                    )
                )
            )
        ),

        # Interactive Demo
        Section(:class => "py-12 bg-gradient-to-br from-emerald-50 to-amber-50 dark:from-emerald-950/20 dark:to-amber-950/20 rounded-lg border border-neutral-300 dark:border-neutral-800",
            Div(:class => "text-center px-8",
                H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-4",
                    "Try It Live"
                ),
                P(:class => "text-neutral-600 dark:text-neutral-300 mb-8 max-w-xl mx-auto",
                    "See fine-grained reactivity in action. This counter updates only the number display—not the entire component—when you click."
                ),
                Div(:class => "bg-white/70 dark:bg-neutral-900/70 backdrop-blur rounded border border-neutral-300 dark:border-neutral-700 p-8 max-w-md mx-auto",
                    InteractiveCounter()
                ),
                P(:class => "text-sm text-neutral-500 dark:text-neutral-500 mt-4",
                    "Running as WebAssembly compiled from Julia."
                )
            )
        ),

        # Navigation
        Div(:class => "py-8 flex justify-between border-t border-neutral-300 dark:border-neutral-800",
            A(:href => "../getting-started/",
              :class => "inline-flex items-center text-neutral-600 dark:text-neutral-400 hover:text-emerald-700 dark:hover:text-emerald-400 transition-colors",
                Svg(:class => "mr-2 w-5 h-5", :fill => "none", :viewBox => "0 0 24 24", :stroke => "currentColor",
                    Path(:stroke_linecap => "round", :stroke_linejoin => "round", :stroke_width => "2", :d => "M11 17l-5-5m0 0l5-5m-5 5h12")
                ),
                "Getting Started"
            ),
            A(:href => "./signals",
              :class => "inline-flex items-center px-4 py-2 bg-emerald-700 hover:bg-emerald-800 dark:bg-emerald-600 dark:hover:bg-emerald-500 text-white rounded font-medium transition-colors",
                "Start with Signals",
                Svg(:class => "ml-2 w-5 h-5", :fill => "none", :viewBox => "0 0 24 24", :stroke => "currentColor",
                    Path(:stroke_linecap => "round", :stroke_linejoin => "round", :stroke_width => "2", :d => "M13 7l5 5m0 0l-5 5m5-5H6")
                )
            )
        )
    )
end

function ChapterCard(title, href, description, icon_path)
    A(:href => href, :class => "block p-6 bg-white dark:bg-neutral-800 rounded-lg border border-neutral-200 dark:border-neutral-700 hover:border-emerald-500 dark:hover:border-emerald-600 transition-colors group",
        Div(:class => "flex items-start gap-4",
            Div(:class => "flex-shrink-0 w-12 h-12 bg-emerald-100 dark:bg-emerald-900/50 rounded-lg flex items-center justify-center group-hover:bg-emerald-200 dark:group-hover:bg-emerald-900 transition-colors",
                Svg(:class => "w-6 h-6 text-emerald-700 dark:text-emerald-400", :fill => "none", :viewBox => "0 0 24 24", :stroke_width => "1.5", :stroke => "currentColor",
                    Path(:stroke_linecap => "round", :stroke_linejoin => "round", :d => icon_path)
                )
            ),
            Div(
                H3(:class => "text-lg font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-2 group-hover:text-emerald-700 dark:group-hover:text-emerald-400 transition-colors", title),
                P(:class => "text-neutral-600 dark:text-neutral-400 text-sm", description)
            )
        )
    )
end

function ConceptItem(term, definition)
    Div(
        Dt(:class => "font-serif font-semibold text-neutral-900 dark:text-neutral-100", term),
        Dd(:class => "mt-1 text-neutral-600 dark:text-neutral-400", definition)
    )
end

# Export the page component
Index
