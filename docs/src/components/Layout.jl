function Layout(content)
    Html(:lang => "en",
        Head(
            Meta(:charset => "UTF-8"),
            Meta(:name => "viewport", :content => "width=device-width, initial-scale=1.0"),
            Title("Therapy.jl"),
            Script(:src => "https://cdn.tailwindcss.com")
        ),
        Body(:class => "bg-gray-950 text-gray-100 min-h-screen",
            Nav(:class => "border-b border-gray-800 px-6 py-4 flex items-center justify-between",
                A(:href => "/", :class => "text-xl font-bold", "Therapy.jl"),
                Div(:class => "flex gap-6 text-sm",
                    A(:href => "/getting-started/", :class => "hover:text-green-400", "Getting Started"),
                    A(:href => "/api/", :class => "hover:text-green-400", "API"),
                    A(:href => "/examples/", :class => "hover:text-green-400", "Examples")
                )
            ),
            Main(:class => "max-w-4xl mx-auto px-6 py-12",
                content
            ),
            Footer(:class => "border-t border-gray-800 px-6 py-4 text-center text-sm text-gray-500",
                P("Built with Therapy.jl")
            )
        )
    )
end
