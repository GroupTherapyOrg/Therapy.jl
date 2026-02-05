# Signals - The Foundation of Reactivity
#
# Deep dive into create_signal, reading and writing, and signal patterns.

function Signals()
    BookLayout("/book/reactivity/signals/",
        # Header
        Div(:class => "py-8 border-b border-warm-200 dark:border-warm-700",
            Span(:class => "text-sm text-accent-700 dark:text-accent-400 font-medium", "Part 2 · Reactivity"),
            H1(:class => "text-4xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-2 mb-4",
                "Signals"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 max-w-3xl",
                "Signals are reactive containers that hold values and notify subscribers when they change. ",
                "They're the foundation of Therapy.jl's fine-grained reactivity system."
            )
        ),

        # What is a Signal?
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "What is a Signal?"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "A signal is a reactive primitive that holds a value. Unlike regular variables, signals track who reads them ",
                "and automatically notify those readers when the value changes. This is the core mechanism that makes ",
                "Therapy.jl reactive."
            ),
            CodeBlock("""# Create a signal with an initial value
count, set_count = create_signal(0)

# Read the current value
count()    # => 0

# Write a new value
set_count(5)

# Read the updated value
count()    # => 5"""),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                Code(:class => "text-accent-700 dark:text-accent-400", "create_signal"),
                " returns a tuple of two callable objects: a ", Strong("getter"), " and a ", Strong("setter"),
                ". Call the getter with ", Code(:class => "text-accent-700 dark:text-accent-400", "count()"),
                " to read, and call the setter with ", Code(:class => "text-accent-700 dark:text-accent-400", "set_count(value)"),
                " to write."
            )
        ),

        # Why Signals?
        Section(:class => "py-12 bg-warm-100 dark:bg-warm-900 rounded-lg border border-warm-200 dark:border-warm-700 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Why Signals Instead of Variables?"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Regular Julia variables don't know when they're being read or modified. ",
                "Signals add this awareness, enabling automatic reactivity."
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-300 mb-4",
                        "Regular Variable"
                    ),
                    CodeBlock("""# Just a value - no tracking
count = 0

# Reading doesn't track anything
println(count)  # 0

# Writing doesn't notify anyone
count = 5

# No automatic updates anywhere""", "neutral")
                ),
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-accent-800 dark:text-accent-300 mb-4",
                        "Signal"
                    ),
                    CodeBlock("""# Reactive value with tracking
count, set_count = create_signal(0)

# Reading tracks dependencies
println(count())  # Records this read

# Writing notifies all readers
set_count(5)  # Triggers updates

# UI automatically refreshes!""", "emerald")
                )
            )
        ),

        # Dependency Tracking
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "How Dependency Tracking Works"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "When you read a signal inside a reactive context (like an effect), Therapy.jl automatically ",
                "records that dependency. When the signal changes, all dependent effects re-run."
            ),
            CodeBlock("""count, set_count = create_signal(0)

# This effect reads count(), establishing a dependency
create_effect() do
    println("Count is: ", count())  # count() registers as dependency
end
# Prints: "Count is: 0"

set_count(1)  # Effect re-runs, prints: "Count is: 1"
set_count(2)  # Effect re-runs, prints: "Count is: 2"

# Only changes trigger effects
set_count(2)  # No output - value didn't change"""),
            InfoBox("Automatic Tracking",
                "You don't need to manually specify dependencies. Therapy.jl tracks them automatically " *
                "when you call the getter inside a reactive context."
            )
        ),

        # Signals with Transforms
        Section(:class => "py-12 bg-warm-100 dark:bg-warm-900 rounded-lg border border-warm-200 dark:border-warm-700 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Signals with Transforms"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "You can provide a transform function that's applied whenever the signal is set. ",
                "This is useful for normalizing input or enforcing constraints."
            ),
            CodeBlock("""# Transform converts to uppercase
name, set_name = create_signal("", uppercase)

set_name("hello")
name()  # => "HELLO"

set_name("World")
name()  # => "WORLD"

# Clamp to a range
temp, set_temp = create_signal(20, x -> clamp(x, 0, 100))

set_temp(150)
temp()  # => 100 (clamped to max)

set_temp(-10)
temp()  # => 0 (clamped to min)"""),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "The transform is applied on every ", Code(:class => "text-accent-700 dark:text-accent-400", "set_*"),
                " call, not on reads. The stored value is always the transformed result."
            )
        ),

        # Signals in Components
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Signals in Components"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Signals are typically created inside component functions to manage local state. ",
                "When a signal updates, only the specific DOM nodes that read it are updated."
            ),
            CodeBlock("""function Counter()
    count, set_count = create_signal(0)

    Div(:class => "flex gap-4 items-center",
        Button(:on_click => () -> set_count(count() - 1), "-"),
        Span(count),  # Only this updates when count changes
        Button(:on_click => () -> set_count(count() + 1), "+")
    )
end"""),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "In this example, clicking the buttons calls ", Code(:class => "text-accent-700 dark:text-accent-400", "set_count"),
                ", which updates the signal and causes the ", Code(:class => "text-accent-700 dark:text-accent-400", "Span"),
                " to update. The ", Code(:class => "text-accent-700 dark:text-accent-400", "Div"),
                " and ", Code(:class => "text-accent-700 dark:text-accent-400", "Button"),
                " elements don't re-render—they never change."
            )
        ),

        # Update Patterns
        Section(:class => "py-12 bg-warm-100 dark:bg-warm-900 rounded-lg border border-warm-200 dark:border-warm-700 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Update Patterns"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "There are several common patterns for updating signals based on their current value."
            ),
            CodeBlock("""count, set_count = create_signal(0)

# Direct set
set_count(10)

# Increment/decrement using current value
set_count(count() + 1)  # 11
set_count(count() - 1)  # 10

# Toggle a boolean
visible, set_visible = create_signal(true)
set_visible(!visible())  # false
set_visible(!visible())  # true

# Update complex values
items, set_items = create_signal(["a", "b"])
set_items([items()..., "c"])  # ["a", "b", "c"]

# Update a struct field
user, set_user = create_signal((name="Alice", age=30))
set_user((name=user().name, age=user().age + 1))""")
        ),

        # Type Safety
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Type Safety"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Signals are typed based on their initial value. Julia's type system ensures ",
                "you only set values of the correct type."
            ),
            CodeBlock("""# Type is inferred from initial value
count, set_count = create_signal(0)      # Signal{Int64}
name, set_name = create_signal("")       # Signal{String}
items, set_items = create_signal([1,2])  # Signal{Vector{Int64}}

# Type-safe updates
set_count(5)        # ✓ OK
set_count("five")   # ✗ MethodError: cannot convert String to Int64

# For flexibility, use Union types
value, set_value = create_signal{Union{Int,String}}(0)
set_value("hello")  # ✓ OK now""")
        ),

        # Interactive Example
        Section(:class => "py-12 bg-gradient-to-br from-warm-50 to-warm-100 dark:from-warm-900 dark:to-warm-950 rounded-lg border border-warm-200 dark:border-warm-700",
            Div(:class => "text-center px-8",
                H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-4",
                    "Try It Live"
                ),
                P(:class => "text-warm-600 dark:text-warm-300 mb-8 max-w-xl mx-auto",
                    "This counter demonstrates signals in action. The buttons update a signal, which automatically updates the display. ",
                    "Click the buttons to see fine-grained reactivity at work!"
                ),
                Div(:class => "bg-warm-50/70 dark:bg-warm-900/70 backdrop-blur rounded border border-warm-200 dark:border-warm-800 p-8 max-w-md mx-auto",
                    InteractiveCounter()
                ),
                P(:class => "text-sm text-warm-600 dark:text-warm-600 mt-4",
                    "This component is running as WebAssembly compiled from Julia."
                )
            )
        ),

        # Key Takeaways
        Section(:class => "py-12 bg-warm-50 dark:bg-warm-900/30 rounded-lg border border-warm-200 dark:border-warm-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-accent-900 dark:text-accent-200 mb-6",
                "Key Takeaways"
            ),
            Ul(:class => "space-y-3 text-accent-800 dark:text-accent-300",
                Li(Strong("Signals are reactive containers"), " — they track reads and notify on writes"),
                Li(Strong("create_signal returns (getter, setter)"), " — call getter() to read, setter(val) to write"),
                Li(Strong("Dependencies are automatic"), " — reading inside effects establishes tracking"),
                Li(Strong("Updates are fine-grained"), " — only the specific DOM nodes that depend on a signal update"),
                Li(Strong("Transforms are optional"), " — normalize or validate values on write")
            )
        ),

        # Navigation handled by BookLayout via path parameter
    )
end

function CodeBlock(code, style="default")
    bg_class = if style == "emerald"
        "bg-warm-900 dark:bg-warm-950 border-warm-700"
    elseif style == "neutral"
        "bg-warm-800 dark:bg-warm-900 border-warm-600"
    else
        "bg-warm-800 dark:bg-warm-950 border-warm-900"
    end

    Div(:class => "$bg_class rounded border p-6 overflow-x-auto",
        Pre(:class => "text-sm text-warm-50",
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
Signals
