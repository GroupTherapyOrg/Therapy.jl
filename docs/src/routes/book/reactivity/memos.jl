# Memos - Cached Computed Values
#
# Deep dive into create_memo for derived reactive state.

function Memos()
    BookLayout(
        # Header
        Div(:class => "py-8 border-b border-neutral-300 dark:border-neutral-800",
            Span(:class => "text-sm text-emerald-700 dark:text-emerald-400 font-medium", "Part 2 · Reactivity"),
            H1(:class => "text-4xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mt-2 mb-4",
                "Memos"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 max-w-3xl",
                "Memos are cached computations that automatically update when their dependencies change. ",
                "Use them for derived values that are expensive to compute or read multiple times."
            )
        ),

        # What is a Memo?
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "What is a Memo?"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "A memo is a reactive computation that caches its result. Unlike effects, memos return values. ",
                "The value is computed once, then cached until one of its dependencies changes."
            ),
            CodeBlock("""count, set_count = create_signal(0)

# Memo computes a derived value
doubled = create_memo(() -> count() * 2)

doubled()     # => 0 (computed once)
doubled()     # => 0 (cached - no recomputation)
doubled()     # => 0 (still cached)

set_count(5)  # Dependency changed - memo marked dirty
doubled()     # => 10 (recomputed)
doubled()     # => 10 (cached again)"""),
            P(:class => "text-neutral-600 dark:text-neutral-400 mt-6",
                Code(:class => "text-emerald-700 dark:text-emerald-400", "create_memo"),
                " returns a getter function. Call it to get the cached value. ",
                "The memo automatically tracks dependencies just like effects do."
            )
        ),

        # Why Memos?
        Section(:class => "py-12 bg-neutral-50 dark:bg-neutral-900 rounded-lg border border-neutral-300 dark:border-neutral-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Why Use Memos?"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "Memos solve two problems: ", Strong("expensive computations"), " and ", Strong("consistent derived values"), "."
            ),

            H3(:class => "text-xl font-serif font-semibold text-neutral-800 dark:text-neutral-200 mb-4 mt-8",
                "Problem 1: Expensive Computation"
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(
                    H4(:class => "text-base font-semibold text-red-700 dark:text-red-400 mb-3", "Without Memo"),
                    CodeBlock("""# Recomputes every time!
function filtered_items()
    filter(expensive_check, items())
end

# Each call re-runs the filter
filtered_items()  # Computes
filtered_items()  # Computes again
filtered_items()  # Computes again""", "neutral")
                ),
                Div(
                    H4(:class => "text-base font-semibold text-emerald-700 dark:text-emerald-400 mb-3", "With Memo"),
                    CodeBlock("""# Computes once, caches result
filtered = create_memo() do
    filter(expensive_check, items())
end

filtered()  # Computes once
filtered()  # Cached
filtered()  # Cached""", "emerald")
                )
            ),

            H3(:class => "text-xl font-serif font-semibold text-neutral-800 dark:text-neutral-200 mb-4 mt-12",
                "Problem 2: Consistent Values"
            ),
            P(:class => "text-neutral-600 dark:text-neutral-400 mb-4",
                "Memos ensure multiple readers always see the same value, even if dependencies changed between reads."
            ),
            CodeBlock("""total = create_memo(() -> sum(items()))

# Both reads get the same cached value
header_text = "Total: \$(total())"
footer_text = "Sum: \$(total())"
# Guaranteed consistent!""")
        ),

        # How Memos Work
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "How Memos Work"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "Memos use lazy evaluation with a ", Strong("dirty flag"), " pattern:"
            ),
            Ol(:class => "space-y-4 text-neutral-600 dark:text-neutral-400 list-decimal list-inside",
                Li(Strong("Initial run:"), " Memo computes its value and tracks dependencies"),
                Li(Strong("Cached reads:"), " Subsequent calls return the cached value immediately"),
                Li(Strong("Dependency change:"), " When a dependency signals change, memo is marked dirty"),
                Li(Strong("Lazy recompute:"), " Next read triggers recomputation and new caching")
            ),
            Div(:class => "mt-8 bg-neutral-100 dark:bg-neutral-800 rounded-lg p-6 font-mono text-sm text-neutral-700 dark:text-neutral-300",
                Pre("""memo created → compute → cache value
                         ↓
read memo() → return cached value
                         ↓
dependency changes → mark dirty (don't compute yet!)
                         ↓
read memo() → recompute → cache new value""")
            ),
            InfoBox("Lazy vs Eager",
                "Unlike effects which run immediately when dependencies change, memos wait until " *
                "they're actually read. This is called \"lazy\" or \"pull-based\" reactivity."
            )
        ),

        # Memo Chains
        Section(:class => "py-12 bg-neutral-50 dark:bg-neutral-900 rounded-lg border border-neutral-300 dark:border-neutral-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Memo Chains"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "Memos can depend on other memos, creating a chain of derived values. ",
                "Each memo in the chain is only recomputed when its specific dependencies change."
            ),
            CodeBlock("""items, set_items = create_signal([1, 2, 3, 4, 5])

# Chain of memos
filtered = create_memo(() -> filter(x -> x > 2, items()))  # [3, 4, 5]
sorted = create_memo(() -> sort(filtered()))               # [3, 4, 5]
total = create_memo(() -> sum(sorted()))                   # 12

total()  # 12

# Change the source
set_items([1, 2, 3, 4, 5, 6, 7])

# All memos marked dirty, but not computed yet!
# Only when we read:
total()  # Recomputes chain: filtered → sorted → total → 22"""),
            P(:class => "text-neutral-600 dark:text-neutral-400 mt-6",
                "The dirty flag propagates through the chain, but recomputation only happens when a value is read."
            )
        ),

        # Memos in Components
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Memos in Components"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "Memos are especially useful in components for derived display values."
            ),
            CodeBlock("""function TodoList()
    todos, set_todos = create_signal([
        (text="Learn Julia", done=false),
        (text="Build app", done=false),
        (text="Deploy", done=true)
    ])

    # Derived values with memos
    completed = create_memo() do
        count(t -> t.done, todos())
    end

    remaining = create_memo() do
        length(todos()) - completed()
    end

    Div(
        H2("Todo List"),
        P("Completed: ", completed(), " / ", () -> length(todos())),
        P("Remaining: ", remaining()),
        # ...
    )
end"""),
            P(:class => "text-neutral-600 dark:text-neutral-400 mt-6",
                "The ", Code(:class => "text-emerald-700 dark:text-emerald-400", "completed"),
                " and ", Code(:class => "text-emerald-700 dark:text-emerald-400", "remaining"),
                " values only recompute when ", Code(:class => "text-emerald-700 dark:text-emerald-400", "todos"),
                " changes, and only if they're read."
            )
        ),

        # Signals vs Memos
        Section(:class => "py-12 bg-neutral-50 dark:bg-neutral-900 rounded-lg border border-neutral-300 dark:border-neutral-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Signals vs Memos"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "Both signals and memos provide reactive values, but they serve different purposes:"
            ),
            Div(:class => "overflow-x-auto",
                Table(:class => "w-full text-sm",
                    Thead(
                        Tr(:class => "border-b border-neutral-300 dark:border-neutral-700",
                            Th(:class => "text-left py-3 px-4 font-serif font-semibold text-neutral-900 dark:text-neutral-100", ""),
                            Th(:class => "text-left py-3 px-4 font-serif font-semibold text-neutral-900 dark:text-neutral-100", "Signal"),
                            Th(:class => "text-left py-3 px-4 font-serif font-semibold text-neutral-900 dark:text-neutral-100", "Memo")
                        )
                    ),
                    Tbody(
                        Tr(:class => "border-b border-neutral-200 dark:border-neutral-800",
                            Td(:class => "py-3 px-4 text-neutral-900 dark:text-neutral-100", "Source"),
                            Td(:class => "py-3 px-4 text-neutral-600 dark:text-neutral-400", "External (user input, events)"),
                            Td(:class => "py-3 px-4 text-neutral-600 dark:text-neutral-400", "Derived from other signals")
                        ),
                        Tr(:class => "border-b border-neutral-200 dark:border-neutral-800",
                            Td(:class => "py-3 px-4 text-neutral-900 dark:text-neutral-100", "Writable"),
                            Td(:class => "py-3 px-4 text-neutral-600 dark:text-neutral-400", "Yes (via setter)"),
                            Td(:class => "py-3 px-4 text-neutral-600 dark:text-neutral-400", "No (read-only)")
                        ),
                        Tr(:class => "border-b border-neutral-200 dark:border-neutral-800",
                            Td(:class => "py-3 px-4 text-neutral-900 dark:text-neutral-100", "Caching"),
                            Td(:class => "py-3 px-4 text-neutral-600 dark:text-neutral-400", "Stores value directly"),
                            Td(:class => "py-3 px-4 text-neutral-600 dark:text-neutral-400", "Caches computed result")
                        ),
                        Tr(
                            Td(:class => "py-3 px-4 text-neutral-900 dark:text-neutral-100", "Use for"),
                            Td(:class => "py-3 px-4 text-neutral-600 dark:text-neutral-400", "Primary state"),
                            Td(:class => "py-3 px-4 text-neutral-600 dark:text-neutral-400", "Derived/computed state")
                        )
                    )
                )
            ),
            P(:class => "text-neutral-600 dark:text-neutral-400 mt-6",
                Strong("Rule of thumb:"), " Use signals for state you set directly; use memos for state computed from other state."
            )
        ),

        # Best Practices
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Best Practices"
            ),
            Ul(:class => "space-y-4 text-neutral-600 dark:text-neutral-400",
                Li(
                    Strong("Keep memos pure:"),
                    " Memos should not have side effects. Use effects for side effects."
                ),
                Li(
                    Strong("Use for expensive operations:"),
                    " Filtering, sorting, mapping large arrays, complex calculations."
                ),
                Li(
                    Strong("Use for consistency:"),
                    " When multiple parts of UI need the same derived value."
                ),
                Li(
                    Strong("Don't over-memo:"),
                    " Simple computations like ", Code(:class => "text-emerald-700 dark:text-emerald-400", "count() + 1"),
                    " don't need memoization."
                )
            )
        ),

        # Key Takeaways
        Section(:class => "py-12 bg-emerald-50 dark:bg-emerald-950/30 rounded-lg border border-emerald-200 dark:border-emerald-900 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-emerald-900 dark:text-emerald-200 mb-6",
                "Key Takeaways"
            ),
            Ul(:class => "space-y-3 text-emerald-800 dark:text-emerald-300",
                Li(Strong("Memos cache derived values"), " — compute once, read many times for free"),
                Li(Strong("Lazy evaluation"), " — only recomputes when read after dependencies change"),
                Li(Strong("Automatic tracking"), " — dependencies detected just like effects"),
                Li(Strong("Chain-friendly"), " — memos can depend on other memos"),
                Li(Strong("Read-only"), " — values come from computation, not external setting")
            )
        ),

        # Navigation
        Div(:class => "py-8 flex justify-between border-t border-neutral-300 dark:border-neutral-800",
            A(:href => "./effects",
              :class => "inline-flex items-center text-neutral-600 dark:text-neutral-400 hover:text-emerald-700 dark:hover:text-emerald-400 transition-colors",
                Svg(:class => "mr-2 w-5 h-5", :fill => "none", :viewBox => "0 0 24 24", :stroke => "currentColor",
                    Path(:stroke_linecap => "round", :stroke_linejoin => "round", :stroke_width => "2", :d => "M11 17l-5-5m0 0l5-5m-5 5h12")
                ),
                "Effects"
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

function CodeBlock(code, style="default")
    bg_class = if style == "emerald"
        "bg-emerald-900 dark:bg-emerald-950 border-emerald-700"
    elseif style == "neutral"
        "bg-neutral-700 dark:bg-neutral-800 border-neutral-600"
    else
        "bg-neutral-900 dark:bg-neutral-950 border-neutral-800"
    end

    Div(:class => "$bg_class rounded border p-6 overflow-x-auto",
        Pre(:class => "text-sm text-neutral-100",
            Code(:class => "language-julia", code)
        )
    )
end

function InfoBox(title, content)
    Div(:class => "mt-8 bg-blue-50 dark:bg-blue-950/30 rounded-lg border border-blue-200 dark:border-blue-900 p-6",
        H3(:class => "text-lg font-serif font-semibold text-blue-900 dark:text-blue-200 mb-2", title),
        P(:class => "text-blue-800 dark:text-blue-300", content)
    )
end

# Export the page component
Memos
