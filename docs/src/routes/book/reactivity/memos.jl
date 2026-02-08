# Memos - Cached Computed Values
#
# Deep dive into create_memo for derived reactive state.

import Suite

function Memos()
    BookLayout("/book/reactivity/memos/",
        # Header
        Div(:class => "py-8 border-b border-warm-200 dark:border-warm-700",
            Suite.Badge(variant="outline", "Part 2 · Reactivity"),
            H1(:class => "text-4xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-2 mb-4",
                "Memos"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 max-w-3xl",
                "Memos are cached computations that automatically update when their dependencies change. ",
                "Use them for derived values that are expensive to compute or read multiple times."
            )
        ),

        # What is a Memo?
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "What is a Memo?"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "A memo is a reactive computation that caches its result. Unlike effects, memos return values. ",
                "The value is computed once, then cached until one of its dependencies changes."
            ),
            Suite.CodeBlock(
                """count, set_count = create_signal(0)

# Memo computes a derived value
doubled = create_memo(() -> count() * 2)

doubled()     # => 0 (computed once)
doubled()     # => 0 (cached - no recomputation)
doubled()     # => 0 (still cached)

set_count(5)  # Dependency changed - memo marked dirty
doubled()     # => 10 (recomputed)
doubled()     # => 10 (cached again)""",
                language="julia"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                Code(:class => "text-accent-700 dark:text-accent-400", "create_memo"),
                " returns a getter function. Call it to get the cached value. ",
                "The memo automatically tracks dependencies just like effects do."
            )
        ),

        Suite.Separator(),

        # Why Memos?
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Why Use Memos?"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Memos solve two problems: ", Strong("expensive computations"), " and ", Strong("consistent derived values"), "."
            ),

            H3(:class => "text-xl font-serif font-semibold text-warm-900 dark:text-warm-300 mb-4 mt-8",
                "Problem 1: Expensive Computation"
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(
                    H4(:class => "text-base font-semibold text-warm-700 dark:text-warm-400 mb-3", "Without Memo"),
                    Suite.CodeBlock(
                        """# Recomputes every time!
function filtered_items()
    filter(expensive_check, items())
end

# Each call re-runs the filter
filtered_items()  # Computes
filtered_items()  # Computes again
filtered_items()  # Computes again""",
                        language="julia",
                        show_copy=false
                    )
                ),
                Div(
                    H4(:class => "text-base font-semibold text-accent-700 dark:text-accent-400 mb-3", "With Memo"),
                    Suite.CodeBlock(
                        """# Computes once, caches result
filtered = create_memo() do
    filter(expensive_check, items())
end

filtered()  # Computes once
filtered()  # Cached
filtered()  # Cached""",
                        language="julia",
                        show_copy=false
                    )
                )
            ),

            H3(:class => "text-xl font-serif font-semibold text-warm-900 dark:text-warm-300 mb-4 mt-12",
                "Problem 2: Consistent Values"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mb-4",
                "Memos ensure multiple readers always see the same value, even if dependencies changed between reads."
            ),
            Suite.CodeBlock(
                """total = create_memo(() -> sum(items()))

# Both reads get the same cached value
header_text = "Total: \$(total())"
footer_text = "Sum: \$(total())"
# Guaranteed consistent!""",
                language="julia"
            )
        ),

        Suite.Separator(),

        # How Memos Work
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "How Memos Work"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Memos use lazy evaluation with a ", Strong("dirty flag"), " pattern:"
            ),
            Ol(:class => "space-y-4 text-warm-600 dark:text-warm-400 list-decimal list-inside",
                Li(Strong("Initial run:"), " Memo computes its value and tracks dependencies"),
                Li(Strong("Cached reads:"), " Subsequent calls return the cached value immediately"),
                Li(Strong("Dependency change:"), " When a dependency signals change, memo is marked dirty"),
                Li(Strong("Lazy recompute:"), " Next read triggers recomputation and new caching")
            ),
            Suite.CodeBlock(class="mt-8",
                code="""memo created → compute → cache value
                         ↓
read memo() → return cached value
                         ↓
dependency changes → mark dirty (don't compute yet!)
                         ↓
read memo() → recompute → cache new value""",
                language="",
                show_copy=false
            ),
            Suite.Alert(class="mt-8",
                Suite.AlertTitle("Lazy vs Eager"),
                Suite.AlertDescription(
                    "Unlike effects which run immediately when dependencies change, memos wait until " *
                    "they're actually read. This is called \"lazy\" or \"pull-based\" reactivity."
                )
            )
        ),

        Suite.Separator(),

        # Memo Chains
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Memo Chains"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Memos can depend on other memos, creating a chain of derived values. ",
                "Each memo in the chain is only recomputed when its specific dependencies change."
            ),
            Suite.CodeBlock(
                """items, set_items = create_signal([1, 2, 3, 4, 5])

# Chain of memos
filtered = create_memo(() -> filter(x -> x > 2, items()))  # [3, 4, 5]
sorted = create_memo(() -> sort(filtered()))               # [3, 4, 5]
total = create_memo(() -> sum(sorted()))                   # 12

total()  # 12

# Change the source
set_items([1, 2, 3, 4, 5, 6, 7])

# All memos marked dirty, but not computed yet!
# Only when we read:
total()  # Recomputes chain: filtered → sorted → total → 22""",
                language="julia"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "The dirty flag propagates through the chain, but recomputation only happens when a value is read."
            )
        ),

        Suite.Separator(),

        # Memos in Components
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Memos in Components"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Memos are especially useful in components for derived display values."
            ),
            Suite.CodeBlock(
                """function TodoList()
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
end""",
                language="julia"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "The ", Code(:class => "text-accent-700 dark:text-accent-400", "completed"),
                " and ", Code(:class => "text-accent-700 dark:text-accent-400", "remaining"),
                " values only recompute when ", Code(:class => "text-accent-700 dark:text-accent-400", "todos"),
                " changes, and only if they're read."
            )
        ),

        Suite.Separator(),

        # Signals vs Memos
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Signals vs Memos"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Both signals and memos provide reactive values, but they serve different purposes:"
            ),
            Suite.Table(
                Suite.TableHeader(
                    Suite.TableRow(
                        Suite.TableHead(""),
                        Suite.TableHead("Signal"),
                        Suite.TableHead("Memo")
                    )
                ),
                Suite.TableBody(
                    Suite.TableRow(
                        Suite.TableCell(class="font-medium", "Source"),
                        Suite.TableCell("External (user input, events)"),
                        Suite.TableCell("Derived from other signals")
                    ),
                    Suite.TableRow(
                        Suite.TableCell(class="font-medium", "Writable"),
                        Suite.TableCell("Yes (via setter)"),
                        Suite.TableCell("No (read-only)")
                    ),
                    Suite.TableRow(
                        Suite.TableCell(class="font-medium", "Caching"),
                        Suite.TableCell("Stores value directly"),
                        Suite.TableCell("Caches computed result")
                    ),
                    Suite.TableRow(
                        Suite.TableCell(class="font-medium", "Use for"),
                        Suite.TableCell("Primary state"),
                        Suite.TableCell("Derived/computed state")
                    )
                )
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                Strong("Rule of thumb:"), " Use signals for state you set directly; use memos for state computed from other state."
            )
        ),

        Suite.Separator(),

        # Best Practices
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Best Practices"
            ),
            Ul(:class => "space-y-4 text-warm-600 dark:text-warm-400",
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
                    " Simple computations like ", Code(:class => "text-accent-700 dark:text-accent-400", "count() + 1"),
                    " don't need memoization."
                )
            )
        ),

        # Key Takeaways
        Suite.Alert(class="mt-12",
            Suite.AlertTitle("Key Takeaways"),
            Suite.AlertDescription(
                Ul(:class => "space-y-2 list-disc pl-5 mt-2",
                    Li(Strong("Memos cache derived values"), " — compute once, read many times for free"),
                    Li(Strong("Lazy evaluation"), " — only recomputes when read after dependencies change"),
                    Li(Strong("Automatic tracking"), " — dependencies detected just like effects"),
                    Li(Strong("Chain-friendly"), " — memos can depend on other memos"),
                    Li(Strong("Read-only"), " — values come from computation, not external setting")
                )
            )
        ),

    )
end

# Export the page component
Memos
