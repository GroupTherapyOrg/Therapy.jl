function Layout(content)
    Div(:class => "min-h-screen flex flex-col",
        Nav(:class => "border-b border-gray-800 px-6 py-4 flex items-center justify-between",
            A(:href => "/", :class => "text-xl font-bold", "Therapy.jl"),
            Div(:class => "flex gap-6 text-sm",
                A(:href => "/getting-started/", :class => "hover:text-green-400", "Getting Started"),
                A(:href => "/api/", :class => "hover:text-green-400", "API"),
                A(:href => "/examples/", :class => "hover:text-green-400", "Examples")
            )
        ),
        Main(:class => "flex-1 max-w-4xl mx-auto px-6 py-12 w-full",
            content
        ),
        Footer(:class => "border-t border-gray-800 px-6 py-4 text-center text-sm text-gray-500",
            P("Built with Therapy.jl")
        )
    )
end
