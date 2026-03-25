#!/usr/bin/env julia
# Therapy.jl Documentation Site
#
# Usage (from Therapy.jl root directory):
#   julia --project=. docs/app.jl dev    # Development server with HMR
#   julia --project=. docs/app.jl build  # Build static site to docs/dist
#
# This site dogfoods Therapy.jl's App framework with:
# - File-based routing from src/routes/
# - Automatic component loading from src/components/
# - Interactive JavaScript components with HMR in dev mode

# Ensure we're using the local Therapy.jl package
if !haskey(ENV, "JULIA_PROJECT")
    # Running without --project, add paths manually
    push!(LOAD_PATH, dirname(@__DIR__))  # Add Therapy.jl
end

using Therapy

# Change to docs directory for relative paths
cd(@__DIR__)

# =============================================================================
# App Configuration
# =============================================================================

# Islands are auto-discovered from component files that use island()
# No need to manually list interactive components anymore!
#
# The Layout is applied at the app level for true SPA navigation.
# Routes return just their page content (not wrapped in Layout).
app = App(
    routes_dir = "src/routes",
    components_dir = "src/components",
    title = "Therapy.jl",
    output_dir = "dist",
    # Base path for GitHub Pages (https://therapeuticjulia.github.io/Therapy.jl/)
    base_path = "/Therapy.jl",
    # Layout applied at app level - routes return just their content
    # Use Symbol for deferred resolution (Layout loaded after components)
    layout = :Layout
)

# =============================================================================
# WebSocket Server Signals
# =============================================================================

# Create a server signal for live visitor count
# This broadcasts to all connected WebSocket clients when updated
visitors = create_server_signal("visitors", 0)

# Track connections with lifecycle hooks
on_ws_connect() do conn
    # Increment visitor count - automatically broadcasts to all clients
    update_server_signal!(visitors, v -> v + 1)
    println("[WS] Client connected: $(conn.id) ($(visitors[]) visitors)")
end

on_ws_disconnect() do conn
    # Decrement on disconnect
    update_server_signal!(visitors, v -> max(0, v - 1))
    println("[WS] Client disconnected: $(conn.id) ($(visitors[]) visitors)")
end

# =============================================================================
# Bidirectional Signals (Collaborative Features)
# =============================================================================

# Shared document for collaborative text editing
# Both server and clients can modify - changes sync via JSON patches
shared_doc = create_bidirectional_signal("shared_doc", "")

# Optional: Add validation handler
on_bidirectional_update("shared_doc") do conn, new_value
    # Could validate/sanitize here
    # Return false to reject, true to accept, or a modified value
    if length(new_value) > 50000
        @warn "Document too large, rejecting update"
        return false  # Reject updates over 50KB
    end
    return true  # Accept the update
end

# =============================================================================
# Message Channels (Chat)
# =============================================================================

# Create a chat channel for discrete messaging
chat = create_channel("chat")

# Handle incoming chat messages
on_channel_message("chat") do conn, data
    # Add metadata and broadcast to ALL clients (including sender)
    message = Dict(
        "text" => get(data, "text", ""),
        "timestamp" => time(),
        "from" => conn.id[1:8]  # Short connection ID
    )

    # Broadcast to all connected clients
    broadcast_channel!("chat", message)

    println("[Chat] $(message["from"]): $(message["text"])")
end

# =============================================================================
# Run - dev or build based on args
# =============================================================================

Therapy.run(app)
