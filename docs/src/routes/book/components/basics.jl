# Component Basics - Function Components and Naming
#
# Deep dive into creating components as functions in Therapy.jl.

import Suite

function Basics()
    BookLayout("/book/components/basics/",
        # Header
        Div(:class => "py-8 border-b border-warm-200 dark:border-warm-700",
            Suite.Badge(variant="outline", "Part 3 · Components"),
            H1(:class => "text-4xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-2 mb-4",
                "Basics"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 max-w-3xl",
                "Components in Therapy.jl are simply Julia functions that return VNode elements. ",
                "This section covers the fundamentals of creating and using components."
            )
        ),

        # What is a Component?
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "What is a Component?"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "A component is a reusable piece of UI. In Therapy.jl, components are just functions ",
                "that return VNode elements—the same ", Code(:class => "text-accent-700 dark:text-accent-400", "Div"),
                ", ", Code(:class => "text-accent-700 dark:text-accent-400", "P"),
                ", ", Code(:class => "text-accent-700 dark:text-accent-400", "Button"),
                " elements you've already been using."
            ),
            Suite.CodeBlock(
                """# The simplest component - just a function
function HelloWorld()
    P("Hello, World!")
end

# Render it
render_to_string(HelloWorld())
# => "<p>Hello, World!</p>"

# Components can use other elements
function Greeting()
    Div(:class => "p-4 bg-gray-100",
        H1("Welcome!"),
        P("Nice to see you.")
    )
end""",
                language="julia"
            ),
            Suite.Alert(class="mt-8",
                Suite.AlertTitle("Functions All The Way Down"),
                Suite.AlertDescription(
                    "Unlike frameworks that require classes, decorators, or special syntax, " *
                    "Therapy.jl components are plain Julia functions. This means you can use " *
                    "all of Julia's features: multiple dispatch, closures, macros, and more."
                )
            )
        ),

        Suite.Separator(),

        # Naming Conventions
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Naming Conventions"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "By convention, component functions use ", Strong("PascalCase"), " names, while regular functions ",
                "use ", Strong("snake_case"), ". This makes it easy to distinguish components from utilities."
            ),
            Suite.CodeBlock(
                """# Components: PascalCase
function UserCard()
    Div(:class => "card", ...)
end

function NavigationBar()
    Nav(:class => "navbar", ...)
end

function TodoItem()
    Li(:class => "todo-item", ...)
end

# Utility functions: snake_case
function format_date(date)
    # ...
end

function validate_email(email)
    # ...
end""",
                language="julia"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "This convention mirrors JSX/React patterns, making it intuitive for developers ",
                "coming from the JavaScript ecosystem."
            )
        ),

        Suite.Separator(),

        # Components with Local State
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Components with Local State"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Components become interesting when they have local state. Use ",
                Code(:class => "text-accent-700 dark:text-accent-400", "create_signal"),
                " inside a component to create reactive state that's scoped to that component instance."
            ),
            Suite.CodeBlock(
                """function Counter()
    # Each Counter instance has its own count signal
    count, set_count = create_signal(0)

    Div(:class => "flex items-center gap-4",
        Button(:on_click => () -> set_count(count() - 1), "-"),
        Span(:class => "text-xl", count),
        Button(:on_click => () -> set_count(count() + 1), "+")
    )
end

# Multiple instances have independent state
Div(
    Counter(),  # count: 0
    Counter(),  # count: 0 (separate)
    Counter()   # count: 0 (separate)
)""",
                language="julia"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "Each time the component function is called, new signals are created. ",
                "This gives each instance its own isolated state."
            )
        ),

        Suite.Separator(),

        # Function Components with Children
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Function Components with Children"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "For components that need to receive props and children, use keyword arguments with ",
                Code(:class => "text-accent-700 dark:text-accent-400", "children..."),
                " varargs to collect nested content."
            ),
            Suite.CodeBlock(
                """# Function component with kwargs and children
function Card(; title="Untitled", children...)
    Div(:class => "border rounded-lg p-4 shadow",
        H2(:class => "text-xl font-bold", title),
        children...  # Render any children passed in
    )
end

# Use it like any other element
Card(title="Welcome",
    P("This is the card content."),
    P("You can put anything here.")
)""",
                language="julia"
            ),
            Div(:class => "mt-6 grid md:grid-cols-2 gap-4",
                Suite.Card(
                    Suite.CardContent(class="p-4",
                        H4(:class => "font-serif font-semibold text-warm-800 dark:text-warm-50 mb-1", "Keyword Arguments"),
                        P(:class => "text-warm-600 dark:text-warm-400 text-sm",
                            "Named parameters with defaults make the component interface clear and self-documenting."
                        )
                    )
                ),
                Suite.Card(
                    Suite.CardContent(class="p-4",
                        H4(:class => "font-serif font-semibold text-warm-800 dark:text-warm-50 mb-1", "children... Varargs"),
                        P(:class => "text-warm-600 dark:text-warm-400 text-sm",
                            "The children... parameter collects all positional arguments as nested content."
                        )
                    )
                )
            )
        ),

        Suite.Separator(),

        # Calling Conventions
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Calling Conventions"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Therapy.jl has two calling conventions. HTML elements use ",
                Strong("Pair syntax"), " for attributes, while your components use ",
                Strong("keyword arguments"), " for props."
            ),
            Suite.CodeBlock(
                """# HTML elements: Pair syntax (:key => value)
Div(:class => "container", :id => "main",
    H1("Title"),
    Button(:on_click => handler, :disabled => true, "Click")
)

# Your components: keyword arguments
UserCard(name="Alice", role="Admin")
Card(title="Welcome", P("Content here"))
Counter(initial=5)

# Why the difference?
# HTML elements need arbitrary string attributes (:data_testid, :aria_label, etc.)
# Your functions have a fixed, typed interface — kwargs are more natural and safe""",
                language="julia"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "Both return VNodes. The difference is just how arguments are passed in."
            )
        ),

        Suite.Separator(),

        # Plain Functions vs Functions with Children
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Plain Functions vs Functions with Children"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Both approaches work. Here's when to use each:"
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-300 mb-4",
                        "Plain Functions"
                    ),
                    Suite.CodeBlock(
                        """# Simple, direct
function Greeting(; name="World")
    P("Hello, ", name, "!")
end

# Call with keyword args
Greeting(name="Julia")""",
                        language="julia",
                        show_copy=false
                    ),
                    Ul(:class => "mt-4 space-y-1 text-warm-600 dark:text-warm-400 text-sm",
                        Li("✓ Simpler syntax"),
                        Li("✓ Full type annotations"),
                        Li("✓ Multiple dispatch works"),
                        Li("✗ No children composition")
                    )
                ),
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-accent-800 dark:text-accent-300 mb-4",
                        "Functions with children..."
                    ),
                    Suite.CodeBlock(
                        """# With children varargs
function Card(; title, children...)
    Div(title, children...)
end

# Call with keyword args
Card(title="Hi", P("Content"))""",
                        language="julia",
                        show_copy=false
                    ),
                    Ul(:class => "mt-4 space-y-1 text-accent-700 dark:text-accent-400 text-sm",
                        Li("✓ Accepts nested content"),
                        Li("✓ children... collects positional args"),
                        Li("✓ Keyword args like HTML"),
                        Li("✗ Slightly more verbose")
                    )
                )
            ),
            Suite.Alert(class="mt-8",
                Suite.AlertTitle("Recommendation"),
                Suite.AlertDescription(
                    "Use plain functions for simple components without children. " *
                    "Use children... when you need to render arbitrary nested content."
                )
            )
        ),

        Suite.Separator(),

        # Islands for Interactivity
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Islands for Interactivity"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Regular components render to static HTML. To make a component interactive ",
                "(handle events, update in browser), mark it with ",
                Code(:class => "text-accent-700 dark:text-accent-400", "@island"), "."
            ),
            Suite.CodeBlock(
                """# Static component - renders to HTML only
function StaticCounter()
    count = 0  # Just a regular variable
    Div(
        Button("-"),  # Click does nothing on client
        Span(count),
        Button("+")   # Click does nothing on client
    )
end

# Interactive island - compiles to JavaScript
@island function Counter()
    count, set_count = create_signal(0)

    Div(
        Button(:on_click => () -> set_count(count() - 1), "-"),
        Span(count),  # Updates in browser!
        Button(:on_click => () -> set_count(count() + 1), "+")
    )
end""",
                language="julia"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "Islands are auto-discovered and compiled to JavaScript. They hydrate on the client ",
                "to become interactive, while static content remains as plain HTML."
            ),
            # Live Demo
            Section(:class => "mt-8 py-8 bg-gradient-to-br from-warm-50 to-warm-100 dark:from-warm-900 dark:to-warm-950 rounded-lg border border-warm-200 dark:border-warm-700",
                Div(:class => "text-center px-8",
                    H3(:class => "text-lg font-serif font-semibold text-warm-800 dark:text-warm-50 mb-4",
                        "Live Island Demo"
                    ),
                    Suite.Card(class="max-w-xs mx-auto",
                        Suite.CardContent(class="flex justify-center p-8",
                            InteractiveCounter()
                        )
                    ),
                    P(:class => "text-sm text-warm-600 dark:text-warm-600 mt-4",
                        "This counter is a Therapy.jl island running as JavaScript."
                    )
                )
            )
        ),

        Suite.Separator(),

        # Component Organization
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Component Organization"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "As your application grows, organize components into files and modules:"
            ),
            Suite.CodeBlock(
                """# src/components/Card.jl
function Card(; title, children...)
    Div(:class => "card",
        H2(:class => "card-title", title),
        Div(:class => "card-body", children...)
    )
end

# src/components/Button.jl
function PrimaryButton(; on_click, children...)
    Button(:class => "btn btn-primary", :on_click => on_click, children...)
end

function SecondaryButton(; on_click, children...)
    Button(:class => "btn btn-secondary", :on_click => on_click, children...)
end

# src/components/index.jl
include("Card.jl")
include("Button.jl")
export Card, PrimaryButton, SecondaryButton""",
                language="julia"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "Group related components together. Use Julia's module system for encapsulation ",
                "when needed."
            )
        ),

        # Key Takeaways
        Suite.Alert(class="mt-12",
            Suite.AlertTitle("Key Takeaways"),
            Suite.AlertDescription(
                Ul(:class => "space-y-2 list-disc pl-5 mt-2",
                    Li(Strong("Components are functions"), " — return VNode elements, no special syntax required"),
                    Li(Strong("PascalCase naming"), " — distinguishes components from utility functions"),
                    Li(Strong("Local state with signals"), " — each instance gets its own reactive state"),
                    Li(Strong("children... for composition"), " — use when you need to accept nested content"),
                    Li(Strong("@island for interactivity"), " — marks components that need browser events/updates")
                )
            )
        ),

    )
end

# Export the page component
Basics
