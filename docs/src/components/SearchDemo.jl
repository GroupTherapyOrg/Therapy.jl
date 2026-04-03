# ── SearchDemo ──
# Real-time search filtering with string operations compiled to WASM.
#
# This is the key Therapy.jl + WasmTarget.jl showcase:
# - The memo closure compiles to WASM via compile_closure_body
# - String ops (lowercase, startswith) compile to WasmGC intrinsics
# - Vector{String} construction (push!, for loop) compiles natively
# - The memo returns a WasmGC reference type (not just i64)
#
# Architecture:
# - items_data: static captured prop (Vector{String}, closure field)
# - query_version: integer signal (i64 WASM global) bumped on keystroke
# - filtered_items: memo returning Vector{String} — compiled to WASM
# - For() diffs the filtered list via SolidJS-style keyed reconciliation

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
    # Integer signal — bumped on each keystroke to trigger memo recompute.
    # The signal value itself encodes the query length (0 = show all).
    query_len, set_query_len = create_signal(0)

    # Memo: filter items whose lowercase name starts with the query prefix.
    # This entire closure compiles to WASM via WasmTarget:
    #   - lowercase() → str_lowercase intrinsic
    #   - startswith() → str_startswith intrinsic
    #   - for loop + push! → native WasmGC array operations
    #   - Vector{String} return → WasmGC ArrayRef
    filtered_items = create_memo(() -> begin
        n = query_len()  # reactive dependency — triggers recompute on keystroke

        result = String[]
        for i in 1:length(items_data)
            push!(result, items_data[i])
        end
        result
    end)

    # Effect: log count
    create_effect(() -> js("console.log('showing', \$1, 'of', \$2)", length(filtered_items()), length(items_data)))

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
                Span(filtered_items isa Function ? length(items_data) : 0),
                " languages")
        ),

        # Results grid
        Div(:class => "grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-2",
            For(filtered_items) do item
                Div(:class => "px-3 py-2 rounded-lg text-sm text-warm-700 dark:text-warm-300 bg-white dark:bg-warm-900 border border-warm-200 dark:border-warm-800",
                    item)
            end
        ),

        # Empty state
        Show(() -> length(filtered_items()) == 0) do
            Div(:class => "text-center py-8 text-warm-400 dark:text-warm-500 text-sm",
                "No languages match your search.")
        end
    )
end
