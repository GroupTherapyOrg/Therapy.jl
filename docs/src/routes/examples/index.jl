() -> begin
    sections = [
        ("interactive-plot", "Interactive Plot"),
        ("counter", "Counter"),
        ("dark-mode", "Dark Mode Toggle"),
        ("search", "Search"),
        ("todo", "Todo List"),
        ("show", "Show / Fallback"),
        ("lifecycle", "Mount vs Effect"),
        ("batching", "Auto-Batching"),
        ("signal-types", "Signal Types"),
        ("data-table", "Data Table"),
    ]

    PageWithTOC(sections, Div(:class => "space-y-12",
        H1(:class => "text-3xl font-serif font-bold text-warm-900 dark:text-warm-100", "Examples"),
        P(:class => "text-warm-600 dark:text-warm-400",
            "Interactive examples built with Therapy.jl. Code snippets below are simplified — see the full source in ",
            A(:href => "https://github.com/GroupTherapyOrg/Therapy.jl/tree/wasm-islands/docs/src/components",
                :target => "_blank",
                :class => "text-accent-500 hover:text-accent-600 underline",
                "docs/src/components"),
            "."),

        # ── Interactive Plot (Makie via WasmTargetMakieExt → Three.js) ──
        Div(:class => "space-y-4",
            H2(:id => "interactive-plot", :class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Interactive Plot"),
            P(:class => "text-sm text-warm-600 dark:text-warm-400", "Standard Makie API compiled to WASM via WasmTargetMakieExt overlays. Sin wave frequency controlled by slider. Math runs in WASM, rendering via Three.js."),
            Div(:class => "flex justify-center py-6", InteractivePlot(frequency=5)),
            Pre(:class => "bg-warm-900 dark:bg-warm-950 text-warm-200 p-5 rounded-lg border border-warm-800 font-mono text-sm overflow-x-auto max-h-[30rem]", Code(:class => "language-julia", """using WasmTarget: WasmFigure, WasmAxis, _wasm_lines, _wasm_display

@island function InteractivePlot(; frequency::Int = 5)
    freq, set_freq = create_signal(frequency)

    create_effect(() -> begin
        f = freq()
        fig = WasmFigure(Int64(1))
        ax = WasmAxis(fig.id, Int64(1))
        x = Vector{Float64}(undef, 100)
        y = Vector{Float64}(undef, 100)
        for i in 1:100
            x[i] = Float64(i) * 0.1
            y[i] = sin(x[i] * Float64(f))
        end
        _wasm_lines(ax.id, Int64(length(x)))
        _wasm_display(fig.id)
    end)

    return Div(
        Div(:id => "makie-canvas"),
        Input(:type => "range", :value => freq, :on_input => set_freq),
        Span(freq)
    )
end"""))
        ),

        # ── Counter ──
        Div(:class => "space-y-4",
            H2(:id => "counter", :class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Counter"),
            P(:class => "text-sm text-warm-600 dark:text-warm-400", "Signals, memos, and effects — open your browser console to see the effect logging."),
            Div(:class => "flex justify-center py-6", InteractiveCounter(initial=0)),
            Pre(:class => "bg-warm-900 dark:bg-warm-950 text-warm-200 p-5 rounded-lg border border-warm-800 font-mono text-sm overflow-x-auto max-h-[30rem]", Code(:class => "language-julia", """using Therapy: Div, Button, Span
using Therapy: @island, create_signal, create_memo, create_effect, js

@island function InteractiveCounter(; initial::Int = 0)
    count, set_count = create_signal(initial)
    doubled = create_memo(() -> count() * 2)
    create_effect(() -> js("console.log('count:', \$1, 'doubled:', \$2)", count(), doubled()))

    return Div(
        Div(
            Button(:on_click => () -> set_count(count() - 1), "-"),
            Span(count),
            Button(:on_click => () -> set_count(count() + 1), "+")
        ),
        Span("doubled ", Span(doubled))
    )
end"""))
        ),

        # ── Dark Mode Toggle (Cross-Island) ──
        Div(:class => "space-y-4",
            H2(:id => "dark-mode", :class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Dark Mode Toggle"),
            P(:class => "text-sm text-warm-600 dark:text-warm-400",
                "Cross-island signal sharing. This toggle and the one in the nav bar are separate ",
                Code(:class => "font-mono text-accent-500", "@island"),
                " instances, each with their own WASM module. They share a module-level signal automatically — WASM reads the shared value via an import call. Click either toggle and both stay in sync."),
            Div(:class => "flex justify-center py-6",
                Div(:class => "flex items-center gap-3 px-4 py-3 rounded-lg border border-warm-200 dark:border-warm-800",
                    Span(:class => "text-sm text-warm-600 dark:text-warm-400", "Toggle dark mode →"),
                    DarkModeToggle()
                )
            ),
            Pre(:class => "bg-warm-900 dark:bg-warm-950 text-warm-200 p-5 rounded-lg border border-warm-800 font-mono text-sm overflow-x-auto max-h-[30rem]", Code(:class => "language-julia", """using Therapy: Button
using Therapy: @island, create_signal, js

# Module-level signal — shared across ALL instances automatically
const dark_mode = create_signal(0)

@island function DarkModeToggle()
    is_dark, set_dark = dark_mode  # captures the shared signal

    # Sync with browser dark state on hydration
    js("if(document.documentElement.classList.contains('dark'))\$1(1)", set_dark)

    return Button(:on_click => () -> begin
        set_dark(1 - is_dark())
        js("document.documentElement.classList.toggle('dark')")
        js("localStorage.setItem('therapy-theme', ...)")
    end, "Toggle")
end"""))
        ),

        # ── Search Demo ──
        Div(:class => "space-y-4",
            H2(:id => "search", :class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Search"),
            P(:class => "text-sm text-warm-600 dark:text-warm-400",
                "Leptos-style string signals. ",
                Code(:class => "font-mono text-accent-500", "create_signal(\"\")"),
                " creates a WasmGC ref-typed global that holds the query string. On each keystroke, the input value is bridged to a WasmGC string and written to the global. The memo reads it via ",
                Code(:class => "font-mono text-accent-500", "query()"),
                " and filters using ",
                Code(:class => "font-mono text-accent-500", "lowercase"),
                " and ",
                Code(:class => "font-mono text-accent-500", "startswith"),
                " — all running in WebAssembly. This is the same code shown below."),
            Div(:class => "flex justify-center py-6", SearchDemo()),
            Pre(:class => "bg-warm-900 dark:bg-warm-950 text-warm-200 p-5 rounded-lg border border-warm-800 font-mono text-sm overflow-x-auto max-h-[30rem]", Code(:class => "language-julia", """@island function SearchableList(;
        items_data::Vector{String} = String[],
        visible_init::Int = 12
    )
    # String signal — the query text, stored as a WasmGC ref global
    query, set_query = create_signal("")

    # Integer signals for pagination
    visible_count, set_visible_count = create_signal(visible_init)
    total_count, _ = create_signal(length(items_data))

    # Memo: filter by query, then take first N items.
    # query() reads the WasmGC string global.
    # lowercase() and startswith() compile to WASM intrinsics.
    visible_items = create_memo(() -> begin
        q = lowercase(query())
        n = visible_count()

        filtered = String[]
        for i in 1:length(items_data)
            if length(q) == 0 || startswith(lowercase(items_data[i]), q)
                push!(filtered, items_data[i])
            end
        end

        result = String[]
        for i in 1:min(n, length(filtered))
            push!(result, filtered[i])
        end
        result
    end)

    return Div(
        Input(:type => "text", :on_input => set_query),
        For(visible_items) do item
            Div(item)
        end,
        # Show() with closure conditions — compiled to WASM
        Show(() -> visible_count() < total_count()) do
            Button(:on_click => () -> set_visible_count(visible_count() + 12),
                "show more")
        end,
        Show(() -> visible_count() > 12) do
            Button(:on_click => () -> set_visible_count(visible_count() - 12),
                "show less")
        end
    )
end"""))
        ),

        # ── Todo List ──
        Div(:class => "space-y-4",
            H2(:id => "todo", :class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Todo List"),
            P(:class => "text-sm text-warm-600 dark:text-warm-400",
                "Dynamic list rendering with ",
                Code(:class => "font-mono text-accent-500", "For()"),
                ". An integer signal tracks how many items to show. A memo derives the visible ",
                Code(:class => "font-mono text-accent-500", "Vector{String}"),
                " slice. When the count shrinks, ",
                Code(:class => "font-mono text-accent-500", "For"),
                " removes DOM nodes and disposes their owners. ",
                Code(:class => "font-mono text-accent-500", "Show()"),
                " conditions control button visibility based on signal comparisons compiled to WASM."),
            Div(:class => "flex justify-center py-6", TodoDemo()),
            Pre(:class => "bg-warm-900 dark:bg-warm-950 text-warm-200 p-5 rounded-lg border border-warm-800 font-mono text-sm overflow-x-auto max-h-[30rem]", Code(:class => "language-julia", """@island function TodoList(;
        items_data::Vector{String} = String[]
    )
    remaining, set_remaining = create_signal(length(items_data))
    total, _ = create_signal(length(items_data))

    visible = create_memo(() -> begin
        n = remaining()
        result = String[]
        for i in 1:min(n, length(items_data))
            push!(result, items_data[i])
        end
        result
    end)

    create_effect(() -> js("console.log('todo remaining:', \\\$1)", remaining()))

    return Div(
        Span(remaining, " / \$(length(items_data))"),
        For(visible) do item
            Div(Span(item))
        end,
        Show(() -> remaining() > 0) do
            Button(:on_click => () -> set_remaining(remaining() - 1), "Remove last")
        end,
        Show(() -> remaining() < total()) do
            Button(:on_click => () -> set_remaining(remaining() + 1), "Add back")
        end
    )
end"""))
        ),

        # ── Show / Fallback ──
        Div(:class => "space-y-4",
            H2(:id => "show", :class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Show / Fallback"),
            P(:class => "text-sm text-warm-600 dark:text-warm-400",
                "Conditional rendering with ",
                Code(:class => "font-mono text-accent-500", "Show()"),
                " and a ",
                Code(:class => "font-mono text-accent-500", "fallback"),
                " prop. When the signal is truthy, the content is inserted into the DOM. When falsy, the fallback replaces it. Owner disposal ensures effects inside the shown content are cleaned up on each toggle — open the console to see the effect log."),
            Div(:class => "flex justify-center py-6", ShowDemo(initial_visible=1)),
            Pre(:class => "bg-warm-900 dark:bg-warm-950 text-warm-200 p-5 rounded-lg border border-warm-800 font-mono text-sm overflow-x-auto max-h-[30rem]", Code(:class => "language-julia", """using Therapy: Div, Button, P, Code, Strong, Show
using Therapy: @island, create_signal, create_effect, js

@island function ShowDemo(; initial_visible::Int = 1)
    visible, set_visible = create_signal(initial_visible)

    create_effect(() -> js("console.log('ShowDemo visible:', \\\$1)", visible()))

    return Div(
        Button(:on_click => () -> set_visible(1 - visible()), "Toggle Content"),

        Show(visible; fallback=Div(
                P("Content is hidden. Click Toggle to show it."),
                P("This is the ", Code("fallback"), " prop.")
            )) do
            Div(
                P("I exist in the DOM right now!"),
                P("These nodes are completely ", Strong("removed"),
                  " when you click Toggle.")
            )
        end
    )
end"""))
        ),

        # ── MountDemo ──
        Div(:class => "space-y-4",
            H2(:id => "lifecycle", :class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Mount vs Effect Lifecycle"),
            P(:class => "text-sm text-warm-600 dark:text-warm-400",
                Code(:class => "font-mono text-accent-500", "on_mount"),
                " runs exactly ", Strong("once"), " after the island hydrates. ",
                Code(:class => "font-mono text-accent-500", "create_effect"),
                " re-runs every time a tracked signal changes. Open your browser console (",
                Code(:class => "font-mono text-accent-500", "F12"),
                ") and click the button — you will see a single ",
                Code(:class => "font-mono", "on_mount"),
                " log, but the effect logs on every click."),
            Div(:class => "flex justify-center py-6", MountDemo()),
            Pre(:class => "bg-warm-900 dark:bg-warm-950 text-warm-200 p-5 rounded-lg border border-warm-800 font-mono text-sm overflow-x-auto max-h-[30rem]", Code(:class => "language-julia", """using Therapy: Div, Button, P
using Therapy: @island, create_signal, create_effect, on_mount, js

@island function MountDemo()
    count, set_count = create_signal(0)

    # Runs ONCE after hydration — never again
    on_mount(() -> js("console.log('on_mount: I ran once!')"))

    # Runs on every count() change
    create_effect(() -> js("console.log('create_effect: count is', \\\$1)", count()))

    return Div(
        Button(:on_click => () -> set_count(count() + 1), "Click me"),
        P("count: ", count)
    )
end"""))
        ),

        # ── BatchDemo ──
        Div(:class => "space-y-4",
            H2(:id => "batching", :class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Auto-Batching"),
            P(:class => "text-sm text-warm-600 dark:text-warm-400",
                "Event handlers are automatically batched. The handler sets ",
                Strong("two"), " signals, but the effect that reads both fires only ",
                Strong("once"), " per click — not twice. Open the console (",
                Code(:class => "font-mono text-accent-500", "F12"),
                ") and click a button to verify: you should see a single ",
                Code(:class => "font-mono", "effect:"),
                " log per click."),
            Div(:class => "flex justify-center py-6", BatchDemo()),
            Pre(:class => "bg-warm-900 dark:bg-warm-950 text-warm-200 p-5 rounded-lg border border-warm-800 font-mono text-sm overflow-x-auto max-h-[30rem]", Code(:class => "language-julia", """using Therapy: Div, Button, P, Span, Strong
using Therapy: @island, create_signal, create_effect, js

@island function BatchDemo()
    a, set_a = create_signal(0)
    b, set_b = create_signal(0)

    # Effect reads BOTH signals — with auto-batch, fires once per click
    create_effect(() -> js("console.log('effect: a=', \\\$1, 'b=', \\\$2)", a(), b()))

    return Div(
        P("a=", Span(a), "  b=", Span(b)),
        Button(:on_click => () -> begin
            set_a(a() + 1)
            set_b(b() + 10)
        end, "Increment both"),
        Button(:on_click => () -> begin
            set_a(0)
            set_b(0)
        end, "Reset")
    )
end"""))
        ),

        # ── Signal Types ──
        Div(:class => "space-y-4",
            H2(:id => "signal-types", :class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Signal Types"),
            P(:class => "text-sm text-warm-600 dark:text-warm-400",
                "All four signal types compiled to WASM. ",
                Code(:class => "font-mono text-accent-500", "Int64"),
                " (i64 global), ",
                Code(:class => "font-mono text-accent-500", "Bool"),
                " (i32 global), ",
                Code(:class => "font-mono text-accent-500", "Float64"),
                " (f64 global), ",
                Code(:class => "font-mono text-accent-500", "String"),
                " (WasmGC ref global). Each type has its own WASM representation and JS bridge."),
            Div(:class => "flex justify-center py-6", SignalTypesDemo()),
            Pre(:class => "bg-warm-900 dark:bg-warm-950 text-warm-200 p-5 rounded-lg border border-warm-800 font-mono text-sm overflow-x-auto max-h-[30rem]", Code(:class => "language-julia", """@island function SignalTypesDemo()
    count, set_count = create_signal(0)        # Int64 → WASM i64
    active, set_active = create_signal(false)  # Bool → WASM i32
    temp, set_temp = create_signal(98.6)       # Float64 → WASM f64
    name, set_name = create_signal("")         # String → WasmGC ref

    create_effect(() -> js("console.log(\$1, \$2, \$3)", count(), active(), temp()))

    return Div(
        Button(:on_click => () -> set_count(count() + 1)),
        Button(:on_click => () -> set_active(!active())),
        Button(:on_click => () -> set_temp(temp() + 1.0)),
        Input(:type => "text", :on_input => set_name)
    )
end"""))
        ),

        # ── Data Table (SSR + Island) ──
        Div(:class => "space-y-4",
            H2(:id => "data-table", :class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Data Table"),
            P(:class => "text-sm text-warm-600 dark:text-warm-400",
                "Sortable, paginated table — all sorting runs in WebAssembly. ",
                Code(:class => "font-mono text-accent-500", "DataTable()"),
                " is an SSR function that passes four column vectors to ",
                Code(:class => "font-mono text-accent-500", "DataExplorer()"),
                ", an ",
                Code(:class => "font-mono text-accent-500", "@island"),
                " that sorts integer indices by the selected column using ",
                Code(:class => "font-mono text-accent-500", "isless()"),
                " on string values, compiled to WASM via the ",
                Code(:class => "font-mono text-accent-500", "cmp"),
                " overlay. Click any column header to toggle ascending/descending sort."),
            Div(:class => "py-6", DataTable()),
            Pre(:class => "bg-warm-900 dark:bg-warm-950 text-warm-200 p-5 rounded-lg border border-warm-800 font-mono text-sm overflow-x-auto max-h-[30rem]", Code(:class => "language-julia", "# TIER 1: SSR — split data into column vectors\nfunction DataTable()\n  names  = [\"Alice\", \"Bob\", \"Carol\", ...]\n  ages   = [\"28\", \"35\", \"42\", ...]\n  scores = [\"95.2\", \"87.1\", \"91.8\", ...]\n  cities = [\"Portland\", \"Austin\", \"Denver\", ...]\n  DataExplorer(col_names=names, col_ages=ages,\n    col_scores=scores, col_cities=cities)\nend\n\n# TIER 2: @island — WASM-compiled sorting\n@island function DataExplorer(;\n    col_names::Vector{String}=String[], ...)\n  visible_count, set_visible_count = create_signal(10)\n  sort_col, set_sort_col = create_signal(0)\n\n  # Memo: sort indices by selected column\n  visible_indices = create_memo(() -> begin\n    c = sort_col()\n    indices = Int64[]\n    for i in 1:length(col_names)\n      push!(indices, Int64(i))\n    end\n    if c == 1 || c == -1\n      # Insertion sort by col_names (isless compiles via cmp overlay)\n      for ii in 2:length(indices)\n        key_idx = indices[ii]\n        jj = ii - 1\n        while jj >= 1\n          if isless(col_names[indices[jj]], col_names[key_idx])\n            break\n          end\n          indices[jj+1] = indices[jj]; jj -= 1\n        end\n        indices[jj+1] = key_idx\n      end\n    end\n    indices[1:min(visible_count(), length(indices))]\n  end)\n\n  sort_by_name() = begin\n    if sort_col() == 1; set_sort_col(-1)\n    else; set_sort_col(1); end\n  end\n\n  Div(Table(\n    Thead(Tr(\n      Th(:on_click => sort_by_name, \"Name\"), ...)),\n    Tbody(For(visible_indices) do idx\n      Tr(Td(col_names[idx]), Td(col_ages[idx]),\n         Td(col_scores[idx]), Td(col_cities[idx]))\n    end)))\nend"))
        )
    ))
end
