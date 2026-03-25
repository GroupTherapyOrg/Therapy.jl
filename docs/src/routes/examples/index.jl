() -> begin
    Div(:class => "space-y-8",
        H1(:class => "text-3xl font-serif font-bold text-warm-900 dark:text-warm-100", "Examples"),
        P(:class => "text-warm-500 dark:text-warm-400", "Interactive examples built with Therapy.jl"),
        
        H2(:class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Counter"),
        InteractiveCounter(initial=0),
        Pre(:class => "bg-warm-900 dark:bg-warm-950 text-warm-200 p-4 rounded-lg border border-warm-800 mt-4 font-mono text-sm overflow-x-auto", Code(:class => "language-julia", """@island function InteractiveCounter(; initial::Int = 0)
    count, set_count = create_signal(initial)
    Div(:class => "flex items-center gap-4",
        Button(:on_click => () -> set_count(count() - 1), "-"),
        Span(:class => "text-2xl font-mono", count),
        Button(:on_click => () -> set_count(count() + 1), "+")
    )
end"""))
    )
end
