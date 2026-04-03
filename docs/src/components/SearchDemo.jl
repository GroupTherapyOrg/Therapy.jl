# ── SearchDemo ──
# Real-time search filtering with pagination — Therapy.jl + WasmTarget.jl showcase.
#
# Architecture (Leptos-style string signals):
# - items_data embedded in WASM at build time (constant Vector{String})
# - query: string signal (WasmGC ref global) — holds the search text
# - visible_count: integer signal (i64 global) — how many items to show
# - Memo reads both signals, filters by query, slices by visible_count
# - lowercase() and startswith() run in WASM as intrinsics
# - Show() buttons for pagination, For() for list rendering

# ─── SSR Component ───

function SearchDemo()
    items = [
        "Julia", "Python", "Rust", "Go", "JavaScript", "TypeScript",
        "Haskell", "Elixir", "Ruby", "Swift", "Kotlin", "Scala",
        "C", "C++", "C#", "R", "MATLAB", "Fortran", "Lisp",
        "Clojure", "Erlang", "Dart", "Zig", "Nim", "Crystal",
        "OCaml", "F#", "Lua", "Perl", "PHP", "Java",
        "Assembly", "Prolog", "Scheme", "Racket", "COBOL", "Bash"
    ]
    return SearchableList(items_data=items)
end

# ─── @island Component ───

@island function SearchableList(;
        items_data::Vector{String} = String[]
    )
    # String signal — the query text, stored as a WasmGC ref global
    query, set_query = create_signal("")

    # Integer signal — how many filtered items to show
    visible_count, set_visible_count = create_signal(12)

    # Memo: filter by query, then take first N items.
    # query() reads the WasmGC string global.
    # visible_count() reads the i64 global.
    # lowercase() and startswith() compile to WASM intrinsics.
    visible_items = create_memo(() -> begin
        q = lowercase(query())
        n = visible_count()

        # Filter
        filtered = String[]
        for i in 1:length(items_data)
            if length(q) == 0 || startswith(lowercase(items_data[i]), q)
                push!(filtered, items_data[i])
            end
        end

        # Paginate
        result = String[]
        for i in 1:min(n, length(filtered))
            push!(result, filtered[i])
        end
        result
    end)

    return Div(:class => "w-full max-w-2xl space-y-5",
        # Search input
        Div(:class => "relative",
            Input(
                :type => "text",
                :placeholder => "Search languages...",
                :class => "w-full px-4 py-2.5 rounded-lg text-sm text-warm-900 dark:text-warm-100 bg-white dark:bg-warm-900 border border-warm-200 dark:border-warm-800 focus:border-accent-500 dark:focus:border-accent-400 focus:outline-none focus:ring-1 focus:ring-accent-500 dark:focus:ring-accent-400 transition-colors placeholder:text-warm-400 dark:placeholder:text-warm-600",
                :on_input => set_query
            ),
            Span(:class => "absolute right-3 top-1/2 -translate-y-1/2 text-xs text-warm-400 dark:text-warm-500",
                "$(length(items_data)) languages")
        ),

        # Results grid
        Div(:class => "grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-2",
            For(visible_items) do item
                Div(:class => "px-3 py-2 rounded-lg text-sm text-warm-700 dark:text-warm-300 bg-white dark:bg-warm-900 border border-warm-200 dark:border-warm-800",
                    item)
            end
        ),

        # Pagination
        Div(:class => "flex items-center justify-center gap-4",
            Show(() -> visible_count() < length(items_data)) do
                Button(
                    :class => "text-sm text-warm-500 dark:text-warm-400 hover:text-accent-500 transition-colors cursor-pointer",
                    :on_click => () -> set_visible_count(visible_count() + 12),
                    "show more"
                )
            end,
            Show(() -> visible_count() > 12) do
                Button(
                    :class => "text-sm text-warm-500 dark:text-warm-400 hover:text-accent-500 transition-colors cursor-pointer",
                    :on_click => () -> set_visible_count(visible_count() - 12),
                    "show less"
                )
            end
        )
    )
end
