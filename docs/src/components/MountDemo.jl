# ── MountDemo ──
# Demonstrates the difference between on_mount (runs once) and
# create_effect (re-runs on every signal change).
# Open browser console (F12) to see the output.

@island function MountDemo()
    count, set_count = create_signal(0)

    # Runs ONCE after hydration — never again
    on_mount(() -> println("on_mount: I ran once!"))

    # Runs on every count() change
    create_effect(() -> println("create_effect: count is ", count()))

    return Div(:class => "w-full max-w-md space-y-3",
        Div(:class => "flex items-center gap-4",
            Button(
                :class => "px-4 py-2 rounded-lg bg-accent-500 text-white font-semibold hover:bg-accent-600 transition-colors cursor-pointer",
                :on_click => () -> set_count(count() + 1),
                "Click me"
            ),
            P(:class => "text-warm-700 dark:text-warm-300 font-mono", "count: ", count)
        ),
        P(:class => "text-xs text-warm-500 dark:text-warm-500 italic",
            "Open console (F12) — on_mount prints once, create_effect prints on every click.")
    )
end
