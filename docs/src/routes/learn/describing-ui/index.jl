# Describing the UI
#
# How to create and compose UI components in Therapy.jl
# Uses Suite.jl components for visual presentation.

import Suite

function DescribingUI()
    TutorialLayout(
        Div(:class => "space-y-8",
            # Header
            Div(:class => "mb-8",
                H1(:class => "text-3xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Describing the UI"
                ),
                P(:class => "text-lg text-warm-800 dark:text-warm-300",
                    "In Therapy.jl, UI is built from components — Julia functions that return elements."
                )
            ),

            # Components are Functions
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Components are Functions"
                ),
                P(:class => "text-warm-800 dark:text-warm-300 mb-4",
                    "A component is just a Julia function that returns a VNode (virtual DOM node):"
                ),
                Suite.CodeBlock(code="""function Greeting(name)
    Div(:class => "p-4 bg-blue-100 rounded",
        H1("Hello, ", name, "!"),
        P("Welcome to Therapy.jl")
    )
end

# Use it
Greeting("Julia")""", language="julia"),
                P(:class => "text-warm-800 dark:text-warm-300 mt-4",
                    "This is similar to React's function components, but it's just regular Julia."
                )
            ),

            Suite.Separator(),

            # Elements
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Elements"
                ),
                P(:class => "text-warm-800 dark:text-warm-300 mb-4",
                    "Therapy.jl provides capitalized element functions that mirror HTML:"
                ),
                Suite.CodeBlock(code="""# Layout
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
Ul(Li("One"), Li("Two"), Li("Three"))""", language="julia"),
                Suite.Alert(
                    Suite.AlertTitle("Why capitalized?"),
                    Suite.AlertDescription(
                        "Like JSX, capitalized names distinguish components from HTML strings. ",
                        Code(:class => "bg-warm-200 dark:bg-warm-900 px-1 rounded", "Div"),
                        " creates an element, ",
                        Code(:class => "bg-warm-200 dark:bg-warm-900 px-1 rounded", "\"div\""),
                        " is just a string."
                    )
                )
            ),

            Suite.Separator(),

            # Attributes
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Attributes"
                ),
                P(:class => "text-warm-800 dark:text-warm-300 mb-4",
                    "Pass attributes as keyword-style pairs using ",
                    Code(:class => "bg-warm-200 dark:bg-warm-900 px-1 rounded", ":name => value"),
                    ":"
                ),
                Suite.CodeBlock(code="""# CSS classes
Div(:class => "flex items-center gap-4", ...)

# IDs and data attributes
Div(:id => "main", Symbol("data-testid") => "container", ...)

# Input attributes
Input(:type => "email", :placeholder => "you@example.com")

# Links
A(:href => "/about", :class => "underline", "About")""", language="julia")
            ),

            Suite.Separator(),

            # Composition
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Composition"
                ),
                P(:class => "text-warm-800 dark:text-warm-300 mb-4",
                    "Build complex UIs by composing smaller components:"
                ),
                Suite.CodeBlock(code="""function Avatar(url, name)
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
end""", language="julia"),
                Suite.Alert(
                    Suite.AlertTitle("Julia power"),
                    Suite.AlertDescription(
                        "Use comprehensions, map, filter — all your favorite Julia patterns work naturally."
                    )
                )
            ),

            Suite.Separator(),

            # When to Use What
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "When to Use What"
                ),
                P(:class => "text-warm-800 dark:text-warm-300 mb-4",
                    "Therapy.jl provides four ways to define UI logic. Choosing the right one matters:"
                ),

                # Regular Functions
                Suite.Card(class="mb-6",
                    Suite.CardHeader(
                        Suite.CardTitle(class="font-serif", "Regular Functions"),
                    ),
                    Suite.CardContent(
                        P(:class => "text-warm-800 dark:text-warm-300 mb-3",
                            "The simplest approach. Use when your UI is static or only needs server-rendered content."
                        ),
                        Suite.CodeBlock(code="""# Just a function — returns VNodes, renders to HTML on the server
function UserCard(name, email)
    Div(:class => "p-4 border rounded",
        H3(name),
        P(email)
    )
end""", language="julia"),
                        P(:class => "text-sm text-warm-600 dark:text-warm-400 mt-2",
                            "Use for: layouts, static pages, content that doesn't change after load."
                        )
                    )
                ),

                # Plain Functions
                Suite.Card(class="mb-6",
                    Suite.CardHeader(
                        Suite.CardTitle(class="font-serif", "Plain Functions"),
                    ),
                    Suite.CardContent(
                        P(:class => "text-warm-800 dark:text-warm-300 mb-3",
                            "A reusable component with keyword arguments. Still server-rendered only."
                        ),
                        Suite.CodeBlock(code="""# Plain function with kwargs
function Greeting(; name="World")
    P("Hello, ", name, "!")
end

# Usage
Greeting(name="Julia")""", language="julia"),
                        P(:class => "text-sm text-warm-600 dark:text-warm-400 mt-2",
                            "Use for: reusable UI patterns with configurable arguments. No client-side interactivity."
                        )
                    )
                ),

                # @island
                Suite.Card(class="mb-6",
                    Suite.CardHeader(
                        Suite.CardTitle(class="font-serif", "@island"),
                    ),
                    Suite.CardContent(
                        P(:class => "text-warm-800 dark:text-warm-300 mb-3",
                            "Interactive component compiled to WebAssembly. Runs in the browser."
                        ),
                        Suite.CodeBlock(code="""# Compiled to Wasm — signals and handlers run client-side
@island function Counter()
    count, set_count = create_signal(0)
    Div(
        Button(:on_click => () -> set_count(count() + 1), "+"),
        Span(count)
    )
end""", language="julia"),
                        P(:class => "text-sm text-warm-800 dark:text-warm-300 mt-2",
                            "Use for: anything that needs to respond to user interaction — buttons, toggles, forms, games."
                        )
                    )
                ),

                # @server
                Suite.Card(class="mb-6",
                    Suite.CardHeader(
                        Suite.CardTitle(class="font-serif", "@server"),
                    ),
                    Suite.CardContent(
                        P(:class => "text-warm-800 dark:text-warm-300 mb-3",
                            "Server function callable from the client via WebSocket RPC."
                        ),
                        Suite.CodeBlock(code="""# Runs on the server, callable from client code
@server function get_user(id::Int)
    DB.query("SELECT * FROM users WHERE id = ?", id)
end""", language="julia"),
                        P(:class => "text-sm text-warm-600 dark:text-warm-400 mt-2",
                            "Use for: database access, file I/O, authentication — anything that must run on the server."
                        )
                    )
                ),

                # Decision flowchart
                Suite.Alert(
                    Suite.AlertTitle("Quick guide"),
                    Suite.AlertDescription(
                        "Does it need to respond to clicks/input? Use ",
                        Code(:class => "bg-warm-200 dark:bg-warm-900 px-1 rounded", "@island"),
                        ". Does it need server data? Use ",
                        Code(:class => "bg-warm-200 dark:bg-warm-900 px-1 rounded", "@server"),
                        ". Otherwise, a regular function is fine."
                    )
                )
            ),

            Suite.Separator(),

            # Conditional Rendering
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Conditional Rendering"
                ),
                P(:class => "text-warm-800 dark:text-warm-300 mb-4",
                    "Use Julia's ternary operator or if/else:"
                ),
                Suite.CodeBlock(code="""# Ternary
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
                        Li(Strong("Components"), " are Julia functions returning VNodes"),
                        Li(Strong("Elements"), " are capitalized: Div, Span, Button, etc."),
                        Li(Strong("Attributes"), " use :name => value syntax"),
                        Li(Strong("Composition"), " works naturally with Julia's features")
                    )
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
