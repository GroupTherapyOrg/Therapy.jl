() -> begin
    card = "border border-warm-200 dark:border-warm-800 rounded-lg p-5 space-y-3"
    code_block = "mt-2 bg-warm-900 dark:bg-warm-950 text-warm-200 p-3 rounded text-xs font-mono overflow-x-auto"

    Div(:class => "space-y-10",
        H1(:class => "text-3xl font-serif font-bold text-warm-900 dark:text-warm-100", "API Reference"),

        # ── Signals ──
        H2(:class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Signals"),
        Div(:class => "space-y-4",
            Div(:class => card,
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "create_signal(initial)"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400", "Create a signal. Returns (getter, setter) tuple. Reading the getter inside effects/memos tracks it as a dependency."),
                Pre(:class => code_block, Code(:class => "language-julia", """count, set_count = create_signal(0)
count()         # read → 0
set_count(5)    # write → count() is now 5"""))),

            Div(:class => card,
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "create_effect(() -> ...)"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400", "Run a side effect whenever its signal dependencies change. Compiles to JS — ", Code(:class => "text-accent-500", "println"), " becomes ", Code(:class => "text-accent-500", "console.log"), "."),
                Pre(:class => code_block, Code(:class => "language-julia", """create_effect(() -> println("count is: ", count()))
# Runs immediately + re-runs on every count() change"""))),

            Div(:class => card,
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "create_memo(() -> ...)"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400", "Create a cached derived value. Recomputes only when dependencies change."),
                Pre(:class => code_block, Code(:class => "language-julia", """doubled = create_memo(() -> count() * 2)
doubled()  # read derived value — cached until count() changes""")))
        ),

        # ── Control Flow ──
        H2(:class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Control Flow"),
        Div(:class => "space-y-4",
            Div(:class => card,
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "Show(condition) do ... end"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400", "Conditional rendering. SolidJS-style — content is actually inserted/removed from the DOM, not hidden with CSS."),
                Pre(:class => code_block, Code(:class => "language-julia", """visible, set_visible = create_signal(1)

Show(visible) do
    P("I exist in the DOM right now!")
end"""))),

            Div(:class => card,
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "For(items) do item, idx ... end"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400", "List rendering. Items can come from a signal or memo for dynamic lists. Supports nested For for 2D data."),
                Pre(:class => code_block, Code(:class => "language-julia", """items, set_items = create_signal(["a", "b", "c"])

Ul(For(items) do item, idx
    Li(item)
end)""")))
        ),

        # ── Components ──
        H2(:class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Components"),
        Div(:class => "space-y-4",
            Div(:class => card,
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "function Name(args...) ... end"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400", "A plain Julia function that returns VNodes is an SSR component. Runs at build time with full access to Julia packages. No macro needed — just return elements."),
                Pre(:class => code_block, Code(:class => "language-julia", """using DataFrames: DataFrame, names, eachrow

function DataTable()
    df = DataFrame(Name=["Alice","Bob"], Age=[28,35])
    cols = names(df)
    rows = [string.(collect(row)) for row in eachrow(df)]
    return Table(
        Thead(Tr(For(cols) do col; Th(col); end)),
        Tbody(For(rows) do row; Tr(For(row) do c; Td(c); end); end)
    )
end"""))),

            Div(:class => card,
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "@island function Name(; kwargs...) ... end"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400", "Mark a component as interactive. Compiled to JavaScript via JST. Kwargs must be typed — they become JSON-serializable props. SSR components pass data to islands via props."),
                Pre(:class => code_block, Code(:class => "language-julia", """@island function Counter(; initial::Int = 0)
    count, set_count = create_signal(initial)
    return Div(
        Button(:on_click => () -> set_count(count() + 1), "+"),
        Span(count)
    )
end"""))),

            Div(:class => card,
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "js(code::String, args...)"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400", "Escape hatch — emit raw JavaScript. Use ", Code(:class => "text-accent-500", "\$1"), ", ", Code(:class => "text-accent-500", "\$2"), " for value passing. Only for browser APIs that can't be expressed in Julia."),
                Pre(:class => code_block, Code(:class => "language-julia", """js("document.documentElement.classList.toggle('dark')")
js("localStorage.setItem(\$1, \$2)", key, value)""")))
        ),

        # ── HTML Elements ──
        H2(:class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "HTML Elements"),
        Div(:class => card,
            P(:class => "text-sm text-warm-600 dark:text-warm-400", "All standard HTML elements are available as capitalized functions. Props use ", Code(:class => "text-accent-500", ":symbol => value"), " syntax. Event handlers use ", Code(:class => "text-accent-500", ":on_click"), ", ", Code(:class => "text-accent-500", ":on_input"), ", etc."),
            Pre(:class => code_block, Code(:class => "language-julia", """Div(:class => "container",
    H1("Hello"),
    Button(:on_click => () -> set_count(count() + 1), "Click me"),
    Input(:type => "range", :value => freq, :on_input => set_freq),
    A(:href => "https://example.com", "Link")
)""")),
            P(:class => "text-xs text-warm-400 dark:text-warm-500 mt-2",
                "Div, Span, P, A, Button, Input, Form, Label, H1–H6, Strong, Em, Code, Pre, Ul, Ol, Li, Table, Thead, Tbody, Tr, Th, Td, Header, Footer, Nav, MainEl, Section, Article, Img, Svg, ..."))
    )
end
