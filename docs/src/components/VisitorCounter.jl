# VisitorCounter.jl - Real-time visitor counter using WebSocket
#
# This component demonstrates Therapy.jl's WebSocket server signals.
# It shows a live visitor count that updates in real-time when:
# - Running locally: Full functionality with WebSocket connection
# - On static hosting: Shows a warning that live features are unavailable

"""
Live visitor counter demonstrating WebSocket server signals.

This is NOT an island (no JS compilation needed) - it's a static component
that receives updates via WebSocket. The `data-server-signal` attribute
tells the WebSocket client to update this element when the server
broadcasts a signal update.

In static mode (GitHub Pages), the WebSocket client detects the
failed connection and shows a warning banner.
"""
function VisitorCounter()
    # This renders static HTML with data attributes
    # The WebSocket client JS handles live updates
    Div(:class => "text-center p-8 bg-warm-50 dark:bg-warm-900 rounded-lg",
        :data_ws_example => "true",  # Marks this for static mode warning

        # The count display - updated by WebSocket client when server sends updates
        Span(:class => "text-6xl font-serif font-bold text-accent-600 dark:text-accent-400 tabular-nums",
             :data_server_signal => "visitors",  # WebSocket client updates this
             "0"),  # Initial value (will be updated by WebSocket)

        P(:class => "text-warm-600 dark:text-warm-400 mt-2 text-lg",
          "current visitors")
    )
end
