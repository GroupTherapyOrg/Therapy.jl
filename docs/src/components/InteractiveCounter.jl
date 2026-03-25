# Example island — compiled to JavaScript via JavaScriptTarget.jl
@island function InteractiveCounter(; initial::Int32 = Int32(0))
    count, set_count = create_signal(initial)
    Div(:class => "flex items-center gap-5",
        Button(:on_click => () -> set_count(count() - Int32(1)),
            :class => "w-10 h-10 flex items-center justify-center rounded-lg bg-warm-200 dark:bg-warm-800 hover:bg-accent-100 dark:hover:bg-accent-900 text-warm-700 dark:text-warm-300 hover:text-accent-700 dark:hover:text-accent-400 cursor-pointer transition-colors font-mono text-lg select-none active:scale-95", "-"),
        Span(:class => "text-3xl font-mono text-warm-900 dark:text-warm-100 min-w-[3ch] text-center", count),
        Button(:on_click => () -> set_count(count() + Int32(1)),
            :class => "w-10 h-10 flex items-center justify-center rounded-lg bg-warm-200 dark:bg-warm-800 hover:bg-accent-100 dark:hover:bg-accent-900 text-warm-700 dark:text-warm-300 hover:text-accent-700 dark:hover:text-accent-400 cursor-pointer transition-colors font-mono text-lg select-none active:scale-95", "+")
    )
end
