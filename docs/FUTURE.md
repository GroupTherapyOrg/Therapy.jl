# Future Features

Features documented here are planned but not yet implemented. They were removed during the JST backend migration (CLN-001) to ship only working code.

## @server — Server Function RPC

Server functions allow islands to call Julia functions on the server via WebSocket RPC.

### Planned API

```julia
@server function search(; query::String, limit::Int = 50)::Vector{Patient}
    DB.query("SELECT * FROM patients WHERE name LIKE ?", "%$query%")[1:limit]
end

# Client calls the same function — auto-generates WebSocket RPC call
user = create_resource(() -> get_user(user_id()))
```

### How it should work

1. `@server` macro validates typed kwargs + return type at expansion time
2. Defines the function normally on the server
3. Registers it in a `SERVER_FUNCTIONS` registry with metadata
4. Generates a client-side JS stub: `async function search(query, limit) { return TherapyWS.callServer('search', {query, limit}); }`
5. Server routes incoming `server_function_call` WebSocket messages to the registered function
6. Response sent back as JSON

### Wire protocol

```
Client → Server: { type: "server_function_call", name: "search", args: { query: "alice", limit: 10 }, id: "req_123" }
Server → Client: { type: "server_function_result", id: "req_123", result: [...] }
Server → Client: { type: "server_function_error", id: "req_123", error: "Not found" }
```

## Server Signals — Real-time Server → Client State

Server signals push state from server to all connected clients in real-time.

### Planned API

```julia
visitors = create_server_signal("visitors", 0)

on_ws_connect() do conn
    update_server_signal!(visitors, v -> v + 1)
end

on_ws_disconnect() do conn
    update_server_signal!(visitors, v -> v - 1)
end
```

### Client binding

```julia
# Auto-updates when server broadcasts
Span(:data_server_signal => "visitors", "0")
```

### How it should work

1. Server creates `ServerSignal{T}` with name and initial value
2. Clients subscribe via WebSocket: `{ type: "subscribe", signal: "visitors" }`
3. When signal changes, server broadcasts full value or RFC 6902 JSON patch
4. Client JS updates DOM elements with matching `data-server-signal` attribute
5. Cross-island signal runtime (`window.__therapy`) notifies island subscribers

## Bidirectional Signals — Collaborative State

Bidirectional signals can be modified by both server and clients (e.g., collaborative editing).

### Planned API

```julia
shared_doc = create_bidirectional_signal("shared_doc", "")

on_bidirectional_update("shared_doc") do conn, new_value
    length(new_value) <= 50000  # Return false to reject
end
```

### How it should work

1. Extends server signals with client → server updates
2. Client sends JSON patches (not full values) for efficiency
3. Server validates via optional handler, then broadcasts patch to other clients
4. Conflict resolution: last-write-wins (patches applied in order received)

## Message Channels — Discrete Events

Channels are for discrete messages (chat, notifications), not continuous state.

### Planned API

```julia
chat = create_channel("chat")

on_channel_message("chat") do conn, data
    broadcast_channel!("chat", Dict(
        "text" => data["text"],
        "from" => conn.id[1:8]
    ))
end
```

### Client API

```javascript
TherapyWS.sendMessage('chat', { text: 'Hello!' });
TherapyWS.onChannelMessage('chat', function(data) {
    console.log(data.text, 'from', data.from);
});
```

## Implementation Priority

1. **@server** — Enables islands to fetch data and perform mutations
2. **Server signals** — Enables real-time dashboards and live counters
3. **Bidirectional signals** — Enables collaborative editing
4. **Channels** — Enables chat and notification patterns
