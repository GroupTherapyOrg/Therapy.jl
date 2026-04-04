# ── DataTable ──
# Two-tier SSR + Island: sortable, paginated data table.
#
# TIER 1 — DataTable() is SSR. Builds data, packs rows as pipe-delimited
#   strings ("Alice|28|95.2|Portland"), passes to island.
#
# TIER 2 — DataExplorer() is an @island. Sort column signal, memo sorts
#   and paginates, For() renders rows. Click column headers to sort.
#   Follows the Leptos/SolidJS pattern: signal → memo → For.
#
# Sorting: sort! compiles to WASM via WasmTarget's overlay method table
#   (GPUCompiler pattern). The sort! overlay produces flat insertion sort
#   IR that WasmTarget can codegen cleanly.

# ─── Tier 1: SSR Component ───

function DataTable()
    # Full Julia access — could use DataFrames.jl, CSV.jl, DB queries
    rows = [
        "Alice|28|95.2|Portland",    "Bob|35|87.1|Austin",
        "Carol|42|91.8|Denver",      "Dave|23|78.4|Seattle",
        "Eve|31|93.6|Boston",        "Frank|45|82.3|Chicago",
        "Grace|27|96.1|Miami",       "Heidi|33|88.5|Phoenix",
        "Ivan|29|90.3|Dallas",       "Judy|38|84.7|Atlanta",
        "Karl|41|76.9|Detroit",      "Laura|26|94.2|Oakland",
        "Mallory|34|89.1|Tampa",     "Niaj|30|85.6|Raleigh",
        "Oscar|36|92.4|Nashville",   "Peggy|24|79.8|Memphis",
        "Quinn|39|86.3|Richmond",    "Rupert|44|77.5|Boulder",
        "Sybil|32|91.1|Eugene",      "Trent|37|83.9|Tucson"
    ]
    return DataExplorer(rows_data=rows)
end

# ─── Tier 2: @island Component (compiled to WASM) ───

@island function DataExplorer(;
        rows_data::Vector{String} = String[]
    )
    # Integer signals
    visible_count, set_visible_count = create_signal(10)
    total_rows, _ = create_signal(length(rows_data))
    sort_col, set_sort_col = create_signal(0)  # 0=none, 1=name asc, -1=name desc

    # Memo: sort + paginate rows.
    # rows_data is captured from closure (constant, embedded at build time).
    # sort! compiles via WasmTarget's overlay (simple insertion sort).
    # String isless provides alphabetical ordering.
    visible_rows = create_memo(() -> begin
        c = sort_col()
        n = visible_count()

        # Copy rows (constant data — don't mutate original)
        copied = String[]
        for i in 1:length(rows_data)
            push!(copied, rows_data[i])
        end

        # Sort if a column is selected
        if c != 0
            # sort! with the overlay: simple insertion sort, compiles to flat WASM IR
            if c > 0
                sort!(copied)
            else
                sort!(copied; rev=true)
            end
        end

        # Paginate: take first N
        result = String[]
        for i in 1:min(n, length(copied))
            push!(result, copied[i])
        end
        result
    end)

    # Effect: log
    create_effect(() -> js("console.log('table: col=', \$1, 'showing', \$2)", sort_col(), visible_count()))

    return Div(:class => "w-full max-w-3xl mx-auto",
        Div(:class => "rounded-lg border border-warm-200 dark:border-warm-800 overflow-hidden",
            Table(:class => "w-full text-sm",
                Thead(
                    Tr(:class => "bg-warm-100 dark:bg-warm-900",
                        Th(:class => "text-left px-4 py-2.5 font-semibold text-warm-700 dark:text-warm-300 cursor-pointer hover:text-accent-500 transition-colors select-none",
                            :on_click => () -> set_sort_col(sort_col() == 1 ? -1 : 1), "Name"),
                        Th(:class => "text-left px-4 py-2.5 font-semibold text-warm-700 dark:text-warm-300 cursor-pointer hover:text-accent-500 transition-colors select-none",
                            :on_click => () -> set_sort_col(sort_col() == 2 ? -2 : 2), "Age"),
                        Th(:class => "text-left px-4 py-2.5 font-semibold text-warm-700 dark:text-warm-300 cursor-pointer hover:text-accent-500 transition-colors select-none",
                            :on_click => () -> set_sort_col(sort_col() == 3 ? -3 : 3), "Score"),
                        Th(:class => "text-left px-4 py-2.5 font-semibold text-warm-700 dark:text-warm-300 cursor-pointer hover:text-accent-500 transition-colors select-none",
                            :on_click => () -> set_sort_col(sort_col() == 4 ? -4 : 4), "City")
                    )
                ),
                Tbody(
                    For(visible_rows) do row
                        # Each row is "Name|Age|Score|City" — rendered as a single string
                        # The JS render template will show the full row
                        Tr(:class => "border-t border-warm-100 dark:border-warm-900",
                            Td(:class => "px-4 py-2 text-warm-800 dark:text-warm-200", row)
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
