# ── DataTable ──
# Two-tier SSR + Island: sortable, paginated data table.
#
# TIER 1 — DataTable() is SSR. Has full Julia access (DataFrames, CSV, DB).
#   Splits data into 4 column vectors and passes to the island.
#
# TIER 2 — DataExplorer() is an @island. Sorts integer indices by the
#   selected column's string values, paginates, and renders 4 Td cells
#   per row. ALL sorting runs in WASM via the sort! overlay + cmp overlay.
#   Follows the Leptos/SolidJS pattern: signal → memo → For.

# ─── Tier 1: SSR Component ───

function DataTable()
    # Full Julia access — could use DataFrames.jl, CSV.jl, DB queries
    names  = ["Alice", "Bob", "Carol", "Dave", "Eve", "Frank", "Grace", "Heidi",
              "Ivan", "Judy", "Karl", "Laura", "Mallory", "Niaj", "Oscar", "Peggy",
              "Quinn", "Rupert", "Sybil", "Trent"]
    ages   = ["28", "35", "42", "23", "31", "45", "27", "33",
              "29", "38", "41", "26", "34", "30", "36", "24",
              "39", "44", "32", "37"]
    scores = ["95.2", "87.1", "91.8", "78.4", "93.6", "82.3", "96.1", "88.5",
              "90.3", "84.7", "76.9", "94.2", "89.1", "85.6", "92.4", "79.8",
              "86.3", "77.5", "91.1", "83.9"]
    cities = ["Portland", "Austin", "Denver", "Seattle", "Boston", "Chicago",
              "Miami", "Phoenix", "Dallas", "Atlanta", "Detroit", "Oakland",
              "Tampa", "Raleigh", "Nashville", "Memphis", "Richmond", "Boulder",
              "Eugene", "Tucson"]

    return DataExplorer(
        col_names=names, col_ages=ages, col_scores=scores, col_cities=cities
    )
end

# ─── Tier 2: @island Component (compiled to WASM) ───

@island function DataExplorer(;
        col_names::Vector{String} = String[],
        col_ages::Vector{String} = String[],
        col_scores::Vector{String} = String[],
        col_cities::Vector{String} = String[]
    )
    # Integer signals
    visible_count, set_visible_count = create_signal(10)
    total_rows, _ = create_signal(length(col_names))
    sort_col, set_sort_col = create_signal(0)  # 0=none, +N=col N asc, -N=desc

    # Memo: sort indices by selected column, then paginate.
    # col_names/ages/scores/cities are captured constants (embedded at build time).
    # sort! compiles via the overlay (insertion sort).
    # String comparison compiles via the cmp overlay (byte-by-byte, no memcmp).
    visible_indices = create_memo(() -> begin
        c = sort_col()
        n = visible_count()
        total = length(col_names)

        # Build index array
        indices = Int64[]
        for i in 1:total
            push!(indices, Int64(i))
        end

        if c == 1 || c == -1
            for ii in 2:length(indices)
                key_idx = indices[ii]
                jj = ii - 1
                while jj >= 1
                    if c > 0
                        if isless(col_names[indices[jj]], col_names[key_idx]); break; end
                    else
                        if isless(col_names[key_idx], col_names[indices[jj]]); break; end
                    end
                    indices[jj + 1] = indices[jj]
                    jj -= 1
                end
                indices[jj + 1] = key_idx
            end
        elseif c == 2 || c == -2
            for ii in 2:length(indices)
                key_idx = indices[ii]
                jj = ii - 1
                while jj >= 1
                    if c > 0
                        if isless(col_ages[indices[jj]], col_ages[key_idx]); break; end
                    else
                        if isless(col_ages[key_idx], col_ages[indices[jj]]); break; end
                    end
                    indices[jj + 1] = indices[jj]
                    jj -= 1
                end
                indices[jj + 1] = key_idx
            end
        elseif c == 3 || c == -3
            for ii in 2:length(indices)
                key_idx = indices[ii]
                jj = ii - 1
                while jj >= 1
                    if c > 0
                        if isless(col_scores[indices[jj]], col_scores[key_idx]); break; end
                    else
                        if isless(col_scores[key_idx], col_scores[indices[jj]]); break; end
                    end
                    indices[jj + 1] = indices[jj]
                    jj -= 1
                end
                indices[jj + 1] = key_idx
            end
        elseif c == 4 || c == -4
            for ii in 2:length(indices)
                key_idx = indices[ii]
                jj = ii - 1
                while jj >= 1
                    if c > 0
                        if isless(col_cities[indices[jj]], col_cities[key_idx]); break; end
                    else
                        if isless(col_cities[key_idx], col_cities[indices[jj]]); break; end
                    end
                    indices[jj + 1] = indices[jj]
                    jj -= 1
                end
                indices[jj + 1] = key_idx
            end
        end

        # Paginate: take first N
        result = Int64[]
        for i in 1:min(n, length(indices))
            push!(result, indices[i])
        end
        result
    end)

    # Sort toggle handlers — each is a direct function, not a wrapper closure
    sort_by_name()  = begin; if sort_col() == 1; set_sort_col(-1); else; set_sort_col(1); end; end
    sort_by_age()   = begin; if sort_col() == 2; set_sort_col(-2); else; set_sort_col(2); end; end
    sort_by_score() = begin; if sort_col() == 3; set_sort_col(-3); else; set_sort_col(3); end; end
    sort_by_city()  = begin; if sort_col() == 4; set_sort_col(-4); else; set_sort_col(4); end; end

    th_class = "text-left px-4 py-2.5 font-semibold text-warm-700 dark:text-warm-300 cursor-pointer hover:text-accent-500 transition-colors select-none"

    # Effect: log
    create_effect(() -> js("console.log('table: col=', \$1, 'showing', \$2)", sort_col(), visible_count()))

    return Div(:class => "w-full max-w-3xl mx-auto",
        Div(:class => "rounded-lg border border-warm-200 dark:border-warm-800 overflow-hidden",
            Table(:class => "w-full text-sm",
                Thead(
                    Tr(:class => "bg-warm-100 dark:bg-warm-900",
                        Th(:class => th_class, :on_click => sort_by_name, "Name"),
                        Th(:class => th_class, :on_click => sort_by_age, "Age"),
                        Th(:class => th_class, :on_click => sort_by_score, "Score"),
                        Th(:class => th_class, :on_click => sort_by_city, "City")
                    )
                ),
                Tbody(
                    For(visible_indices) do idx
                        Tr(:class => "border-t border-warm-100 dark:border-warm-900",
                            Td(:class => "px-4 py-2 text-warm-800 dark:text-warm-200", col_names[idx]),
                            Td(:class => "px-4 py-2 text-warm-800 dark:text-warm-200", col_ages[idx]),
                            Td(:class => "px-4 py-2 text-warm-800 dark:text-warm-200", col_scores[idx]),
                            Td(:class => "px-4 py-2 text-warm-800 dark:text-warm-200", col_cities[idx])
                        )
                    end
                )
            )
        ),
        # Pagination
        Div(:class => "flex items-center justify-center gap-4 py-3",
            Show(() -> visible_count() < total_rows()) do
                Button(
                    :class => "text-sm text-warm-500 dark:text-warm-400 hover:text-accent-500 transition-colors cursor-pointer",
                    :on_click => () -> set_visible_count(visible_count() + 10),
                    "show more"
                )
            end,
            Show(() -> visible_count() > 10) do
                Button(
                    :class => "text-sm text-warm-500 dark:text-warm-400 hover:text-accent-500 transition-colors cursor-pointer",
                    :on_click => () -> set_visible_count(visible_count() - 10),
                    "show less"
                )
            end
        )
    )
end
