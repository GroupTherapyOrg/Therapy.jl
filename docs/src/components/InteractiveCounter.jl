# Example island — compiled to JavaScript via JavaScriptTarget.jl
@island function InteractiveCounter(; initial::Int32 = Int32(0))
    count, set_count = create_signal(initial)
    Div(:class => "flex items-center gap-4",
        Button(:on_click => () -> set_count(count() - Int32(1)),
            :class => "px-3 py-1 bg-gray-800 rounded hover:bg-gray-700", "-"),
        Span(:class => "text-2xl font-mono", count),
        Button(:on_click => () -> set_count(count() + Int32(1)),
            :class => "px-3 py-1 bg-gray-800 rounded hover:bg-gray-700", "+")
    )
end
