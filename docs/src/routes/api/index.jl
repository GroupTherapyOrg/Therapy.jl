() -> begin
    Div(:class => "space-y-10",
        H1(:class => "text-3xl font-serif font-bold text-warm-900 dark:text-warm-100", "API Reference"),

        H2(:class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Signals"),
        Div(:class => "space-y-4",
            Div(:class => "border border-warm-200 dark:border-warm-800 rounded-lg p-5",
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "create_signal(initial)"),
                P(:class => "text-sm text-warm-500 dark:text-warm-400 mt-1", "Create a signal. Returns (getter, setter) tuple.")),
            Div(:class => "border border-warm-200 dark:border-warm-800 rounded-lg p-5",
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "create_effect(() -> ...)"),
                P(:class => "text-sm text-warm-500 dark:text-warm-400 mt-1", "Run a side effect that re-runs when signals change.")),
            Div(:class => "border border-warm-200 dark:border-warm-800 rounded-lg p-5",
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "create_memo(() -> ...)"),
                P(:class => "text-sm text-warm-500 dark:text-warm-400 mt-1", "Create a cached derived value."))
        ),

        H2(:class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Components"),
        Div(:class => "space-y-4",
            Div(:class => "border border-warm-200 dark:border-warm-800 rounded-lg p-5",
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "@island function Name(; kwargs...)"),
                P(:class => "text-sm text-warm-500 dark:text-warm-400 mt-1", "Mark a component as interactive. Compiled to JavaScript. All kwargs must be typed.")),
            Div(:class => "border border-warm-200 dark:border-warm-800 rounded-lg p-5",
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "Show(condition) do ... end"),
                P(:class => "text-sm text-warm-500 dark:text-warm-400 mt-1", "Conditional rendering.")),
            Div(:class => "border border-warm-200 dark:border-warm-800 rounded-lg p-5",
                H3(:class => "font-mono font-semibold text-warm-900 dark:text-warm-100", "For(items) do item ... end"),
                P(:class => "text-sm text-warm-500 dark:text-warm-400 mt-1", "List rendering."))
        ),

        H2(:class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "HTML Elements"),
        P(:class => "text-warm-500 dark:text-warm-400 leading-relaxed",
            "All standard HTML elements: Div, Span, P, H1-H6, Button, Input, Form, Nav, Header, Footer, MainEl, Section, Article, Ul, Ol, Li, A, Img, Table, Tr, Td, Th, Pre, Code, etc.")
    )
end
