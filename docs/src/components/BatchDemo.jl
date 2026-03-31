# TEMPORARILY DISABLED — home-page-only rebuild
#=
# ── BatchDemo ──
# Demonstrates auto-batched event handlers (SolidJS behavior).
# Handler sets TWO signals. Without batch: effect fires twice.
# With batch: effect fires ONCE. Check console to verify.

@island function BatchDemo(; first_init::String = "Alice", last_init::String = "Smith")
    first, set_first = create_signal(first_init)
    last, set_last = create_signal(last_init)

    # Effect reads BOTH signals — with auto-batch, fires once per click
    create_effect(() -> println("name: ", first(), " ", last()))

    return Div(:class => "w-full max-w-sm mx-auto space-y-4",
        Div(:class => "text-center",
            P(:class => "text-lg font-medium text-warm-800 dark:text-warm-200",
                Span(first), " ", Span(last))
        ),
        Div(:class => "flex justify-center gap-3",
            Button(
                :class => "px-3 py-1.5 rounded-lg bg-accent-600 hover:bg-accent-700 text-white text-sm font-medium transition-colors cursor-pointer",
                :on_click => () -> begin
                    set_first("Bob")
                    set_last("Jones")
                end,
                "Set Bob Jones"
            ),
            Button(
                :class => "px-3 py-1.5 rounded-lg bg-accent-600 hover:bg-accent-700 text-white text-sm font-medium transition-colors cursor-pointer",
                :on_click => () -> begin
                    set_first("Alice")
                    set_last("Smith")
                end,
                "Set Alice Smith"
            )
        ),
        P(:class => "text-xs text-center text-warm-500 dark:text-warm-500",
            "Open console — each click logs ", Strong("one"), " render, not two")
    )
end
=#
