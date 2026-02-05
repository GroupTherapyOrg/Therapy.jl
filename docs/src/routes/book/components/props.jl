# Props - Passing Data to Components
#
# How to pass data to components using props, defaults, and types.

function PropsPage()
    BookLayout("/book/components/props/",
        # Header
        Div(:class => "py-8 border-b border-warm-200 dark:border-warm-900",
            Span(:class => "text-sm text-accent-700 dark:text-accent-400 font-medium", "Part 3 · Components"),
            H1(:class => "text-4xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-2 mb-4",
                "Props"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 max-w-3xl",
                "Props (properties) are how data flows into components. They're the interface ",
                "between a component and its parent—the inputs that configure what the component displays."
            )
        ),

        # What Are Props?
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "What Are Props?"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 mb-6",
                "Props are values passed to a component from its parent. In Therapy.jl, there are ",
                "two main ways to handle props: keyword arguments for plain functions, and the ",
                Code(:class => "text-accent-700 dark:text-accent-400", "get_prop()"),
                " helper for ", Code(:class => "text-accent-700 dark:text-accent-400", "component()"),
                " wrapped components."
            ),
            CodeBlock("""# Props via keyword arguments (plain functions)
function Greeting(; name, greeting="Hello")
    P(greeting, ", ", name, "!")
end

# Usage
Greeting(name="Julia")              # "Hello, Julia!"
Greeting(name="World", greeting="Hi")  # "Hi, World!"

# Props via get_prop (component wrapper)
UserCard = component(:UserCard) do props
    name = get_prop(props, :name)
    role = get_prop(props, :role, "Guest")  # Default value

    Div(:class => "card",
        H3(name),
        P(:class => "text-gray-500", role)
    )
end

# Usage
UserCard(:name => "Alice", :role => "Admin")
UserCard(:name => "Bob")  # role defaults to "Guest" """),
            InfoBox("Data Flows Down",
                "Props flow from parent to child. A component receives props from above " *
                "and uses them to render. This one-way data flow makes applications easier to reason about."
            )
        ),

        # Props with Defaults
        Section(:class => "py-12 bg-warm-100 dark:bg-warm-800 rounded-lg border border-warm-200 dark:border-warm-900 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Props with Defaults"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 mb-6",
                "Default values make props optional. If the parent doesn't provide a value, ",
                "the default is used."
            ),
            CodeBlock("""# Keyword argument defaults
function Button(;
    label,
    variant = "primary",    # Default: "primary"
    size = "md",            # Default: "md"
    disabled = false        # Default: false
)
    class = "btn btn-\$variant btn-\$size"
    Button(:class => class, :disabled => disabled, label)
end

# All defaults
Button(label="Click")  # variant=primary, size=md, disabled=false

# Override some
Button(label="Submit", variant="success", size="lg")

# Override all
Button(label="Cancel", variant="ghost", size="sm", disabled=true)"""),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "With ", Code(:class => "text-accent-700 dark:text-accent-400", "get_prop()"),
                ", provide the default as the third argument:"
            ),
            CodeBlock("""Alert = component(:Alert) do props
    message = get_prop(props, :message)
    type = get_prop(props, :type, "info")      # Default "info"
    dismissible = get_prop(props, :dismissible, true)  # Default true

    # ...
end""")
        ),

        # Type Annotations
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Type Annotations"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 mb-6",
                "Julia's type system can enforce prop types at compile time or runtime. ",
                "This catches bugs early and documents your component's interface."
            ),
            CodeBlock("""# Type-annotated props
function UserProfile(;
    name::String,
    age::Int,
    email::Union{String, Nothing} = nothing,
    verified::Bool = false
)
    Div(
        H2(name),
        P("Age: ", string(age)),
        email !== nothing ? P("Email: ", email) : nothing,
        verified ? Span("✓ Verified") : nothing
    )
end

# Correct usage
UserProfile(name="Alice", age=30, email="alice@example.com")

# Type error at call site
UserProfile(name="Bob", age="thirty")  # MethodError!"""),
            Div(:class => "mt-6 grid md:grid-cols-2 gap-4",
                FeatureBox("Required Props",
                    "Props without defaults must be provided. The caller gets a clear error if they're missing."
                ),
                FeatureBox("Optional Props",
                    "Use Union{T, Nothing} or provide a default to make props optional."
                )
            )
        ),

        # Destructuring Patterns
        Section(:class => "py-12 bg-warm-100 dark:bg-warm-800 rounded-lg border border-warm-200 dark:border-warm-900 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Destructuring Patterns"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 mb-6",
                "For components with many props, you can pass structured data and destructure inside the component."
            ),
            CodeBlock("""# Props as a struct
struct User
    name::String
    email::String
    avatar_url::String
end

function UserAvatar(; user::User, size = 40)
    Img(
        :src => user.avatar_url,
        :alt => user.name,
        :width => size,
        :height => size,
        :class => "rounded-full"
    )
end

# Usage
alice = User("Alice", "alice@example.com", "https://...")
UserAvatar(user=alice)
UserAvatar(user=alice, size=80)

# Props as NamedTuple (inline)
function ProductCard(; product)
    Div(:class => "card",
        Img(:src => product.image),
        H3(product.name),
        P(:class => "price", "\$", string(product.price))
    )
end

ProductCard(product=(name="Widget", price=9.99, image="widget.jpg"))"""),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "This pattern is useful when the same data shape is used across multiple components."
            )
        ),

        # Spreading Props
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Spreading Props"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 mb-6",
                "Sometimes you want to pass additional attributes through to an underlying element. ",
                "Use the splat operator to forward props."
            ),
            CodeBlock("""# Forward extra props to the underlying element
function CustomButton(; label, class="", kwargs...)
    Button(
        :class => "btn \$class",
        kwargs...,  # Forward :on_click, :disabled, etc.
        label
    )
end

# All extra props are forwarded
CustomButton(
    label = "Click Me",
    class = "btn-primary",
    on_click = () -> println("Clicked!"),
    disabled = false,
    data_testid = "submit-btn"
)

# Input wrapper that forwards attributes
function FormInput(; label, name, kwargs...)
    Div(:class => "form-group",
        Label(:for => name, label),
        Input(:name => name, :id => name, kwargs...)
    )
end

FormInput(
    label = "Email",
    name = "email",
    type = "email",
    placeholder = "you@example.com",
    required = true
)"""),
            InfoBox("Be Explicit",
                "While spreading is convenient, be intentional about what gets forwarded. " *
                "Explicitly listing expected props makes your component's interface clearer."
            )
        ),

        # Reactive Props
        Section(:class => "py-12 bg-warm-100 dark:bg-warm-800 rounded-lg border border-warm-200 dark:border-warm-900 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Reactive Props"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 mb-6",
                "Props can be signals! When a signal is passed as a prop, the component ",
                "automatically updates when the signal changes."
            ),
            CodeBlock("""# Parent with state
function App()
    theme, set_theme = create_signal("light")

    Div(
        # Pass the signal getter as a prop
        Header(theme=theme),  # theme is a function () -> "light"

        # Toggle button
        Button(:on_click => () -> set_theme(theme() == "light" ? "dark" : "light"),
            "Toggle Theme"
        ),

        # Content also receives the signal
        Content(theme=theme)
    )
end

# Child component reads the signal
function Header(; theme)
    class = theme() == "dark" ? "bg-gray-900 text-white" : "bg-warm-50 text-gray-900"
    Header(:class => class, "My App")
end

# When set_theme is called:
# 1. theme signal updates
# 2. Header automatically re-renders with new class"""),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "This is the foundation of reactive UI: pass signals down, ",
                "and children automatically stay in sync."
            )
        ),

        # Callback Props
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Callback Props"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 mb-6",
                "While data flows down via props, events flow up via callbacks. ",
                "Pass functions as props to let children communicate with parents."
            ),
            CodeBlock("""# Child component accepts a callback
function TodoItem(; todo, on_toggle, on_delete)
    Li(:class => "flex items-center gap-2",
        Input(
            :type => "checkbox",
            :checked => todo.completed,
            :on_change => () -> on_toggle(todo.id)
        ),
        Span(:class => todo.completed ? "line-through" : "", todo.text),
        Button(:on_click => () -> on_delete(todo.id), "×")
    )
end

# Parent provides callbacks
function TodoList()
    todos, set_todos = create_signal([
        (id=1, text="Learn Therapy.jl", completed=false),
        (id=2, text="Build an app", completed=false)
    ])

    toggle_todo = (id) -> set_todos([
        t.id == id ? (id=t.id, text=t.text, completed=!t.completed) : t
        for t in todos()
    ])

    delete_todo = (id) -> set_todos([t for t in todos() if t.id != id])

    Ul(
        For(todos) do todo
            TodoItem(todo=todo, on_toggle=toggle_todo, on_delete=delete_todo)
        end
    )
end"""),
            Div(:class => "mt-6 bg-amber-50 dark:bg-amber-950/30 rounded-lg border border-amber-200 dark:border-amber-900 p-6",
                H3(:class => "text-lg font-serif font-semibold text-amber-900 dark:text-amber-200 mb-2", "The Naming Convention"),
                P(:class => "text-amber-800 dark:text-amber-300",
                    "Callback props typically use the ", Code("on_"), " prefix: ",
                    Code("on_click"), ", ", Code("on_change"), ", ", Code("on_submit"),
                    ". This makes it clear the prop is an event handler."
                )
            )
        ),

        # Key Takeaways
        Section(:class => "py-12 bg-warm-50 dark:bg-warm-900/30 rounded-lg border border-warm-200 dark:border-warm-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-accent-900 dark:text-accent-200 mb-6",
                "Key Takeaways"
            ),
            Ul(:class => "space-y-3 text-accent-800 dark:text-accent-300",
                Li(Strong("Props flow down"), " — from parent to child, one-way data flow"),
                Li(Strong("Keyword args or get_prop()"), " — two patterns, same concept"),
                Li(Strong("Defaults make props optional"), " — provide sensible defaults for better UX"),
                Li(Strong("Type annotations catch bugs"), " — Julia's type system documents and validates"),
                Li(Strong("Signals as props"), " — pass reactive state for automatic updates"),
                Li(Strong("Callbacks for events"), " — children communicate up through function props")
            )
        ),

    )
end

function CodeBlock(code, style="default")
    bg_class = if style == "emerald"
        "bg-warm-900 dark:bg-warm-950 border-warm-700"
    elseif style == "neutral"
        "bg-warm-800 dark:bg-warm-900 border-warm-600"
    else
        "bg-warm-800 dark:bg-warm-950 border-warm-900"
    end

    Div(:class => "$bg_class rounded border p-6 overflow-x-auto",
        Pre(:class => "text-sm text-warm-50",
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
    Div(:class => "bg-warm-50 dark:bg-warm-900 rounded-lg border border-warm-200 dark:border-warm-800 p-4",
        H4(:class => "font-serif font-semibold text-warm-800 dark:text-warm-50 mb-1", title),
        P(:class => "text-warm-600 dark:text-warm-400 text-sm", content)
    )
end

# Export the page component
PropsPage
