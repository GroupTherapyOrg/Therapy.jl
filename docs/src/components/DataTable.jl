# ── DataTable ──
# Two-tier component: SSR function + @island.
#
# TIER 1 — DataTable() is a plain Julia function (SSR).
#   Runs at BUILD TIME on the server. Has full access to Julia packages.
#   Builds the data and passes it as JSON-serializable props to the island.
#
# TIER 2 — DataExplorer() is an @island (compiled to JavaScript).
#   Runs in the BROWSER. Receives data as typed props (string arrays).
#   Helper functions (sort_rows, take_rows) are defined locally — just
#   like you'd write helpers in React or SolidJS.

using DataFrames: DataFrame, names, eachrow

# ─── Helper functions (compiled to JS via JST package registry) ───

# Sort rows by column index. Positive = asc, negative = desc, 0 = unsorted.
@noinline function sort_rows(items::Vector{Vector{String}}, col::Int)::Vector{Vector{String}}
    col == 0 && return items
    return sort(items, by = r -> r[abs(col)], rev = col < 0)
end

# Take first n items (pagination).
@noinline function take_rows(items::Vector{Vector{String}}, n::Int)::Vector{Vector{String}}
    return items[1:min(n, length(items))]
end

# Register JST compilations so these compile to JS Array.sort() / .slice()
const _JST = Therapy.JST
_JST.register_package_compilation!(Main, :sort_rows) do ctx, kwargs, pos_args
    i, c = pos_args[1], pos_args[2]
    "(function(_i,_c){var s=_i.slice();if(_c!==0){var ci=Math.abs(_c)-1,d=_c>0?1:-1;s.sort(function(a,b){return d*(a[ci]<b[ci]?-1:a[ci]>b[ci]?1:0)})}return s})($i,$c)"
end
_JST.register_package_compilation!(Main, :take_rows) do ctx, kwargs, pos_args
    "$(pos_args[1]).slice(0,$(pos_args[2]))"
end

# ─── Tier 1: SSR Component ───

function DataTable()
    df = DataFrame(
        Name  = ["Alice", "Bob", "Carol", "Dave", "Eve", "Frank", "Grace",
                 "Heidi", "Ivan", "Judy", "Karl", "Laura", "Mallory", "Niaj",
                 "Oscar", "Peggy", "Quinn", "Rupert", "Sybil", "Trent",
                 "Uma", "Victor", "Wendy", "Xander", "Yara"],
        Age   = [28, 35, 42, 23, 31, 45, 27, 33, 29, 38, 41, 26, 34, 30,
                 36, 24, 39, 44, 32, 37, 25, 40, 22, 43, 28],
        Score = [95.2, 87.1, 91.8, 78.4, 93.6, 82.3, 96.1, 88.5, 90.3,
                 84.7, 76.9, 94.2, 89.1, 85.6, 92.4, 79.8, 86.3, 77.5,
                 91.1, 83.9, 97.4, 80.2, 98.1, 75.3, 93.0],
        City  = ["Portland", "Austin", "Denver", "Seattle", "Boston", "Chicago",
                 "Miami", "Phoenix", "Dallas", "Atlanta", "Detroit", "Oakland",
                 "Tampa", "Raleigh", "Nashville", "Memphis", "Richmond", "Boulder",
                 "Eugene", "Tucson", "Boise", "Fresno", "Madison", "Reno", "Omaha"]
    )

    cols = names(df)
    rows = [string.(collect(row)) for row in eachrow(df)]

    return DataExplorer(
        columns_data   = cols,
        rows_data      = rows,
        sort_col_init  = 0,
        page_size_init = 10,
        can_collapse_init = 0,
        can_more_init = 1
    )
end

# ─── Tier 2: @island Component ───

@island function DataExplorer(;
        columns_data::Vector{String} = String[],
        rows_data::Vector{Vector{String}} = Vector{String}[],
        sort_col_init::Int = 0,
        page_size_init::Int = 10,
        can_collapse_init::Int = 0,
        can_more_init::Int = 1
    )

    # Signals
    columns, _              = create_signal(columns_data)
    rows, _                 = create_signal(rows_data)
    sort_col, set_sort_col  = create_signal(sort_col_init)
    visible_count, set_visible_count = create_signal(page_size_init)
    can_collapse, set_can_collapse   = create_signal(can_collapse_init)
    can_more, set_can_more           = create_signal(can_more_init)

    # Memo: sort + paginate using local helpers
    sorted_visible = create_memo(() ->
        take_rows(sort_rows(rows(), sort_col()), visible_count())
    )

    # Effect: console.log on every change
    create_effect(() -> println("table: showing ", visible_count(), " rows"))

    return Div(:class => "w-full max-w-3xl rounded-lg border border-warm-200 dark:border-warm-800 overflow-hidden",
        Table(:class => "w-full text-sm",
            Thead(
                Tr(
                    For(columns) do col, idx
                        Th(:class => "text-left px-4 py-2.5 border-b-2 border-warm-200 dark:border-warm-700 font-semibold text-warm-700 dark:text-warm-300 cursor-pointer hover:text-accent-500 transition-colors select-none",
                            :on_click => () -> set_sort_col(sort_col() == idx ? -idx : idx),
                            col)
                    end
                )
            ),
            Tbody(
                For(sorted_visible) do row
                    Tr(:class => "border-b border-warm-100 dark:border-warm-900",
                        For(row) do cell
                            Td(:class => "px-4 py-2", cell)
                        end
                    )
                end
            )
        ),
        Div(:class => "flex items-center justify-center gap-4 py-3 border-t border-warm-200 dark:border-warm-800",
            Show(can_more) do
                Button(
                    :class => "text-sm text-warm-500 dark:text-warm-400 hover:text-accent-500 transition-colors cursor-pointer flex items-center gap-1",
                    :on_click => () -> begin
                        set_visible_count(visible_count() + 10)
                        set_can_collapse(1)
                        set_can_more(visible_count() < 25 ? 1 : 0)
                    end,
                    Span(:class => "text-xs", "⋮"),
                    " show more"
                )
            end,
            Show(can_collapse) do
                Button(
                    :class => "text-sm text-warm-500 dark:text-warm-400 hover:text-accent-500 transition-colors cursor-pointer flex items-center gap-1",
                    :on_click => () -> begin
                        set_visible_count(visible_count() - 10)
                        set_can_collapse(visible_count() > 10 ? 1 : 0)
                        set_can_more(1)
                    end,
                    Span(:class => "text-xs", "⋮"),
                    " show less"
                )
            end
        )
    )
end
