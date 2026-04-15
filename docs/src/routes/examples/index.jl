() -> begin
    sections = [
        ("counter", "Counter"),
        ("dark-mode", "Dark Mode Toggle"),
        ("search", "Search"),
        ("todo", "Todo List"),
        ("show", "Show / Fallback"),
        ("lifecycle", "Mount vs Effect"),
        ("batching", "Auto-Batching"),
        ("signal-types", "Signal Types"),
        ("data-table", "Data Table"),
        ("interactive-dashboard", "Plot Dashboard"),
        ("notebook", "Notebook"),
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
        ),

        # ── Plot Dashboard ──
        Div(:class => "space-y-4",
            H2(:id => "interactive-dashboard", :class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Plot Dashboard"),
            P(:class => "text-sm text-warm-600 dark:text-warm-400",
                "One ",
                Code(:class => "font-mono text-accent-500", "@island"),
                ", one ",
                Code(:class => "font-mono text-accent-500", "<canvas>"),
                ", one ",
                Code(:class => "font-mono text-accent-500", "WasmPlot.Figure"),
                " with four ",
                Code(:class => "font-mono text-accent-500", "Axis"),
                " subplots — driven by three signals (",
                Code(:class => "font-mono text-accent-500", "freq"),
                ", ",
                Code(:class => "font-mono text-accent-500", "n_pts"),
                ", ",
                Code(:class => "font-mono text-accent-500", "shift"),
                "). Each signal touches a unique plot AND a shared one: adjusting ",
                Code(:class => "font-mono text-accent-500", "freq"),
                " redraws both the line plot and the heatmap; ",
                Code(:class => "font-mono text-accent-500", "n_pts"),
                " updates the scatter and the line; ",
                Code(:class => "font-mono text-accent-500", "shift"),
                " rotates the barplot and shifts the heatmap phase. Every redraw is a single signal → effect → ",
                Code(:class => "font-mono text-accent-500", "render!"),
                " pass."),
            Div(:class => "flex justify-center py-6", InteractivePlotDashboard()),
            Pre(:class => "bg-warm-900 dark:bg-warm-950 text-warm-200 p-5 rounded-lg border border-warm-800 font-mono text-sm overflow-x-auto max-h-[40rem]", Code(:class => "language-julia", """using WasmPlot
using Therapy: @island, create_signal, create_effect, Div, Span, Button, Canvas

@island function InteractivePlotDashboard()
    # Three independent signals driving four subplots
    freq,  set_freq  = create_signal(Int64(3))
    n_pts, set_n_pts = create_signal(Int64(12))
    shift, set_shift = create_signal(Int64(0))

    # SINGLE effect — reads all three signals, (re)builds fig + 4 axes, renders once
    create_effect(() -> begin
        f = Float64(freq()); npts = Int64(n_pts()); sh = Int64(shift())
        phase = Float64(sh) * 0.5

        fig = WasmPlot.Figure(size=(1000, 560))

        # [1,1] lines — depends on freq + n_pts. Makie convention: title + subtitle.
        ax_ln = Axis(fig[1, 1]; title="lines!", subtitle="depends on freq + n_pts",
                                xlabel="x", ylabel="sin(freq*x)")
        n_ln = npts * Int64(12); xs_ln = Float64[]; ys_ln = Float64[]
        i = Int64(1)
        while i <= n_ln
            xi = Float64(i) / Float64(n_ln) * 6.28318
            push!(xs_ln, xi); push!(ys_ln, sin(xi * f))
            i += Int64(1)
        end
        lines!(ax_ln, xs_ln, ys_ln; color=:blue, linewidth=2.0)

        # [1,2] scatter — depends on n_pts
        ax_sc = Axis(fig[1, 2]; title="scatter!", subtitle="depends on n_pts", xlabel="x", ylabel="y")
        xs_sc = Float64[]; ys_sc = Float64[]; seed = UInt64(1); j = Int64(1)
        while j <= npts
            seed = seed * UInt64(6364136223846793005) + UInt64(1442695040888963407)
            push!(xs_sc, Float64(seed >> 32) / Float64(typemax(UInt32)) * 10.0)
            seed = seed * UInt64(6364136223846793005) + UInt64(1442695040888963407)
            push!(ys_sc, Float64(seed >> 32) / Float64(typemax(UInt32)) * 10.0)
            j += Int64(1)
        end
        scatter!(ax_sc, xs_sc, ys_sc; color=:red, markersize=8.0)

        # [2,1] barplot — depends on shift
        ax_bp = Axis(fig[2, 1]; title="barplot!", subtitle="depends on shift", xlabel="category", ylabel="value")
        base = Float64[3.0, 7.0, 2.0, 5.0, 8.0, 4.0, 6.0]
        xs_bp = Float64[]; hs_bp = Float64[]; nb = length(base); k = Int64(1)
        while k <= nb
            push!(xs_bp, Float64(k))
            idx = (k - Int64(1) + sh) % Int64(nb)
            if idx < Int64(0); idx += Int64(nb); end
            push!(hs_bp, base[idx + Int64(1)])
            k += Int64(1)
        end
        barplot!(ax_bp, xs_bp, hs_bp; color=:green)

        # [2,2] heatmap — depends on freq + shift
        ax_hm = Axis(fig[2, 2]; title="heatmap!", subtitle="depends on freq + shift",
                                xlabel="x", ylabel="y")
        nx = Int64(20); ny = Int64(12); values = Float64[]; row = Int64(0)
        while row < ny
            col = Int64(0)
            while col < nx
                x = Float64(col) / Float64(nx) * 6.28318
                y = Float64(row) / Float64(ny) * 6.28318
                push!(values, sin(x * f + phase) * cos(y * f))
                col += Int64(1)
            end
            row += Int64(1)
        end
        heatmap!(ax_hm, (0.0, 10.0), (0.0, 6.0), Int(nx), Int(ny), values)

        render!(fig)   # single pass — all 4 subplots drawn together
    end)

    # Return the island's DOM tree.
    #
    # The `Canvas()` element renders a plain `<canvas>` — no prop wires it to
    # WasmPlot. The connection happens inside Therapy's runtime: when the island
    # hydrates, `__tw.io(island)` (WasmRuntime.jl) auto-detects any `<canvas>`
    # child with `el.querySelector('canvas')` and grabs its 2D context, then
    # supplies it as the `canvas2d` namespace in the WASM import object. Every
    # call WasmPlot makes to `canvas_move_to`, `canvas_fill`, `canvas_stroke`,
    # etc. routes through that context. So Canvas() "just shows up" because
    # Therapy silently wires the 2D context to WasmPlot's import stubs at
    # instantiate time — no user-visible plumbing needed.
    return Div(
        Canvas(:width => 1000, :height => 560),
        Div(
            Span("freq"),
            Button(:on_click => () -> set_freq(freq() - Int64(1)), "-"),
            Span(freq),
            Button(:on_click => () -> set_freq(freq() + Int64(1)), "+"),
        ),
        Div(
            Span("n_pts"),
            Button(:on_click => () -> set_n_pts(n_pts() - Int64(4)), "-"),
            Span(n_pts),
            Button(:on_click => () -> set_n_pts(n_pts() + Int64(4)), "+"),
        ),
        Div(
            Span("shift"),
            Button(:on_click => () -> set_shift(shift() - Int64(1)), "-"),
            Span(shift),
            Button(:on_click => () -> set_shift(shift() + Int64(1)), "+"),
        ),
    )
end"""))
        ),

        # ── Notebook (single section — all 6 stress-test steps inline) ──
        Div(:class => "space-y-4",
            H2(:id => "notebook", :class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Notebook"),
            P(:class => "text-sm text-warm-600 dark:text-warm-400",
                "The full notebook UI built up in six steps. Each step composes the previous: static cells → visibility toggles → a slider-driven memo → a reactive WasmPlot chart → multiple inputs → a full published-notebook layout."),

            # Step 1
            Div(:class => "pt-4",
                P(:class => "font-semibold text-warm-800 dark:text-warm-200 mb-1", "Step 1: Static Code Cells"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400",
                    "The building block — a read-only code cell with its output. Cell numbers appear on hover."),
                Div(:class => "py-4", NotebookDemo()),
            ),

            # Step 2
            Div(:class => "pt-4",
                P(:class => "font-semibold text-warm-800 dark:text-warm-200 mb-1", "Step 2: Cell Visibility"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400",
                    "Hover the left gutter and click the eye to toggle a cell's code. Each cell owns its own ",
                    Code(:class => "font-mono text-accent-500", "create_signal"),
                    "; ",
                    Code(:class => "font-mono text-accent-500", "Show"),
                    " inserts / removes the code block from the DOM on toggle."),
                Div(:class => "py-4", NotebookDemo2()),
            ),

            # Step 3
            Div(:class => "pt-4",
                P(:class => "font-semibold text-warm-800 dark:text-warm-200 mb-1", "Step 3: Slider → Reactive Output"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400",
                    "The ",
                    Code(:class => "font-mono text-accent-500", "@bind"),
                    " pattern. A slider signal drives a ",
                    Code(:class => "font-mono text-accent-500", "create_memo"),
                    " — the dependent cell updates whenever the slider moves."),
                Div(:class => "py-4", NotebookDemo3()),
            ),

            # Step 4
            Div(:class => "pt-4",
                P(:class => "font-semibold text-warm-800 dark:text-warm-200 mb-1", "Step 4: Reactive Plot"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400",
                    "Slider → computation → WasmPlot ",
                    Code(:class => "font-mono text-accent-500", "lines!"),
                    " chart. The signal drives a 3-cell reactive chain compiled to WebAssembly. Each cell has its own eye toggle."),
                Div(:class => "py-4", NotebookDemo4()),
            ),

            # Step 5
            Div(:class => "pt-4",
                P(:class => "font-semibold text-warm-800 dark:text-warm-200 mb-1", "Step 5: Multiple Inputs"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400",
                    "Two ",
                    Code(:class => "font-mono text-accent-500", "@bind"),
                    " sliders feed one ",
                    Code(:class => "font-mono text-accent-500", "create_memo"),
                    ". Handlers are auto-batched — changing either slider fires the dependent effect exactly once."),
                Div(:class => "py-4", NotebookDemo5()),
            ),

            # Step 6
            Div(:class => "pt-4",
                P(:class => "font-semibold text-warm-800 dark:text-warm-200 mb-1", "Step 6: Full Published Notebook"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400",
                    "Everything composed: tab bar, markdown, interactive ",
                    Code(:class => "font-mono text-accent-500", "@bind"),
                    " → WasmPlot heatmap, static cells with diagnostic badges, eye toggles, runtime badges, and ",
                    Code(:class => "font-mono text-accent-500", "on_mount"),
                    " lifecycle. This is what a Sessions.jl published notebook will look like."),
                Div(:class => "py-4", NotebookDemo6()),
            ),
        ),

    ))
end
