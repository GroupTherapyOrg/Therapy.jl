# ── SearchDemo ──
# Signal-driven list with pagination via For() and Show().
# Tests: create_signal, create_memo, For(), Show(), integer arithmetic in WASM.
#
# WasmTarget TODOs:
# - Reference-typed signal globals (Vector{String} can't be i64)
# - map(typeof(lowercase), String) — Julia's lowercase() dispatch
# - Base._searchindex — Julia's contains() dispatch
# - filter(closure, Vector) — needs autodiscovery in compile_closure_body

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
    return PaginatedList(items_data=items, visible_init=12)
end

# ─── @island Component ───

@island function PaginatedList(;
        items_data::Vector{String} = String[],
        visible_init::Int = 12
    )
    # Only integer signals — these compile to WASM i64 globals.
    # items_data is static prop data, not a signal (Vector{String}
    # can't be an i64 global — needs reference-typed globals, a WasmTarget TODO).
    visible_count, set_visible_count = create_signal(visible_init)
    total_count, _ = create_signal(length(items_data))

    # Memo: take first N items
    visible_items = create_memo(() -> begin
        n = visible_count()
        result = String[]
        for i in 1:min(n, length(items_data))
            push!(result, items_data[i])
        end
        result
    end)

    # Effect: log visible count
    create_effect(() -> js("console.log('showing:', \$1, 'of', \$2)", visible_count(), total_count()))

    return Div(:class => "w-full max-w-2xl space-y-5",
        # Results grid
        Div(:class => "grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-2",
            For(visible_items) do item
                Div(:class => "px-3 py-2 rounded-lg text-sm text-warm-700 dark:text-warm-300 bg-white dark:bg-warm-900 border border-warm-200 dark:border-warm-800",
                    item)
            end
        ),
        # Pagination
        Div(:class => "flex items-center justify-center gap-4",
            Show(() -> visible_count() < total_count()) do
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
