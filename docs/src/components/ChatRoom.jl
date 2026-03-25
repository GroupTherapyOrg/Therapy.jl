# ChatRoom.jl - Real-time chat room demo
#
# This component demonstrates Therapy.jl's message channels.
# Unlike signals (continuous state), channels are for discrete
# messages that are delivered but not persisted.

"""
Live chat room demonstrating message channels.

This is NOT an island (no JS compilation needed) - it's a static component
that communicates via WebSocket channels. Messages sent through
the channel are:
1. Delivered to all connected clients
2. Not persisted (no message history on reconnect)

In static mode (GitHub Pages), the warning will show that
chat features are unavailable.
"""
function ChatRoom()
    Div(:class => "mb-8",
        :data_ws_example => "true",  # Marks this for static mode warning

        H3(:class => "text-xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-4",
            "Live Chat Room"
        ),

        P(:class => "text-warm-600 dark:text-warm-400 mb-4",
            "Send messages to all connected browsers. Messages appear instantly - no page refresh needed!"
        ),

        # Messages container - receives channel messages
        Div(:id => "chat-messages",
            :class => "h-48 overflow-y-auto border border-warm-200 dark:border-warm-600 rounded-lg p-4 mb-4 bg-warm-100 dark:bg-warm-900 space-y-2",
            :data_channel_messages => "chat",

            # Empty state
            P(:class => "text-warm-400 dark:text-warm-600 text-sm italic",
              :id => "chat-empty-state",
              "No messages yet. Be the first to say hello!")
        ),

        # Input area
        Div(:class => "flex gap-2",
            Input(:id => "chat-input",
                  :type => "text",
                  :class => "flex-1 px-4 py-2 border border-warm-200 dark:border-warm-600 rounded-lg bg-warm-50 dark:bg-warm-900 text-warm-800 dark:text-warm-50 focus:outline-none focus:ring-2 focus:ring-accent-500",
                  :placeholder => "Type a message...",
                  :onkeydown => "if(event.key==='Enter'){sendChatMessage();event.preventDefault()}"
            ),
            Button(:class => "px-6 py-2 bg-accent-600 hover:bg-accent-700 text-white rounded-lg transition-colors cursor-pointer",
                   :onclick => "sendChatMessage()",
                   "Send")
        ),

        # Client-side script for chat functionality
        Script("""
            function sendChatMessage() {
                const input = document.getElementById('chat-input');
                const text = input.value.trim();
                if (text && typeof TherapyWS !== 'undefined' && TherapyWS.isConnected()) {
                    TherapyWS.sendMessage('chat', { text: text });
                    input.value = '';
                }
            }

            // Listen for chat messages
            window.addEventListener('therapy:channel:chat', function(e) {
                const container = document.getElementById('chat-messages');
                const emptyState = document.getElementById('chat-empty-state');
                if (emptyState) emptyState.remove();

                const msg = e.detail;
                const div = document.createElement('div');
                div.className = 'flex items-start gap-2';

                const time = new Date(msg.timestamp * 1000).toLocaleTimeString();
                div.innerHTML = '<span class=\"text-xs text-warm-400\">' + time + '</span>' +
                    '<span class=\"text-xs text-accent-600 dark:text-accent-400 font-mono\">' + msg.from + '</span>' +
                    '<span class=\"text-warm-800 dark:text-warm-50\">' + escapeHtml(msg.text) + '</span>';

                container.appendChild(div);
                container.scrollTop = container.scrollHeight;
            });

            function escapeHtml(text) {
                const div = document.createElement('div');
                div.textContent = text;
                return div.innerHTML;
            }
        """)
    )
end
