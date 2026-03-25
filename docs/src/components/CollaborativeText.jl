# CollaborativeText.jl - Real-time collaborative text editing demo
#
# This component demonstrates Therapy.jl's bidirectional signals.
# Multiple users can edit the same text simultaneously - changes
# are synchronized in real-time via WebSocket.

"""
Collaborative text editor demonstrating bidirectional signals.

This is NOT an island (no JS compilation needed) - it's a static component
that syncs via WebSocket. The `data-bidirectional-signal` attribute
tells the WebSocket client to:
1. Update this element when server broadcasts changes
2. Send changes to server when user types

In static mode (GitHub Pages), the warning will show that
collaborative features are unavailable.
"""
function CollaborativeText()
    Div(:class => "mb-8",
        :data_ws_example => "true",  # Marks this for static mode warning

        H3(:class => "text-xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-4",
            "Collaborative Text Editor"
        ),

        P(:class => "text-warm-600 dark:text-warm-400 mb-4",
            "Type below - changes sync to all connected browsers in real-time. ",
            "Open this page in multiple tabs or browsers to see collaborative editing."
        ),

        # The textarea - bidirectional binding via WebSocket
        # data-bidirectional-signal: WebSocket client updates this AND sends changes
        Textarea(
            :class => "w-full h-32 p-4 border border-warm-200 dark:border-warm-600 rounded-lg bg-warm-50 dark:bg-warm-900 text-warm-800 dark:text-warm-50 resize-none focus:outline-none focus:ring-2 focus:ring-accent-500",
            :data_bidirectional_signal => "shared_doc",
            :placeholder => "Start typing to collaborate...",
            :oninput => "TherapyWS.setBidirectional('shared_doc', this.value)"
        ),

        P(:class => "text-sm text-warm-600 dark:text-warm-400 mt-2",
            "Changes are sent as JSON patches (RFC 6902) for efficient sync."
        )
    )
end
