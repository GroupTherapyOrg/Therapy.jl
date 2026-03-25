# Adding Interactivity
#
# How to make your UI respond to user input with signals
# Uses Suite.jl components for visual presentation.

import Suite

function AddingInteractivity()
    TutorialLayout(
        Div(:class => "space-y-8",
            # Header
            Div(:class => "mb-8",
                H1(:class => "text-3xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Adding Interactivity"
                ),
                P(:class => "text-lg text-warm-800 dark:text-warm-300",
                    "Signals make your UI reactive. When a signal changes, only the parts that depend on it update."
                )
            ),

            # Signals
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Signals: Reactive Values"
                ),
                P(:class => "text-warm-800 dark:text-warm-300 mb-4",
                    "A signal is a value that can change over time. Create one with ",
                    Code(:class => "bg-warm-200 dark:bg-warm-900 px-1 rounded", "create_signal"),
                    ":"
                ),
                Suite.CodeBlock("""# Create a signal with initial value 0
count, set_count = create_signal(0)

count()       # Read: returns 0
set_count(5)  # Write: updates to 5
count()       # Read: returns 5""", language="julia"),
                Suite.Alert(
                    Suite.AlertTitle("Note"),
                    Suite.AlertDescription(
                        "The getter is a function — call it with ",
                        Code(:class => "bg-warm-200 dark:bg-warm-900 px-1 rounded", "count()"),
                        " to read the value. This is how Therapy.jl tracks dependencies."
                    )
                )
            ),

            Suite.Separator(),

            # Event Handlers
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Event Handlers"
                ),
                P(:class => "text-warm-800 dark:text-warm-300 mb-4",
                    "Attach handlers with ",
                    Code(:class => "bg-warm-200 dark:bg-warm-900 px-1 rounded", ":on_click"),
                    ", ",
                    Code(:class => "bg-warm-200 dark:bg-warm-900 px-1 rounded", ":on_input"),
                    ", etc.:"
                ),
                Suite.CodeBlock("""function Counter()
    count, set_count = create_signal(0)

    Div(:class => "flex items-center gap-4",
        Button(:on_click => () -> set_count(count() - 1), "-"),
        Span(count),
        Button(:on_click => () -> set_count(count() + 1), "+")
    )
end""", language="julia"),
                P(:class => "text-warm-800 dark:text-warm-300 mt-4",
                    "Click handlers are Julia closures. They compile to JavaScript and run in the browser."
                )
            ),

            Suite.Separator(),

            # Binding Signals to the DOM
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Binding Signals to the DOM"
                ),
                P(:class => "text-warm-800 dark:text-warm-300 mb-4",
                    "Pass a signal getter directly to display its value:"
                ),
                Suite.CodeBlock("""# The signal value appears in the DOM
Span(count)  # Shows current count

# When count changes, ONLY this Span updates
# No re-rendering of the parent component!""", language="julia"),
                Suite.Alert(
                    Suite.AlertTitle("Fine-grained updates"),
                    Suite.AlertDescription(
                        "Unlike React, the component function doesn't re-run. Only the specific text node updates."
                    )
                )
            ),

            Suite.Separator(),

            # Input Binding
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Input Binding"
                ),
                P(:class => "text-warm-800 dark:text-warm-300 mb-4",
                    "Bind inputs to signals for two-way data flow:"
                ),
                Suite.CodeBlock("""function SearchBox()
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
end""", language="julia")
            ),

            Suite.Separator(),

            # Conditional Display
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Conditional Display"
                ),
                P(:class => "text-warm-800 dark:text-warm-300 mb-4",
                    "Use ",
                    Code(:class => "bg-warm-200 dark:bg-warm-900 px-1 rounded", "Show"),
                    " for reactive conditional rendering:"
                ),
                Suite.CodeBlock("""function Toggle()
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
end""", language="julia"),
                P(:class => "text-warm-800 dark:text-warm-300 mt-4",
                    "The Show component efficiently adds/removes DOM elements based on the signal."
                )
            ),

            Suite.Separator(),

            # Islands vs Functions
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Functions vs Islands"
                ),
                P(:class => "text-warm-800 dark:text-warm-300 mb-4",
                    "Not every component needs interactivity. Only wrap code in ",
                    Code(:class => "bg-warm-200 dark:bg-warm-900 px-1 rounded", "@island"),
                    " when it needs to respond to user actions in the browser:"
                ),
                Suite.CodeBlock("""# Static — just a regular function (no JS compilation, no signals)
function Header(title)
    H1(:class => "text-2xl font-bold", title)
end

# Interactive — needs @island because it has signals + handlers
@island function Counter()
    count, set_count = create_signal(0)
    Div(
        Button(:on_click => () -> set_count(count() + 1), "+"),
        Span(count)
    )
end

# Server function — runs on server, callable from client
@server function save_count(value::Int)
    # Database access, file I/O, etc.
end""", language="julia"),
                Suite.Alert(
                    Suite.AlertTitle("Rule of thumb"),
                    Suite.AlertDescription(
                        "Start with a regular function. Only upgrade to ",
                        Code(:class => "bg-warm-200 dark:bg-warm-900 px-1 rounded", "@island"),
                        " when you need signals or event handlers. This keeps your app fast — less JS means faster page loads."
                    )
                )
            ),

            Suite.Separator(),

            # Complete Example
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Complete Example"
                ),
                P(:class => "text-warm-800 dark:text-warm-300 mb-4",
                    "Combining everything — a temperature converter:"
                ),
                Suite.CodeBlock("""function TempConverter()
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
end""", language="julia")
            ),

            Suite.Separator(),

            # Summary
            Suite.Card(
                Suite.CardHeader(
                    Suite.CardTitle(class="font-serif", "Summary"),
                ),
                Suite.CardContent(
                    Ul(:class => "space-y-2 text-warm-800 dark:text-warm-300 text-sm",
                        Li(Strong("create_signal(value)"), " — returns (getter, setter) for reactive state"),
                        Li(Strong(":on_click => handler"), " — attach event handlers to elements"),
                        Li(Strong("Span(signal)"), " — bind signal values to the DOM"),
                        Li(Strong("Show(signal) do ... end"), " — conditional rendering")
                    )
                )
            ),

            # Next
            Div(:class => "mt-8",
                A(:href => "./learn/managing-state/",
                  :class => "text-accent-700 dark:text-accent-400 font-medium",
                    "Next: Managing State →"
                )
            )
        );
        current_path="learn/adding-interactivity/"
    )
end

AddingInteractivity
