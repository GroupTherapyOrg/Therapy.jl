# Server Features - Part 5 of the Therapy.jl Book
#
# Overview hub for SSR, server functions, and real-time WebSocket communication.

import Suite

function ServerIndex()
    BookLayout("/book/server/",
        # Header
        Div(:class => "py-8 border-b border-warm-200 dark:border-warm-700",
            Suite.Badge(variant="outline", "Part 5"),
            H1(:class => "text-4xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-2 mb-4",
                "Server Features"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 max-w-3xl",
                "Therapy.jl is a full-stack framework. Your Julia code runs on the server for SSR, ",
                "handles client-server communication via WebSocket, and provides seamless RPC ",
                "with the ", Code(:class => "text-accent-700 dark:text-accent-400", "@server"), " macro."
            )
        ),

        # The Server Story
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "The Full-Stack Story"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Modern web applications need more than just a reactive frontend. They need server-side rendering ",
                "for SEO and fast initial load, server functions for secure data access, and real-time updates ",
                "for collaborative features. Therapy.jl provides all of this in one cohesive package."
            ),
            Div(:class => "grid md:grid-cols-3 gap-6 mt-8",
                Suite.Card(class="text-center",
                    Suite.CardContent(class="pt-6",
                        Div(:class => "text-3xl mb-3", "\xF0\x9F\x96\xA5\xEF\xB8\x8F"),
                        H3(:class => "text-lg font-serif font-semibold text-warm-800 dark:text-warm-50 mb-2", "Server-Side Rendering"),
                        P(:class => "text-warm-600 dark:text-warm-400 text-sm", "Fast initial load, SEO-friendly, progressive enhancement")
                    )
                ),
                Suite.Card(class="text-center",
                    Suite.CardContent(class="pt-6",
                        Div(:class => "text-3xl mb-3", "\xE2\x9A\xA1"),
                        H3(:class => "text-lg font-serif font-semibold text-warm-800 dark:text-warm-50 mb-2", "Server Functions"),
                        P(:class => "text-warm-600 dark:text-warm-400 text-sm", "Type-safe RPC, automatic serialization, secure by default")
                    )
                ),
                Suite.Card(class="text-center",
                    Suite.CardContent(class="pt-6",
                        Div(:class => "text-3xl mb-3", "\xF0\x9F\x94\x84"),
                        H3(:class => "text-lg font-serif font-semibold text-warm-800 dark:text-warm-50 mb-2", "Real-Time"),
                        P(:class => "text-warm-600 dark:text-warm-400 text-sm", "WebSocket signals, collaborative editing, live updates")
                    )
                )
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "The same Julia code runs on both server and client. Write once, deploy everywhere."
            )
        ),

        Suite.Separator(),

        # Chapters in This Section
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Chapters in This Section"
            ),
            Div(:class => "grid md:grid-cols-2 gap-6",
                A(:href => "./ssr", :class => "block group",
                    Suite.Card(class="h-full transition-colors hover:border-accent-400 dark:hover:border-accent-600",
                        Suite.CardHeader(
                            Suite.CardTitle(:class => "font-serif group-hover:text-accent-700 dark:group-hover:text-accent-400", "Server-Side Rendering"),
                            Suite.CardDescription(
                                Code(:class => "text-sm text-accent-700 dark:text-accent-400", "render_to_string")
                            )
                        ),
                        Suite.CardContent(
                            P(:class => "text-warm-600 dark:text-warm-400 text-sm", "Render components to HTML on the server, with automatic hydration on the client.")
                        )
                    )
                ),
                A(:href => "./server-functions", :class => "block group",
                    Suite.Card(class="h-full transition-colors hover:border-accent-400 dark:hover:border-accent-600",
                        Suite.CardHeader(
                            Suite.CardTitle(:class => "font-serif group-hover:text-accent-700 dark:group-hover:text-accent-400", "Server Functions"),
                            Suite.CardDescription(
                                Code(:class => "text-sm text-accent-700 dark:text-accent-400", "@server macro")
                            )
                        ),
                        Suite.CardContent(
                            P(:class => "text-warm-600 dark:text-warm-400 text-sm", "Define functions that run on the server but can be called from the client.")
                        )
                    )
                ),
                A(:href => "./websocket", :class => "block group",
                    Suite.Card(class="h-full transition-colors hover:border-accent-400 dark:hover:border-accent-600",
                        Suite.CardHeader(
                            Suite.CardTitle(:class => "font-serif group-hover:text-accent-700 dark:group-hover:text-accent-400", "WebSocket & Real-Time"),
                            Suite.CardDescription(
                                Code(:class => "text-sm text-accent-700 dark:text-accent-400", "ServerSignal / Channel")
                            )
                        ),
                        Suite.CardContent(
                            P(:class => "text-warm-600 dark:text-warm-400 text-sm", "Push updates to clients, enable collaborative editing, build real-time features.")
                        )
                    )
                )
            )
        ),

        Suite.Separator(),

        # Quick Overview: SSR
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "SSR at a Glance"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Server-side rendering converts your components to HTML before sending to the browser:"
            ),
            Suite.CodeBlock(
                """# Any component can be rendered to HTML
html = render_to_string(
    Div(:class => "container",
        H1("Hello from Julia!"),
        P("This HTML was generated on the server.")
    )
)
# => "<div class=\\"container\\" data-hk=\\"1\\">..."

# Full page with doctype, head, and body
html = render_page(
    MyApp();
    title = "My Application",
    head_extra = tailwind_cdn()
)""",
                language="julia"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-4",
                "The ", Code(:class => "text-accent-700 dark:text-accent-400", "data-hk"),
                " attributes are hydration keys\u2014they allow interactive ", Code(:class => "text-accent-700 dark:text-accent-400", "@island"),
                " components to find their DOM nodes after the page loads."
            )
        ),

        Suite.Separator(),

        # Quick Overview: Server Functions
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Server Functions at a Glance"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "The ", Code(:class => "text-accent-700 dark:text-accent-400", "@server"),
                " macro defines functions that execute on the server but can be called from the client:"
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-300 mb-4",
                        "Server Side (Julia)"
                    ),
                    Suite.CodeBlock(
                        """# Define a server function
@server function get_user(id::Int)
    DB.query("SELECT * FROM users
              WHERE id = ?", id)
end

@server function save_note(
    title::String,
    content::String
)
    DB.insert("notes",
        title=title,
        content=content
    )
end""",
                        language="julia",
                        show_copy=false
                    )
                ),
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-300 mb-4",
                        "Client Side (JavaScript)"
                    ),
                    Suite.CodeBlock(
                        """// Call server functions via WebSocket
const user = await TherapyWS.callServer(
    "get_user",
    [123]
);
console.log(user.name);

// Save data
await TherapyWS.callServer(
    "save_note",
    ["My Title", "Content here"]
);""",
                        language="javascript",
                        show_copy=false
                    )
                )
            ),
            Suite.Alert(class="mt-8",
                Suite.AlertTitle("Security by Default"),
                Suite.AlertDescription(
                    "Server functions only expose what you explicitly define. Database access, file operations, " *
                    "and sensitive logic stay on the server. Arguments are validated before execution."
                )
            )
        ),

        Suite.Separator(),

        # Quick Overview: Real-Time
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Real-Time at a Glance"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Therapy.jl provides three primitives for real-time communication:"
            ),
            Div(:class => "space-y-6",
                # Server Signals
                Suite.Card(
                    Suite.CardHeader(
                        Suite.CardTitle(:class => "text-xl font-serif", "Server Signals (Server \u2192 Clients)")
                    ),
                    Suite.CardContent(
                        P(:class => "text-warm-600 dark:text-warm-400 mb-4",
                            "Push state updates from server to all connected clients. Read-only on client."
                        ),
                        Suite.CodeBlock(
                            """# Server: Create and update
visitors = create_server_signal("visitors", 0)
on_ws_connect() do conn
    update_server_signal!(visitors, v -> v + 1)
end

# Client: Auto-subscribes via data attribute
Span(:data_server_signal => "visitors", "0")""",
                            language="julia",
                            show_copy=false
                        )
                    )
                ),

                # Bidirectional Signals
                Suite.Card(
                    Suite.CardHeader(
                        Suite.CardTitle(:class => "text-xl font-serif", "Bidirectional Signals (Server \u2194 Clients)")
                    ),
                    Suite.CardContent(
                        P(:class => "text-warm-600 dark:text-warm-400 mb-4",
                            "Two-way sync for collaborative features. Any client can update, all see changes."
                        ),
                        Suite.CodeBlock(
                            """# Server: Create with validation
shared_doc = create_bidirectional_signal("doc", "")
on_bidirectional_update("doc") do conn, new_value
    length(new_value) <= 50000  # Reject if too long
end

# Client: Update from textarea
Textarea(
    :data_bidirectional_signal => "doc",
    :oninput => "TherapyWS.setBidirectional('doc', this.value)"
)""",
                            language="julia",
                            show_copy=false
                        )
                    )
                ),

                # Channels
                Suite.Card(
                    Suite.CardHeader(
                        Suite.CardTitle(:class => "text-xl font-serif", "Channels (Discrete Messages)")
                    ),
                    Suite.CardContent(
                        P(:class => "text-warm-600 dark:text-warm-400 mb-4",
                            "Event-based messaging for chat, notifications, game events. Messages are delivered, not persisted."
                        ),
                        Suite.CodeBlock(
                            """# Server: Handle and broadcast
chat = create_channel("chat")
on_channel_message("chat") do conn, data
    broadcast_channel!("chat", Dict(
        "text" => data["text"],
        "from" => conn.id[1:8]
    ))
end

# Client: Send and listen
TherapyWS.sendMessage('chat', { text: 'Hello!' });
TherapyWS.onChannelMessage('chat', msg => {
    console.log(msg.from + ': ' + msg.text);
});""",
                            language="javascript",
                            show_copy=false
                        )
                    )
                )
            )
        ),

        Suite.Separator(),

        # How It All Connects
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "How It All Connects"
            ),
            Div(:class => "space-y-4",
                Div(:class => "flex items-start gap-4",
                    Suite.Badge(variant="default", "1"),
                    P(:class => "pt-0.5 text-warm-600 dark:text-warm-300", "Browser requests a page")
                ),
                Div(:class => "flex items-start gap-4",
                    Suite.Badge(variant="default", "2"),
                    P(:class => "pt-0.5 text-warm-600 dark:text-warm-300", "Server renders components to HTML (SSR)")
                ),
                Div(:class => "flex items-start gap-4",
                    Suite.Badge(variant="default", "3"),
                    P(:class => "pt-0.5 text-warm-600 dark:text-warm-300", "Browser receives HTML, shows content immediately")
                ),
                Div(:class => "flex items-start gap-4",
                    Suite.Badge(variant="default", "4"),
                    P(:class => "pt-0.5 text-warm-600 dark:text-warm-300", "JavaScript loads, WebSocket connects")
                ),
                Div(:class => "flex items-start gap-4",
                    Suite.Badge(variant="default", "5"),
                    P(:class => "pt-0.5 text-warm-600 dark:text-warm-300", "Islands hydrate\u2014interactive components come alive")
                ),
                Div(:class => "flex items-start gap-4",
                    Suite.Badge(variant="default", "6"),
                    P(:class => "pt-0.5 text-warm-600 dark:text-warm-300", "Client calls @server functions for data operations")
                ),
                Div(:class => "flex items-start gap-4",
                    Suite.Badge(variant="default", "7"),
                    P(:class => "pt-0.5 text-warm-600 dark:text-warm-300", "ServerSignals push real-time updates to all clients")
                )
            ),
            Suite.Alert(class="mt-12",
                Suite.AlertTitle("Key Takeaways"),
                Suite.AlertDescription(
                    P("This flow gives you the best of both worlds: fast initial load with SSR, rich interactivity with islands, " *
                      "and real-time collaboration with WebSocket.")
                )
            )
        ),

    )
end

# Export the page component
ServerIndex
