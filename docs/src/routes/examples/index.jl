() -> begin
    Div(:class => "space-y-8",
        H1(:class => "text-3xl font-bold", "Examples"),
        P(:class => "text-gray-400", "Interactive examples built with Therapy.jl"),
        
        H2(:class => "text-xl font-semibold", "Counter"),
        InteractiveCounter(initial=Int32(0)),
        Pre(:class => "bg-gray-900 p-4 rounded mt-4", Code("""@island function InteractiveCounter(; initial::Int32 = Int32(0))
    count, set_count = create_signal(initial)
    Div(:class => "flex items-center gap-4",
        Button(:on_click => () -> set_count(count() - Int32(1)), "-"),
        Span(:class => "text-2xl font-mono", count),
        Button(:on_click => () -> set_count(count() + Int32(1)), "+")
    )
end"""))
    )
end
