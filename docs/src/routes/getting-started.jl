() -> begin
    Div(:class => "space-y-8",
        H1(:class => "text-3xl font-serif font-bold text-warm-900 dark:text-warm-100", "Getting Started"),
        
        H2(:class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Installation"),
        Pre(:class => "bg-warm-900 dark:bg-warm-950 p-4 rounded", Code(:class => "language-julia", "using Pkg\nPkg.add(\"Therapy\")")),
        
        H2(:class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Your First Component"),
        P(:class => "text-warm-600 dark:text-warm-400", "Components are plain Julia functions that return HTML elements:"),
        Pre(:class => "bg-warm-900 dark:bg-warm-950 p-4 rounded", Code(:class => "language-julia", """function Greeting(; name="World")
    return P("Hello, ", name, "!")
end""")),
        
        H2(:class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Adding Interactivity"),
        P(:class => "text-warm-600 dark:text-warm-400", "Use @island and signals for interactive components:"),
        Pre(:class => "bg-warm-900 dark:bg-warm-950 p-4 rounded", Code(:class => "language-julia", """@island function Counter(; initial::Int = 0)
    count, set_count = create_signal(initial)
    return Div(
        Button(:on_click => () -> set_count(count() - 1), "-"),
        Span(count),
        Button(:on_click => () -> set_count(count() + 1), "+")
    )
end""")),
        P(:class => "text-warm-600 dark:text-warm-400", "The @island macro compiles this to ~500 bytes of inline JavaScript. No framework runtime needed.")
    )
end
