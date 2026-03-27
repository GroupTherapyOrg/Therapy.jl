() -> begin
    Div(:class => "space-y-12",
        H1(:class => "text-3xl font-serif font-bold text-warm-900 dark:text-warm-100", "Examples"),
        P(:class => "text-warm-600 dark:text-warm-400",
            "Interactive examples built with Therapy.jl. Code snippets below are simplified — see the full source in ",
            A(:href => "https://github.com/GroupTherapyOrg/Therapy.jl/tree/main/docs/src/components",
                :target => "_blank",
                :class => "text-accent-500 hover:text-accent-600 underline",
                "docs/src/components"),
            "."),

        # ── Counter ──
        Div(:class => "space-y-4",
            H2(:class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Counter"),
            P(:class => "text-sm text-warm-600 dark:text-warm-400", "Signals, memos, and effects — open your browser console to see the effect logging."),
            Div(:class => "flex justify-center py-6", InteractiveCounter(initial=0)),
            Pre(:class => "bg-warm-900 dark:bg-warm-950 text-warm-200 p-5 rounded-lg border border-warm-800 font-mono text-sm overflow-x-auto max-h-[30rem]", Code(:class => "language-julia", """using Therapy: Div, Button, Span, P
using Therapy: @island, create_signal, create_memo, create_effect

@island function InteractiveCounter(; initial::Int = 0)
    count, set_count = create_signal(initial)
    doubled = create_memo(() -> count() * 2)
    create_effect(() -> println("count: ", count(), " doubled: ", doubled()))

    return Div(
        Button(:on_click => () -> set_count(count() - 1), "-"),
        Span(count),
        Button(:on_click => () -> set_count(count() + 1), "+"),
        P("doubled ", doubled)
    )
end"""))
        ),

        # ── Dark Mode Toggle (Cross-Island) ──
        Div(:class => "space-y-4",
            H2(:class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Dark Mode Toggle"),
            P(:class => "text-sm text-warm-600 dark:text-warm-400",
                "Cross-island signal sharing. This toggle and the one in the nav bar are separate ",
                Code(:class => "font-mono text-accent-500", "@island"),
                " instances that share a module-level signal — click either one and both stay in sync."),
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

    return Button(:on_click => () -> begin
        set_dark(1 - is_dark())
        js("document.documentElement.classList.toggle('dark')")
        js("localStorage.setItem('therapy-theme', ...)")
    end, "Toggle")
end"""))
        ),

        # ── Interactive Plot ──
        Div(:class => "space-y-4",
            H2(:class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Interactive Plot"),
            P(:class => "text-sm text-warm-600 dark:text-warm-400",
                "Standard ", Code(:class => "font-mono text-accent-500", "PlotlyBase"),
                " API — just ", Code(:class => "font-mono text-accent-500", "Plot()"),
                ", ", Code(:class => "font-mono text-accent-500", "scatter()"),
                ", ", Code(:class => "font-mono text-accent-500", "Layout()"),
                ". Therapy auto-compiles to Plotly.js via a package extension."),
            Div(:class => "flex justify-center py-6", InteractivePlot(frequency=5)),
            Pre(:class => "bg-warm-900 dark:bg-warm-950 text-warm-200 p-5 rounded-lg border border-warm-800 font-mono text-sm overflow-x-auto max-h-[30rem]", Code(:class => "language-julia", """using Therapy: Div, Input, Span
using Therapy: @island, create_signal, create_effect
import PlotlyBase  # auto-compiled via TherapyPlotlyBaseExt

@island function InteractivePlot(; frequency::Int = 5)
    freq, set_freq = create_signal(frequency)

    # Effect: recompute plot on slider change
    create_effect(() -> begin
        f = freq()
        x = Float64[]
        for i in 1:100
            push!(x, Float64(i) * 0.1)
        end
        y = sin.(x .* Float64(f))

        # Standard PlotlyBase — auto-compiled to Plotly.js
        PlotlyBase.Plot(
            [PlotlyBase.scatter(x=x, y=y, mode="lines")],
            PlotlyBase.Layout(title="sin(x * frequency)")
        )
    end)

    return Div(
        Div(:id => "therapy-plot"),
        Input(:type => "range", :min => "1", :max => "20",
            :value => freq, :on_input => set_freq)
    )
end"""))
        ),

        # ── Heatmap ──
        Div(:class => "space-y-4",
            H2(:class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "2D Heatmap"),
            P(:class => "text-sm text-warm-600 dark:text-warm-400",
                "ND arrays transpile to nested JS arrays — the native format Plotly expects for ",
                Code(:class => "font-mono text-accent-500", "heatmap(z=matrix)"),
                ". Drag the slider to change the frequency pattern."),
            Div(:class => "flex justify-center py-6", HeatmapDemo(freq_init=3)),
            Pre(:class => "bg-warm-900 dark:bg-warm-950 text-warm-200 p-5 rounded-lg border border-warm-800 font-mono text-sm overflow-x-auto max-h-[30rem]", Code(:class => "language-julia", """import PlotlyBase

@island function HeatmapDemo(; freq_init::Int = 3)
    freq, set_freq = create_signal(freq_init)

    create_effect(() -> begin
        f = Float64(freq())
        rows = 30
        cols = 30

        # zeros(rows, cols) → nested JS array [[0,...],[0,...],...]
        z = zeros(rows, cols)
        for i in 1:rows
            for j in 1:cols
                x = Float64(i) / Float64(rows)
                y = Float64(j) / Float64(cols)
                z[i, j] = sin(x * f) * cos(y * f)
            end
        end

        # z is nested — Plotly accepts it directly
        PlotlyBase.Plot(
            [PlotlyBase.heatmap(z=z, colorscale="Viridis")],
            PlotlyBase.Layout(title="sin(x*f) * cos(y*f)")
        )
    end)

    return Div(
        Div(:id => "therapy-plot"),
        Input(:type => "range", :min => "1", :max => "20",
            :value => freq, :on_input => set_freq)
    )
end"""))
        ),

        # ── Search Filter ──
        Div(:class => "space-y-4",
            H2(:class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Search Filter"),
            P(:class => "text-sm text-warm-600 dark:text-warm-400",
                "Text input → ", Code(:class => "font-mono text-accent-500", "create_memo"),
                " → ", Code(:class => "font-mono text-accent-500", "For()"),
                " re-render on every keystroke. Open console to see the effect log."),
            Div(:class => "flex justify-center py-6", SearchDemo()),
            Pre(:class => "bg-warm-900 dark:bg-warm-950 text-warm-200 p-5 rounded-lg border border-warm-800 font-mono text-sm overflow-x-auto max-h-[30rem]", Code(:class => "language-julia", """using Therapy: Div, Input, For
using Therapy: @island, create_signal, create_memo

@island function FilterableList(; items_data::Vector{String} = String[])
    items, _ = create_signal(items_data)
    query, set_query = create_signal("")
    visible_count, set_visible_count = create_signal(12)

    # filter() and lowercase() transpile directly to JS
    visible_items = create_memo(() -> begin
        all_items = items()
        q = query()
        n = visible_count()
        filtered = if length(q) == 0
            all_items
        else
            ql = lowercase(q)
            filter(item -> contains(lowercase(item), ql), all_items)
        end
        result = String[]
        for i in 1:min(n, length(filtered))
            push!(result, filtered[i])
        end
        result
    end)

    return Div(
        Input(:type => "text", :on_input => set_query,
              :placeholder => "Search languages..."),
        Div(For(visible_items) do item
            Div(item)
        end)
    )
end"""))
        ),

        # ── Show with Fallback ──
        Div(:class => "space-y-4",
            H2(:class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Show with Fallback"),
            P(:class => "text-sm text-warm-600 dark:text-warm-400",
                "SolidJS-style ", Code(:class => "font-mono text-accent-500", "Show()"),
                " — content is actually inserted/removed from the DOM (not ", Code(:class => "font-mono", "display:none"),
                "). The ", Code(:class => "font-mono text-accent-500", "fallback"),
                " prop renders alternative content when the condition is false."),
            Div(:class => "flex justify-center py-6", ShowDemo(initial_visible=1)),
            Pre(:class => "bg-warm-900 dark:bg-warm-950 text-warm-200 p-5 rounded-lg border border-warm-800 font-mono text-sm overflow-x-auto max-h-[30rem]", Code(:class => "language-julia", """using Therapy: Div, P, Button, Code, Strong
using Therapy: @island, create_signal, create_effect, Show

@island function ShowDemo(; initial_visible::Int = 1)
    visible, set_visible = create_signal(initial_visible)

    create_effect(() -> println(
        visible() == 1 ? "content INSERTED" : "content REMOVED"
    ))

    return Div(
        Button(:on_click => () -> set_visible(1 - visible()), "Toggle"),

        # SolidJS-style: Show with fallback
        Show(visible; fallback=P("Content is hidden.")) do
            Div("I exist in the DOM right now!")
        end
    )
end"""))
        ),

        # ── Batch ──
        Div(:class => "space-y-4",
            H2(:class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Auto-Batched Handlers"),
            P(:class => "text-sm text-warm-600 dark:text-warm-400",
                "Like SolidJS, all DOM event handlers are auto-batched. Setting multiple signals in one handler triggers effects ",
                Strong("once"), " (not once per signal). Open console — each click logs one render, not two."),
            Div(:class => "flex justify-center py-6", BatchDemo(first_init="Alice", last_init="Smith")),
            Pre(:class => "bg-warm-900 dark:bg-warm-950 text-warm-200 p-5 rounded-lg border border-warm-800 font-mono text-sm overflow-x-auto max-h-[30rem]", Code(:class => "language-julia", """using Therapy: Div, P, Button
using Therapy: @island, create_signal, create_effect

@island function BatchDemo()
    first, set_first = create_signal("Alice")
    last, set_last = create_signal("Smith")

    # Effect reads BOTH signals
    # Auto-batch: fires ONCE per click (not twice)
    create_effect(() -> println("name: ", first(), " ", last()))

    return Div(
        P(first, " ", last),
        Button(:on_click => () -> begin
            set_first("Bob")     # deferred
            set_last("Jones")    # deferred
        end, "Set Bob Jones")    # effect fires once here
    )
end"""))
        ),

        # ── Data Table ──
        Div(:class => "space-y-4",
            H2(:class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Data Table"),
            P(:class => "text-sm text-warm-600 dark:text-warm-400",
                "SSR with ", Code(:class => "font-mono text-accent-500", "DataFrames.jl"),
                " + interactive ", Code(:class => "font-mono text-accent-500", "For()"),
                " list rendering. Pure Julia — zero ", Code(:class => "font-mono text-accent-500", "js()"),
                " calls. Click headers to sort. Open console (F12) to see the effect log."),
            Div(:class => "flex justify-center py-6", DataTable()),
            Pre(:class => "bg-warm-900 dark:bg-warm-950 text-warm-200 p-5 rounded-lg border border-warm-800 font-mono text-sm overflow-x-auto max-h-[30rem]", Code(:class => "language-julia", """using Therapy: Div, Table, Thead, Tbody, Tr, Th, Td
using Therapy: @island, create_signal, create_memo, For

@island function DataExplorer(;
        columns_data::Vector{String} = String[],
        rows_data::Vector{Vector{String}} = Vector{String}[]
    )
    columns, _ = create_signal(columns_data)
    rows, _ = create_signal(rows_data)
    sort_col, set_sort_col = create_signal(0)
    visible_count, set_visible_count = create_signal(10)

    # sort() and filter() transpile directly — no helpers needed
    sorted_visible = create_memo(() -> begin
        data = rows()
        c = sort_col()
        n = visible_count()
        sorted = if c == 0
            data
        else
            ci = c > 0 ? c : -c
            sort(data, by = r -> r[ci], rev = c < 0)
        end
        result = Vector{Vector{String}}()
        for i in 1:min(n, length(sorted))
            push!(result, sorted[i])
        end
        result
    end)

    return Div(Table(
        Thead(Tr(For(columns) do col, idx
            Th(:on_click => () -> set_sort_col(
                sort_col() == idx ? -idx : idx), col)
        end)),
        Tbody(For(sorted_visible) do row
            Tr(For(row) do cell; Td(cell); end)
        end)
    ))
end"""))
        ),

        # ── on_mount ──
        Div(:class => "space-y-4",
            H2(:class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "on_mount"),
            P(:class => "text-sm text-warm-600 dark:text-warm-400",
                "SolidJS-style ", Code(:class => "font-mono text-accent-500", "onMount"),
                " — runs once after the component hydrates. Unlike ", Code(:class => "font-mono text-accent-500", "create_effect"),
                ", it does NOT track dependencies and never re-runs. Use for one-time DOM initialization, third-party library setup, or focusing inputs."),
            Pre(:class => "bg-warm-900 dark:bg-warm-950 text-warm-200 p-5 rounded-lg border border-warm-800 font-mono text-sm overflow-x-auto max-h-[30rem]", Code(:class => "language-julia", """using Therapy: Div, Input
using Therapy: @island, create_signal, on_mount, js

@island function AutoFocusInput()
    query, set_query = create_signal("")

    # Runs ONCE after hydration — no dependency tracking
    on_mount() do
        js("document.querySelector('[data-autofocus]').focus()")
    end

    return Div(
        Input(:type => "text", :on_input => set_query,
              \"data-autofocus\" => \"true\",
              :placeholder => "I focus automatically on mount...")
    )
end"""))
        )
    )
end
