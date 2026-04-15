# ── TodoDemo ──
# Demonstrates For() list rendering with dynamic item count, memo-derived
# visible items, and Show() conditions — the closest we can get to a
# Leptos-style todo list without Vector-typed signal mutation in handlers.
#
# Architecture:
# - items_data: constant Vector{String} embedded in WASM at build time
# - remaining: integer signal (i64 global) — how many items to show
# - total: integer signal (i64 global) — total count (for Show conditions)
# - visible: memo returns Vector{String} (first N items from items_data)
# - For(visible) re-renders when remaining changes (items shrink/grow)
# - Show() buttons conditioned on remaining vs total (both signals)
# - Effect logs remaining count changes
#
# What this tests:
# - For() item removal/addition (owner disposal when items shrink)
# - Memo returning Vector{String} (WasmGC ref) derived from integer signal
# - Show() with closure conditions comparing two signals
# - create_effect with js() console logging

# ─── SSR Component ───

function TodoDemo()
    return TodoList(items_data=["Buy milk", "Write Julia code", "Ship to production", "Review PR", "Fix tests"])
end

# ─── @island Component ───

@island function TodoList(;
        items_data::Vector{String} = String[]
    )
    # Integer signal: how many items remain (starts at total, decrements)
    remaining, set_remaining = create_signal(length(items_data))

    # Integer signal: total item count (constant — for Show() conditions)
    total, _ = create_signal(length(items_data))

    # Memo: build the visible items list (first N of items_data)
    visible = create_memo(() -> begin
        n = remaining()
        result = String[]
        for i in 1:min(n, length(items_data))
            push!(result, items_data[i])
        end
        result
    end)

    # Effect: log when count changes
    create_effect(() -> js("console.log('todo remaining:', \$1)", remaining()))

    return Div(:class => "w-full max-w-md mx-auto space-y-4",
        # Header with count
        Div(:class => "flex items-center justify-between",
            H3(:class => "text-lg font-semibold text-warm-800 dark:text-warm-200", "Todos"),
            Span(:class => "text-sm text-warm-500 dark:text-warm-400 font-mono tabular-nums",
                Span(remaining), " / $(length(items_data))")
        ),

        # Todo list
        Div(:class => "space-y-2",
            For(visible) do item
                Div(:class => "flex items-center px-3 py-2 rounded-lg bg-white dark:bg-warm-900 border border-warm-200 dark:border-warm-800",
                    Span(:class => "text-sm text-warm-700 dark:text-warm-300", item)
                )
            end
        ),

        # Action buttons
        Div(:class => "flex items-center justify-center gap-3",
            # Remove last: visible when remaining > 0
            Show(() -> remaining() > 0) do
                Button(
                    :class => "px-4 py-2 rounded-lg text-sm bg-red-50 dark:bg-red-950/30 text-red-600 dark:text-red-400 border border-red-200 dark:border-red-800 hover:bg-red-100 dark:hover:bg-red-900/40 transition-colors cursor-pointer",
                    :on_click => () -> set_remaining(remaining() - 1),
                    "Remove last"
                )
            end,
            # Add back: visible when remaining < total (both signals, no non-signal captures)
            Show(() -> remaining() < total()) do
                Button(
                    :class => "px-4 py-2 rounded-lg text-sm bg-accent-50 dark:bg-accent-950/30 text-accent-600 dark:text-accent-400 border border-accent-200 dark:border-accent-800 hover:bg-accent-100 dark:hover:bg-accent-900/40 transition-colors cursor-pointer",
                    :on_click => () -> set_remaining(remaining() + 1),
                    "Add back"
                )
            end
        ),

        # Helper text
        Show(() -> remaining() > 0) do
            P(:class => "text-xs text-center text-warm-400 dark:text-warm-500",
                "Click 'Remove last' to shrink the list")
        end
    )
end
