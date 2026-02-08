# Components - Part 3 of the Therapy.jl Book
#
# Building reusable UI components with props, children, and control flow.

import Suite

function _ComponentsChapterCard(title, href, description, icon_path)
    A(:href => href, :class => "block group",
        Suite.Card(class="hover:border-accent-400 dark:hover:border-accent-500 transition-colors h-full",
            Suite.CardHeader(
                Div(:class => "flex items-start gap-4",
                    Div(:class => "flex-shrink-0 w-12 h-12 bg-warm-100 dark:bg-warm-800 rounded-lg flex items-center justify-center group-hover:bg-warm-200 dark:group-hover:bg-warm-700 transition-colors",
                        Svg(:class => "w-6 h-6 text-accent-700 dark:text-accent-400", :fill => "none", :viewBox => "0 0 24 24", :stroke_width => "1.5", :stroke => "currentColor",
                            Path(:stroke_linecap => "round", :stroke_linejoin => "round", :d => icon_path)
                        )
                    ),
                    Div(
                        Suite.CardTitle(:class => "font-serif group-hover:text-accent-700 dark:group-hover:text-accent-400 transition-colors", title),
                        Suite.CardDescription(description)
                    )
                )
            )
        )
    )
end

function ComponentsIndex()
    BookLayout("/book/components/",
        # Header
        Div(:class => "py-8 border-b border-warm-200 dark:border-warm-700",
            Suite.Badge(variant="outline", "Part 3"),
            H1(:class => "text-4xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-2 mb-4",
                "Components"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 max-w-3xl",
                "Learn to build reusable UI components with props, children, and conditional rendering. ",
                "Components are the building blocks of Therapy.jl applications."
            )
        ),

        # Introduction - Three-Tier Component Model
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "The Three-Tier Component Model"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Therapy.jl has three kinds of callable units. Understanding these three tiers is the key to building applications."
            ),
            Div(:class => "overflow-x-auto mb-8",
                Suite.Table(
                    Suite.TableHeader(
                        Suite.TableRow(
                            Suite.TableHead("Tier"),
                            Suite.TableHead("Syntax"),
                            Suite.TableHead("Runs Where"),
                            Suite.TableHead("Returns")
                        )
                    ),
                    Suite.TableBody(
                        Suite.TableRow(
                            Suite.TableCell(:class => "font-semibold", "Static"),
                            Suite.TableCell(Code(:class => "text-accent-700 dark:text-accent-400", "function Name(; kwargs...)")),
                            Suite.TableCell("Server (SSR only)"),
                            Suite.TableCell("VNodes")
                        ),
                        Suite.TableRow(
                            Suite.TableCell(:class => "font-semibold", "Interactive"),
                            Suite.TableCell(Code(:class => "text-accent-700 dark:text-accent-400", "@island function Name(; kwargs...)")),
                            Suite.TableCell("Server + Client (Wasm)"),
                            Suite.TableCell("VNodes")
                        ),
                        Suite.TableRow(
                            Suite.TableCell(:class => "font-semibold", "Server RPC"),
                            Suite.TableCell(Code(:class => "text-accent-700 dark:text-accent-400", "@server function name(args...)")),
                            Suite.TableCell("Server only, called from client"),
                            Suite.TableCell("Data (JSON)")
                        )
                    )
                )
            ),
            Suite.CodeBlock(
                code="""# Tier 1: Static component — renders to HTML on the server
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
end""",
                language="julia"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "This section covers the component system from basics to advanced patterns."
            )
        ),

        Suite.Separator(),

        # Calling Conventions
        Section(:class => "py-12",
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
                    Suite.CodeBlock(
                        code="""# Attributes use :key => value pairs
Div(:class => "container",
    :id => "main",
    H1("Title"),
    Button(:on_click => handler, "Go")
)""",
                        language="julia",
                        show_copy=false
                    ),
                    P(:class => "text-warm-600 dark:text-warm-400 text-sm mt-3",
                        "Built-in elements (Div, Span, Button, etc.) accept ", Code("Pair"), " arguments for HTML attributes."
                    )
                ),
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-accent-800 dark:text-accent-300 mb-4",
                        "Your Components: Kwargs"
                    ),
                    Suite.CodeBlock(
                        code="""# Props use keyword arguments
UserCard(name="Alice", role="Admin")

Card(title="Welcome",
    P("Content here"),
    P("More content")
)""",
                        language="julia",
                        show_copy=false
                    ),
                    P(:class => "text-accent-700 dark:text-accent-400 text-sm mt-3",
                        "Your functions use Julia keyword arguments — natural and type-safe."
                    )
                )
            )
        ),

        Suite.Separator(),

        # Naming Conventions
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Naming Conventions"
            ),
            Div(:class => "overflow-x-auto",
                Suite.Table(
                    Suite.TableHeader(
                        Suite.TableRow(
                            Suite.TableHead("Style"),
                            Suite.TableHead("Meaning"),
                            Suite.TableHead("Examples")
                        )
                    ),
                    Suite.TableBody(
                        Suite.TableRow(
                            Suite.TableCell(:class => "font-semibold", "PascalCase"),
                            Suite.TableCell("Returns VNodes (markup)"),
                            Suite.TableCell(Code(:class => "text-accent-700 dark:text-accent-400", "UserCard, Counter, BookLayout"))
                        ),
                        Suite.TableRow(
                            Suite.TableCell(:class => "font-semibold", "snake_case"),
                            Suite.TableCell("Returns data (logic/utilities)"),
                            Suite.TableCell(Code(:class => "text-accent-700 dark:text-accent-400", "create_signal, format_date, get_user"))
                        ),
                        Suite.TableRow(
                            Suite.TableCell(:class => "font-semibold", "No camelCase"),
                            Suite.TableCell("Never used in Therapy.jl"),
                            Suite.TableCell(Span(:class => "line-through text-warm-400", "createSignal, getUserData"))
                        )
                    )
                )
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-4",
                "This convention makes intent clear at a glance: PascalCase means \"this returns UI\", ",
                "snake_case means \"this returns data\"."
            )
        ),

        Suite.Separator(),

        # Chapter Links
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-8",
                "In This Section"
            ),
            Div(:class => "grid md:grid-cols-2 gap-6",
                _ComponentsChapterCard("Basics", "./basics",
                    "Function components, naming conventions, and patterns for reusable UI building blocks.",
                    "M4 5a1 1 0 011-1h14a1 1 0 011 1v2a1 1 0 01-1 1H5a1 1 0 01-1-1V5zM4 13a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H5a1 1 0 01-1-1v-6zM16 13a1 1 0 011-1h2a1 1 0 011 1v6a1 1 0 01-1 1h-2a1 1 0 01-1-1v-6z"
                ),
                _ComponentsChapterCard("Props", "./props",
                    "Pass data to components with typed properties, defaults, and destructuring patterns.",
                    "M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v12a4 4 0 01-4 4zm0 0h12a2 2 0 002-2v-4a2 2 0 00-2-2h-2.343M11 7.343l1.657-1.657a2 2 0 012.828 0l2.829 2.829a2 2 0 010 2.828l-8.486 8.485M7 17h.01"
                ),
                _ComponentsChapterCard("Children", "./children",
                    "Compose components with child content using slots, fragments, and the children pattern.",
                    "M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"
                ),
                _ComponentsChapterCard("Control Flow", "./control-flow",
                    "Conditional rendering with Show and efficient list rendering with For and keyed iteration.",
                    "M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
                )
            )
        ),

        Suite.Separator(),

        # Quick Overview Code
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Quick Overview"
            ),
            Suite.CodeBlock(
                code="""# Static component (Tier 1) — server-rendered HTML
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
Greeting(name="Julia")        # Your components: kwargs""",
                language="julia"
            )
        ),

        Suite.Separator(),

        # Key Concepts
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Key Concepts"
            ),
            Div(:class => "space-y-4",
                Suite.Alert(
                    Suite.AlertTitle("Three Tiers"),
                    Suite.AlertDescription(
                        "Static functions for server-rendered markup, @island for interactive components compiled to WebAssembly, " *
                        "and @server for RPC functions called from the client."
                    )
                ),
                Suite.Alert(
                    Suite.AlertTitle("Function Components"),
                    Suite.AlertDescription(
                        "Components are just functions. They receive props as keyword arguments and return VNode trees. " *
                        "No classes, no inheritance, no decorators—just Julia functions."
                    )
                ),
                Suite.Alert(
                    Suite.AlertTitle("Two Calling Conventions"),
                    Suite.AlertDescription(
                        "HTML elements use Pair syntax (Div(:class => \"foo\")), your components use keyword arguments " *
                        "(UserCard(name=\"Alice\")). Both return VNodes."
                    )
                ),
                Suite.Alert(
                    Suite.AlertTitle("Props & Children"),
                    Suite.AlertDescription(
                        "Data flows down through keyword arguments. Components can accept child content via children... varargs. " *
                        "Props can have defaults, type annotations, and include signals for reactivity."
                    )
                ),
                Suite.Alert(
                    Suite.AlertTitle("Control Flow"),
                    Suite.AlertDescription(
                        "Show for conditional rendering and For for lists. Both integrate with signals for " *
                        "fine-grained reactivity—only the affected elements update."
                    )
                )
            )
        ),

        Suite.Separator(),

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
                Suite.Card(class="border-accent-200 dark:border-accent-700",
                    Suite.CardContent(class="p-6",
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
            )
        ),

    )
end

# Export the page component
ComponentsIndex
