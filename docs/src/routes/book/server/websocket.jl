# WebSocket & Real-Time - Part 5.3 of the Therapy.jl Book
#
# Push updates to clients, enable collaborative editing, build real-time features.

function Index()
    BookLayout(
        # Header
        Div(:class => "py-8 border-b border-neutral-300 dark:border-neutral-800",
            Span(:class => "text-sm text-emerald-700 dark:text-emerald-400 font-medium", "Part 5 · Server Features"),
            H1(:class => "text-4xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mt-2 mb-4",
                "WebSocket & Real-Time"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 max-w-3xl",
                "HTTP is request-response: the client asks, the server answers. But what if the ",
                "server needs to push updates to the client? That's where WebSocket comes in—a ",
                "persistent, bidirectional connection for real-time features."
            )
        ),

        # Three Primitives
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Three Primitives for Real-Time"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "Therapy.jl provides three complementary primitives for real-time communication:"
            ),
            Div(:class => "grid md:grid-cols-3 gap-6",
                PrimitiveCard(
                    "Server Signals",
                    "Server → Clients",
                    "Server controls the value. Clients subscribe and receive updates. Read-only on client.",
                    "Visitor counters, server status, live prices"
                ),
                PrimitiveCard(
                    "Bidirectional Signals",
                    "Server ↔ Clients",
                    "Any participant can update. Changes sync to all others. Two-way binding.",
                    "Collaborative editing, shared whiteboards, multiplayer state"
                ),
                PrimitiveCard(
                    "Channels",
                    "Messages (Events)",
                    "Discrete messages, not continuous state. Fire-and-forget delivery.",
                    "Chat, notifications, game events, triggers"
                )
            )
        ),

        # Server Signals
        Section(:class => "py-12 bg-neutral-50 dark:bg-neutral-900 rounded-lg border border-neutral-300 dark:border-neutral-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Server Signals: Push State to Clients"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "Server signals are the simplest real-time primitive. The server controls the value; ",
                "clients can only subscribe and read."
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-neutral-800 dark:text-neutral-200 mb-4",
                        "Server Side"
                    ),
                    CodeBlock("""# Create a server signal
visitors = create_server_signal("visitors", 0)

# Update it (broadcasts to all subscribers)
set_server_signal!(visitors, 42)

# Or update with a function
update_server_signal!(visitors, v -> v + 1)

# Convenient operators
visitors[] = 100     # Same as set_server_signal!
current = visitors[] # Read current value

# Connection lifecycle hooks
on_ws_connect() do conn
    update_server_signal!(visitors, v -> v + 1)
    println("Connected: ", conn.id)
end

on_ws_disconnect() do conn
    update_server_signal!(visitors, v -> v - 1)
end""", "neutral")
                ),
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-neutral-800 dark:text-neutral-200 mb-4",
                        "Client Side"
                    ),
                    CodeBlock("""<!-- Auto-subscribe via data attribute -->
<span data-server-signal="visitors">0</span>

<!-- Element updates automatically when
     server broadcasts "visitors" signal -->

<!-- JavaScript API -->
<script>
// Manual subscription
TherapyWS.subscribe("visitors");

// Listen for updates
window.addEventListener(
    'therapy:signal:visitors',
    (e) => console.log('New value:', e.detail.value)
);

// Read current value
const count = TherapyWS.getSignalValue("visitors");
</script>""", "neutral")
                )
            ),
            InfoBox("JSON Patches for Efficiency",
                "Server signals use JSON patches (RFC 6902) by default. Instead of sending the " *
                "entire value on each update, only the diff is sent. This is especially important " *
                "for large objects or arrays. Set use_patches=false for simple values if needed."
            )
        ),

        # Bidirectional Signals
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Bidirectional Signals: Collaborative State"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "When multiple users need to edit the same data, use bidirectional signals. ",
                "Any participant (server or client) can update the value, and changes sync to everyone else."
            ),
            CodeBlock("""# Server: Create bidirectional signal
shared_doc = create_bidirectional_signal("document", "")

# Add validation (optional but recommended)
on_bidirectional_update("document") do conn, new_value
    # Validate the update
    if length(new_value) > 50000
        return false  # Reject (too long)
    end

    # Sanitize if needed
    sanitized = strip(new_value)

    # Return true to accept as-is, or return modified value
    return sanitized
end

# Server can also update (broadcasts to ALL clients)
set_bidirectional_signal!(shared_doc, "Initial content")"""),
            Div(:class => "mt-8",
                H3(:class => "text-lg font-serif font-semibold text-neutral-800 dark:text-neutral-200 mb-4",
                    "Client-Side Binding"
                ),
                CodeBlock("""<!-- Textarea that syncs with server and other clients -->
<textarea
    data-bidirectional-signal="document"
    oninput="TherapyWS.setBidirectional('document', this.value)">
</textarea>

<!-- In Therapy.jl component syntax -->
Textarea(
    :data_bidirectional_signal => "document",
    :oninput => "TherapyWS.setBidirectional('document', this.value)"
)""")
            ),
            WarnBox("Conflict Resolution",
                "Bidirectional signals use last-write-wins. For complex collaborative editing " *
                "with OT or CRDT conflict resolution, you'll need additional logic. " *
                "The signal provides the sync mechanism; you provide the merge strategy."
            )
        ),

        # Channels
        Section(:class => "py-12 bg-neutral-50 dark:bg-neutral-900 rounded-lg border border-neutral-300 dark:border-neutral-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Channels: Discrete Messages"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "Channels are for discrete events—messages that are delivered once, not persistent state. ",
                "Think chat messages, notifications, game events."
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-neutral-800 dark:text-neutral-200 mb-4",
                        "Server Side"
                    ),
                    CodeBlock("""# Create a channel
chat = create_channel("chat")

# Handle incoming messages
on_channel_message("chat") do conn, data
    # Process the message
    message = Dict(
        "text" => data["text"],
        "from" => conn.id[1:8],
        "timestamp" => time()
    )

    # Broadcast to all clients
    broadcast_channel!("chat", message)
end

# Server can also send messages
broadcast_channel!("chat", Dict(
    "text" => "Server announcement!",
    "from" => "system"
))

# Send to specific user
send_channel!("notifications", user_conn_id, Dict(
    "text" => "You have a new message!"
))

# Broadcast except sender (avoid echo)
broadcast_channel_except!("chat", msg, sender_conn.id)""", "neutral")
                ),
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-neutral-800 dark:text-neutral-200 mb-4",
                        "Client Side"
                    ),
                    CodeBlock("""// Send a message
TherapyWS.sendMessage('chat', {
    text: 'Hello everyone!'
});

// Listen for messages
TherapyWS.onChannelMessage('chat', (data) => {
    console.log(data.from + ': ' + data.text);

    // Add to chat UI
    addMessage(data);
});

// Or use DOM events
window.addEventListener(
    'therapy:channel:chat',
    (e) => addMessage(e.detail)
);""", "neutral")
                )
            ),
            InfoBox("Signals vs Channels",
                "Use Signals when you care about the current state (\"what is the value now?\"). " *
                "Use Channels when you care about events (\"what happened?\"). " *
                "A chat needs channels (messages are events). A visitor counter needs signals (it's state)."
            )
        ),

        # Connection Lifecycle
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Connection Lifecycle"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "The WebSocket connection has lifecycle hooks for tracking connections:"
            ),
            CodeBlock("""# Track connections
on_ws_connect() do conn
    @info "Client connected" id=conn.id

    # Initialize per-user state
    USER_STATES[conn.id] = Dict("joined_at" => time())

    # Send welcome message
    send_channel!("private", conn.id, Dict(
        "text" => "Welcome! You are user " * conn.id[1:8]
    ))

    # Update visitor count
    update_server_signal!(visitors, v -> v + 1)
end

on_ws_disconnect() do conn
    @info "Client disconnected" id=conn.id

    # Cleanup per-user state
    delete!(USER_STATES, conn.id)

    # Update visitor count
    update_server_signal!(visitors, v -> v - 1)
end

# Access connection info
# conn.id       - Unique connection ID (UUID)
# conn.ws       - Raw WebSocket object
# conn.metadata - Dict for custom data"""),
            P(:class => "text-neutral-600 dark:text-neutral-400 mt-4",
                "Connection IDs are UUIDs—unique per connection, not per user. A user refreshing ",
                "the page gets a new connection ID."
            )
        ),

        # Client JavaScript API
        Section(:class => "py-12 bg-neutral-50 dark:bg-neutral-900 rounded-lg border border-neutral-300 dark:border-neutral-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Client JavaScript API"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "The ", Code(:class => "text-emerald-700 dark:text-emerald-400", "TherapyWS"),
                " object provides the client-side WebSocket API:"
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-neutral-800 dark:text-neutral-200 mb-4",
                        "Connection"
                    ),
                    CodeBlock("""// Check connection status
TherapyWS.isConnected()
// => true / false

// Get connection ID
TherapyWS.getConnectionId()
// => "abc123-..."

// Connection events
window.addEventListener(
    'therapy:ws:connected', () => {
        console.log('WebSocket connected!');
    }
);

window.addEventListener(
    'therapy:ws:disconnected', () => {
        console.log('WebSocket lost!');
    }
);""", "neutral")
                ),
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-neutral-800 dark:text-neutral-200 mb-4",
                        "Server Signals"
                    ),
                    CodeBlock("""// Manual subscription
TherapyWS.subscribe("visitors");
TherapyWS.unsubscribe("visitors");

// Auto-discover data-server-signal
TherapyWS.discoverAndSubscribe();

// Read current value
const val = TherapyWS.getSignalValue("visitors");

// Signal update events
window.addEventListener(
    'therapy:signal:visitors',
    (e) => console.log(e.detail.value)
);""", "neutral")
                ),
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-neutral-800 dark:text-neutral-200 mb-4",
                        "Bidirectional Signals"
                    ),
                    CodeBlock("""// Update a bidirectional signal
TherapyWS.setBidirectional(
    "document",
    newValue
);

// Read current value
const doc = TherapyWS.getSignalValue("document");""", "neutral")
                ),
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-neutral-800 dark:text-neutral-200 mb-4",
                        "Channels"
                    ),
                    CodeBlock("""// Send a message
TherapyWS.sendMessage("chat", {
    text: "Hello!"
});

// Listen for messages
TherapyWS.onChannelMessage("chat", (data) => {
    console.log(data);
});

// Channel events
window.addEventListener(
    'therapy:channel:chat',
    (e) => console.log(e.detail)
);""", "neutral")
                )
            )
        ),

        # Auto-Reconnect
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Auto-Reconnect & Resilience"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "WebSocket connections can drop due to network issues, server restarts, or mobile ",
                "devices going to sleep. Therapy.jl handles this automatically:"
            ),
            Div(:class => "bg-white dark:bg-neutral-800 rounded-lg border border-neutral-300 dark:border-neutral-700 p-6",
                Ul(:class => "space-y-3 text-neutral-600 dark:text-neutral-400",
                    Li(Strong("Exponential Backoff"), " — Reconnect attempts start at 1s, double each time (max 30s)"),
                    Li(Strong("Auto Re-Subscribe"), " — After reconnect, client re-subscribes to previous signals"),
                    Li(Strong("Connection Events"), " — Your code is notified of connect/disconnect via events"),
                    Li(Strong("Graceful Degradation"), " — On static hosting (no WebSocket), shows warning UI instead of crashing")
                )
            ),
            CodeBlock("""// Detect connection issues in your app
window.addEventListener('therapy:ws:disconnected', () => {
    showNotification("Connection lost. Reconnecting...");
});

window.addEventListener('therapy:ws:connected', () => {
    hideNotification();

    // Re-sync state if needed
    refreshData();
});"""),
            InfoBox("Static Hosting",
                "If you deploy to static hosting (GitHub Pages, Netlify static), WebSocket won't work. " *
                "Therapy.jl detects this and shows a warning for elements that need WebSocket. " *
                "Your SSR content still works—only real-time features are affected."
            )
        ),

        # Complete Example: Live Chat
        Section(:class => "py-12 bg-emerald-50 dark:bg-emerald-950/30 rounded-lg border border-emerald-200 dark:border-emerald-900 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-emerald-900 dark:text-emerald-200 mb-6",
                "Complete Example: Live Chat"
            ),
            P(:class => "text-lg text-emerald-800 dark:text-emerald-300 mb-6",
                "Let's build a simple chat app using channels:"
            ),
            CodeBlock("""# Server (app.jl)
using Therapy

# Track online users
users_online = create_server_signal("users_online", 0)

# Create chat channel
chat = create_channel("chat")

on_channel_message("chat") do conn, data
    # Validate
    text = strip(get(data, "text", ""))
    if isempty(text) || length(text) > 1000
        return
    end

    # Broadcast to all
    broadcast_channel!("chat", Dict(
        "text" => text,
        "from" => conn.id[1:8],
        "time" => Dates.format(now(), "HH:MM")
    ))
end

on_ws_connect() do conn
    update_server_signal!(users_online, n -> n + 1)
end

on_ws_disconnect() do conn
    update_server_signal!(users_online, n -> n - 1)
end""", "emerald"),
            CodeBlock("""# Component (routes/chat.jl)
function ChatPage()
    Div(:class => "max-w-2xl mx-auto p-4",
        # Header with user count
        Div(:class => "flex justify-between items-center mb-4",
            H1(:class => "text-2xl font-bold", "Live Chat"),
            Span(:class => "text-gray-600",
                Span(:data_server_signal => "users_online", "0"),
                " users online"
            )
        ),

        # Messages container
        Div(:id => "messages",
            :class => "h-96 overflow-y-auto border rounded p-4 mb-4 space-y-2"
        ),

        # Input form
        Form(:onsubmit => "sendMessage(event)",
            Div(:class => "flex gap-2",
                Input(:id => "msgInput",
                    :type => "text",
                    :class => "flex-1 border rounded px-4 py-2",
                    :placeholder => "Type a message..."
                ),
                Button(:type => "submit",
                    :class => "bg-blue-500 text-white px-4 py-2 rounded",
                    "Send"
                )
            )
        ),

        # Chat JavaScript
        Script(RawHtml(\"\"\"
        function sendMessage(e) {
            e.preventDefault();
            const input = document.getElementById('msgInput');
            if (input.value.trim()) {
                TherapyWS.sendMessage('chat', { text: input.value });
                input.value = '';
            }
        }

        TherapyWS.onChannelMessage('chat', (msg) => {
            const div = document.createElement('div');
            div.innerHTML = '<b>' + msg.from + '</b> <span class="text-gray-500">' +
                           msg.time + '</span><br>' + msg.text;
            document.getElementById('messages').appendChild(div);
        });
        \"\"\"))
    )
end""", "emerald")
        ),

        # Key Takeaways
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Key Takeaways"
            ),
            Ul(:class => "space-y-3 text-neutral-700 dark:text-neutral-300",
                Li(Strong("Server Signals"), " push state from server to clients (read-only on client)"),
                Li(Strong("Bidirectional Signals"), " sync state between server and all clients (two-way)"),
                Li(Strong("Channels"), " send discrete messages/events (not state)"),
                Li(Strong("Auto-reconnect"), " with exponential backoff handles connection drops"),
                Li(Strong("JSON Patches"), " (RFC 6902) minimize bandwidth for signal updates"),
                Li(Strong("Validation handlers"), " let you sanitize or reject bidirectional updates")
            )
        ),

        # Navigation
        Div(:class => "py-8 flex justify-between border-t border-neutral-300 dark:border-neutral-800",
            A(:href => "./server-functions",
              :class => "inline-flex items-center text-neutral-600 dark:text-neutral-400 hover:text-emerald-700 dark:hover:text-emerald-400 transition-colors",
                Svg(:class => "mr-2 w-5 h-5", :fill => "none", :viewBox => "0 0 24 24", :stroke => "currentColor",
                    Path(:stroke_linecap => "round", :stroke_linejoin => "round", :stroke_width => "2", :d => "M11 17l-5-5m0 0l5-5m-5 5h12")
                ),
                "Server Functions"
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

# Helper Components

function PrimitiveCard(title, flow, description, examples)
    Div(:class => "bg-white dark:bg-neutral-800 rounded-lg border border-neutral-300 dark:border-neutral-700 p-6",
        H3(:class => "text-xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-1", title),
        Span(:class => "text-sm text-emerald-700 dark:text-emerald-400 font-medium", flow),
        P(:class => "text-neutral-600 dark:text-neutral-400 mt-3 mb-3", description),
        P(:class => "text-sm text-neutral-500 dark:text-neutral-500 italic", "Use for: ", examples)
    )
end

function CodeBlock(code, style="default")
    bg_class = if style == "emerald"
        "bg-emerald-900 dark:bg-emerald-950 border-emerald-700"
    elseif style == "neutral"
        "bg-neutral-700 dark:bg-neutral-800 border-neutral-600"
    else
        "bg-neutral-900 dark:bg-neutral-950 border-neutral-800"
    end

    Div(:class => "$bg_class rounded border p-6 overflow-x-auto",
        Pre(:class => "text-sm text-neutral-100",
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

function WarnBox(title, content)
    Div(:class => "mt-8 bg-amber-50 dark:bg-amber-950/30 rounded-lg border border-amber-200 dark:border-amber-900 p-6",
        H3(:class => "text-lg font-serif font-semibold text-amber-900 dark:text-amber-200 mb-2", title),
        P(:class => "text-amber-800 dark:text-amber-300", content)
    )
end

# Export the page component
Index
