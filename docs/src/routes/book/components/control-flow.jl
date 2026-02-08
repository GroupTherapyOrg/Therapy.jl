# Control Flow - Conditional and List Rendering
#
# Show for conditionals, For for lists, and reactive control flow patterns.

import Suite

function ControlFlow()
    BookLayout("/book/components/control-flow/",
        # Header
        Div(:class => "py-8 border-b border-warm-200 dark:border-warm-700",
            Suite.Badge(variant="outline", "Part 3 · Components"),
            H1(:class => "text-4xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-2 mb-4",
                "Control Flow"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 max-w-3xl",
                "Dynamic UIs need to show content conditionally and render lists. Therapy.jl provides ",
                Code(:class => "text-accent-700 dark:text-accent-400", "Show"),
                " and ", Code(:class => "text-accent-700 dark:text-accent-400", "For"),
                " components that integrate with signals for reactive updates."
            )
        ),

        # Show Component
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "The Show Component"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                Code(:class => "text-accent-700 dark:text-accent-400", "Show"),
                " conditionally renders content based on a signal's value. When the condition changes, ",
                "the content is shown or hidden—reactively and efficiently."
            ),
            Suite.CodeBlock(
                """visible, set_visible = create_signal(true)

# Show renders content when condition is truthy
Show(visible) do
    Div(:class => "notification",
        P("This is visible!")
    )
end

# Toggle visibility
set_visible(false)  # Content disappears
set_visible(true)   # Content reappears

# With a fallback for the false case
Show(visible, fallback=()->P("Nothing to see here")) do
    Div("Content when visible")
end""",
                language="julia"
            ),
            Suite.Alert(class="mt-8",
                Suite.AlertTitle("Reactive Updates"),
                Suite.AlertDescription(
                    "Unlike ternary operators which re-evaluate the entire expression, " *
                    "Show tracks the condition signal and only updates when it changes. " *
                    "The content is created once and toggled, not recreated each time."
                )
            )
        ),

        Suite.Separator(),

        # Show vs Ternary
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Show vs Ternary Operator"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "You can use Julia's ternary operator for conditionals, but ",
                Code(:class => "text-accent-700 dark:text-accent-400", "Show"),
                " has advantages for reactive content."
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-300 mb-4",
                        "Ternary Operator"
                    ),
                    Suite.CodeBlock(
                        """# Works, but creates new VNode each time
Div(
    active() ? Span("Active") : Span("Inactive")
)

# Fine for static values
Div(
    is_admin ? AdminPanel() : UserPanel()
)

# Nothing for absent content
Div(
    has_error ? P("Error!") : nothing
)""",
                        language="julia",
                        show_copy=false
                    ),
                    Ul(:class => "mt-4 space-y-1 text-warm-600 dark:text-warm-400 text-sm",
                        Li("✓ Familiar Julia syntax"),
                        Li("✓ Both branches evaluated at build"),
                        Li("✗ May recreate nodes on toggle")
                    )
                ),
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-accent-800 dark:text-accent-300 mb-4",
                        "Show Component"
                    ),
                    Suite.CodeBlock(
                        """# Optimized for reactive toggling
Show(active) do
    Span("Active")
end

# With fallback
Show(is_admin,
     fallback=()->UserPanel()) do
    AdminPanel()
end

# Content preserved on toggle
Show(loading) do
    Spinner()  # Same instance reused
end""",
                        language="julia",
                        show_copy=false
                    ),
                    Ul(:class => "mt-4 space-y-1 text-accent-700 dark:text-accent-400 text-sm",
                        Li("✓ Lazy evaluation"),
                        Li("✓ Content preserved on toggle"),
                        Li("✓ Better for complex content")
                    )
                )
            )
        ),

        Suite.Separator(),

        # Nested Show
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Nested Conditionals"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Show components can be nested for complex conditional logic. However, consider ",
                "refactoring to clearer patterns if nesting gets deep."
            ),
            Suite.CodeBlock(
                """# Nested Show for multi-condition logic
function UserStatus(; user)
    Show(() -> user !== nothing) do
        Show(() -> user.is_admin) do
            Badge("Admin")
        end
        Show(() -> user.is_premium, fallback=()->Badge("Free")) do
            Badge("Premium")
        end
    end
end

# Alternative: Extract to a function for clarity
function StatusBadge(; user)
    if user === nothing
        nothing
    elseif user.is_admin
        Badge("Admin")
    elseif user.is_premium
        Badge("Premium")
    else
        Badge("Free")
    end
end

# Use when/else pattern for multiple conditions
function LoadingState(; state)
    # state is :loading | :error | :success
    Div(
        Show(() -> state() == :loading) do
            Spinner()
        end,
        Show(() -> state() == :error) do
            ErrorMessage()
        end,
        Show(() -> state() == :success) do
            SuccessMessage()
        end
    )
end""",
                language="julia"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "For mutually exclusive states, only one Show's content renders at a time."
            )
        ),

        Suite.Separator(),

        # The For Component
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "The For Component"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                Code(:class => "text-accent-700 dark:text-accent-400", "For"),
                " renders a list of items. When the list changes, For efficiently updates ",
                "only the changed items—not the entire list."
            ),
            Suite.CodeBlock(
                """items, set_items = create_signal(["Apple", "Banana", "Cherry"])

# For iterates over a signal
Ul(
    For(items) do item
        Li(item)
    end
)

# Renders:
# <ul>
#   <li>Apple</li>
#   <li>Banana</li>
#   <li>Cherry</li>
# </ul>

# When items change, only affected elements update
set_items(["Apple", "Banana", "Cherry", "Date"])
# Only the new <li>Date</li> is added

# Works with complex items
users, set_users = create_signal([
    (id=1, name="Alice", role="Admin"),
    (id=2, name="Bob", role="User"),
    (id=3, name="Carol", role="User")
])

Ul(
    For(users) do user
        Li(:class => "user-item",
            Span(:class => "font-bold", user.name),
            Span(:class => "text-gray-500", " - ", user.role)
        )
    end
)""",
                language="julia"
            )
        ),

        Suite.Separator(),

        # Keyed Iteration
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Keyed Iteration"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "When items can be reordered or have state, use a key function to help For ",
                "track which items moved vs which are new."
            ),
            Suite.CodeBlock(
                """# Without keys, For uses index-based tracking
# This can cause issues when items are reordered

# With keys, For tracks items by identity
todos, set_todos = create_signal([
    (id=1, text="Learn Therapy.jl", done=false),
    (id=2, text="Build an app", done=false),
    (id=3, text="Deploy", done=false)
])

Ul(
    For(todos, key = t -> t.id) do todo
        Li(
            Input(:type => "checkbox", :checked => todo.done),
            Span(todo.text)
        )
    end
)

# When you reorder items:
set_todos([todos()[3], todos()[1], todos()[2]])
# For uses id to match existing DOM elements
# Checkbox states are preserved!

# Key function extracts unique identifier
For(items, key = item -> item.id)      # Use .id field
For(items, key = item -> item.uuid)    # Use .uuid field
For(items, key = identity)             # Use item itself""",
                language="julia"
            ),
            Suite.Alert(class="mt-8",
                Suite.AlertTitle("When to Use Keys"),
                Suite.AlertDescription(
                    "Always use keys when items have local state (input values, focus, animations) " *
                    "or when the list can be reordered. For simple static lists, keys are optional."
                )
            )
        ),

        Suite.Separator(),

        # Index in For
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Index Access in For"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Sometimes you need the index of each item. Use Julia's ",
                Code(:class => "text-accent-700 dark:text-accent-400", "enumerate"),
                " to get both index and item."
            ),
            Suite.CodeBlock(
                """items, set_items = create_signal(["First", "Second", "Third"])

# Iterate with index using enumerate
Ol(
    For(() -> enumerate(items())) do (i, item)
        Li(
            Span(:class => "font-mono text-gray-500", "\$i. "),
            Span(item)
        )
    end
)

# Or for 0-based index
Div(
    For(() -> enumerate(items())) do (i, item)
        Div(:class => "row row-\$(i-1)",
            item
        )
    end
)

# Note: wrap enumerate in a function for reactivity
# This ensures re-evaluation when items() changes""",
                language="julia"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "The function wrapper ", Code(:class => "text-accent-700 dark:text-accent-400", "() -> enumerate(items())"),
                " is important for reactivity."
            )
        ),

        Suite.Separator(),

        # Empty States
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Empty States"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Handle empty lists gracefully with Show or conditional rendering."
            ),
            Suite.CodeBlock(
                """items, set_items = create_signal([])

# Pattern 1: Show for empty state
Div(
    Show(() -> isempty(items())) do
        P(:class => "text-gray-500", "No items yet. Add some!")
    end,
    Show(() -> !isempty(items())) do
        Ul(
            For(items) do item
                Li(item)
            end
        )
    end
)

# Pattern 2: Component with empty prop
function ItemList(; items, empty_message="No items")
    Div(
        length(items()) == 0 ?
            P(:class => "empty-state", empty_message) :
            Ul(For(items) do item; Li(item) end)
    )
end

ItemList(items=items, empty_message="Your cart is empty")

# Pattern 3: Fragment with conditional
Div(:class => "item-list",
    For(items) do item
        Li(item)
    end,
    length(items()) == 0 ? P("Nothing here") : nothing
)""",
                language="julia"
            )
        ),

        Suite.Separator(),

        # Nested For
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Nested For Loops"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "For can be nested for multi-dimensional data like tables or grids."
            ),
            Suite.CodeBlock(
                """# 2D grid
grid, set_grid = create_signal([
    [1, 2, 3],
    [4, 5, 6],
    [7, 8, 9]
])

Table(
    Tbody(
        For(grid) do row
            Tr(
                For(() -> row) do cell
                    Td(:class => "border p-2", string(cell))
                end
            )
        end
    )
)

# Grouped data
categories, set_categories = create_signal([
    (name="Fruits", items=["Apple", "Banana"]),
    (name="Vegetables", items=["Carrot", "Broccoli"])
])

Div(
    For(categories) do category
        Section(
            H2(category.name),
            Ul(
                For(() -> category.items) do item
                    Li(item)
                end
            )
        )
    end
)""",
                language="julia"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "Note the inner For uses ", Code(:class => "text-accent-700 dark:text-accent-400", "() -> row"),
                " to wrap the static value in a function."
            )
        ),

        # Key Takeaways
        Suite.Alert(class="mt-12",
            Suite.AlertTitle("Key Takeaways"),
            Suite.AlertDescription(
                Ul(:class => "space-y-2 list-disc pl-5 mt-2",
                    Li(Strong("Show for conditionals"), " — reactive, preserves content on toggle, supports fallback"),
                    Li(Strong("Ternary works too"), " — simpler syntax for static conditions"),
                    Li(Strong("For for lists"), " — efficiently updates only changed items"),
                    Li(Strong("Keys for reordering"), " — use key function when items have state or can move"),
                    Li(Strong("Handle empty states"), " — combine Show with For for good UX"),
                    Li(Strong("Nested For for grids"), " — wrap inner values in functions for reactivity")
                )
            )
        ),

    )
end

# Export the page component
ControlFlow
