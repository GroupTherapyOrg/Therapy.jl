# ── SearchDemo ──
# Real-time search filtering — the Therapy.jl + WasmTarget.jl showcase.
#
# Architecture (Leptos-style string signals):
# - items_data is embedded in WASM at build time (constant Vector{String})
# - query signal is a string-typed signal (WasmGC ref global, not i64)
# - On each keystroke, JS builds a WasmGC string via _jsToWasm bridge
# - The memo reads the string global directly — filtering runs entirely in WASM
# - lowercase() and startswith() run in WASM (str_lowercase, str_startswith intrinsics)
# - Result Vector{String} is extracted via bridge functions
# - For() diffs with SolidJS-style keyed reconciliation

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
    query, set_query = create_signal("")

    filtered_items = create_memo(() -> begin
        q = lowercase(query())
        result = String[]
        for i in 1:length(items_data)
            if length(q) == 0 || startswith(lowercase(items_data[i]), q)
                push!(result, items_data[i])
            end
        end
        result
    end)

    return Div(:class => "w-full max-w-2xl space-y-5",
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
        Div(:class => "grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-2",
            For(filtered_items) do item
                Div(:class => "px-3 py-2 rounded-lg text-sm text-warm-700 dark:text-warm-300 bg-white dark:bg-warm-900 border border-warm-200 dark:border-warm-800",
                    item)
            end
        )
    )
end
