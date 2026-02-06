# Server Features - Part 5 of the Therapy.jl Book
#
# Overview hub for SSR, server functions, and real-time WebSocket communication.

function ServerIndex()
    BookLayout("/book/server/",
        # Header
        Div(:class => "py-8 border-b border-warm-200 dark:border-warm-700",
            Span(:class => "text-sm text-accent-700 dark:text-accent-400 font-medium", "Part 5"),
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
                ServerIconCard("🖥️", "Server-Side Rendering", "Fast initial load, SEO-friendly, progressive enhancement"),
                ServerIconCard("⚡", "Server Functions", "Type-safe RPC, automatic serialization, secure by default"),
                ServerIconCard("🔄", "Real-Time", "WebSocket signals, collaborative editing, live updates")
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "The same Julia code runs on both server and client. Write once, deploy everywhere."
            )
        ),

        # Chapters in This Section
        Section(:class => "py-12 bg-warm-100 dark:bg-warm-900 rounded-lg border border-warm-200 dark:border-warm-700 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Chapters in This Section"
            ),
            Div(:class => "grid md:grid-cols-2 gap-6",
                ChapterCard(
                    "./ssr",
                    "Server-Side Rendering",
                    "render_to_string",
                    "Render components to HTML on the server, with automatic hydration on the client."
                ),
                ChapterCard(
                    "./server-functions",
                    "Server Functions",
                    "@server macro",
                    "Define functions that run on the server but can be called from the client."
                ),
                ChapterCard(
                    "./websocket",
                    "WebSocket & Real-Time",
                    "ServerSignal / Channel",
                    "Push updates to clients, enable collaborative editing, build real-time features."
                )
            )
        ),

        # Quick Overview: SSR
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "SSR at a Glance"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Server-side rendering converts your components to HTML before sending to the browser:"
            ),
            CodeBlock("""# Any component can be rendered to HTML
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
)"""),
            P(:class => "text-warm-600 dark:text-warm-400 mt-4",
                "The ", Code(:class => "text-accent-700 dark:text-accent-400", "data-hk"),
                " attributes are hydration keys—they allow interactive ", Code(:class => "text-accent-700 dark:text-accent-400", "@island"),
                " components to find their DOM nodes after the page loads."
            )
        ),

        # Quick Overview: Server Functions
        Section(:class => "py-12 bg-warm-100 dark:bg-warm-900 rounded-lg border border-warm-200 dark:border-warm-700 px-8",
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
                    CodeBlock("""# Define a server function
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
end""", "neutral")
                ),
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-300 mb-4",
                        "Client Side (JavaScript)"
                    ),
                    CodeBlock("""// Call server functions via WebSocket
const user = await TherapyWS.callServer(
    "get_user",
    [123]
);
console.log(user.name);

// Save data
await TherapyWS.callServer(
    "save_note",
    ["My Title", "Content here"]
);""", "neutral")
                )
            ),
            InfoBox("Security by Default",
                "Server functions only expose what you explicitly define. Database access, file operations, " *
                "and sensitive logic stay on the server. Arguments are validated before execution."
            )
        ),

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
                Div(:class => "bg-warm-50 dark:bg-warm-900 rounded-lg border border-warm-200 dark:border-warm-800 p-6",
                    H3(:class => "text-xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-3",
                        "Server Signals (Server → Clients)"
                    ),
                    P(:class => "text-warm-600 dark:text-warm-400 mb-4",
                        "Push state updates from server to all connected clients. Read-only on client."
                    ),
                    CodeBlock("""# Server: Create and update
visitors = create_server_signal("visitors", 0)
on_ws_connect() do conn
    update_server_signal!(visitors, v -> v + 1)
end

# Client: Auto-subscribes via data attribute
Span(:data_server_signal => "visitors", "0")""", "neutral")
                ),

                # Bidirectional Signals
                Div(:class => "bg-warm-50 dark:bg-warm-900 rounded-lg border border-warm-200 dark:border-warm-800 p-6",
                    H3(:class => "text-xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-3",
                        "Bidirectional Signals (Server ↔ Clients)"
                    ),
                    P(:class => "text-warm-600 dark:text-warm-400 mb-4",
                        "Two-way sync for collaborative features. Any client can update, all see changes."
                    ),
                    CodeBlock("""# Server: Create with validation
shared_doc = create_bidirectional_signal("doc", "")
on_bidirectional_update("doc") do conn, new_value
    length(new_value) <= 50000  # Reject if too long
end

# Client: Update from textarea
Textarea(
    :data_bidirectional_signal => "doc",
    :oninput => "TherapyWS.setBidirectional('doc', this.value)"
)""", "neutral")
                ),

                # Channels
                Div(:class => "bg-warm-50 dark:bg-warm-900 rounded-lg border border-warm-200 dark:border-warm-800 p-6",
                    H3(:class => "text-xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-3",
                        "Channels (Discrete Messages)"
                    ),
                    P(:class => "text-warm-600 dark:text-warm-400 mb-4",
                        "Event-based messaging for chat, notifications, game events. Messages are delivered, not persisted."
                    ),
                    CodeBlock("""# Server: Handle and broadcast
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
});""", "neutral")
                )
            )
        ),

        # How It All Connects
        Section(:class => "py-12 bg-warm-50 dark:bg-warm-900/30 rounded-lg border border-warm-200 dark:border-warm-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-accent-900 dark:text-accent-200 mb-6",
                "How It All Connects"
            ),
            Div(:class => "space-y-4 text-accent-800 dark:text-accent-300",
                FlowStep("1", "Browser requests a page"),
                FlowStep("2", "Server renders components to HTML (SSR)"),
                FlowStep("3", "Browser receives HTML, shows content immediately"),
                FlowStep("4", "JavaScript loads, WebSocket connects"),
                FlowStep("5", "Islands hydrate—interactive components come alive"),
                FlowStep("6", "Client calls @server functions for data operations"),
                FlowStep("7", "ServerSignals push real-time updates to all clients")
            ),
            P(:class => "mt-6 text-accent-700 dark:text-accent-400 font-medium",
                "This flow gives you the best of both worlds: fast initial load with SSR, rich interactivity with islands, ",
                "and real-time collaboration with WebSocket."
            )
        ),

    )
end

# Helper Components

function ServerIconCard(icon, title, description)
    # Local helper - avoids name collision with homepage FeatureCard
    Div(:class => "bg-warm-50 dark:bg-warm-900 rounded-lg border border-warm-200 dark:border-warm-800 p-6 text-center",
        Div(:class => "text-3xl mb-3", icon),
        H3(:class => "text-lg font-serif font-semibold text-warm-800 dark:text-warm-50 mb-2", title),
        P(:class => "text-warm-600 dark:text-warm-400 text-sm", description)
    )
end

function ChapterCard(href, title, code_preview, description)
    A(:href => href,
      :class => "block bg-warm-50 dark:bg-warm-900 rounded-lg border border-warm-200 dark:border-warm-800 p-6 hover:border-accent-400 dark:hover:border-accent-600 transition-colors group",
        H3(:class => "text-xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-2 group-hover:text-accent-700 dark:group-hover:text-accent-400", title),
        Code(:class => "text-sm text-accent-700 dark:text-accent-400", code_preview),
        P(:class => "text-warm-600 dark:text-warm-400 mt-3 text-sm", description)
    )
end

function CodeBlock(code, style="default")
    bg_class = if style == "emerald"
        "bg-warm-900 dark:bg-warm-950 border-warm-700"
    elseif style == "neutral"
        "bg-warm-800 dark:bg-warm-900 border-warm-600"
    else
        "bg-warm-800 dark:bg-warm-950 border-warm-900"
    end

    Div(:class => "$bg_class rounded border p-6 overflow-x-auto",
        Pre(:class => "text-sm text-warm-50",
            Code(:class => "language-julia", code)
        )
    )
end

function InfoBox(title, content)
    Div(:class => "mt-8 bg-blue-50 dark:bg-blue-950/30 rounded-lg border border-blue-200 dark:border-blue-900 p-6",
        H3(:class => "text-lg font-serif font-semibold text-blue-900 dark:text-blue-200 mb-2", title),
        P(:class => "text-blue-800 dark:text-blue-300", content)
    )
end

function FlowStep(number, text)
    Div(:class => "flex items-start gap-4",
        Span(:class => "flex-shrink-0 w-8 h-8 bg-accent-700 dark:bg-accent-600 text-white rounded-full flex items-center justify-center font-semibold text-sm", number),
        P(:class => "pt-1", text)
    )
end

# Export the page component
ServerIndex
