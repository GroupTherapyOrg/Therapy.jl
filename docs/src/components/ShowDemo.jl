# ── ShowDemo ──
# Demonstrates SolidJS-style Show() with fallback — actual DOM insertion/removal.
# When visible: content is in the DOM. When hidden: fallback is shown instead.
# Also shows owner disposal: effects inside Show content are cleaned up on toggle.

@island function ShowDemo(; initial_visible::Int = 1)
    visible, set_visible = create_signal(initial_visible)

    create_effect(() -> js("console.log('ShowDemo visible:', \$1)", visible()))

    return Div(:class => "w-full max-w-md space-y-4 mx-auto",
        Div(:class => "flex justify-center",
            Button(
                :class => "px-4 py-2 rounded-lg bg-accent-600 hover:bg-accent-700 text-white font-medium transition-colors cursor-pointer",
                :on_click => () -> set_visible(1 - visible()),
                "Toggle Content"
            )
        ),

        # Show with fallback — like SolidJS: <Show when={visible()} fallback={<p>Hidden!</p>}>
        Show(visible; fallback=Div(
                :class => "p-4 rounded-lg border-2 border-dashed border-warm-400 dark:border-warm-600 text-warm-500 dark:text-warm-400 text-center",
                P(:class => "text-sm", "Content is hidden. Click Toggle to show it."),
                P(:class => "text-xs font-mono mt-1", "This is the ", Code(:class => "text-accent-500", "fallback"), " prop — swapped in when condition is false.")
            )) do
            Div(:class => "p-4 rounded-lg border-2 border-accent-500 bg-accent-50 dark:bg-accent-950/30 space-y-2",
                P(:class => "font-semibold text-accent-700 dark:text-accent-300",
                    "I exist in the DOM right now!"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400",
                    "Inspect this element — when you click Toggle, these nodes are completely ",
                    Strong("removed"), " and the fallback content appears instead.")
            )
        end
    )
end
