() -> begin
    Div(:class => "space-y-12",
        H1(:class => "text-3xl font-serif font-bold text-warm-900 dark:text-warm-100", "Examples"),
        P(:class => "text-warm-500 dark:text-warm-400", "Interactive examples built with Therapy.jl. Each code snippet is the actual code running above it."),

        # ── Counter ──
        Div(:class => "space-y-4",
            H2(:class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Counter"),
            P(:class => "text-sm text-warm-500 dark:text-warm-400", "Signals, memos, and effects — open your browser console to see the effect logging."),
            Div(:class => "flex justify-center", InteractiveCounter(initial=0)),
            Pre(:class => "bg-warm-900 dark:bg-warm-950 text-warm-200 p-5 rounded-lg border border-warm-800 font-mono text-sm overflow-x-auto", Code(:class => "language-julia", """@island function InteractiveCounter(; initial::Int = 0)
    count, set_count = create_signal(initial)
    doubled = create_memo(() -> count() * 2)
    create_effect(() -> println("count: ", count(), " doubled: ", doubled()))

    Div(
        Button(:on_click => () -> set_count(count() - 1), "-"),
        Span(count),
        Button(:on_click => () -> set_count(count() + 1), "+"),
        P("doubled ", doubled)
    )
end"""))
        ),

        # ── Dark Mode Toggle ──
        Div(:class => "space-y-4",
            H2(:class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Dark Mode Toggle"),
            P(:class => "text-sm text-warm-500 dark:text-warm-400",
                "Signals + ", Code(:class => "font-mono text-accent-500", "js()"),
                " escape hatch for browser APIs. Try the toggle in the top-right corner of this page."),
            Pre(:class => "bg-warm-900 dark:bg-warm-950 text-warm-200 p-5 rounded-lg border border-warm-800 font-mono text-sm overflow-x-auto", Code(:class => "language-julia", """@island function DarkModeToggle()
    is_dark, set_dark = create_signal(0)
    Button(:on_click => () -> begin
        set_dark(1 - is_dark())
        js("document.documentElement.classList.toggle('dark')")
        js("localStorage.setItem('therapy-theme', ...)")
    end, "Toggle")
end"""))
        ),

        # ── Interactive Plot ──
        Div(:class => "space-y-4",
            H2(:class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Interactive Plot"),
            P(:class => "text-sm text-warm-500 dark:text-warm-400",
                "Pure Julia data generation compiled to JS. ",
                Code(:class => "font-mono text-accent-500", "scatter()"),
                ", ", Code(:class => "font-mono text-accent-500", "Layout()"),
                ", and ", Code(:class => "font-mono text-accent-500", "plotly()"),
                " compile to Plotly.js calls via JST's package registry."),
            Div(:class => "flex justify-center", InteractivePlot(frequency=5)),
            Pre(:class => "bg-warm-900 dark:bg-warm-950 text-warm-200 p-5 rounded-lg border border-warm-800 font-mono text-sm overflow-x-auto", Code(:class => "language-julia", """@island function InteractivePlot(; frequency::Int = 5)
    freq, set_freq = create_signal(frequency)

    create_effect(() -> begin
        f = freq()
        x = Float64[]
        for i in 1:100
            push!(x, Float64(i) * 0.1)
        end
        y = sin.(x .* Float64(f))

        # Pure Julia — no js() needed
        plotly("therapy-plot",
            [scatter(x=x, y=y, mode="lines")],
            Layout(title="sin(x * frequency)")
        )
    end)

    Div(
        Div(:id => "therapy-plot"),
        Input(:type => "range", :min => "1", :max => "20",
            :value => freq, :on_input => set_freq)
    )
end"""))
        ),

        # ── Data Table ──
        Div(:class => "space-y-4",
            H2(:class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Data Table"),
            P(:class => "text-sm text-warm-500 dark:text-warm-400",
                "Sortable table from Julia arrays. Click column headers to sort. Data compiles to JS arrays, rendering via ",
                Code(:class => "font-mono text-accent-500", "js()"),
                "."),
            Div(:class => "flex justify-center", DataTable()),
            Pre(:class => "bg-warm-900 dark:bg-warm-950 text-warm-200 p-5 rounded-lg border border-warm-800 font-mono text-sm overflow-x-auto", Code(:class => "language-julia", """@island function DataTable()
    sort_col, set_sort_col = create_signal(0)

    create_effect(() -> begin
        col = sort_col()

        # Julia arrays — compiled to JS
        names = ["Alice", "Bob", "Carol", "Dave", "Eve"]
        ages = [28, 35, 42, 23, 31]
        scores = [95.2, 87.1, 91.8, 78.4, 93.6]

        # Sort + render via js()
        js("/* sort by column, render <table> */")
    end)

    Div(:id => "therapy-table")
end"""))
        )
    )
end
