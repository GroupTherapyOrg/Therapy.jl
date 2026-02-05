# Describing the UI
#
# How to create and compose UI components in Therapy.jl

function DescribingUI()
    TutorialLayout(
        Div(:class => "space-y-8",
            # Header
            Div(:class => "mb-8",
                H1(:class => "text-3xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Describing the UI"
                ),
                P(:class => "text-lg text-warm-800 dark:text-warm-200",
                    "In Therapy.jl, UI is built from components — Julia functions that return elements."
                )
            ),

            # Components are Functions
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Components are Functions"
                ),
                P(:class => "text-warm-800 dark:text-warm-200 mb-4",
                    "A component is just a Julia function that returns a VNode (virtual DOM node):"
                ),
                CodeBlock("""function Greeting(name)
    Div(:class => "p-4 bg-blue-100 rounded",
        H1("Hello, ", name, "!"),
        P("Welcome to Therapy.jl")
    )
end

# Use it
Greeting("Julia")"""),
                P(:class => "text-warm-800 dark:text-warm-200 mt-4",
                    "This is similar to React's function components, but it's just regular Julia."
                )
            ),

            Hr(:class => "border-warm-200 dark:border-warm-900"),

            # Elements
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Elements"
                ),
                P(:class => "text-warm-800 dark:text-warm-200 mb-4",
                    "Therapy.jl provides capitalized element functions that mirror HTML:"
                ),
                CodeBlock("""# Layout
Div(:class => "container", children...)
Span(:class => "text-red-500", "Error!")

# Text
H1("Title")
P("Paragraph")
Strong("Bold"), Em("Italic")

# Forms
Input(:type => "text", :placeholder => "Name...")
Button(:on_click => handler, "Click me")

# Lists
Ul(Li("One"), Li("Two"), Li("Three"))"""),
                Div(:class => "bg-warm-100 dark:bg-warm-800 rounded-lg p-4 mt-4",
                    P(:class => "text-warm-600 dark:text-warm-400 text-sm",
                        Strong("Why capitalized? "),
                        "Like JSX, capitalized names distinguish components from HTML strings. ",
                        Code(:class => "bg-warm-200 dark:bg-warm-900 px-1 rounded", "Div"),
                        " creates an element, ",
                        Code(:class => "bg-warm-200 dark:bg-warm-900 px-1 rounded", "\"div\""),
                        " is just a string."
                    )
                )
            ),

            Hr(:class => "border-warm-200 dark:border-warm-900"),

            # Attributes
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Attributes"
                ),
                P(:class => "text-warm-800 dark:text-warm-200 mb-4",
                    "Pass attributes as keyword-style pairs using ",
                    Code(:class => "bg-warm-200 dark:bg-warm-900 px-1 rounded", ":name => value"),
                    ":"
                ),
                CodeBlock("""# CSS classes
Div(:class => "flex items-center gap-4", ...)

# IDs and data attributes
Div(:id => "main", Symbol("data-testid") => "container", ...)

# Input attributes
Input(:type => "email", :placeholder => "you@example.com")

# Links
A(:href => "/about", :class => "underline", "About")""")
            ),

            Hr(:class => "border-warm-200 dark:border-warm-900"),

            # Composition
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Composition"
                ),
                P(:class => "text-warm-800 dark:text-warm-200 mb-4",
                    "Build complex UIs by composing smaller components:"
                ),
                CodeBlock("""function Avatar(url, name)
    Img(:src => url, :alt => name,
        :class => "w-10 h-10 rounded-full")
end

function UserCard(user)
    Div(:class => "flex items-center gap-3 p-4 border rounded",
        Avatar(user.avatar, user.name),
        Div(
            P(:class => "font-bold", user.name),
            P(:class => "text-sm text-gray-500", user.email)
        )
    )
end

function UserList(users)
    Div(:class => "space-y-2",
        [UserCard(u) for u in users]...
    )
end"""),
                Div(:class => "bg-warm-50 dark:bg-warm-900/20 border border-warm-200 dark:border-warm-700 rounded p-4 mt-4",
                    P(:class => "text-warm-800 dark:text-warm-300 text-sm",
                        Strong("Julia power: "),
                        "Use comprehensions, map, filter — all your favorite Julia patterns work naturally."
                    )
                )
            ),

            Hr(:class => "border-warm-200 dark:border-warm-900"),

            # When to Use What
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "When to Use What"
                ),
                P(:class => "text-warm-800 dark:text-warm-200 mb-4",
                    "Therapy.jl provides four ways to define UI logic. Choosing the right one matters:"
                ),

                # Regular Functions
                Div(:class => "mb-6",
                    H3(:class => "text-lg font-semibold font-serif text-warm-800 dark:text-warm-50 mb-2",
                        "Regular Functions"
                    ),
                    P(:class => "text-warm-800 dark:text-warm-200 mb-3",
                        "The simplest approach. Use when your UI is static or only needs server-rendered content."
                    ),
                    CodeBlock("""# Just a function — returns VNodes, renders to HTML on the server
function UserCard(name, email)
    Div(:class => "p-4 border rounded",
        H3(name),
        P(email)
    )
end"""),
                    Div(:class => "bg-warm-100 dark:bg-warm-800 rounded p-3 mt-2 text-sm text-warm-600 dark:text-warm-400",
                        "Use for: layouts, static pages, content that doesn't change after load."
                    )
                ),

                # component()
                Div(:class => "mb-6",
                    H3(:class => "text-lg font-semibold font-serif text-warm-800 dark:text-warm-50 mb-2",
                        "component()"
                    ),
                    P(:class => "text-warm-800 dark:text-warm-200 mb-3",
                        "A named, reusable component with props. Still server-rendered only."
                    ),
                    CodeBlock("""# Named component with typed props
Greeting = component(:Greeting) do props
    name = get_prop(props, :name, "World")
    P("Hello, ", name, "!")
end

# Usage
Greeting(:name => "Julia")"""),
                    Div(:class => "bg-warm-100 dark:bg-warm-800 rounded p-3 mt-2 text-sm text-warm-600 dark:text-warm-400",
                        "Use for: reusable UI patterns with configurable props. No client-side interactivity."
                    )
                ),

                # island()
                Div(:class => "mb-6",
                    H3(:class => "text-lg font-semibold font-serif text-warm-800 dark:text-warm-50 mb-2",
                        "island()"
                    ),
                    P(:class => "text-warm-800 dark:text-warm-200 mb-3",
                        "Interactive component compiled to WebAssembly. Runs in the browser."
                    ),
                    CodeBlock("""# Compiled to Wasm — signals and handlers run client-side
Counter = island(:Counter) do
    count, set_count = create_signal(0)
    Div(
        Button(:on_click => () -> set_count(count() + 1), "+"),
        Span(count)
    )
end"""),
                    Div(:class => "bg-warm-50 dark:bg-warm-900/20 border border-warm-200 dark:border-warm-700 rounded p-3 mt-2 text-sm text-warm-800 dark:text-warm-300",
                        "Use for: anything that needs to respond to user interaction — buttons, toggles, forms, games."
                    )
                ),

                # @server
                Div(:class => "mb-6",
                    H3(:class => "text-lg font-semibold font-serif text-warm-800 dark:text-warm-50 mb-2",
                        "@server"
                    ),
                    P(:class => "text-warm-800 dark:text-warm-200 mb-3",
                        "Server function callable from the client via WebSocket RPC."
                    ),
                    CodeBlock("""# Runs on the server, callable from client code
@server function get_user(id::Int)
    DB.query(\"SELECT * FROM users WHERE id = ?\", id)
end"""),
                    Div(:class => "bg-warm-100 dark:bg-warm-800 rounded p-3 mt-2 text-sm text-warm-600 dark:text-warm-400",
                        "Use for: database access, file I/O, authentication — anything that must run on the server."
                    )
                ),

                # Decision flowchart
                Div(:class => "bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 rounded p-4 mt-4",
                    P(:class => "text-amber-800 dark:text-amber-200 text-sm",
                        Strong("Quick guide: "),
                        "Does it need to respond to clicks/input? Use ",
                        Code(:class => "bg-amber-100 dark:bg-amber-800 px-1 rounded", "island()"),
                        ". Does it need server data? Use ",
                        Code(:class => "bg-amber-100 dark:bg-amber-800 px-1 rounded", "@server"),
                        ". Otherwise, a regular function is fine."
                    )
                )
            ),

            Hr(:class => "border-warm-200 dark:border-warm-900"),

            # Conditional Rendering
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Conditional Rendering"
                ),
                P(:class => "text-warm-800 dark:text-warm-200 mb-4",
                    "Use Julia's ternary operator or if/else:"
                ),
                CodeBlock("""# Ternary
Div(
    is_logged_in ? UserMenu(user) : LoginButton()
)

# If/else in a function
function Status(online)
    if online
        Span(:class => "text-green-500", "Online")
    else
        Span(:class => "text-gray-400", "Offline")
    end
end

# Show component (reactive)
Show(is_visible) do
    Modal("Hello!")
end""")
            ),

            Hr(:class => "border-warm-200 dark:border-warm-900"),

            # Summary
            Div(:class => "bg-warm-100 dark:bg-warm-800 rounded-lg p-6",
                H3(:class => "text-lg font-semibold font-serif text-warm-800 dark:text-warm-50 mb-3",
                    "Summary"
                ),
                Ul(:class => "space-y-2 text-warm-800 dark:text-warm-200 text-sm",
                    Li(Strong("Components"), " are Julia functions returning VNodes"),
                    Li(Strong("Elements"), " are capitalized: Div, Span, Button, etc."),
                    Li(Strong("Attributes"), " use :name => value syntax"),
                    Li(Strong("Composition"), " works naturally with Julia's features")
                )
            ),

            # Next
            Div(:class => "mt-8",
                A(:href => "./learn/adding-interactivity/",
                  :class => "text-accent-700 dark:text-accent-400 font-medium",
                    "Next: Adding Interactivity →"
                )
            )
        );
        current_path="learn/describing-ui/"
    )
end

DescribingUI
