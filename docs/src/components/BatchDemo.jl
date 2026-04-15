# ── BatchDemo ──
# Demonstrates auto-batched event handlers (SolidJS behavior).
# Handler sets TWO signals. Without batch: effect fires twice.
# With batch: effect fires ONCE. Check console to verify.

@island function BatchDemo()
    a, set_a = create_signal(0)
    b, set_b = create_signal(0)

    # Effect reads BOTH signals — with auto-batch, fires once per click
    create_effect(() -> js("console.log('effect: a=', \$1, 'b=', \$2)", a(), b()))

    return Div(:class => "w-full max-w-sm mx-auto space-y-4",
        Div(:class => "text-center",
            P(:class => "text-lg font-medium text-warm-800 dark:text-warm-200 font-mono",
                "a=", Span(a), "  b=", Span(b))
        ),
        Div(:class => "flex justify-center gap-3",
            Button(
                :class => "px-3 py-1.5 rounded-lg bg-accent-600 hover:bg-accent-700 text-white text-sm font-medium transition-colors cursor-pointer",
                :on_click => () -> begin
                    set_a(a() + 1)
                    set_b(b() + 10)
                end,
                "Increment both"
            ),
            Button(
                :class => "px-3 py-1.5 rounded-lg bg-accent-600 hover:bg-accent-700 text-white text-sm font-medium transition-colors cursor-pointer",
                :on_click => () -> begin
                    set_a(0)
                    set_b(0)
                end,
                "Reset"
            )
        ),
        P(:class => "text-xs text-center text-warm-500 dark:text-warm-500",
            "Open console — each click logs ", Strong("one"), " effect, not two")
    )
end
