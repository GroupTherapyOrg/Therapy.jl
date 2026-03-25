() -> begin
    Div(:class => "space-y-8",
        H1(:class => "text-3xl font-bold", "API Reference"),
        
        H2(:class => "text-xl font-semibold", "Reactivity"),
        Div(:class => "space-y-4",
            Div(:class => "border border-gray-800 rounded p-4",
                H3(:class => "font-mono font-bold", "create_signal(initial)"),
                P(:class => "text-gray-400 text-sm", "Create a reactive signal. Returns (getter, setter) tuple.")),
            Div(:class => "border border-gray-800 rounded p-4",
                H3(:class => "font-mono font-bold", "create_effect(() -> ...)"),
                P(:class => "text-gray-400 text-sm", "Run a side effect that re-runs when dependencies change.")),
            Div(:class => "border border-gray-800 rounded p-4",
                H3(:class => "font-mono font-bold", "create_memo(() -> ...)"),
                P(:class => "text-gray-400 text-sm", "Create a cached derived value."))
        ),
        
        H2(:class => "text-xl font-semibold", "Components"),
        Div(:class => "space-y-4",
            Div(:class => "border border-gray-800 rounded p-4",
                H3(:class => "font-mono font-bold", "@island function Name(; kwargs...)"),
                P(:class => "text-gray-400 text-sm", "Mark a component as interactive. Compiled to JavaScript. All kwargs must be typed.")),
            Div(:class => "border border-gray-800 rounded p-4",
                H3(:class => "font-mono font-bold", "Show(condition) do ... end"),
                P(:class => "text-gray-400 text-sm", "Conditional rendering.")),
            Div(:class => "border border-gray-800 rounded p-4",
                H3(:class => "font-mono font-bold", "For(items) do item ... end"),
                P(:class => "text-gray-400 text-sm", "List rendering."))
        ),

        H2(:class => "text-xl font-semibold", "HTML Elements"),
        P(:class => "text-gray-400", "All standard HTML elements: Div, Span, P, H1-H6, Button, Input, Form, Nav, Header, Footer, Main, Section, Article, Ul, Ol, Li, A, Img, Table, Tr, Td, Th, Pre, Code, etc.")
    )
end
