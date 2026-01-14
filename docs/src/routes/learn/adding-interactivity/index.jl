# Adding Interactivity
#
# How to make your UI respond to user input with signals

function AddingInteractivity()
    TutorialLayout(
        Div(:class => "space-y-8",
            # Header
            Div(:class => "mb-8",
                H1(:class => "text-3xl font-semibold font-serif text-neutral-900 dark:text-neutral-100 mb-4",
                    "Adding Interactivity"
                ),
                P(:class => "text-lg text-neutral-700 dark:text-neutral-300",
                    "Signals make your UI reactive. When a signal changes, only the parts that depend on it update."
                )
            ),

            # Signals
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-neutral-900 dark:text-neutral-100 mb-4",
                    "Signals: Reactive Values"
                ),
                P(:class => "text-neutral-700 dark:text-neutral-300 mb-4",
                    "A signal is a value that can change over time. Create one with ",
                    Code(:class => "bg-neutral-200 dark:bg-neutral-800 px-1 rounded", "create_signal"),
                    ":"
                ),
                CodeBlock("""# Create a signal with initial value 0
count, set_count = create_signal(0)

count()       # Read: returns 0
set_count(5)  # Write: updates to 5
count()       # Read: returns 5"""),
                Div(:class => "bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 rounded p-4 mt-4",
                    P(:class => "text-amber-800 dark:text-amber-200 text-sm",
                        Strong("Note: "),
                        "The getter is a function — call it with ",
                        Code(:class => "bg-amber-100 dark:bg-amber-800 px-1 rounded", "count()"),
                        " to read the value. This is how Therapy.jl tracks dependencies."
                    )
                )
            ),

            Hr(:class => "border-neutral-300 dark:border-neutral-800"),

            # Event Handlers
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-neutral-900 dark:text-neutral-100 mb-4",
                    "Event Handlers"
                ),
                P(:class => "text-neutral-700 dark:text-neutral-300 mb-4",
                    "Attach handlers with ",
                    Code(:class => "bg-neutral-200 dark:bg-neutral-800 px-1 rounded", ":on_click"),
                    ", ",
                    Code(:class => "bg-neutral-200 dark:bg-neutral-800 px-1 rounded", ":on_input"),
                    ", etc.:"
                ),
                CodeBlock("""function Counter()
    count, set_count = create_signal(0)

    Div(:class => "flex items-center gap-4",
        Button(:on_click => () -> set_count(count() - 1), "-"),
        Span(count),
        Button(:on_click => () -> set_count(count() + 1), "+")
    )
end"""),
                P(:class => "text-neutral-700 dark:text-neutral-300 mt-4",
                    "Click handlers are Julia closures. They compile to WebAssembly and run at native speed."
                )
            ),

            Hr(:class => "border-neutral-300 dark:border-neutral-800"),

            # Binding Signals to the DOM
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-neutral-900 dark:text-neutral-100 mb-4",
                    "Binding Signals to the DOM"
                ),
                P(:class => "text-neutral-700 dark:text-neutral-300 mb-4",
                    "Pass a signal getter directly to display its value:"
                ),
                CodeBlock("""# The signal value appears in the DOM
Span(count)  # Shows current count

# When count changes, ONLY this Span updates
# No re-rendering of the parent component!"""),
                Div(:class => "bg-emerald-50 dark:bg-emerald-900/20 border border-emerald-200 dark:border-emerald-800 rounded p-4 mt-4",
                    P(:class => "text-emerald-800 dark:text-emerald-200 text-sm",
                        Strong("Fine-grained updates: "),
                        "Unlike React, the component function doesn't re-run. Only the specific text node updates."
                    )
                )
            ),

            Hr(:class => "border-neutral-300 dark:border-neutral-800"),

            # Input Binding
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-neutral-900 dark:text-neutral-100 mb-4",
                    "Input Binding"
                ),
                P(:class => "text-neutral-700 dark:text-neutral-300 mb-4",
                    "Bind inputs to signals for two-way data flow:"
                ),
                CodeBlock("""function SearchBox()
    query, set_query = create_signal("")

    Div(
        Input(
            :type => "text",
            :value => query,
            :on_input => (e) -> set_query(e.target.value),
            :placeholder => "Search..."
        ),
        P("You typed: ", query)
    )
end""")
            ),

            Hr(:class => "border-neutral-300 dark:border-neutral-800"),

            # Conditional Display
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-neutral-900 dark:text-neutral-100 mb-4",
                    "Conditional Display"
                ),
                P(:class => "text-neutral-700 dark:text-neutral-300 mb-4",
                    "Use ",
                    Code(:class => "bg-neutral-200 dark:bg-neutral-800 px-1 rounded", "Show"),
                    " for reactive conditional rendering:"
                ),
                CodeBlock("""function Toggle()
    visible, set_visible = create_signal(false)

    Div(
        Button(
            :on_click => () -> set_visible(!visible()),
            visible() ? "Hide" : "Show"
        ),
        Show(visible) do
            Div(:class => "p-4 bg-blue-100 rounded mt-2",
                "I appear and disappear!"
            )
        end
    )
end"""),
                P(:class => "text-neutral-700 dark:text-neutral-300 mt-4",
                    "The Show component efficiently adds/removes DOM elements based on the signal."
                )
            ),

            Hr(:class => "border-neutral-300 dark:border-neutral-800"),

            # Complete Example
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-neutral-900 dark:text-neutral-100 mb-4",
                    "Complete Example"
                ),
                P(:class => "text-neutral-700 dark:text-neutral-300 mb-4",
                    "Combining everything — a temperature converter:"
                ),
                CodeBlock("""function TempConverter()
    celsius, set_celsius = create_signal(0)

    # Derived value (computed from celsius)
    fahrenheit = () -> celsius() * 9/5 + 32

    Div(:class => "space-y-4 p-4",
        Div(
            Label("Celsius: "),
            Input(
                :type => "number",
                :value => celsius,
                :on_input => (e) -> set_celsius(parse(Int, e.target.value))
            )
        ),
        P(:class => "text-lg",
            celsius(), "°C = ", fahrenheit(), "°F"
        )
    )
end""")
            ),

            Hr(:class => "border-neutral-300 dark:border-neutral-800"),

            # Summary
            Div(:class => "bg-neutral-50 dark:bg-neutral-900 rounded-lg p-6",
                H3(:class => "text-lg font-semibold font-serif text-neutral-900 dark:text-neutral-100 mb-3",
                    "Summary"
                ),
                Ul(:class => "space-y-2 text-neutral-700 dark:text-neutral-300 text-sm",
                    Li(Strong("create_signal(value)"), " — returns (getter, setter) for reactive state"),
                    Li(Strong(":on_click => handler"), " — attach event handlers to elements"),
                    Li(Strong("Span(signal)"), " — bind signal values to the DOM"),
                    Li(Strong("Show(signal) do ... end"), " — conditional rendering")
                )
            ),

            # Next
            Div(:class => "mt-8",
                A(:href => "./learn/managing-state/",
                  :class => "text-emerald-700 dark:text-emerald-400 font-medium",
                    "Next: Managing State →"
                )
            )
        );
        current_path="learn/adding-interactivity/"
    )
end

AddingInteractivity
