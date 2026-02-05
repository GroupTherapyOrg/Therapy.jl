# WebSocket Example
#
# Demonstrates Therapy.jl's real-time WebSocket capabilities
# - Server signals (read-only on client)
# - Bidirectional signals (client ↔ server sync)
# - Message channels (discrete messaging)
# - Automatic reconnection
# - Graceful degradation on static hosting

function WebSocketExample()
    # Content only - Layout applied at app level for true SPA navigation
    Div(:class => "max-w-4xl mx-auto",
        # Page Header
        Div(:class => "mb-8",
            H1(:class => "text-4xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-4",
                "WebSocket Real-Time Features"
            ),
            P(:class => "text-xl text-warm-600 dark:text-warm-400",
                "Server signals, collaborative editing, and live chat - all via WebSocket."
            )
        ),

        # Demo Section 1: Visitor Counter (Server Signal)
        Section(:class => "mb-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-4",
                "1. Server Signals (Read-Only)"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mb-6",
                "Server signals are controlled server-side and broadcast to all clients. This visitor counter updates automatically when browsers connect/disconnect."
            ),

            # The VisitorCounter component (defined in components/)
            VisitorCounter()
        ),

        # Demo Section 2: Collaborative Text (Bidirectional Signal)
        Section(:class => "mb-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-4",
                "2. Bidirectional Signals (Collaborative)"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mb-6",
                "Bidirectional signals can be modified by both server AND clients. Changes sync in real-time using JSON patches (RFC 6902)."
            ),

            # The CollaborativeText component (defined in components/)
            CollaborativeText()
        ),

        # Demo Section 3: Chat Room (Channel)
        Section(:class => "mb-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-4",
                "3. Message Channels (Chat)"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mb-6",
                "Channels are for discrete messages (events), not continuous state. Messages are delivered but not persisted."
            ),

            # The ChatRoom component (defined in components/)
            ChatRoom()
        ),

        # How It Works
        Section(:class => "mb-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-4",
                "How It Works"
            ),

            # Architecture diagram
            Div(:class => "bg-warm-100 dark:bg-warm-900 rounded-lg p-6 border border-warm-200 dark:border-warm-700 mb-6",
                Pre(:class => "text-sm text-warm-800 dark:text-warm-300 overflow-x-auto",
                    Code("""
Server (Julia)                    Client (Browser)
      |                                 |
      |  WebSocket Connection           |
      |<------------------------------->|
      |                                 |
      |  {"type": "connected", ...}     |
      |-------------------------------->|
      |                                 |
      |  {"type": "subscribe",          |
      |   "signal": "visitors"}         |
      |<--------------------------------|
      |                                 |
      |  {"type": "signal_update",      |
      |   "signal": "visitors",         |
      |   "value": 42}                  |
      |-------------------------------->|
      |                                 |
                    """)
                )
            ),

            P(:class => "text-warm-600 dark:text-warm-400 mb-4",
                "Server signals are created and controlled server-side. When you update them, all subscribed clients receive the new value instantly."
            )
        ),

        # Server-Side Code
        Section(:class => "mb-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-4",
                "Server-Side Code"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mb-4",
                "Create a server signal and update it when connections change:"
            ),
            CodeBlock("""
using Therapy

# Create a server signal - broadcasts to all subscribers on update
visitors = create_server_signal("visitors", 0)

# Track connections with lifecycle hooks
on_ws_connect() do conn
    # Increment visitor count - automatically broadcasts to all clients
    update_server_signal!(visitors, v -> v + 1)
end

on_ws_disconnect() do conn
    # Decrement on disconnect
    update_server_signal!(visitors, v -> v - 1)
end
""", lang="julia")
        ),

        # Client-Side Code
        Section(:class => "mb-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-4",
                "Client-Side Code"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mb-4",
                "No JavaScript needed! Just add data attributes to your HTML:"
            ),
            CodeBlock("""
function VisitorCounter()
    Div(:data_ws_example => "true",  # Shows warning on static hosting

        # This span auto-updates when server sends "visitors" signal
        Span(:data_server_signal => "visitors", "0"),

        P("current visitors")
    )
end
""", lang="julia"),

            P(:class => "text-warm-600 dark:text-warm-400 mt-4",
                "The WebSocket client JavaScript is automatically included by the App framework. It connects to ",
                Code(:class => "bg-warm-200 dark:bg-warm-900 px-1.5 py-0.5 rounded text-sm", "ws://host/ws"),
                " and updates any element with ",
                Code(:class => "bg-warm-200 dark:bg-warm-900 px-1.5 py-0.5 rounded text-sm", "data-server-signal"),
                " when the server broadcasts."
            )
        ),

        # Features
        Section(:class => "mb-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-4",
                "Features"
            ),
            Ul(:class => "space-y-3",
                FeatureItem("Auto-reconnect", "Exponential backoff reconnection with configurable delays"),
                FeatureItem("Graceful degradation", "Shows warning on static hosting (GitHub Pages, etc.)"),
                FeatureItem("Protocol support", "wss:// on HTTPS, ws:// on HTTP"),
                FeatureItem("Subscription model", "Subscribe to specific signals, not all updates"),
                FeatureItem("JavaScript API", "window.TherapyWS for programmatic control")
            )
        ),

        # JavaScript API
        Section(:class => "mb-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-4",
                "JavaScript API"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mb-4",
                "For advanced use cases, the WebSocket client exposes a global API:"
            ),
            CodeBlock("""
// Check connection status
TherapyWS.isConnected()  // true/false

// Subscribe to additional signals
TherapyWS.subscribe("chat_messages")

// Send custom actions to server
TherapyWS.sendAction("chat", "send_message", {text: "Hello!"})

// Listen for events
window.addEventListener('therapy:ws:connected', () => {
    console.log('WebSocket connected!')
})

window.addEventListener('therapy:signal:visitors', (e) => {
    console.log('Visitors:', e.detail.value)
})
""", lang="javascript")
        ),

        # Running Locally
        Section(:class => "mb-8",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-4",
                "Running Locally"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mb-4",
                "WebSocket features require a running server. To see this example in action:"
            ),
            CodeBlock("""
# Clone the repo
git clone https://github.com/TherapeuticJulia/Therapy.jl
cd Therapy.jl

# Run the docs dev server
julia --project=. docs/app.jl dev

# Open http://localhost:8080/examples/websocket/
""", lang="bash")
        )
    )
end

# Helper for feature list items
function FeatureItem(title::String, description::String)
    Li(:class => "flex items-start gap-3",
        Span(:class => "text-accent-500 mt-1",
            Svg(:class => "w-5 h-5", :fill => "none", :viewBox => "0 0 24 24", :stroke => "currentColor", :stroke_width => "2",
                Path(:stroke_linecap => "round", :stroke_linejoin => "round", :d => "M5 13l4 4L19 7")
            )
        ),
        Div(
            Span(:class => "font-medium text-warm-800 dark:text-warm-50", title),
            Span(:class => "text-warm-600 dark:text-warm-400", " - ", description)
        )
    )
end

WebSocketExample
