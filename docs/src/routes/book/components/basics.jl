# Component Basics - Function Components and Naming
#
# Deep dive into creating components as functions in Therapy.jl.

function Basics()
    BookLayout("/book/components/basics/",
        # Header
        Div(:class => "py-8 border-b border-neutral-300 dark:border-neutral-800",
            Span(:class => "text-sm text-emerald-700 dark:text-emerald-400 font-medium", "Part 3 · Components"),
            H1(:class => "text-4xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mt-2 mb-4",
                "Basics"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 max-w-3xl",
                "Components in Therapy.jl are simply Julia functions that return VNode elements. ",
                "This section covers the fundamentals of creating and using components."
            )
        ),

        # What is a Component?
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "What is a Component?"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "A component is a reusable piece of UI. In Therapy.jl, components are just functions ",
                "that return VNode elements—the same ", Code(:class => "text-emerald-700 dark:text-emerald-400", "Div"),
                ", ", Code(:class => "text-emerald-700 dark:text-emerald-400", "P"),
                ", ", Code(:class => "text-emerald-700 dark:text-emerald-400", "Button"),
                " elements you've already been using."
            ),
            CodeBlock("""# The simplest component - just a function
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
end"""),
            InfoBox("Functions All The Way Down",
                "Unlike frameworks that require classes, decorators, or special syntax, " *
                "Therapy.jl components are plain Julia functions. This means you can use " *
                "all of Julia's features: multiple dispatch, closures, macros, and more."
            )
        ),

        # Naming Conventions
        Section(:class => "py-12 bg-neutral-50 dark:bg-neutral-900 rounded-lg border border-neutral-300 dark:border-neutral-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Naming Conventions"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "By convention, component functions use ", Strong("PascalCase"), " names, while regular functions ",
                "use ", Strong("snake_case"), ". This makes it easy to distinguish components from utilities."
            ),
            CodeBlock("""# Components: PascalCase
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
end"""),
            P(:class => "text-neutral-600 dark:text-neutral-400 mt-6",
                "This convention mirrors JSX/React patterns, making it intuitive for developers ",
                "coming from the JavaScript ecosystem."
            )
        ),

        # Components with Local State
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Components with Local State"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "Components become interesting when they have local state. Use ",
                Code(:class => "text-emerald-700 dark:text-emerald-400", "create_signal"),
                " inside a component to create reactive state that's scoped to that component instance."
            ),
            CodeBlock("""function Counter()
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
)"""),
            P(:class => "text-neutral-600 dark:text-neutral-400 mt-6",
                "Each time the component function is called, new signals are created. ",
                "This gives each instance its own isolated state."
            )
        ),

        # The component() Wrapper
        Section(:class => "py-12 bg-neutral-50 dark:bg-neutral-900 rounded-lg border border-neutral-300 dark:border-neutral-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "The component() Wrapper"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "For components that need to receive props via the standard pattern, use the ",
                Code(:class => "text-emerald-700 dark:text-emerald-400", "component()"),
                " wrapper. This registers the component and provides a ",
                Code(:class => "text-emerald-700 dark:text-emerald-400", "props"),
                " object."
            ),
            CodeBlock("""# Create a named component with props support
Card = component(:Card) do props
    title = get_prop(props, :title, "Untitled")

    Div(:class => "border rounded-lg p-4 shadow",
        H2(:class => "text-xl font-bold", title),
        get_children(props)  # Render any children passed in
    )
end

# Use it like any other element
Card(:title => "Welcome",
    P("This is the card content."),
    P("You can put anything here.")
)"""),
            Div(:class => "mt-6 grid md:grid-cols-2 gap-4",
                FeatureBox("Registration",
                    "The :Card symbol registers the component for debugging, DevTools, and error messages."
                ),
                FeatureBox("Props Object",
                    "The props argument gives access to get_prop() and get_children() helpers."
                )
            )
        ),

        # Plain Functions vs component()
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Plain Functions vs component()"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "Both approaches work. Here's when to use each:"
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-neutral-800 dark:text-neutral-200 mb-4",
                        "Plain Functions"
                    ),
                    CodeBlock("""# Simple, direct
function Greeting(; name="World")
    P("Hello, ", name, "!")
end

# Call with keyword args
Greeting(name="Julia")""", "neutral"),
                    Ul(:class => "mt-4 space-y-1 text-neutral-600 dark:text-neutral-400 text-sm",
                        Li("✓ Simpler syntax"),
                        Li("✓ Full type annotations"),
                        Li("✓ Multiple dispatch works"),
                        Li("✗ No get_children() pattern")
                    )
                ),
                Div(:class => "bg-emerald-50 dark:bg-emerald-950/30 rounded-lg p-6 border border-emerald-200 dark:border-emerald-900",
                    H3(:class => "text-lg font-serif font-semibold text-emerald-800 dark:text-emerald-300 mb-4",
                        "component() Wrapper"
                    ),
                    CodeBlock("""# Registered with props
Card = component(:Card) do props
    title = get_prop(props, :title)
    Div(title, get_children(props))
end

# Call with pair syntax
Card(:title => "Hi", P("Content"))""", "emerald"),
                    Ul(:class => "mt-4 space-y-1 text-emerald-700 dark:text-emerald-400 text-sm",
                        Li("✓ Named for debugging"),
                        Li("✓ get_children() works"),
                        Li("✓ Pair syntax like HTML"),
                        Li("✗ Slightly more verbose")
                    )
                )
            ),
            InfoBox("Recommendation",
                "Use plain functions for simple components without children. " *
                "Use component() when you need to render arbitrary children or want registration."
            )
        ),

        # Islands for Interactivity
        Section(:class => "py-12 bg-neutral-50 dark:bg-neutral-900 rounded-lg border border-neutral-300 dark:border-neutral-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Islands for Interactivity"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "Regular components render to static HTML. To make a component interactive ",
                "(handle events, update in browser), wrap it with ",
                Code(:class => "text-emerald-700 dark:text-emerald-400", "island()"), "."
            ),
            CodeBlock("""# Static component - renders to HTML only
function StaticCounter()
    count = 0  # Just a regular variable
    Div(
        Button("-"),  # Click does nothing on client
        Span(count),
        Button("+")   # Click does nothing on client
    )
end

# Interactive island - compiles to WebAssembly
Counter = island(:Counter) do
    count, set_count = create_signal(0)

    Div(
        Button(:on_click => () -> set_count(count() - 1), "-"),
        Span(count),  # Updates in browser!
        Button(:on_click => () -> set_count(count() + 1), "+")
    )
end"""),
            P(:class => "text-neutral-600 dark:text-neutral-400 mt-6",
                "Islands are auto-discovered and compiled to WebAssembly. They hydrate on the client ",
                "to become interactive, while static content remains as plain HTML."
            ),
            # Live Demo
            Div(:class => "mt-8 bg-gradient-to-br from-emerald-100 to-amber-100 dark:from-emerald-950/50 dark:to-amber-950/50 rounded-lg border border-neutral-200 dark:border-neutral-700 p-6",
                H4(:class => "text-lg font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-4 text-center",
                    "Live Island Demo"
                ),
                Div(:class => "bg-white/70 dark:bg-neutral-900/70 backdrop-blur rounded border border-neutral-300 dark:border-neutral-700 p-6 max-w-xs mx-auto",
                    InteractiveCounter()
                ),
                P(:class => "text-sm text-neutral-500 dark:text-neutral-500 mt-4 text-center",
                    "This counter is a Therapy.jl island running as WebAssembly."
                )
            )
        ),

        # Component Organization
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Component Organization"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "As your application grows, organize components into files and modules:"
            ),
            CodeBlock("""# src/components/Card.jl
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
export Card, PrimaryButton, SecondaryButton"""),
            P(:class => "text-neutral-600 dark:text-neutral-400 mt-6",
                "Group related components together. Use Julia's module system for encapsulation ",
                "when needed."
            )
        ),

        # Key Takeaways
        Section(:class => "py-12 bg-emerald-50 dark:bg-emerald-950/30 rounded-lg border border-emerald-200 dark:border-emerald-900 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-emerald-900 dark:text-emerald-200 mb-6",
                "Key Takeaways"
            ),
            Ul(:class => "space-y-3 text-emerald-800 dark:text-emerald-300",
                Li(Strong("Components are functions"), " — return VNode elements, no special syntax required"),
                Li(Strong("PascalCase naming"), " — distinguishes components from utility functions"),
                Li(Strong("Local state with signals"), " — each instance gets its own reactive state"),
                Li(Strong("component() for props"), " — use when you need get_children() or registration"),
                Li(Strong("island() for interactivity"), " — wraps components that need browser events/updates")
            )
        ),

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

function FeatureBox(title, content)
    Div(:class => "bg-white dark:bg-neutral-800 rounded-lg border border-neutral-200 dark:border-neutral-700 p-4",
        H4(:class => "font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-1", title),
        P(:class => "text-neutral-600 dark:text-neutral-400 text-sm", content)
    )
end

# Export the page component
Basics
