() -> begin
    Div(:class => "space-y-8",
        H1(:class => "text-3xl font-bold", "Getting Started"),
        
        H2(:class => "text-xl font-semibold", "Installation"),
        Pre(:class => "bg-gray-900 p-4 rounded", Code("using Pkg\nPkg.add(\"Therapy\")")),
        
        H2(:class => "text-xl font-semibold", "Your First Component"),
        P(:class => "text-gray-400", "Components are plain Julia functions that return HTML elements:"),
        Pre(:class => "bg-gray-900 p-4 rounded", Code("""function Greeting(; name="World")
    P("Hello, ", name, "!")
end""")),
        
        H2(:class => "text-xl font-semibold", "Adding Interactivity"),
        P(:class => "text-gray-400", "Use @island and signals for interactive components:"),
        Pre(:class => "bg-gray-900 p-4 rounded", Code("""@island function Counter(; initial::Int32 = Int32(0))
    count, set_count = create_signal(initial)
    Div(
        Button(:on_click => () -> set_count(count() - Int32(1)), "-"),
        Span(count),
        Button(:on_click => () -> set_count(count() + Int32(1)), "+")
    )
end""")),
        P(:class => "text-gray-400", "The @island macro compiles this to ~500 bytes of inline JavaScript. No framework runtime needed.")
    )
end
