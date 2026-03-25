# WebSocket Example
#
# Demonstrates Therapy.jl's real-time WebSocket capabilities
# Uses Suite.jl components for visual presentation.

import Suite

function WebSocketExample()
    # Content only - Layout applied at app level for true SPA navigation
    Div(:class => "max-w-4xl mx-auto",
        # Future feature note
        Div(:class => "mb-8 p-4 bg-red-50 dark:bg-red-950 border border-red-200 dark:border-red-800 rounded-lg",
            P(:class => "text-red-800 dark:text-red-200 font-semibold", "Planned Feature"),
            P(:class => "text-red-700 dark:text-red-300 text-sm mt-1",
                "Note: @server functions and server signals are planned features. " *
                "See FUTURE.md for the architecture."
            )
        ),

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
        Suite.Card(class="mb-12",
            Suite.CardHeader(
                Suite.CardTitle("1. Server Signals (Read-Only)"),
                Suite.CardDescription("Server signals are controlled server-side and broadcast to all clients. This visitor counter updates automatically when browsers connect/disconnect.")
            ),
            Suite.CardContent(
                VisitorCounter()
            )
        ),

        # Demo Section 2: Collaborative Text (Bidirectional Signal)
        Suite.Card(class="mb-12",
            Suite.CardHeader(
                Suite.CardTitle("2. Bidirectional Signals (Collaborative)"),
                Suite.CardDescription("Bidirectional signals can be modified by both server AND clients. Changes sync in real-time using JSON patches (RFC 6902).")
            ),
            Suite.CardContent(
                CollaborativeText()
            )
        ),

        # Demo Section 3: Chat Room (Channel)
        Suite.Card(class="mb-12",
            Suite.CardHeader(
                Suite.CardTitle("3. Message Channels (Chat)"),
                Suite.CardDescription("Channels are for discrete messages (events), not continuous state. Messages are delivered but not persisted.")
            ),
            Suite.CardContent(
                ChatRoom()
            )
        ),

        # How It Works
        Section(:class => "mb-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-4",
                "How It Works"
            ),

            Suite.CodeBlock("""Server (Julia)                    Client (Browser)
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
      |                                 |"""),

            P(:class => "text-warm-600 dark:text-warm-400 mt-4",
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
            Suite.CodeBlock("""using Therapy

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
end""", language="julia")
        ),

        # Client-Side Code
        Section(:class => "mb-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-4",
                "Client-Side Code"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mb-4",
                "No JavaScript needed! Just add data attributes to your HTML:"
            ),
            Suite.CodeBlock("""function VisitorCounter()
    Div(:data_ws_example => "true",  # Shows warning on static hosting

        # This span auto-updates when server sends "visitors" signal
        Span(:data_server_signal => "visitors", "0"),

        P("current visitors")
    )
end""", language="julia"),

            Suite.Alert(class="mt-4",
                Suite.AlertDescription(
                    "The WebSocket client JavaScript is automatically included by the App framework. It connects to ",
                    Code(:class => "bg-warm-200 dark:bg-warm-900 px-1.5 py-0.5 rounded text-sm", "ws://host/ws"),
                    " and updates any element with ",
                    Code(:class => "bg-warm-200 dark:bg-warm-900 px-1.5 py-0.5 rounded text-sm", "data-server-signal"),
                    " when the server broadcasts."
                )
            )
        ),

        # Features
        Section(:class => "mb-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-4",
                "Features"
            ),
            Suite.Card(
                Suite.CardContent(
                    Ul(:class => "space-y-3",
                        _FeatureItem("Auto-reconnect", "Exponential backoff reconnection with configurable delays"),
                        _FeatureItem("Graceful degradation", "Shows warning on static hosting (GitHub Pages, etc.)"),
                        _FeatureItem("Protocol support", "wss:// on HTTPS, ws:// on HTTP"),
                        _FeatureItem("Subscription model", "Subscribe to specific signals, not all updates"),
                        _FeatureItem("JavaScript API", "window.TherapyWS for programmatic control")
                    )
                )
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
            Suite.CodeBlock("""// Check connection status
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
})""", language="javascript")
        ),

        # Running Locally
        Section(:class => "mb-8",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-4",
                "Running Locally"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mb-4",
                "WebSocket features require a running server. To see this example in action:"
            ),
            Suite.CodeBlock("""# Clone the repo
git clone https://github.com/GroupTherapyOrg/Therapy.jl
cd Therapy.jl

# Run the docs dev server
julia --project=. docs/app.jl dev

# Open http://localhost:8080/examples/websocket/""", language="bash")
        )
    )
end

# Helper for feature list items
function _FeatureItem(title::String, description::String)
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
