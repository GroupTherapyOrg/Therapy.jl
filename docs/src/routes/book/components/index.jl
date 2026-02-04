# Components - Part 3 of the Therapy.jl Book
#
# Building reusable UI components with props, children, and control flow.

function ComponentsIndex()
    BookLayout("/book/components/",
        # Header
        Div(:class => "py-8 border-b border-neutral-300 dark:border-neutral-800",
            Span(:class => "text-sm text-emerald-700 dark:text-emerald-400 font-medium", "Part 3"),
            H1(:class => "text-4xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mt-2 mb-4",
                "Components"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 max-w-3xl",
                "Learn to build reusable UI components with props, children, and conditional rendering. ",
                "Components are the building blocks of Therapy.jl applications."
            )
        ),

        # Introduction
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Components in Therapy.jl"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "In Therapy.jl, components are simply Julia functions that return ",
                Code(:class => "text-emerald-700 dark:text-emerald-400", "VNode"),
                " elements. There's no special syntax or class inheritance—just functions. ",
                "This makes components easy to write, test, and compose."
            ),
            Div(:class => "bg-neutral-100 dark:bg-neutral-800 rounded-lg p-8 font-mono text-sm text-neutral-700 dark:text-neutral-300 text-center",
                Pre(:class => "inline-block text-left", """      Julia Function
            ↓
    Props (named arguments)
            ↓
       VNode Tree
            ↓
    HTML / Interactive Island""")
            ),
            P(:class => "text-neutral-600 dark:text-neutral-400 mt-6",
                "This section covers the component system from basics to advanced patterns."
            )
        ),

        # Chapter Links
        Section(:class => "py-12 bg-neutral-50 dark:bg-neutral-900 rounded-lg border border-neutral-300 dark:border-neutral-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-8",
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
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Quick Overview"
            ),
            Div(:class => "bg-neutral-900 dark:bg-neutral-950 rounded border border-neutral-800 p-6 overflow-x-auto",
                Pre(:class => "text-sm text-neutral-100",
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
        Section(:class => "py-12 bg-neutral-50 dark:bg-neutral-900 rounded-lg border border-neutral-300 dark:border-neutral-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
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
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "The Therapy.jl Component Philosophy"
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-neutral-800 dark:text-neutral-200 mb-4",
                        "Class-Based (Other Frameworks)"
                    ),
                    Ul(:class => "space-y-2 text-neutral-600 dark:text-neutral-400",
                        Li("Components extend base class"),
                        Li("Lifecycle methods (mount, update, unmount)"),
                        Li("State stored in class instance"),
                        Li("Requires understanding OOP patterns")
                    )
                ),
                Div(:class => "bg-emerald-50 dark:bg-emerald-950/30 rounded-lg p-6 border border-emerald-200 dark:border-emerald-900",
                    H3(:class => "text-lg font-serif font-semibold text-emerald-800 dark:text-emerald-300 mb-4",
                        "Functions (Therapy.jl)"
                    ),
                    Ul(:class => "space-y-2 text-emerald-700 dark:text-emerald-400",
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
    A(:href => href, :class => "block p-6 bg-white dark:bg-neutral-800 rounded-lg border border-neutral-200 dark:border-neutral-700 hover:border-emerald-500 dark:hover:border-emerald-600 transition-colors group",
        Div(:class => "flex items-start gap-4",
            Div(:class => "flex-shrink-0 w-12 h-12 bg-emerald-100 dark:bg-emerald-900/50 rounded-lg flex items-center justify-center group-hover:bg-emerald-200 dark:group-hover:bg-emerald-900 transition-colors",
                Svg(:class => "w-6 h-6 text-emerald-700 dark:text-emerald-400", :fill => "none", :viewBox => "0 0 24 24", :stroke_width => "1.5", :stroke => "currentColor",
                    Path(:stroke_linecap => "round", :stroke_linejoin => "round", :d => icon_path)
                )
            ),
            Div(
                H3(:class => "text-lg font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-2 group-hover:text-emerald-700 dark:group-hover:text-emerald-400 transition-colors", title),
                P(:class => "text-neutral-600 dark:text-neutral-400 text-sm", description)
            )
        )
    )
end

function ConceptItem(term, definition)
    Div(
        Dt(:class => "font-serif font-semibold text-neutral-900 dark:text-neutral-100", term),
        Dd(:class => "mt-1 text-neutral-600 dark:text-neutral-400", definition)
    )
end

# Export the page component
ComponentsIndex
