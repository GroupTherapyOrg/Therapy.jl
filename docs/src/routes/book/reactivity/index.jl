# Reactivity - Part 2 of the Therapy.jl Book
#
# Core reactive primitives: signals, effects, and memos.

function Index()
    Fragment(
        # Header
        Div(:class => "py-8 border-b border-neutral-300 dark:border-neutral-800",
            Span(:class => "text-sm text-emerald-700 dark:text-emerald-400 font-medium", "Part 2"),
            H1(:class => "text-4xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mt-2 mb-4",
                "Reactivity"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 max-w-3xl",
                "Master signals, effects, and memos\u2014the building blocks of Therapy.jl's fine-grained reactivity system."
            )
        ),

        # Coming Soon Notice
        Section(:class => "py-12",
            Div(:class => "bg-amber-50 dark:bg-amber-950/20 rounded-lg border border-amber-200 dark:border-amber-900 p-8 text-center",
                H2(:class => "text-2xl font-serif font-semibold text-amber-900 dark:text-amber-200 mb-4",
                    "Coming Soon"
                ),
                P(:class => "text-amber-800 dark:text-amber-300",
                    "This section is currently being written. Check back soon for deep dives into signals, effects, memos, and batching!"
                )
            )
        ),

        # Topics Preview
        Section(:class => "py-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "What You'll Learn"
            ),
            Ul(:class => "space-y-3 text-neutral-600 dark:text-neutral-400",
                Li(Strong("Signals"), " - Reactive state containers that notify subscribers on change"),
                Li(Strong("Effects"), " - Side effects that automatically re-run when dependencies change"),
                Li(Strong("Memos"), " - Cached computed values that only recalculate when needed"),
                Li(Strong("Batching"), " - Group multiple updates to avoid redundant re-renders"),
                Li(Strong("Dependency Tracking"), " - How Therapy.jl knows what to update")
            )
        ),

        # Quick Preview
        Section(:class => "py-8 bg-neutral-50 dark:bg-neutral-900 rounded-lg border border-neutral-300 dark:border-neutral-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Quick Preview"
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

# Memos: cached computations
doubled = create_memo(() -> count() * 2)
doubled()  # Only recomputes when count changes

# Batching: group updates
batch() do
    set_count(1)
    set_count(2)
    set_count(3)
end  # Effect runs once with final value""")
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
            A(:href => "../components/",
              :class => "inline-flex items-center text-neutral-600 dark:text-neutral-400 hover:text-emerald-700 dark:hover:text-emerald-400 transition-colors",
                "Components",
                Svg(:class => "ml-2 w-5 h-5", :fill => "none", :viewBox => "0 0 24 24", :stroke => "currentColor",
                    Path(:stroke_linecap => "round", :stroke_linejoin => "round", :stroke_width => "2", :d => "M13 7l5 5m0 0l-5 5m5-5H6")
                )
            )
        )
    )
end

Index
