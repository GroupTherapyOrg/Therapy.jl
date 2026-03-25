() -> begin
    Div(:class => "space-y-12",
        Div(:class => "text-center space-y-4",
            H1(:class => "text-5xl font-bold", "Reactive Web Apps"),
            H1(:class => "text-5xl font-bold text-green-400", "in Pure Julia"),
            P(:class => "text-lg text-gray-400 max-w-xl mx-auto",
                "Build interactive web applications with fine-grained reactivity, ",
                "server-side rendering, and JavaScript compilation. Inspired by SolidJS and Leptos."
            )
        ),
        Div(:class => "text-center",
            InteractiveCounter(initial=Int32(0))
        ),
        Div(:class => "grid grid-cols-1 md:grid-cols-3 gap-6",
            Div(:class => "border border-gray-800 rounded-lg p-6",
                H3(:class => "font-bold mb-2", "Fine-Grained Reactivity"),
                P(:class => "text-gray-400 text-sm", "SolidJS-style signals and effects that update only what changes. No virtual DOM diffing.")
            ),
            Div(:class => "border border-gray-800 rounded-lg p-6",
                H3(:class => "font-bold mb-2", "SSR + Hydration"),
                P(:class => "text-gray-400 text-sm", "Server-side rendering with islands architecture. Static by default, interactive where needed.")
            ),
            Div(:class => "border border-gray-800 rounded-lg p-6",
                H3(:class => "font-bold mb-2", "JavaScript Compilation"),
                P(:class => "text-gray-400 text-sm", "Compile Julia to tiny inline JS via JavaScriptTarget.jl. ~500 bytes per island, no framework runtime.")
            )
        )
    )
end
