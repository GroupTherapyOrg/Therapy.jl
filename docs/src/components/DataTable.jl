# ── DataTable ──
# Two-tier SSR + Island pattern:
#
# TIER 1 — DataTable() is a plain Julia function (SSR).
#   Runs at BUILD TIME. Full Julia package access (DataFrames, CSV, DB, etc.).
#   Renders ALL 20 rows as full HTML with all 4 columns.
#   Rows beyond page_size get a `hidden` class.
#
# TIER 2 — DataExplorer() is an @island (compiled to WASM).
#   Runs in the BROWSER. Controls row visibility via effect + js().
#   Show/hide buttons use Show() with signal conditions.

# ─── Tier 1: SSR Component ───

function DataTable()
    # Full Julia access — could use DataFrames.jl, CSV.jl, database queries
    names_col = ["Alice", "Bob", "Carol", "Dave", "Eve", "Frank", "Grace",
                 "Heidi", "Ivan", "Judy", "Karl", "Laura", "Mallory", "Niaj",
                 "Oscar", "Peggy", "Quinn", "Rupert", "Sybil", "Trent"]
    ages_col = string.([28, 35, 42, 23, 31, 45, 27, 33, 29, 38, 41, 26, 34, 30, 36, 24, 39, 44, 32, 37])
    scores_col = string.([95.2, 87.1, 91.8, 78.4, 93.6, 82.3, 96.1, 88.5, 90.3,
                          84.7, 76.9, 94.2, 89.1, 85.6, 92.4, 79.8, 86.3, 77.5, 91.1, 83.9])
    cities_col = ["Portland", "Austin", "Denver", "Seattle", "Boston", "Chicago",
                  "Miami", "Phoenix", "Dallas", "Atlanta", "Detroit", "Oakland",
                  "Tampa", "Raleigh", "Nashville", "Memphis", "Richmond", "Boulder",
                  "Eugene", "Tucson"]

    page_size = 10
    total = length(names_col)

    # Build SSR table rows — all 20 rendered, rows beyond page_size get `hidden`
    rows = map(1:total) do i
        hidden_class = i > page_size ? " hidden" : ""
        Tr(:class => "border-t border-warm-100 dark:border-warm-900 data-table-row$(hidden_class)",
            Td(:class => "px-4 py-2 text-warm-800 dark:text-warm-200", names_col[i]),
            Td(:class => "px-4 py-2 text-warm-600 dark:text-warm-400 font-mono", ages_col[i]),
            Td(:class => "px-4 py-2 text-warm-600 dark:text-warm-400 font-mono", scores_col[i]),
            Td(:class => "px-4 py-2 text-warm-600 dark:text-warm-400", cities_col[i])
        )
    end

    return Div(:class => "w-full max-w-3xl mx-auto",
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
                Tbody(:class => "data-table-body", rows...)
            )
        ),
        # Island for interactivity — controls pagination
        TableControls(page_size=page_size, total=total)
    )
end

# ─── Tier 2: @island Component (compiled to WASM) ───

@island function TableControls(; page_size::Int = 10, total::Int = 20)
    visible_count, set_visible_count = create_signal(page_size)
    total_rows, _ = create_signal(total)
    can_more, set_can_more = create_signal(page_size < total ? 1 : 0)
    can_collapse, set_can_collapse = create_signal(0)

    # Effect: toggle row visibility via js() DOM manipulation.
    # Reads visible_count() for signal tracking — re-runs when it changes.
    create_effect(() -> js(
        "var n=\$1;var rows=document.querySelectorAll('.data-table-row');for(var i=0;i<rows.length;i++){if(i<n){rows[i].classList.remove('hidden')}else{rows[i].classList.add('hidden')}}",
        visible_count()
    ))

    return Div(:class => "flex items-center justify-center gap-4 py-3",
        Show(can_more) do
            Button(
                :class => "text-sm text-warm-500 dark:text-warm-400 hover:text-accent-500 transition-colors cursor-pointer",
                :on_click => () -> begin
                    set_visible_count(visible_count() + 10)
                    set_can_collapse(1)
                    set_can_more(visible_count() + 10 < total_rows() ? 1 : 0)
                end,
                "show more"
            )
        end,
        Show(can_collapse) do
            Button(
                :class => "text-sm text-warm-500 dark:text-warm-400 hover:text-accent-500 transition-colors cursor-pointer",
                :on_click => () -> begin
                    set_visible_count(visible_count() - 10)
                    set_can_collapse(visible_count() - 10 > 10 ? 1 : 0)
                    set_can_more(1)
                end,
                "show less"
            )
        end
    )
end
