function Layout(; children...)
    Html(:lang => "en",
        Head(
            Meta(:charset => "UTF-8"),
            Meta(:name => "viewport", :content => "width=device-width, initial-scale=1.0"),
            Title("Therapy.jl"),
            Link(:href => "https://cdn.tailwindcss.com", :rel => "stylesheet")
        ),
        Body(:class => "bg-gray-950 text-gray-100 min-h-screen",
            Nav(:class => "border-b border-gray-800 px-6 py-4 flex items-center justify-between",
                A(:href => "/Therapy.jl/", :class => "text-xl font-bold", "Therapy.jl"),
                Div(:class => "flex gap-6 text-sm",
                    A(:href => "/Therapy.jl/getting-started/", :class => "hover:text-green-400", "Getting Started"),
                    A(:href => "/Therapy.jl/book/", :class => "hover:text-green-400", "Book"),
                    A(:href => "/Therapy.jl/api/", :class => "hover:text-green-400", "API"),
                    A(:href => "/Therapy.jl/examples/", :class => "hover:text-green-400", "Examples")
                )
            ),
            Main(:class => "max-w-4xl mx-auto px-6 py-12",
                children...
            ),
            Footer(:class => "border-t border-gray-800 px-6 py-4 text-center text-sm text-gray-500",
                P("Built with Therapy.jl — Reactive Web Apps in Pure Julia")
            )
        )
    )
end
