# ── DataTable ──
# Two-tier SSR + Island pattern (Astro/Fresh style):
#
# TIER 1 — DataTable() is a plain Julia function (SSR).
#   Runs at BUILD TIME on the server. Full Julia package access.
#   Renders the complete HTML table with all 20 rows.
#
# TIER 2 — TableControls() is an @island (compiled to WASM).
#   Runs in the BROWSER. Controls pagination with integer signals.
#   Show more/less buttons toggle how many rows are visible via JS effect.
#
# The table DATA is server-rendered HTML. The INTERACTIVITY is a tiny island.
# This is the core SSR + Islands insight: static content from the server,
# interactive controls as small WASM modules.

# ─── Tier 1: SSR Component (runs on server, ships HTML only) ───

function DataTable()
    # Full Julia access — could use DataFrames.jl, CSV.jl, DB queries, etc.
    data = [
        ("Alice",   28, 95.2, "Portland"),
        ("Bob",     35, 87.1, "Austin"),
        ("Carol",   42, 91.8, "Denver"),
        ("Dave",    23, 78.4, "Seattle"),
        ("Eve",     31, 93.6, "Boston"),
        ("Frank",   45, 82.3, "Chicago"),
        ("Grace",   27, 96.1, "Miami"),
        ("Heidi",   33, 88.5, "Phoenix"),
        ("Ivan",    29, 90.3, "Dallas"),
        ("Judy",    38, 84.7, "Atlanta"),
        ("Karl",    41, 76.9, "Detroit"),
        ("Laura",   26, 94.2, "Oakland"),
        ("Mallory", 34, 89.1, "Tampa"),
        ("Niaj",    30, 85.6, "Raleigh"),
        ("Oscar",   36, 92.4, "Nashville"),
        ("Peggy",   24, 79.8, "Memphis"),
        ("Quinn",   39, 86.3, "Richmond"),
        ("Rupert",  44, 77.5, "Boulder"),
        ("Sybil",   32, 91.1, "Eugene"),
        ("Trent",   37, 83.9, "Tucson")
    ]

    return Div(:class => "w-full max-w-3xl mx-auto space-y-3",
        # Table — pure SSR HTML, zero JavaScript
        Div(:class => "rounded-lg border border-warm-200 dark:border-warm-800 overflow-hidden",
            Table(:class => "w-full text-sm",
                Thead(
                    Tr(:class => "bg-warm-100 dark:bg-warm-900",
                        Th(:class => "text-left px-4 py-2.5 font-semibold text-warm-700 dark:text-warm-300", "Name"),
                        Th(:class => "text-left px-4 py-2.5 font-semibold text-warm-700 dark:text-warm-300", "Age"),
                        Th(:class => "text-left px-4 py-2.5 font-semibold text-warm-700 dark:text-warm-300", "Score"),
                        Th(:class => "text-left px-4 py-2.5 font-semibold text-warm-700 dark:text-warm-300", "City")
                    )
                ),
                Tbody(:id => "table-body",
                    [Tr(:class => "border-t border-warm-100 dark:border-warm-900 $(i > 10 ? "hidden" : "")",
                        Symbol("data-row") => string(i),
                        Td(:class => "px-4 py-2 text-warm-800 dark:text-warm-200", name),
                        Td(:class => "px-4 py-2 text-warm-600 dark:text-warm-400 font-mono", string(age)),
                        Td(:class => "px-4 py-2 text-warm-600 dark:text-warm-400 font-mono", string(score)),
                        Td(:class => "px-4 py-2 text-warm-600 dark:text-warm-400", city)
                    ) for (i, (name, age, score, city)) in enumerate(data)]...
                )
            )
        ),
        # Interactive controls — tiny island for pagination
        TableControls(total=length(data))
    )
end

# ─── Tier 2: @island Component (compiled to WASM) ───

@island function TableControls(; total::Int = 20)
    visible, set_visible = create_signal(10)
    total_count, _ = create_signal(total)

    # Effect: show/hide table rows via JS DOM manipulation
    create_effect(() -> begin
        n = visible()
        js("var rows=document.querySelectorAll('#table-body tr');for(var i=0;i<rows.length;i++){rows[i].classList.toggle('hidden',i>=\$1)}", n)
    end)

    create_effect(() -> js("console.log('table: showing', \$1, 'of', \$2)", visible(), total_count()))

    return Div(:class => "flex items-center justify-center gap-4",
        Show(() -> visible() < total_count()) do
            Button(
                :class => "text-sm text-warm-500 dark:text-warm-400 hover:text-accent-500 transition-colors cursor-pointer",
                :on_click => () -> set_visible(visible() + 10),
                "show more"
            )
        end,
        Show(() -> visible() > 10) do
            Button(
                :class => "text-sm text-warm-500 dark:text-warm-400 hover:text-accent-500 transition-colors cursor-pointer",
                :on_click => () -> set_visible(visible() - 10),
                "show less"
            )
        end
    )
end
