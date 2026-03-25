# ── ShowDemo ──
# Demonstrates SolidJS-style Show() — actual DOM insertion/removal, not display:none.
# Open DevTools Elements panel and watch the <span data-show> wrapper:
#   - When hidden: its innerHTML is EMPTY (nodes removed from DOM)
#   - When shown:  nodes are RE-INSERTED and handlers re-wired
# Console (F12) logs "content INSERTED" / "content REMOVED" on every toggle.

@island function ShowDemo(; initial_visible::Int = 1)
    visible, set_visible = create_signal(initial_visible)

    # Effect: logs DOM lifecycle to console
    create_effect(() -> println(
        visible() == 1 ? "Show: content INSERTED into DOM" : "Show: content REMOVED from DOM"
    ))

    return Div(:class => "w-full max-w-md space-y-4",
        # Toggle button
        Button(
            :class => "px-4 py-2 rounded-lg bg-accent-600 hover:bg-accent-700 text-white font-medium transition-colors cursor-pointer",
            :on_click => () -> set_visible(1 - visible()),
            "Toggle Content"
        ),

        # Show: content is actually added/removed from the DOM
        Show(visible) do
            Div(:class => "p-4 rounded-lg border-2 border-accent-500 bg-accent-50 dark:bg-accent-950/30 space-y-2",
                P(:class => "font-semibold text-accent-700 dark:text-accent-300",
                    "I exist in the DOM right now!"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400",
                    "Inspect this element — when you click Toggle, these nodes are completely ",
                    Strong("removed"), " from the DOM tree, not just hidden with CSS."),
                P(:class => "text-xs font-mono text-warm-500 dark:text-warm-500",
                    "Right-click → Inspect the ",
                    Code(:class => "text-accent-500", "<span data-show>"),
                    " wrapper to see it empty out.")
            )
        end
    )
end
