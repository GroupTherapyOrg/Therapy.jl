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

        # ── Search Filter ──
        Div(:class => "space-y-4",
            H2(:class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Search Filter"),
            P(:class => "text-sm text-warm-600 dark:text-warm-400",
                "Text input → ", Code(:class => "font-mono text-accent-500", "create_memo"),
                " → ", Code(:class => "font-mono text-accent-500", "For()"),
                " re-render on every keystroke. Open console to see the effect log."),
            Div(:class => "flex justify-center py-6", SearchDemo()),
            Pre(:class => "bg-warm-900 dark:bg-warm-950 text-warm-200 p-5 rounded-lg border border-warm-800 font-mono text-sm overflow-x-auto max-h-[30rem]", Code(:class => "language-julia", """using Therapy: Div, Ul, Li, Input
using Therapy: @island, create_signal, create_memo, create_effect, For

@island function FilterableList(; items_data::Vector{String} = String[])
    items, _ = create_signal(items_data)
    query, set_query = create_signal("")

    # Recomputes on every keystroke
    filtered = create_memo(() -> filter_items(items(), query()))

    create_effect(() -> println("search: ", query(), " → found matches"))

    return Div(
        Input(:type => "text", :value => query, :on_input => set_query,
              :placeholder => "Search languages..."),
        Ul(For(filtered) do item
            Li(item)
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

        # ── Data Table ──
        Div(:class => "space-y-4",
            H2(:class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Data Table"),
            P(:class => "text-sm text-warm-600 dark:text-warm-400",
                "SSR with ", Code(:class => "font-mono text-accent-500", "DataFrames.jl"),
                " + interactive ", Code(:class => "font-mono text-accent-500", "For()"),
                " list rendering. Pure Julia — zero ", Code(:class => "font-mono text-accent-500", "js()"),
                " calls. Click headers to sort. Open console (F12) to see the effect log."),
            Div(:class => "flex justify-center py-6", DataTable()),
            Pre(:class => "bg-warm-900 dark:bg-warm-950 text-warm-200 p-5 rounded-lg border border-warm-800 font-mono text-sm overflow-x-auto max-h-[30rem]", Code(:class => "language-julia", """using Therapy: Div, Table, Thead, Tbody, Tr, Th, Td, Button
using Therapy: @island, create_signal, create_memo, create_effect
using Therapy: For, Show
using DataFrames: DataFrame, names, eachrow

# ── SSR Component (runs in Julia at build time) ──
# Just a normal Julia function — returns a VNode tree.
# Has full access to Julia packages (DataFrames, CSV, etc).
function DataTable()
    df = DataFrame(
        Name  = ["Alice", "Bob", ...],  # 25 rows
        Age   = [28, 35, ...],
        Score = [95.2, 87.1, ...],
        City  = ["Portland", "Austin", ...]
    )
    # Pass data as props to the interactive island
    return DataExplorer(
        columns_data = names(df),
        rows_data    = [string.(collect(row)) for row in eachrow(df)]
    )
end

# ── @island (compiled to JS, runs in browser) ──
# Receives props as typed kwargs. All Julia code here
# is compiled to JavaScript — no js() needed.
@island function DataExplorer(;
        columns_data::Vector{String} = String[],
        rows_data::Vector{Vector{String}} = Vector{String}[],
        ...
    )

    columns, _ = create_signal(columns_data)
    rows, _ = create_signal(rows_data)
    sort_col, set_sort_col = create_signal(0)
    visible_count, set_visible_count = create_signal(10)

    sorted_visible = create_memo(() -> ...)

    create_effect(() -> println("showing ", visible_count(), " rows"))

    return Div(
        Table(
            Thead(Tr(For(columns) do col, idx
                Th(:on_click => () -> set_sort_col(...), col)
            end)),
            Tbody(For(sorted_visible) do row
                Tr(For(row) do cell; Td(cell); end)
            end)
        ),
        Button(:on_click => () -> set_visible_count(visible_count() + 10),
            "⋮ show more"),
        Show(can_collapse) do
            Button(:on_click => () -> ..., "⋮ show less")
        end
    )
end"""))
        )
    )
end
