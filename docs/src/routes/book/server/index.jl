# Server Features - Part 5 of the Therapy.jl Book
#
# SSR, server functions, and real-time WebSocket communication.

function Index()
    Fragment(
        # Header
        Div(:class => "py-8 border-b border-neutral-300 dark:border-neutral-800",
            Span(:class => "text-sm text-emerald-700 dark:text-emerald-400 font-medium", "Part 5"),
            H1(:class => "text-4xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mt-2 mb-4",
                "Server Features"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 max-w-3xl",
                "Explore server-side rendering, server functions for RPC, and real-time WebSocket communication."
            )
        ),

        # Coming Soon Notice
        Section(:class => "py-12",
            Div(:class => "bg-amber-50 dark:bg-amber-950/20 rounded-lg border border-amber-200 dark:border-amber-900 p-8 text-center",
                H2(:class => "text-2xl font-serif font-semibold text-amber-900 dark:text-amber-200 mb-4",
                    "Coming Soon"
                ),
                P(:class => "text-amber-800 dark:text-amber-300",
                    "This section is currently being written. Check back soon for SSR, @server macro, and WebSocket patterns!"
                )
            )
        ),

        # Topics Preview
        Section(:class => "py-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "What You'll Learn"
            ),
            Ul(:class => "space-y-3 text-neutral-600 dark:text-neutral-400",
                Li(Strong("Server-Side Rendering"), " - render_to_string and hydration"),
                Li(Strong("@server Functions"), " - Type-safe RPC from client to server"),
                Li(Strong("Server Signals"), " - Push updates from server to all clients"),
                Li(Strong("Bidirectional Signals"), " - Collaborative real-time state"),
                Li(Strong("Channels"), " - Discrete message passing (chat, notifications)"),
                Li(Strong("WebSocket Integration"), " - Auto-reconnect and graceful degradation")
            )
        ),

        # Quick Preview
        Section(:class => "py-8 bg-neutral-50 dark:bg-neutral-900 rounded-lg border border-neutral-300 dark:border-neutral-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Quick Preview"
            ),
            Div(:class => "bg-neutral-900 dark:bg-neutral-950 rounded border border-neutral-800 p-6 overflow-x-auto",
                Pre(:class => "text-sm text-neutral-100",
                    Code(:class => "language-julia", """# Define a server function with @server macro
@server function get_user(id::Int)
    # This runs on the server
    DB.query(\"SELECT * FROM users WHERE id = ?\", id)
end

# Client calls via WebSocket (automatically generated)
# const user = await TherapyWS.callServer("get_user", [123]);

# Server signals push updates to all clients
visitors = create_server_signal("visitors", 0)
on_ws_connect() do conn
    update_server_signal!(visitors, v -> v + 1)
end

# Bidirectional signals for collaborative editing
shared_doc = create_bidirectional_signal("doc", "")""")
                )
            )
        ),

        # Navigation
        Div(:class => "py-8 flex justify-between border-t border-neutral-300 dark:border-neutral-800",
            A(:href => "../async/",
              :class => "inline-flex items-center text-neutral-600 dark:text-neutral-400 hover:text-emerald-700 dark:hover:text-emerald-400 transition-colors",
                Svg(:class => "mr-2 w-5 h-5", :fill => "none", :viewBox => "0 0 24 24", :stroke => "currentColor",
                    Path(:stroke_linecap => "round", :stroke_linejoin => "round", :stroke_width => "2", :d => "M11 17l-5-5m0 0l5-5m-5 5h12")
                ),
                "Async Patterns"
            ),
            A(:href => "../routing/",
              :class => "inline-flex items-center text-neutral-600 dark:text-neutral-400 hover:text-emerald-700 dark:hover:text-emerald-400 transition-colors",
                "Routing",
                Svg(:class => "ml-2 w-5 h-5", :fill => "none", :viewBox => "0 0 24 24", :stroke => "currentColor",
                    Path(:stroke_linecap => "round", :stroke_linejoin => "round", :stroke_width => "2", :d => "M13 7l5 5m0 0l-5 5m5-5H6")
                )
            )
        )
    )
end

Index
