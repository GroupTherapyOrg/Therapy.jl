# Components - Part 3 of the Therapy.jl Book
#
# Building reusable UI components with props, children, and control flow.

function ComponentsIndex()
    BookLayout("/book/components/",
        # Header
        Div(:class => "py-8 border-b border-warm-200 dark:border-warm-700",
            Span(:class => "text-sm text-accent-700 dark:text-accent-400 font-medium", "Part 3"),
            H1(:class => "text-4xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-2 mb-4",
                "Components"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 max-w-3xl",
                "Learn to build reusable UI components with props, children, and conditional rendering. ",
                "Components are the building blocks of Therapy.jl applications."
            )
        ),

        # Introduction
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "The Three-Tier Component Model"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Therapy.jl has three kinds of callable units. Understanding these three tiers is the key to building applications."
            ),
            Div(:class => "overflow-x-auto mb-8",
                Table(:class => "w-full text-sm",
                    Thead(
                        Tr(:class => "border-b border-warm-300 dark:border-warm-700",
                            Th(:class => "text-left py-3 px-4 font-serif font-semibold text-warm-800 dark:text-warm-50", "Tier"),
                            Th(:class => "text-left py-3 px-4 font-serif font-semibold text-warm-800 dark:text-warm-50", "Syntax"),
                            Th(:class => "text-left py-3 px-4 font-serif font-semibold text-warm-800 dark:text-warm-50", "Runs Where"),
                            Th(:class => "text-left py-3 px-4 font-serif font-semibold text-warm-800 dark:text-warm-50", "Returns")
                        )
                    ),
                    Tbody(:class => "text-warm-600 dark:text-warm-400",
                        Tr(:class => "border-b border-warm-200 dark:border-warm-700",
                            Td(:class => "py-3 px-4 font-semibold text-warm-800 dark:text-warm-300", "Static"),
                            Td(:class => "py-3 px-4", Code(:class => "text-accent-700 dark:text-accent-400", "function Name(; kwargs...)")),
                            Td(:class => "py-3 px-4", "Server (SSR only)"),
                            Td(:class => "py-3 px-4", "VNodes")
                        ),
                        Tr(:class => "border-b border-warm-200 dark:border-warm-700",
                            Td(:class => "py-3 px-4 font-semibold text-warm-800 dark:text-warm-300", "Interactive"),
                            Td(:class => "py-3 px-4", Code(:class => "text-accent-700 dark:text-accent-400", "@island function Name(; kwargs...)")),
                            Td(:class => "py-3 px-4", "Server + Client (Wasm)"),
                            Td(:class => "py-3 px-4", "VNodes")
                        ),
                        Tr(
                            Td(:class => "py-3 px-4 font-semibold text-warm-800 dark:text-warm-300", "Server RPC"),
                            Td(:class => "py-3 px-4", Code(:class => "text-accent-700 dark:text-accent-400", "@server function name(args...)")),
                            Td(:class => "py-3 px-4", "Server only, called from client"),
                            Td(:class => "py-3 px-4", "Data (JSON)")
                        )
                    )
                )
            ),
            Div(:class => "bg-warm-800 dark:bg-warm-950 rounded border border-warm-900 p-6 overflow-x-auto mb-6",
                Pre(:class => "text-sm text-warm-50",
                    Code(:class => "language-julia", """# Tier 1: Static component — renders to HTML on the server
function UserCard(; name, email)
    Div(:class => "card",
        H2(name),
        P(email)
    )
end

# Tier 2: Interactive island — compiles to WebAssembly, hydrates on client
@island function Counter(; initial=0)
    count, set_count = create_signal(initial)
    Div(
        Button(:on_click => () -> set_count(count() - 1), "-"),
        Span(count),
        Button(:on_click => () -> set_count(count() + 1), "+")
    )
end

# Tier 3: Server RPC — runs on server, callable from client via WebSocket
@server function get_user(id::Int)
    DB.query("SELECT * FROM users WHERE id = ?", id)
end""")
                )
            ),
            P(:class => "text-warm-600 dark:text-warm-400",
                "This section covers the component system from basics to advanced patterns."
            )
        ),

        # Calling Conventions
        Section(:class => "py-12 bg-warm-50 dark:bg-warm-900/30 rounded-lg border border-warm-200 dark:border-warm-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Two Calling Conventions"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Therapy.jl uses two different syntaxes depending on what you're calling:"
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-300 mb-4",
                        "HTML Elements: Pair Syntax"
                    ),
                    Div(:class => "bg-warm-800 dark:bg-warm-950 rounded border border-warm-900 p-4 overflow-x-auto",
                        Pre(:class => "text-sm text-warm-50",
                            Code(:class => "language-julia", """# Attributes use :key => value pairs
Div(:class => "container",
    :id => "main",
    H1("Title"),
    Button(:on_click => handler, "Go")
)""")
                        )
                    ),
                    P(:class => "text-warm-600 dark:text-warm-400 text-sm mt-3",
                        "Built-in elements (Div, Span, Button, etc.) accept ", Code("Pair"), " arguments for HTML attributes."
                    )
                ),
                Div(:class => "bg-warm-50 dark:bg-warm-900/30 rounded-lg p-6 border border-warm-200 dark:border-warm-800",
                    H3(:class => "text-lg font-serif font-semibold text-accent-800 dark:text-accent-300 mb-4",
                        "Your Components: Kwargs"
                    ),
                    Div(:class => "bg-warm-800 dark:bg-warm-950 rounded border border-warm-900 p-4 overflow-x-auto",
                        Pre(:class => "text-sm text-warm-50",
                            Code(:class => "language-julia", """# Props use keyword arguments
UserCard(name="Alice", role="Admin")

Card(title="Welcome",
    P("Content here"),
    P("More content")
)""")
                        )
                    ),
                    P(:class => "text-accent-700 dark:text-accent-400 text-sm mt-3",
                        "Your functions use Julia keyword arguments — natural and type-safe."
                    )
                )
            )
        ),

        # Naming Conventions
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Naming Conventions"
            ),
            Div(:class => "overflow-x-auto",
                Table(:class => "w-full text-sm",
                    Thead(
                        Tr(:class => "border-b border-warm-300 dark:border-warm-700",
                            Th(:class => "text-left py-3 px-4 font-serif font-semibold text-warm-800 dark:text-warm-50", "Style"),
                            Th(:class => "text-left py-3 px-4 font-serif font-semibold text-warm-800 dark:text-warm-50", "Meaning"),
                            Th(:class => "text-left py-3 px-4 font-serif font-semibold text-warm-800 dark:text-warm-50", "Examples")
                        )
                    ),
                    Tbody(:class => "text-warm-600 dark:text-warm-400",
                        Tr(:class => "border-b border-warm-200 dark:border-warm-700",
                            Td(:class => "py-3 px-4 font-semibold text-warm-800 dark:text-warm-300", "PascalCase"),
                            Td(:class => "py-3 px-4", "Returns VNodes (markup)"),
                            Td(:class => "py-3 px-4", Code(:class => "text-accent-700 dark:text-accent-400", "UserCard, Counter, BookLayout"))
                        ),
                        Tr(:class => "border-b border-warm-200 dark:border-warm-700",
                            Td(:class => "py-3 px-4 font-semibold text-warm-800 dark:text-warm-300", "snake_case"),
                            Td(:class => "py-3 px-4", "Returns data (logic/utilities)"),
                            Td(:class => "py-3 px-4", Code(:class => "text-accent-700 dark:text-accent-400", "create_signal, format_date, get_user"))
                        ),
                        Tr(
                            Td(:class => "py-3 px-4 font-semibold text-warm-800 dark:text-warm-300", "No camelCase"),
                            Td(:class => "py-3 px-4", "Never used in Therapy.jl"),
                            Td(:class => "py-3 px-4 line-through text-warm-400", "createSignal, getUserData")
                        )
                    )
                )
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-4",
                "This convention makes intent clear at a glance: PascalCase means \"this returns UI\", ",
                "snake_case means \"this returns data\"."
            )
        ),

        # Chapter Links
        Section(:class => "py-12 bg-warm-100 dark:bg-warm-900 rounded-lg border border-warm-200 dark:border-warm-700 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-8",
                "In This Section"
            ),
            Div(:class => "grid md:grid-cols-2 gap-6",
                ChapterCard("Basics", "./basics",
                    "Function components, naming conventions, and patterns for reusable UI building blocks.",
                    "M4 5a1 1 0 011-1h14a1 1 0 011 1v2a1 1 0 01-1 1H5a1 1 0 01-1-1V5zM4 13a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H5a1 1 0 01-1-1v-6zM16 13a1 1 0 011-1h2a1 1 0 011 1v6a1 1 0 01-1 1h-2a1 1 0 01-1-1v-6z"
                ),
                ChapterCard("Props", "./props",
                    "Pass data to components with typed properties, defaults, and destructuring patterns.",
                    "M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v12a4 4 0 01-4 4zm0 0h12a2 2 0 002-2v-4a2 2 0 00-2-2h-2.343M11 7.343l1.657-1.657a2 2 0 012.828 0l2.829 2.829a2 2 0 010 2.828l-8.486 8.485M7 17h.01"
                ),
                ChapterCard("Children", "./children",
                    "Compose components with child content using slots, fragments, and the children pattern.",
                    "M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"
                ),
                ChapterCard("Control Flow", "./control-flow",
                    "Conditional rendering with Show and efficient list rendering with For and keyed iteration.",
                    "M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
                )
            )
        ),

        # Quick Overview Code
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Quick Overview"
            ),
            Div(:class => "bg-warm-800 dark:bg-warm-950 rounded border border-warm-900 p-6 overflow-x-auto",
                Pre(:class => "text-sm text-warm-50",
                    Code(:class => "language-julia", """# Static component (Tier 1) — server-rendered HTML
function Greeting(; name="World")
    P("Hello, ", name, "!")
end

# Interactive island (Tier 2) — compiled to WebAssembly
@island function Counter(; initial=0)
    count, set_count = create_signal(initial)
    Div(
        Button(:on_click => () -> set_count(count() - 1), "-"),
        Span(count),
        Button(:on_click => () -> set_count(count() + 1), "+")
    )
end

# Server RPC (Tier 3) — callable from client
@server function get_todos(user_id::Int)
    DB.query("SELECT * FROM todos WHERE user_id = ?", user_id)
end

# Calling conventions:
Div(:class => "card")         # HTML elements: Pair syntax
Greeting(name="Julia")        # Your components: kwargs""")
                )
            )
        ),

        # Key Concepts
        Section(:class => "py-12 bg-warm-100 dark:bg-warm-900 rounded-lg border border-warm-200 dark:border-warm-700 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Key Concepts"
            ),
            Dl(:class => "space-y-6",
                ConceptItem("Three Tiers",
                    "Static functions for server-rendered markup, @island for interactive components compiled to WebAssembly, " *
                    "and @server for RPC functions called from the client."
                ),
                ConceptItem("Function Components",
                    "Components are just functions. They receive props as keyword arguments and return VNode trees. " *
                    "No classes, no inheritance, no decorators—just Julia functions."
                ),
                ConceptItem("Two Calling Conventions",
                    "HTML elements use Pair syntax (Div(:class => \"foo\")), your components use keyword arguments " *
                    "(UserCard(name=\"Alice\")). Both return VNodes."
                ),
                ConceptItem("Props & Children",
                    "Data flows down through keyword arguments. Components can accept child content via children... varargs. " *
                    "Props can have defaults, type annotations, and include signals for reactivity."
                ),
                ConceptItem("Control Flow",
                    "Show for conditional rendering and For for lists. Both integrate with signals for " *
                    "fine-grained reactivity—only the affected elements update."
                )
            )
        ),

        # Component Philosophy
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "The Therapy.jl Component Philosophy"
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-300 mb-4",
                        "Class-Based (Other Frameworks)"
                    ),
                    Ul(:class => "space-y-2 text-warm-600 dark:text-warm-400",
                        Li("Components extend base class"),
                        Li("Lifecycle methods (mount, update, unmount)"),
                        Li("State stored in class instance"),
                        Li("Requires understanding OOP patterns")
                    )
                ),
                Div(:class => "bg-warm-50 dark:bg-warm-900/30 rounded-lg p-6 border border-warm-200 dark:border-warm-800",
                    H3(:class => "text-lg font-serif font-semibold text-accent-800 dark:text-accent-300 mb-4",
                        "Functions (Therapy.jl)"
                    ),
                    Ul(:class => "space-y-2 text-accent-700 dark:text-accent-400",
                        Li("Components are just functions"),
                        Li("Lifecycle via on_mount, on_cleanup"),
                        Li("State via signals (closures)"),
                        Li("Familiar Julia patterns")
                    )
                )
            )
        ),

    )
end

function ChapterCard(title, href, description, icon_path)
    A(:href => href, :class => "block p-6 bg-warm-50 dark:bg-warm-900 rounded-lg border border-warm-200 dark:border-warm-800 hover:border-accent-500 dark:hover:border-accent-600 transition-colors group",
        Div(:class => "flex items-start gap-4",
            Div(:class => "flex-shrink-0 w-12 h-12 bg-warm-100 dark:bg-warm-900 rounded-lg flex items-center justify-center group-hover:bg-warm-200 dark:group-hover:bg-warm-700 transition-colors",
                Svg(:class => "w-6 h-6 text-accent-700 dark:text-accent-400", :fill => "none", :viewBox => "0 0 24 24", :stroke_width => "1.5", :stroke => "currentColor",
                    Path(:stroke_linecap => "round", :stroke_linejoin => "round", :d => icon_path)
                )
            ),
            Div(
                H3(:class => "text-lg font-serif font-semibold text-warm-800 dark:text-warm-50 mb-2 group-hover:text-accent-700 dark:group-hover:text-accent-400 transition-colors", title),
                P(:class => "text-warm-600 dark:text-warm-400 text-sm", description)
            )
        )
    )
end

function ConceptItem(term, definition)
    Div(
        Dt(:class => "font-serif font-semibold text-warm-800 dark:text-warm-50", term),
        Dd(:class => "mt-1 text-warm-600 dark:text-warm-400", definition)
    )
end

# Export the page component
ComponentsIndex
