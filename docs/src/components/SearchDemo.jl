# ── SearchDemo ──
# Reactive list rendered from WASM-compiled memo.
# The memo closure runs in WebAssembly: for loop + push! + Vector{String}
# return are all compiled to WasmGC via WasmTarget.jl.
# For() extracts items via bridge functions and diffs with SolidJS-style keying.

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
    # Integer signal — bumped on each keystroke to trigger memo recompute
    query_len, set_query_len = create_signal(0)

    # Memo: return all items (filtering is the next step).
    # This compiles to WASM: for loop + push! + Vector{String} return.
    filtered_items = create_memo(() -> begin
        n = query_len()  # reactive dependency
        result = String[]
        for i in 1:length(items_data)
            push!(result, items_data[i])
        end
        result
    end)

    # Simple effect — just log the signal value
    create_effect(() -> js("console.log('query_len:', \$1)", query_len()))

    return Div(:class => "w-full max-w-2xl space-y-5",
        # Search input
        Div(:class => "relative",
            Input(
                :type => "text",
                :placeholder => "Search languages...",
                :class => "w-full px-4 py-2.5 rounded-lg text-sm text-warm-900 dark:text-warm-100 bg-white dark:bg-warm-900 border border-warm-200 dark:border-warm-800 focus:border-accent-500 dark:focus:border-accent-400 focus:outline-none focus:ring-1 focus:ring-accent-500 dark:focus:ring-accent-400 transition-colors placeholder:text-warm-400 dark:placeholder:text-warm-600",
                :on_input => () -> set_query_len(query_len() + 1)
            ),
            Span(:class => "absolute right-3 top-1/2 -translate-y-1/2 text-xs text-warm-400 dark:text-warm-500",
                "$(length(items_data)) languages")
        ),

        # Results grid — For() renders from WASM memo via bridge extraction
        Div(:class => "grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-2",
            For(filtered_items) do item
                Div(:class => "px-3 py-2 rounded-lg text-sm text-warm-700 dark:text-warm-300 bg-white dark:bg-warm-900 border border-warm-200 dark:border-warm-800",
                    item)
            end
        )
    )
end
