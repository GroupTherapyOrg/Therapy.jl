# Thinking in Therapy.jl
#
# A guide to the mental model of fine-grained reactivity and Julia-to-WebAssembly compilation.
# Adapted from React's "Thinking in React" but for signals-based reactivity.
# Uses Suite.jl components for visual presentation.

import Suite

function ThinkingInTherapy()
    TutorialLayout(
        Div(:class => "space-y-12",
            # Header
            Div(:class => "mb-8",
                H1(:class => "text-3xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Thinking in Therapy.jl"
                ),
                P(:class => "text-lg text-warm-800 dark:text-warm-300",
                    "Therapy.jl changes how you think about building interactive UIs. Instead of re-rendering entire components when data changes, you create ",
                    Strong("signals"),
                    " that update only the exact DOM nodes that depend on them. Your Julia code compiles directly to WebAssembly."
                )
            ),

            # Key Insight Box
            Suite.Card(class="bg-gradient-to-r from-warm-50 to-warm-100 dark:from-warm-900 dark:to-warm-950",
                Suite.CardHeader(
                    Suite.CardTitle(class="font-serif", "The Core Insight"),
                ),
                Suite.CardContent(
                    P(:class => "text-warm-800 dark:text-warm-300",
                        "In React, components re-run on every state change. In Therapy.jl, components run ",
                        Strong("once"),
                        " during render. After that, signals update the DOM directly — no diffing, no virtual DOM, just surgical updates."
                    )
                )
            ),

            Suite.Separator(),

            # Reactive Paradigms Comparison
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Two Reactive Paradigms"
                ),
                P(:class => "text-warm-800 dark:text-warm-300 mb-6",
                    "Understanding the difference between virtual DOM and fine-grained reactivity is key to thinking in Therapy.jl."
                ),

                # Comparison Grid
                Div(:class => "grid md:grid-cols-2 gap-6 mb-6",
                    # React/VDOM approach
                    Suite.Card(
                        Suite.CardHeader(
                            Suite.CardTitle(class="font-serif", "Virtual DOM (React)"),
                        ),
                        Suite.CardContent(
                            Ul(:class => "space-y-2 text-warm-800 dark:text-warm-300 text-sm mb-4",
                                Li("State changes trigger component re-execution"),
                                Li("New virtual DOM tree is created"),
                                Li("Diffing algorithm compares old and new trees"),
                                Li("Patches are applied to real DOM"),
                                Li("Components may re-render even if output unchanged")
                            ),
                            Suite.CodeBlock("""# React mental model (pseudocode)
function Counter()
    # This ENTIRE function runs on every click!
    count = useState(0)
    return Div(
        Button(onClick: () -> setCount(count + 1)),
        Span(count)  # Re-created each time
    )
end""", language="julia")
                        )
                    ),

                    # Therapy.jl/Signals approach
                    Suite.Card(class="border-2",
                        Suite.CardHeader(
                            Suite.CardTitle(class="font-serif text-accent-700 dark:text-accent-400",
                                "Fine-Grained Reactivity (Therapy.jl)"
                            ),
                        ),
                        Suite.CardContent(
                            Ul(:class => "space-y-2 text-warm-800 dark:text-warm-300 text-sm mb-4",
                                Li("Component runs once during initial render"),
                                Li("Signal changes update only subscribed DOM nodes"),
                                Li("No diffing — direct DOM mutations"),
                                Li("Event handlers compile to WebAssembly"),
                                Li("Only the exact text node updates")
                            ),
                            Suite.CodeBlock("""# Therapy.jl mental model
function Counter()
    # This runs ONCE!
    count, set_count = create_signal(0)
    return Div(
        Button(:on_click => () -> set_count(count() + 1)),
        Span(count)  # Creates subscription, updates directly
    )
end""", language="julia")
                        )
                    )
                ),

                # Visual diagram
                Suite.Card(class="text-center",
                    Suite.CardContent(
                        P(:class => "text-warm-600 dark:text-warm-400 text-sm mb-4",
                            "When you click the button:"
                        ),
                        Div(:class => "flex justify-around items-center flex-wrap gap-4",
                            Div(:class => "text-center",
                                Div(:class => "text-3xl mb-2", "React"),
                                Div(:class => "text-sm text-warm-600 dark:text-warm-400",
                                    "Re-runs Counter()\n→ Creates new VDOM\n→ Diffs trees\n→ Updates DOM"
                                )
                            ),
                            Div(:class => "text-2xl text-warm-200", "vs"),
                            Div(:class => "text-center",
                                Div(:class => "text-3xl mb-2 text-accent-600 dark:text-accent-400", "Therapy.jl"),
                                Div(:class => "text-sm text-warm-600 dark:text-warm-400",
                                    "Wasm handler runs\n→ Updates signal\n→ Updates ONE text node"
                                )
                            )
                        )
                    )
                )
            ),

            Suite.Separator(),

            # Step 1: Break into Components
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Step 1: Break the UI into Components"
                ),
                P(:class => "text-warm-800 dark:text-warm-300 mb-4",
                    "Start by identifying the components in your UI. In Therapy.jl, components are just Julia functions that return VNodes. Each component should have a single responsibility."
                ),
                P(:class => "text-warm-800 dark:text-warm-300 mb-4",
                    "Imagine building a searchable product table. Here's the JSON data:"
                ),
                Suite.CodeBlock("""products = [
    (category="Fruits", price="\$1", stocked=true, name="Apple"),
    (category="Fruits", price="\$1", stocked=true, name="Dragonfruit"),
    (category="Fruits", price="\$2", stocked=false, name="Passionfruit"),
    (category="Vegetables", price="\$2", stocked=true, name="Spinach"),
    (category="Vegetables", price="\$4", stocked=false, name="Pumpkin"),
    (category="Vegetables", price="\$1", stocked=true, name="Peas")
]""", language="julia"),
                P(:class => "text-warm-800 dark:text-warm-300 mb-4",
                    "Break the UI into a component hierarchy:"
                ),
                Ul(:class => "space-y-2 text-warm-800 dark:text-warm-300 ml-4",
                    Li(Strong("FilterableProductTable"), " — contains the entire app"),
                    Li(Strong("SearchBar"), " — receives user input"),
                    Li(Strong("ProductTable"), " — displays and filters the list"),
                    Li(Strong("ProductCategoryRow"), " — heading for each category"),
                    Li(Strong("ProductRow"), " — row for each product")
                ),
                Suite.CodeBlock("""# Component hierarchy
FilterableProductTable
├── SearchBar
└── ProductTable
    ├── ProductCategoryRow
    └── ProductRow""", language="text")
            ),

            Suite.Separator(),

            # Step 2: Build Static Version
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Step 2: Build a Static Version"
                ),
                P(:class => "text-warm-800 dark:text-warm-300 mb-4",
                    "Build a version that renders the UI from your data model without any interactivity. This is SSR (Server-Side Rendering) — the HTML that gets sent to the browser."
                ),
                Suite.Alert(
                    Suite.AlertTitle("No signals yet!"),
                    Suite.AlertDescription(
                        "At this stage, don't add any signals. Just pass data through function arguments. This is pure rendering."
                    )
                ),
                Suite.CodeBlock("""function ProductRow(product)
    name_style = product.stocked ? "" : "text-red-500"
    Tr(
        Td(:class => name_style, product.name),
        Td(product.price)
    )
end

function ProductCategoryRow(category)
    Tr(
        Th(:colspan => "2", :class => "font-bold bg-warm-50", category)
    )
end

function ProductTable(products)
    rows = []
    last_category = nothing

    for product in products
        if product.category != last_category
            push!(rows, ProductCategoryRow(product.category))
            last_category = product.category
        end
        push!(rows, ProductRow(product))
    end

    Table(:class => "w-full",
        Thead(Tr(Th("Name"), Th("Price"))),
        Tbody(rows...)
    )
end

function SearchBar()
    Form(
        Input(:type => "text", :placeholder => "Search..."),
        Label(
            Input(:type => "checkbox"),
            " Only show products in stock"
        )
    )
end

function FilterableProductTable(products)
    Div(
        SearchBar(),
        ProductTable(products)
    )
end""", language="julia"),
                P(:class => "text-warm-800 dark:text-warm-300 mb-4",
                    "At this point, you have a static page. Data flows down from parent to child through function arguments. This is the foundation that Therapy.jl will enhance with reactivity."
                )
            ),

            Suite.Separator(),

            # Step 3: Find Minimal State
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Step 3: Find the Minimal Set of Signals"
                ),
                P(:class => "text-warm-800 dark:text-warm-300 mb-4",
                    "Now think about interactivity. What data needs to change over time? These become ",
                    Strong("signals"),
                    ". The key principle: keep it minimal. Don't store computed values."
                ),
                P(:class => "text-warm-800 dark:text-warm-300 mb-4",
                    "Consider all the data in our app:"
                ),
                Ol(:class => "list-decimal list-inside text-warm-800 dark:text-warm-300 space-y-2 mb-4 ml-4",
                    Li("The original list of products"),
                    Li("The search text the user has entered"),
                    Li("The value of the checkbox"),
                    Li("The filtered list of products")
                ),
                P(:class => "text-warm-800 dark:text-warm-300 mb-4",
                    "Ask three questions for each:"
                ),
                Ul(:class => "space-y-2 text-warm-800 dark:text-warm-300 ml-4 mb-4",
                    Li(Strong("Does it change over time?"), " If not, it's not a signal."),
                    Li(Strong("Is it passed in from outside?"), " If so, it's a prop, not a signal."),
                    Li(Strong("Can you compute it from other data?"), " If so, it's derived, not a signal.")
                ),
                Suite.Card(
                    Suite.CardContent(
                        P(:class => "text-warm-800 dark:text-warm-300 text-sm",
                            "1. Products list — passed in as argument → ", Strong("not a signal"), Br(),
                            "2. Search text — changes over time → ", Strong(:class => "text-accent-700 dark:text-accent-400", "signal"), Br(),
                            "3. Checkbox value — changes over time → ", Strong(:class => "text-accent-700 dark:text-accent-400", "signal"), Br(),
                            "4. Filtered list — computed from 1, 2, 3 → ", Strong("derived (memo)")
                        )
                    )
                ),
                Suite.CodeBlock("""# Only TWO signals needed!
filter_text, set_filter_text = create_signal("")
in_stock_only, set_in_stock_only = create_signal(false)

# The filtered list is DERIVED, not stored
filtered = create_memo() do
    filter(products) do p
        matches_search = contains(lowercase(p.name), lowercase(filter_text()))
        matches_stock = !in_stock_only() || p.stocked
        matches_search && matches_stock
    end
end""", language="julia"),
                Suite.Alert(
                    Suite.AlertTitle("Key insight"),
                    Suite.AlertDescription(
                        "In Therapy.jl, ", Code(:class => "bg-warm-200 dark:bg-warm-900 px-1 rounded", "create_memo"),
                        " creates a cached derived value. It only recomputes when its dependencies change. This compiles to efficient WebAssembly!"
                    )
                )
            ),

            Suite.Separator(),

            # Step 4: Where State Lives
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Step 4: Identify Where Signals Should Live"
                ),
                P(:class => "text-warm-800 dark:text-warm-300 mb-4",
                    "Place signals in the nearest common ancestor of all components that need them. In our example, both SearchBar and ProductTable need the filter state, so signals live in FilterableProductTable."
                ),
                Suite.CodeBlock("""function FilterableProductTable(products)
    # Signals live here - nearest common ancestor
    filter_text, set_filter_text = create_signal("")
    in_stock_only, set_in_stock_only = create_signal(false)

    Div(
        SearchBar(filter_text, set_filter_text,
                  in_stock_only, set_in_stock_only),
        ProductTable(products, filter_text, in_stock_only)
    )
end""", language="julia"),
                P(:class => "text-warm-800 dark:text-warm-300 mb-4",
                    "Now connect the signals to the UI. Notice how we pass both the getter and setter to SearchBar, but only the getter to ProductTable:"
                ),
                Suite.CodeBlock("""function SearchBar(filter_text, set_filter_text,
                  in_stock_only, set_in_stock_only)
    Form(
        Input(
            :type => "text",
            :placeholder => "Search...",
            :value => filter_text,
            :on_input => (e) -> set_filter_text(e.target.value)
        ),
        Label(
            Input(
                :type => "checkbox",
                :checked => in_stock_only,
                :on_change => (e) -> set_in_stock_only(e.target.checked)
            ),
            " Only show products in stock"
        )
    )
end""", language="julia")
            ),

            Suite.Separator(),

            # Step 5: No Inverse Data Flow Needed!
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Step 5: Direct Signal Updates (No Callbacks Needed!)"
                ),
                P(:class => "text-warm-800 dark:text-warm-300 mb-4",
                    "Here's where Therapy.jl shines compared to React. In React, you pass callback functions down to child components. In Therapy.jl, you pass the setter directly — the child can update the signal, and all subscribers automatically update."
                ),
                Div(:class => "grid md:grid-cols-2 gap-6 mb-6",
                    # React way
                    Suite.Card(
                        Suite.CardHeader(
                            Suite.CardTitle(class="text-sm", "React: Callback Props"),
                        ),
                        Suite.CardContent(
                            Suite.CodeBlock("""# React requires callbacks
<SearchBar
  filterText={filterText}
  onFilterTextChange={setFilterText}
/>""", language="javascript")
                        )
                    ),
                    # Therapy.jl way
                    Suite.Card(class="border-2",
                        Suite.CardHeader(
                            Suite.CardTitle(class="text-sm text-accent-700 dark:text-accent-400",
                                "Therapy.jl: Direct Setters"
                            ),
                        ),
                        Suite.CardContent(
                            Suite.CodeBlock("""# Just pass the setter!
SearchBar(filter_text, set_filter_text,
          in_stock_only, set_in_stock_only)""", language="julia")
                        )
                    )
                ),
                P(:class => "text-warm-800 dark:text-warm-300 mb-4",
                    "When the user types, the signal updates, and Therapy.jl automatically updates every DOM node that depends on that signal. No manual wiring, no props drilling callbacks."
                )
            ),

            Suite.Separator(),

            # WebAssembly Section
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "The WebAssembly Advantage"
                ),
                P(:class => "text-warm-800 dark:text-warm-300 mb-4",
                    "What makes Therapy.jl unique is that your event handlers compile to WebAssembly. The signal operations, conditionals, and logic all run as native Wasm — not interpreted JavaScript."
                ),
                Suite.CodeBlock("""# This Julia code...
() -> begin
    if winner() == 0 && s0() == 0
        set_s0(turn() == 0 ? 1 : 2)
        set_turn(turn() == 0 ? 1 : 0)
        if s0() != 0 && s0() == s1() && s0() == s2()
            set_winner(s0())
        end
    end
end

# ...compiles to efficient WebAssembly!
# No JavaScript interpreter overhead for game logic.""", language="julia"),
                Suite.Alert(
                    Suite.AlertTitle("How Compilation Works"),
                    Suite.AlertDescription(
                        Ol(:class => "list-decimal list-inside text-sm space-y-1",
                            Li("Therapy.jl analyzes your component to find signals and handlers"),
                            Li("Handler closures are inspected via Julia's type system"),
                            Li("Signal operations are compiled to Wasm global.get/global.set"),
                            Li("DOM updates are automatically injected after signal writes"),
                            Li("Result: a tiny Wasm module (~3KB) with all your logic")
                        )
                    )
                )
            ),

            Suite.Separator(),

            # Summary
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Summary: The Therapy.jl Mental Model"
                ),
                Div(:class => "space-y-4",
                    _SummaryPoint("1", "Components run once",
                        "Unlike React, your component function executes once during initial render. No re-rendering on state changes."),
                    _SummaryPoint("2", "Signals are reactive values",
                        "Use create_signal() for state that changes. Reading a signal in a component creates a subscription."),
                    _SummaryPoint("3", "Updates are surgical",
                        "When a signal changes, only the exact DOM nodes that depend on it update. No diffing, no tree traversal."),
                    _SummaryPoint("4", "Derive, don't duplicate",
                        "Use create_memo() for computed values. Only store the minimal state — derive everything else."),
                    _SummaryPoint("5", "Handlers compile to Wasm",
                        "Your Julia logic compiles directly to WebAssembly. All conditionals, loops, and computations run as native code.")
                )
            ),

            # Comparison with Leptos/SolidJS
            Suite.Card(
                Suite.CardHeader(
                    Suite.CardTitle(class="font-serif", "Related Frameworks"),
                ),
                Suite.CardContent(
                    P(:class => "text-warm-800 dark:text-warm-300 text-sm mb-3",
                        "Therapy.jl's reactivity model is inspired by:"
                    ),
                    Ul(:class => "space-y-2 text-warm-800 dark:text-warm-300 text-sm",
                        Li(Strong("SolidJS"), " (JavaScript) — Pioneer of fine-grained reactivity in the JS ecosystem"),
                        Li(Strong("Leptos"), " (Rust) — Full-stack Rust framework with similar signal semantics, also compiling to Wasm"),
                        Li(Strong("Svelte 5"), " — Recently adopted signals (\"runes\") moving away from compiler magic")
                    ),
                    P(:class => "text-warm-600 dark:text-warm-600 text-sm mt-3 italic",
                        "Therapy.jl brings this proven model to Julia, with the unique advantage of compiling Julia code directly to WebAssembly."
                    )
                )
            ),

            # Next steps
            Suite.Card(class="bg-gradient-to-r from-warm-50 to-warm-100 dark:from-warm-900 dark:to-warm-950 mt-8",
                Suite.CardHeader(
                    Suite.CardTitle(class="font-serif", "Next Steps"),
                ),
                Suite.CardContent(
                    Ul(:class => "space-y-2 text-warm-800 dark:text-warm-300",
                        Li(A(:href => "./learn/tutorial-tic-tac-toe/", :class => "text-accent-700 dark:text-accent-400 underline font-medium", "Tutorial: Tic-Tac-Toe"), " — Build a complete game with signals and Wasm"),
                        Li(A(:href => "./examples/", :class => "text-accent-700 dark:text-accent-400 underline font-medium", "Examples"), " — See more components in action"),
                        Li(A(:href => "./api/", :class => "text-accent-700 dark:text-accent-400 underline font-medium", "API Reference"), " — Full documentation")
                    )
                )
            )
        );
        current_path="learn/thinking-in-therapy/"
    )
end

function _SummaryPoint(number, title, description)
    Div(:class => "flex gap-4 items-start",
        Div(:class => "w-8 h-8 rounded-full bg-warm-100 dark:bg-warm-900 text-accent-700 dark:text-accent-400 flex items-center justify-center font-bold shrink-0",
            number
        ),
        Div(
            H4(:class => "font-semibold text-warm-800 dark:text-warm-50 mb-1", title),
            P(:class => "text-warm-800 dark:text-warm-300 text-sm", description)
        )
    )
end

ThinkingInTherapy
