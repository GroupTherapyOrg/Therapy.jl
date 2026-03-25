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
                "Plotly.js via CDN + signals. The slider drives a signal, ",
                Code(:class => "font-mono text-accent-500", "create_effect"),
                " calls ", Code(:class => "font-mono text-accent-500", "Plotly.react()"),
                " via ", Code(:class => "font-mono text-accent-500", "js()"),
                " value passing."),
            Div(:class => "flex justify-center", InteractivePlot(frequency=5)),
            Pre(:class => "bg-warm-900 dark:bg-warm-950 text-warm-200 p-5 rounded-lg border border-warm-800 font-mono text-sm overflow-x-auto", Code(:class => "language-julia", """@island function InteractivePlot(; frequency::Int = 5)
    freq, set_freq = create_signal(frequency)

    create_effect(() -> begin
        js("var el = document.getElementById('therapy-plot')")
        js("if (!el) return")
        js("var f = \\\$1", freq())
        js("var x = []; var y = []")
        js("for (var i = 0; i < 100; i++) { x.push(i*0.1); y.push(Math.sin(i*0.1*f)) }")
        js("Plotly.react(el, [{x:x, y:y, type:'scatter', mode:'lines'}], {responsive:true})")
    end)

    Div(
        Div(:id => "therapy-plot"),
        Input(:type => "range", :min => "1", :max => "20",
            :value => freq, :on_input => set_freq)
    )
end"""))
        )
    )
end
