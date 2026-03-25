# Signals - The Foundation of Reactivity
#
# Deep dive into create_signal, reading and writing, and signal patterns.

import Suite

function Signals()
    BookLayout("/book/reactivity/signals/",
        # Header
        Div(:class => "py-8 border-b border-warm-200 dark:border-warm-700",
            Suite.Badge(variant="outline", "Part 2 · Reactivity"),
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
            Suite.CodeBlock(
                """# Create a signal with an initial value
count, set_count = create_signal(0)

# Read the current value
count()    # => 0

# Write a new value
set_count(5)

# Read the updated value
count()    # => 5""",
                language="julia"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                Code(:class => "text-accent-700 dark:text-accent-400", "create_signal"),
                " returns a tuple of two callable objects: a ", Strong("getter"), " and a ", Strong("setter"),
                ". Call the getter with ", Code(:class => "text-accent-700 dark:text-accent-400", "count()"),
                " to read, and call the setter with ", Code(:class => "text-accent-700 dark:text-accent-400", "set_count(value)"),
                " to write."
            )
        ),

        Suite.Separator(),

        # Why Signals?
        Section(:class => "py-12",
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
                    Suite.CodeBlock(
                        """# Just a value - no tracking
count = 0

# Reading doesn't track anything
println(count)  # 0

# Writing doesn't notify anyone
count = 5

# No automatic updates anywhere""",
                        language="julia",
                        show_copy=false
                    )
                ),
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-accent-800 dark:text-accent-300 mb-4",
                        "Signal"
                    ),
                    Suite.CodeBlock(
                        """# Reactive value with tracking
count, set_count = create_signal(0)

# Reading tracks dependencies
println(count())  # Records this read

# Writing notifies all readers
set_count(5)  # Triggers updates

# UI automatically refreshes!""",
                        language="julia",
                        show_copy=false
                    )
                )
            )
        ),

        Suite.Separator(),

        # Dependency Tracking
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "How Dependency Tracking Works"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "When you read a signal inside a reactive context (like an effect), Therapy.jl automatically ",
                "records that dependency. When the signal changes, all dependent effects re-run."
            ),
            Suite.CodeBlock(
                """count, set_count = create_signal(0)

# This effect reads count(), establishing a dependency
create_effect() do
    println("Count is: ", count())  # count() registers as dependency
end
# Prints: "Count is: 0"

set_count(1)  # Effect re-runs, prints: "Count is: 1"
set_count(2)  # Effect re-runs, prints: "Count is: 2"

# Only changes trigger effects
set_count(2)  # No output - value didn't change""",
                language="julia"
            ),
            Suite.Alert(class="mt-8",
                Suite.AlertTitle("Automatic Tracking"),
                Suite.AlertDescription(
                    "You don't need to manually specify dependencies. Therapy.jl tracks them automatically " *
                    "when you call the getter inside a reactive context."
                )
            )
        ),

        Suite.Separator(),

        # Signals with Transforms
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Signals with Transforms"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "You can provide a transform function that's applied whenever the signal is set. ",
                "This is useful for normalizing input or enforcing constraints."
            ),
            Suite.CodeBlock(
                """# Transform converts to uppercase
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
temp()  # => 0 (clamped to min)""",
                language="julia"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "The transform is applied on every ", Code(:class => "text-accent-700 dark:text-accent-400", "set_*"),
                " call, not on reads. The stored value is always the transformed result."
            )
        ),

        Suite.Separator(),

        # Signals in Components
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Signals in Components"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Signals are typically created inside component functions to manage local state. ",
                "When a signal updates, only the specific DOM nodes that read it are updated."
            ),
            Suite.CodeBlock(
                """function Counter()
    count, set_count = create_signal(0)

    Div(:class => "flex gap-4 items-center",
        Button(:on_click => () -> set_count(count() - 1), "-"),
        Span(count),  # Only this updates when count changes
        Button(:on_click => () -> set_count(count() + 1), "+")
    )
end""",
                language="julia"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "In this example, clicking the buttons calls ", Code(:class => "text-accent-700 dark:text-accent-400", "set_count"),
                ", which updates the signal and causes the ", Code(:class => "text-accent-700 dark:text-accent-400", "Span"),
                " to update. The ", Code(:class => "text-accent-700 dark:text-accent-400", "Div"),
                " and ", Code(:class => "text-accent-700 dark:text-accent-400", "Button"),
                " elements don't re-render—they never change."
            )
        ),

        Suite.Separator(),

        # Update Patterns
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Update Patterns"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "There are several common patterns for updating signals based on their current value."
            ),
            Suite.CodeBlock(
                """count, set_count = create_signal(0)

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
set_user((name=user().name, age=user().age + 1))""",
                language="julia"
            )
        ),

        Suite.Separator(),

        # Type Safety
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Type Safety"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Signals are typed based on their initial value. Julia's type system ensures ",
                "you only set values of the correct type."
            ),
            Suite.CodeBlock(
                """# Type is inferred from initial value
count, set_count = create_signal(0)      # Signal{Int64}
name, set_name = create_signal("")       # Signal{String}
items, set_items = create_signal([1,2])  # Signal{Vector{Int64}}

# Type-safe updates
set_count(5)        # ✓ OK
set_count("five")   # ✗ MethodError: cannot convert String to Int64

# For flexibility, use Union types
value, set_value = create_signal{Union{Int,String}}(0)
set_value("hello")  # ✓ OK now""",
                language="julia"
            )
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
                Suite.Card(class="max-w-md mx-auto",
                    Suite.CardContent(class="flex justify-center p-8",
                        InteractiveCounter()
                    )
                ),
                P(:class => "text-sm text-warm-600 dark:text-warm-600 mt-4",
                    "This component is running as JavaScript compiled from Julia."
                )
            )
        ),

        # Key Takeaways
        Suite.Alert(class="mt-12",
            Suite.AlertTitle("Key Takeaways"),
            Suite.AlertDescription(
                Ul(:class => "space-y-2 list-disc pl-5 mt-2",
                    Li(Strong("Signals are reactive containers"), " — they track reads and notify on writes"),
                    Li(Strong("create_signal returns (getter, setter)"), " — call getter() to read, setter(val) to write"),
                    Li(Strong("Dependencies are automatic"), " — reading inside effects establishes tracking"),
                    Li(Strong("Updates are fine-grained"), " — only the specific DOM nodes that depend on a signal update"),
                    Li(Strong("Transforms are optional"), " — normalize or validate values on write")
                )
            )
        ),

        # Navigation handled by BookLayout via path parameter
    )
end

# Export the page component
Signals
