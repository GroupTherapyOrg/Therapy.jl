# Children - Composition and Slots
#
# How to compose components with child content, fragments, and slots.

import Suite

function Children()
    BookLayout("/book/components/children/",
        # Header
        Div(:class => "py-8 border-b border-warm-200 dark:border-warm-700",
            Suite.Badge(variant="outline", "Part 3 · Components"),
            H1(:class => "text-4xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-2 mb-4",
                "Children"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 max-w-3xl",
                "Composition is key to building reusable components. Learn how to pass arbitrary ",
                "content into components using the children pattern, fragments, and slots."
            )
        ),

        # What Are Children?
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "What Are Children?"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Children are the content nested inside a component. Just like HTML elements can ",
                "contain other elements, your components can accept and render arbitrary content."
            ),
            Suite.CodeBlock(
                """# HTML elements have children
Div(
    H1("Title"),      # child 1
    P("Paragraph"),   # child 2
    Button("Click")   # child 3
)

# Your components can too!
Card(
    :title => "Welcome",
    P("This paragraph is a child"),
    P("So is this one"),
    Button("And this button")
)""",
                language="julia"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "Children enable composition: wrapping arbitrary content in reusable containers ",
                "like cards, modals, layouts, and more."
            )
        ),

        Suite.Separator(),

        # The children... Pattern
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "The children... Pattern"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "For plain function components, use Julia's varargs syntax to collect children:"
            ),
            Suite.CodeBlock(
                """# The children... collects all non-keyword arguments
function Card(; title, children...)
    Div(:class => "border rounded-lg shadow p-6",
        H2(:class => "text-xl font-bold mb-4", title),
        Div(:class => "space-y-2",
            children...  # Splat children into the div
        )
    )
end

# Usage - children come after keyword args
Card(title="Features",
    P("Fast"),
    P("Secure"),
    P("Scalable")
)

# Renders:
# <div class="border rounded-lg shadow p-6">
#   <h2 class="text-xl font-bold mb-4">Features</h2>
#   <div class="space-y-2">
#     <p>Fast</p>
#     <p>Secure</p>
#     <p>Scalable</p>
#   </div>
# </div>""",
                language="julia"
            ),
            Suite.Alert(class="mt-8",
                Suite.AlertTitle("Splat Operator"),
                Suite.AlertDescription(
                    "The ... in children... collects remaining arguments into a tuple. " *
                    "Use children... again to expand them when rendering."
                )
            )
        ),

        Suite.Separator(),

        # Children in Complex Components
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Children in Complex Components"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "The same ", Code(:class => "text-accent-700 dark:text-accent-400", "children..."),
                " pattern works for complex components like modals, dialogs, and layouts:"
            ),
            Suite.CodeBlock(
                """function Modal(; title="Modal", children...)
    Div(:class => "fixed inset-0 bg-black/50 flex items-center justify-center",
        Div(:class => "bg-warm-50 rounded-lg p-6 max-w-md",
            H2(:class => "text-xl font-bold mb-4", title),
            Div(:class => "space-y-4",
                children...  # Children from varargs
            ),
            Div(:class => "mt-6 flex justify-end",
                Button(:class => "btn", "Close")
            )
        )
    )
end

# Usage with keyword arguments
Modal(title="Confirm Action",
    P("Are you sure you want to continue?"),
    P("This action cannot be undone.")
)""",
                language="julia"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "The ", Code(:class => "text-accent-700 dark:text-accent-400", ":key => value"),
                " syntax mirrors HTML attribute syntax."
            )
        ),

        Suite.Separator(),

        # Fragment for Multiple Elements
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Fragment for Multiple Elements"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "What if your component needs to return multiple sibling elements without a wrapper? ",
                "Use ", Code(:class => "text-accent-700 dark:text-accent-400", "Fragment"), "."
            ),
            Suite.CodeBlock(
                """# Without Fragment - must use a wrapper
function TableRow(; item)
    Tr(  # Wrapping element required
        Td(item.name),
        Td(item.price)
    )
end

# Fragment groups without adding DOM elements
function UserInfo(; user)
    BookLayout(
        H1(user.name),         # No wrapper <div>
        P(user.bio),           # These render as siblings
        Span(user.location)    # in the parent
    )
end

# Useful in layouts
function PageLayout(; children...)
    BookLayout(
        Header(Nav("...")),    # <header>...
        Main(children...),     # <main>...
        Footer("© 2024")       # <footer>...
    )  # No wrapping element, these are direct children
end""",
                language="julia"
            ),
            Suite.Alert(class="mt-8",
                Suite.AlertTitle("Why Fragment?"),
                Suite.AlertDescription(
                    "Sometimes a wrapper element breaks CSS layouts (flexbox, grid) or semantic HTML. " *
                    "Fragment renders children directly without adding DOM nodes."
                )
            )
        ),

        Suite.Separator(),

        # Conditional Children
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Conditional Children"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Children can be conditionally included. Use Julia's standard conditionals."
            ),
            Suite.CodeBlock(
                """function Alert(; type, message, dismissible=false)
    Div(:class => "alert alert-\$type",
        Span(message),

        # Conditional child
        dismissible ? Button(:class => "close", "×") : nothing
    )
end

# nothing renders as empty - no DOM node
Alert(type="info", message="FYI", dismissible=false)
# <div class="alert alert-info"><span>FYI</span></div>

Alert(type="warning", message="Watch out!", dismissible=true)
# <div class="alert alert-warning"><span>Watch out!</span><button class="close">×</button></div>

# Multiple conditional children
function UserStatus(; user)
    Div(:class => "user-status",
        Span(user.name),
        user.verified ? Span(:class => "badge", "✓") : nothing,
        user.premium ? Span(:class => "premium", "⭐") : nothing,
        user.online ? Span(:class => "online", "●") : nothing
    )
end""",
                language="julia"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                Code(:class => "text-accent-700 dark:text-accent-400", "nothing"),
                " is skipped during rendering—it produces no output."
            )
        ),

        Suite.Separator(),

        # Named Slots Pattern
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Named Slots Pattern"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Sometimes you need multiple content areas. Pass different content as separate props."
            ),
            Suite.CodeBlock(
                """# Multiple content areas via props
function PageLayout(; header, sidebar, children...)
    Div(:class => "min-h-screen",
        # Header slot
        Header(:class => "h-16 border-b", header),

        Div(:class => "flex",
            # Sidebar slot
            Aside(:class => "w-64 border-r", sidebar),

            # Main content (default children)
            Main(:class => "flex-1 p-6", children...)
        )
    )
end

# Usage - pass VNodes to named props
PageLayout(
    header = Nav(A("Home"), A("About"), A("Contact")),
    sidebar = BookLayout(
        H3("Navigation"),
        Ul(Li("Dashboard"), Li("Settings"))
    ),
    # Default children go to Main
    H1("Welcome"),
    P("Main content here...")
)

# Another example: Dialog with footer slot
function Dialog(; title, footer, children...)
    Div(:class => "dialog",
        H2(:class => "dialog-title", title),
        Div(:class => "dialog-body", children...),
        Div(:class => "dialog-footer", footer)
    )
end

Dialog(
    title = "Confirm",
    footer = BookLayout(Button("Cancel"), Button("OK")),
    P("Are you sure?")
)""",
                language="julia"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "This pattern is similar to named slots in Vue or render props in React."
            )
        ),

        Suite.Separator(),

        # Render Props Pattern
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Render Props Pattern"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "For dynamic children that need data from the parent component, pass a function instead of content."
            ),
            Suite.CodeBlock(
                """# The parent provides data to the render function
function MouseTracker(; render)
    x, set_x = create_signal(0)
    y, set_y = create_signal(0)

    Div(
        :on_mousemove => (e) -> begin
            set_x(e.clientX)
            set_y(e.clientY)
        end,
        :class => "h-64 bg-gray-100",
        # Call render with the tracked position
        render(x, y)
    )
end

# Usage - child decides how to display the data
MouseTracker(
    render = (x, y) -> P("Mouse: (", x, ", ", y, ")")
)

MouseTracker(
    render = (x, y) -> Div(
        :style => "position:absolute;left:\$(x())px;top:\$(y())px",
        "🎯"
    )
)

# List rendering is similar
function FetchData(; url, render)
    data, set_data = create_signal(nothing)
    loading, set_loading = create_signal(true)

    # ... fetch logic ...

    loading() ? P("Loading...") : render(data())
end

FetchData(
    url = "/api/users",
    render = (users) -> Ul(For(users) do u; Li(u.name) end)
)""",
                language="julia"
            ),
            Suite.Alert(class="mt-8",
                Suite.AlertTitle("When to Use Render Props"),
                Suite.AlertDescription(
                    "Render props are powerful for sharing stateful logic without prescribing UI. " *
                    "Use them when different consumers need different presentations of the same data."
                )
            )
        ),

        # Key Takeaways
        Suite.Alert(class="mt-12",
            Suite.AlertTitle("Key Takeaways"),
            Suite.AlertDescription(
                Ul(:class => "space-y-2 list-disc pl-5 mt-2",
                    Li(Strong("children... collects content"), " — use varargs to accept arbitrary nested elements"),
                    Li(Strong("children... works everywhere"), " — same pattern for simple and complex components"),
                    Li(Strong("Fragment groups without wrapping"), " — render multiple siblings with no extra DOM"),
                    Li(Strong("nothing renders as empty"), " — conditionally omit content with ternary operators"),
                    Li(Strong("Named slots via props"), " — pass VNodes to named props for multiple content areas"),
                    Li(Strong("Render props for dynamic children"), " — pass functions when children need parent data")
                )
            )
        ),

    )
end

# Export the page component
Children
