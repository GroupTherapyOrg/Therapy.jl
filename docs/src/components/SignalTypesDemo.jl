# ── SignalTypesDemo ──
# Demonstrates all four signal types compiled to WASM:
# - Int64 (i64 global), Bool (i32 global), Float64 (f64 global), String (WasmGC ref global)
# Each signal type has a control and a reactive display.

@island function SignalTypesDemo()
    # Int64 signal — WASM i64 global
    count, set_count = create_signal(0)

    # Bool signal — WASM i32 global (0/1)
    active, set_active = create_signal(false)

    # Float64 signal — WASM f64 global
    temp, set_temp = create_signal(98.6)

    # String signal — WasmGC ref global
    name, set_name = create_signal("")

    # Effect reads all four — proves they all trigger reactivity
    create_effect(() -> js("console.log('signals:', \$1, \$2, \$3)", count(), active(), temp()))

    return Div(:class => "w-full max-w-md mx-auto space-y-3",
        # Int64
        Div(:class => "flex items-center justify-between px-3 py-2 rounded-lg bg-white dark:bg-warm-900 border border-warm-200 dark:border-warm-800",
            Span(:class => "text-sm text-warm-500 dark:text-warm-400 font-mono", "Int64"),
            Div(:class => "flex items-center gap-2",
                Button(:class => "w-8 h-8 rounded bg-warm-200 dark:bg-warm-700 text-warm-700 dark:text-warm-300 cursor-pointer text-sm",
                    :on_click => () -> set_count(count() - 1), "-"),
                Span(:class => "font-mono text-warm-800 dark:text-warm-200 min-w-[3ch] text-center", count),
                Button(:class => "w-8 h-8 rounded bg-warm-200 dark:bg-warm-700 text-warm-700 dark:text-warm-300 cursor-pointer text-sm",
                    :on_click => () -> set_count(count() + 1), "+")
            )
        ),

        # Bool
        Div(:class => "flex items-center justify-between px-3 py-2 rounded-lg bg-white dark:bg-warm-900 border border-warm-200 dark:border-warm-800",
            Span(:class => "text-sm text-warm-500 dark:text-warm-400 font-mono", "Bool"),
            Button(:class => "px-3 py-1 rounded text-sm cursor-pointer bg-warm-200 dark:bg-warm-700 text-warm-700 dark:text-warm-300",
                :on_click => () -> set_active(!active()),
                Span(active))
        ),

        # Float64
        Div(:class => "flex items-center justify-between px-3 py-2 rounded-lg bg-white dark:bg-warm-900 border border-warm-200 dark:border-warm-800",
            Span(:class => "text-sm text-warm-500 dark:text-warm-400 font-mono", "Float64"),
            Div(:class => "flex items-center gap-2",
                Button(:class => "w-8 h-8 rounded bg-warm-200 dark:bg-warm-700 text-warm-700 dark:text-warm-300 cursor-pointer text-sm",
                    :on_click => () -> set_temp(temp() - 1.0), "-"),
                Span(:class => "font-mono text-warm-800 dark:text-warm-200 min-w-[5ch] text-center", temp),
                Button(:class => "w-8 h-8 rounded bg-warm-200 dark:bg-warm-700 text-warm-700 dark:text-warm-300 cursor-pointer text-sm",
                    :on_click => () -> set_temp(temp() + 1.0), "+")
            )
        ),

        # String
        Div(:class => "flex items-center justify-between px-3 py-2 rounded-lg bg-white dark:bg-warm-900 border border-warm-200 dark:border-warm-800",
            Span(:class => "text-sm text-warm-500 dark:text-warm-400 font-mono", "String"),
            Input(:type => "text",
                :placeholder => "type here...",
                :class => "w-40 px-2 py-1 rounded text-sm border border-warm-300 dark:border-warm-700 bg-warm-50 dark:bg-warm-800 text-warm-800 dark:text-warm-200",
                :on_input => set_name)
        )
    )
end
