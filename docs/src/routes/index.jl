() -> begin
    Div(:class => "space-y-16",
        # Hero
        Div(:class => "text-center space-y-6 pt-8",
            H1(:class => "no-rule text-5xl md:text-6xl font-serif font-bold text-warm-900 dark:text-warm-100",
                "Signals-Based Web Apps"
            ),
            H1(:class => "no-rule text-5xl md:text-6xl font-serif font-bold text-accent-500",
                "Pure Julia"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-400 max-w-2xl mx-auto leading-relaxed",
                "Build interactive web applications with fine-grained signals, ",
                "server-side rendering, and WebAssembly islands. Signals architecture originated by ",
                A(:href => "https://solidjs.com", :target => "_blank", :class => "text-accent-500 hover:text-accent-600 underline", "SolidJS"),
                ", compiled to WASM following ",
                A(:href => "https://leptos.dev", :target => "_blank", :class => "text-accent-500 hover:text-accent-600 underline", "Leptos"),
                " (Rust), with ",
                A(:href => "https://astro.build", :target => "_blank", :class => "text-accent-500 hover:text-accent-600 underline", "Astro"),
                "-style islands and view transitions."
            ),
            Div(:class => "flex gap-4 justify-center pt-4",
                A(:href => "./getting-started/",
                    :class => "px-6 py-3 bg-accent-600 hover:bg-accent-700 text-white rounded-lg font-medium transition-colors",
                    "Get Started"
                ),
                A(:href => "https://github.com/GroupTherapyOrg/Therapy.jl", :target => "_blank",
                    :class => "px-6 py-3 border border-warm-300 dark:border-warm-700 rounded-lg font-medium text-warm-700 dark:text-warm-300 hover:bg-warm-100 dark:hover:bg-warm-900 transition-colors",
                    "View on GitHub"
                )
            )
        ),
        # Interactive demo + code block together
        Div(:class => "flex flex-col items-center gap-6",
            InteractiveCounter(initial=0),
            P(:class => "text-xs text-warm-500 dark:text-warm-500",
                "Open your browser console (F12) to see Julia's ",
                Code(:class => "text-accent-500 font-mono", "create_effect"),
                " → ", Code(:class => "text-accent-500 font-mono", "console.log"),
                " compiled via WasmTarget.jl"
            ),
            # Code that produced the counter above
            Div(:class => "w-full max-w-3xl",
                Pre(:class => "bg-warm-900 dark:bg-warm-950 text-warm-200 p-6 rounded-lg overflow-x-auto border border-warm-800",
                    Code(:class => "language-julia text-sm font-mono", """using Therapy

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
end""")
                )
            )
        ),
        # Feature cards
        Div(:class => "grid grid-cols-1 md:grid-cols-3 gap-6",
            Div(:class => "border border-warm-200 dark:border-warm-800 rounded-lg p-6 bg-warm-100/50 dark:bg-warm-900/50",
                Div(:class => "w-10 h-10 rounded-lg bg-accent-100 dark:bg-accent-900/50 flex items-center justify-center mb-4",
                    RawHtml("""<svg class="w-5 h-5 text-accent-600 dark:text-accent-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"/></svg>""")
                ),
                H3(:class => "font-semibold mb-2 text-warm-900 dark:text-warm-100", "Fine-Grained Signals"),
                P(:class => "text-warm-600 dark:text-warm-400 text-sm leading-relaxed", "Leptos-style signals that update only what changes. No virtual DOM, no diffing.")
            ),
            Div(:class => "border border-warm-200 dark:border-warm-800 rounded-lg p-6 bg-warm-100/50 dark:bg-warm-900/50",
                Div(:class => "w-10 h-10 rounded-lg bg-accent-secondary-100 dark:bg-accent-secondary-900/50 flex items-center justify-center mb-4",
                    RawHtml("""<svg class="w-5 h-5 text-accent-secondary-600 dark:text-accent-secondary-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="2" y="3" width="20" height="14" rx="2"/><line x1="8" y1="21" x2="16" y2="21"/><line x1="12" y1="17" x2="12" y2="21"/></svg>""")
                ),
                H3(:class => "font-semibold mb-2 text-warm-900 dark:text-warm-100", "SSR + Hydration"),
                P(:class => "text-warm-600 dark:text-warm-400 text-sm leading-relaxed", "Server-side rendering with islands architecture. Static by default, interactive where needed.")
            ),
            Div(:class => "border border-warm-200 dark:border-warm-800 rounded-lg p-6 bg-warm-100/50 dark:bg-warm-900/50",
                Div(:class => "w-10 h-10 rounded-lg bg-accent-100 dark:bg-accent-900/50 flex items-center justify-center mb-4",
                    RawHtml("""<svg class="w-5 h-5 text-accent-600 dark:text-accent-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/></svg>""")
                ),
                H3(:class => "font-semibold mb-2 text-warm-900 dark:text-warm-100", "WebAssembly Compilation"),
                P(:class => "text-warm-600 dark:text-warm-400 text-sm leading-relaxed", "Compile Julia to compact inline Wasm via WasmTarget.jl. Tiny per-island modules, no framework runtime.")
            )
        )
    )
end
