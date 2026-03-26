# ── SearchDemo ──
# Text input → memo-driven filtering → For() re-render on every keystroke.
# Tests: text input binding, memo, For, pagination, multi-column grid.

# ─── Helper: filter + paginate (compiled to JS) ───

@noinline function filter_take(items::Vector{String}, query::String, n::Int)::Vector{String}
    filtered = if length(query) == 0
        items
    else
        q = lowercase(query)
        filter(item -> contains(lowercase(item), q), items)
    end
    return filtered[1:min(n, length(filtered))]
end

const _JST = Therapy.JST
_JST.register_package_compilation!(Main, :filter_take) do ctx, kwargs, pos_args
    i, q, n = pos_args[1], pos_args[2], pos_args[3]
    "(function(_i,_q,_n){var f=(!_q||_q.length===0)?_i:_i.filter(function(x){return x.toLowerCase().indexOf(_q.toLowerCase())!==-1});return f.slice(0,_n)})($(i),$(q),$(n))"
end

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
    return FilterableList(
        items_data=items, query_init="", visible_init=12,
        can_collapse_init=0, can_more_init=1
    )
end

# ─── @island Component ───

@island function FilterableList(;
        items_data::Vector{String} = String[],
        query_init::String = "",
        visible_init::Int = 12,
        can_collapse_init::Int = 0,
        can_more_init::Int = 1
    )
    # Signals — order MUST match props order for JS initialization
    items, _ = create_signal(items_data)
    query, set_query = create_signal(query_init)
    visible_count, set_visible_count = create_signal(visible_init)
    can_collapse, set_can_collapse = create_signal(can_collapse_init)
    can_more, set_can_more = create_signal(can_more_init)

    # Memo: filter by query then take first N (one compiled function)
    visible_items = create_memo(() -> filter_take(items(), query(), visible_count()))

    # Effect: log to console on every search
    create_effect(() -> println("search: \"", query(), "\""))

    return Div(:class => "w-full max-w-2xl space-y-5",
        # Search input — visually distinct from list items
        Div(:class => "relative",
            Input(
                :type => "text",
                :on_input => set_query,
                :placeholder => "Try it — type to search 36 languages in real time...",
                :class => "w-full px-4 py-3 rounded-xl border-2 border-accent-300 dark:border-accent-700 bg-white dark:bg-warm-900 text-warm-800 dark:text-warm-200 placeholder-warm-400 dark:placeholder-warm-600 focus:outline-none focus:ring-2 focus:ring-accent-500 focus:border-accent-500 text-base shadow-sm"
            )
        ),
        # Results grid — 4 rows deep at every breakpoint (4×1, 4×2, 4×3)
        Div(:class => "grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-2",
            For(visible_items) do item
                Div(:class => "px-3 py-2 rounded-lg text-sm text-warm-700 dark:text-warm-300 bg-white dark:bg-warm-900 border border-warm-200 dark:border-warm-800",
                    item)
            end
        ),
        # Pagination
        Div(:class => "flex items-center justify-center gap-4",
            Show(can_more) do
                Button(
                    :class => "text-sm text-warm-500 dark:text-warm-400 hover:text-accent-500 transition-colors cursor-pointer flex items-center gap-1",
                    :on_click => () -> begin
                        set_visible_count(visible_count() + 12)
                        set_can_collapse(1)
                        set_can_more(visible_count() < 36 ? 1 : 0)
                    end,
                    Span(:class => "text-xs", "⋮"),
                    " show more"
                )
            end,
            Show(can_collapse) do
                Button(
                    :class => "text-sm text-warm-500 dark:text-warm-400 hover:text-accent-500 transition-colors cursor-pointer flex items-center gap-1",
                    :on_click => () -> begin
                        set_visible_count(visible_count() - 12)
                        set_can_collapse(visible_count() > 12 ? 1 : 0)
                        set_can_more(1)
                    end,
                    Span(:class => "text-xs", "⋮"),
                    " show less"
                )
            end
        )
    )
end
