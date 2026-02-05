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
                "Components in Therapy.jl"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "In Therapy.jl, components are simply Julia functions that return ",
                Code(:class => "text-accent-700 dark:text-accent-400", "VNode"),
                " elements. There's no special syntax or class inheritance—just functions. ",
                "This makes components easy to write, test, and compose."
            ),
            Div(:class => "bg-warm-50 dark:bg-warm-900 rounded-lg p-8 font-mono text-sm text-warm-800 dark:text-warm-300 text-center",
                Pre(:class => "inline-block text-left", """      Julia Function
            ↓
    Props (named arguments)
            ↓
       VNode Tree
            ↓
    HTML / Interactive Island""")
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "This section covers the component system from basics to advanced patterns."
            )
        ),

        # Chapter Links
        Section(:class => "py-12 bg-warm-100 dark:bg-warm-900 rounded-lg border border-warm-200 dark:border-warm-700 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-8",
                "In This Section"
            ),
            Div(:class => "grid md:grid-cols-2 gap-6",
                ChapterCard("Basics", "./basics",
                    "Function components, the component() wrapper, and naming conventions for reusable UI building blocks.",
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
                    Code(:class => "language-julia", """# Simple function component
function Greeting(; name="World")
    P("Hello, ", name, "!")
end

# Using the component() wrapper for registration
Card = component(:Card) do props
    title = get_prop(props, :title, "Untitled")
    Div(:class => "border rounded p-4",
        H2(title),
        get_children(props)  # Render children
    )
end

# Conditional rendering with Show
Show(is_visible) do
    Div("I appear when is_visible() is true")
end

# List rendering with For
For(items) do item
    Li(item.name)
end

# Fragment for multiple elements
BookLayout(
    H1("Title"),
    P("First paragraph"),
    P("Second paragraph")
)""")
                )
            )
        ),

        # Key Concepts
        Section(:class => "py-12 bg-warm-100 dark:bg-warm-900 rounded-lg border border-warm-200 dark:border-warm-700 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Key Concepts"
            ),
            Dl(:class => "space-y-6",
                ConceptItem("Function Components",
                    "Components are just functions. They receive props as keyword arguments and return VNode trees. " *
                    "No classes, no inheritance, no decorators—just Julia functions."
                ),
                ConceptItem("Props",
                    "Data flows down through props. Components declare what they need as keyword arguments, " *
                    "and callers provide values. Props can have defaults and be typed."
                ),
                ConceptItem("Children",
                    "Components can accept child content to render. This enables composition patterns like " *
                    "cards, modals, and layouts that wrap arbitrary content."
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
