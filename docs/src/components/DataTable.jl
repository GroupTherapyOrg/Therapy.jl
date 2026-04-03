# ── DataTable ──
# Two-tier SSR + Island pattern:
#
# TIER 1 — DataTable() is a plain Julia function (SSR).
#   Runs at BUILD TIME. Full Julia package access (DataFrames, CSV, DB, etc.).
#   Builds the data and passes it as props to the island.
#
# TIER 2 — DataExplorer() is an @island (compiled to WASM).
#   Runs in the BROWSER. Receives data as Vector{String} props.
#   Pagination via integer signals. For() renders from memo-sliced data.
#   Show() buttons use bare signal getters (can_more, can_collapse).

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

    return DataExplorer(
        names_data=names_col, ages_data=ages_col,
        scores_data=scores_col, cities_data=cities_col,
        page_size_init=10
    )
end

# ─── Tier 2: @island Component (compiled to WASM) ───

@island function DataExplorer(;
        names_data::Vector{String} = String[],
        ages_data::Vector{String} = String[],
        scores_data::Vector{String} = String[],
        cities_data::Vector{String} = String[],
        page_size_init::Int = 10
    )
    # Integer signals for pagination state
    visible_count, set_visible_count = create_signal(page_size_init)
    total_rows, _ = create_signal(length(names_data))
    can_more, set_can_more = create_signal(1)
    can_collapse, set_can_collapse = create_signal(0)

    # Memo: slice first N names (For() renders from this)
    visible_names = create_memo(() -> begin
        n = visible_count()
        result = String[]
        for i in 1:min(n, length(names_data))
            push!(result, names_data[i])
        end
        result
    end)

    # Effect: log visible count
    create_effect(() -> js("console.log('table: showing', \$1, 'rows')", visible_count()))

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
                Tbody(
                    For(visible_names) do name
                        Tr(:class => "border-t border-warm-100 dark:border-warm-900",
                            Td(:class => "px-4 py-2 text-warm-800 dark:text-warm-200", name),
                            Td(:class => "px-4 py-2 text-warm-600 dark:text-warm-400 font-mono", ""),
                            Td(:class => "px-4 py-2 text-warm-600 dark:text-warm-400 font-mono", ""),
                            Td(:class => "px-4 py-2 text-warm-600 dark:text-warm-400", "")
                        )
                    end
                )
            )
        ),
        # Pagination — bare signal getters for Show() (same pattern as original)
        Div(:class => "flex items-center justify-center gap-4 py-3",
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
    )
end
