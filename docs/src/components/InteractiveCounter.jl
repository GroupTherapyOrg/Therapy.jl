# ── InteractiveCounter ──
# @island component — compiled to WebAssembly via WasmTarget.
# Demonstrates: create_signal, create_memo, create_effect.
# Effect println() compiles to console.log in browser.

@island function InteractiveCounter(; initial::Int = 0)
    # Signals
    count, set_count = create_signal(initial)

    # Memo: derived value, recomputes when count changes
    doubled = create_memo(() -> count() * 2)

    # Effect: runs on every count change → console.log in browser
    create_effect(() -> js("console.log('count:', \$1, 'doubled:', \$2)", count(), doubled()))

    # Return: VNode tree (the component UI)
    return Div(:class => "flex flex-col items-center gap-3",
        Div(:class => "flex items-center gap-5",
            Button(:on_click => () -> set_count(count() - 1),
                :class => "w-10 h-10 flex items-center justify-center rounded-lg bg-warm-200 dark:bg-warm-800 hover:bg-accent-100 dark:hover:bg-accent-900 text-warm-700 dark:text-warm-300 hover:text-accent-700 dark:hover:text-accent-400 cursor-pointer transition-colors font-mono text-lg select-none active:scale-95",
                "-"),
            Span(:class => "text-3xl font-mono text-warm-900 dark:text-warm-100 min-w-[3ch] text-center",
                count),
            Button(:on_click => () -> set_count(count() + 1),
                :class => "w-10 h-10 flex items-center justify-center rounded-lg bg-warm-200 dark:bg-warm-800 hover:bg-accent-100 dark:hover:bg-accent-900 text-warm-700 dark:text-warm-300 hover:text-accent-700 dark:hover:text-accent-400 cursor-pointer transition-colors font-mono text-lg select-none active:scale-95",
                "+")
        ),
        Span(:class => "text-xs font-mono px-3 py-1 rounded-full bg-warm-200/60 dark:bg-warm-800/60 text-warm-500 dark:text-warm-400",
            "doubled ", Span(:class => "text-accent-500", doubled))
    )
end
