() -> begin
    Div(:class => "space-y-12",
        H1(:class => "text-3xl font-serif font-bold text-warm-900 dark:text-warm-100", "Examples"),
        P(:class => "text-warm-600 dark:text-warm-400",
            "Interactive examples built with Therapy.jl. Code snippets below are simplified — see the full source in ",
            A(:href => "https://github.com/GroupTherapyOrg/Therapy.jl/tree/wasm-islands/docs/src/components",
                :target => "_blank",
                :class => "text-accent-500 hover:text-accent-600 underline",
                "docs/src/components"),
            "."),

        # ── Counter ──
        Div(:class => "space-y-4",
            H2(:class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Counter"),
            P(:class => "text-sm text-warm-600 dark:text-warm-400", "Signals, memos, and effects — open your browser console to see the effect logging."),
            Div(:class => "flex justify-center py-6", InteractiveCounter(initial=0)),
            Pre(:class => "bg-warm-900 dark:bg-warm-950 text-warm-200 p-5 rounded-lg border border-warm-800 font-mono text-sm overflow-x-auto max-h-[30rem]", Code(:class => "language-julia", """using Therapy: Div, Button, Span
using Therapy: @island, create_signal, create_memo, create_effect, js

@island function InteractiveCounter(; initial::Int = 0)
    count, set_count = create_signal(initial)
    doubled = create_memo(() -> count() * 2)
    create_effect(() -> js("console.log('count:', \$1, 'doubled:', \$2)", count(), doubled()))

    return Div(
        Div(
            Button(:on_click => () -> set_count(count() - 1), "-"),
            Span(count),
            Button(:on_click => () -> set_count(count() + 1), "+")
        ),
        Span("doubled ", Span(doubled))
    )
end"""))
        ),

        # ── Dark Mode Toggle (Cross-Island) ──
        Div(:class => "space-y-4",
            H2(:class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Dark Mode Toggle"),
            P(:class => "text-sm text-warm-600 dark:text-warm-400",
                "Cross-island signal sharing. This toggle and the one in the nav bar are separate ",
                Code(:class => "font-mono text-accent-500", "@island"),
                " instances, each with their own WASM module. They share a module-level signal via ",
                Code(:class => "font-mono text-accent-500", "__t.shared()"),
                " in JS — the single source of truth. WASM reads the shared signal via an import call (",
                Code(:class => "font-mono text-accent-500", "call \$get_shared"),
                "), so every instance always reads the latest value. Click either toggle and both stay in sync."),
            Div(:class => "flex justify-center py-6",
                Div(:class => "flex items-center gap-3 px-4 py-3 rounded-lg border border-warm-200 dark:border-warm-800",
                    Span(:class => "text-sm text-warm-600 dark:text-warm-400", "Toggle dark mode →"),
                    DarkModeToggle()
                )
            ),
            Pre(:class => "bg-warm-900 dark:bg-warm-950 text-warm-200 p-5 rounded-lg border border-warm-800 font-mono text-sm overflow-x-auto max-h-[30rem]", Code(:class => "language-julia", """using Therapy: Button
using Therapy: @island, create_signal, js

# Module-level signal — shared across ALL instances automatically
const dark_mode = create_signal(0)

@island function DarkModeToggle()
    is_dark, set_dark = dark_mode  # captures the shared signal

    # Sync with browser dark state on hydration
    js("if(document.documentElement.classList.contains('dark'))\$1(1)", set_dark)

    return Button(:on_click => () -> begin
        set_dark(1 - is_dark())
        js("document.documentElement.classList.toggle('dark')")
        js("localStorage.setItem('therapy-theme', ...)")
    end, "Toggle")
end"""))
        ),

        # ── Search Demo ──
        Div(:class => "space-y-4",
            H2(:class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Search"),
            P(:class => "text-sm text-warm-600 dark:text-warm-400",
                "Leptos-style string signals. ",
                Code(:class => "font-mono text-accent-500", "create_signal(\"\")"),
                " creates a WasmGC ref-typed global that holds the query string. On each keystroke, the input value is bridged to a WasmGC string and written to the global. The memo reads it via ",
                Code(:class => "font-mono text-accent-500", "query()"),
                " and filters using ",
                Code(:class => "font-mono text-accent-500", "lowercase"),
                " and ",
                Code(:class => "font-mono text-accent-500", "startswith"),
                " — all running in WebAssembly. This is the same code shown below."),
            Div(:class => "flex justify-center py-6", SearchDemo()),
            Pre(:class => "bg-warm-900 dark:bg-warm-950 text-warm-200 p-5 rounded-lg border border-warm-800 font-mono text-sm overflow-x-auto max-h-[30rem]", Code(:class => "language-julia", """@island function SearchableList(;
        items_data::Vector{String} = String[],
        visible_init::Int = 12
    )
    # String signal — the query text, stored as a WasmGC ref global
    query, set_query = create_signal("")

    # Integer signals for pagination
    visible_count, set_visible_count = create_signal(visible_init)
    total_count, _ = create_signal(length(items_data))

    # Memo: filter by query, then take first N items.
    # query() reads the WasmGC string global.
    # lowercase() and startswith() compile to WASM intrinsics.
    visible_items = create_memo(() -> begin
        q = lowercase(query())
        n = visible_count()

        filtered = String[]
        for i in 1:length(items_data)
            if length(q) == 0 || startswith(lowercase(items_data[i]), q)
                push!(filtered, items_data[i])
            end
        end

        result = String[]
        for i in 1:min(n, length(filtered))
            push!(result, filtered[i])
        end
        result
    end)

    return Div(
        Input(:type => "text", :on_input => set_query),
        For(visible_items) do item
            Div(item)
        end,
        # Show() with closure conditions — compiled to WASM
        Show(() -> visible_count() < total_count()) do
            Button(:on_click => () -> set_visible_count(visible_count() + 12),
                "show more")
        end,
        Show(() -> visible_count() > 12) do
            Button(:on_click => () -> set_visible_count(visible_count() - 12),
                "show less")
        end
    )
end"""))
        )

        #= ── Remaining examples (to be restored incrementally) ──
        # InteractivePlot, HeatmapDemo, ShowDemo,
        # BatchDemo, DataTable, MountDemo, NotebookDemos
        =#
    )
end
