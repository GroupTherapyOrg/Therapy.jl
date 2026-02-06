# Server-Side Rendering - Part 5.1 of the Therapy.jl Book
#
# Render components to HTML on the server with automatic hydration.

function SSRPage()
    BookLayout("/book/server/ssr/",
        # Header
        Div(:class => "py-8 border-b border-warm-200 dark:border-warm-700",
            Span(:class => "text-sm text-accent-700 dark:text-accent-400 font-medium", "Part 5 · Server Features"),
            H1(:class => "text-4xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-2 mb-4",
                "Server-Side Rendering"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 max-w-3xl",
                "Server-side rendering (SSR) converts your components to HTML on the server, ",
                "delivering fully-rendered pages to the browser. This improves load times, SEO, ",
                "and works even with JavaScript disabled."
            )
        ),

        # Why SSR?
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Why Server-Side Rendering?"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Client-side rendering requires the browser to download JavaScript, parse it, and execute it ",
                "before any content appears. This creates a blank white page while loading. SSR solves this:"
            ),
            Div(:class => "grid md:grid-cols-2 gap-8 mt-8",
                Div(:class => "bg-warm-50 dark:bg-warm-900 rounded-lg border border-warm-200 dark:border-warm-800 p-6",
                    H3(:class => "text-xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-4",
                        "Client-Side Only"
                    ),
                    Ul(:class => "space-y-2 text-warm-600 dark:text-warm-400",
                        Li("⬜ Browser downloads HTML (empty shell)"),
                        Li("⬜ Browser downloads JavaScript"),
                        Li("⬜ Browser executes JavaScript"),
                        Li("⬜ JavaScript renders content"),
                        Li("✅ User sees content")
                    ),
                    P(:class => "mt-4 text-sm text-warm-600 dark:text-warm-600",
                        "User waits through all steps before seeing anything."
                    )
                ),
                Div(:class => "bg-warm-50 dark:bg-warm-900/30 rounded-lg border border-warm-200 dark:border-warm-800 p-6",
                    H3(:class => "text-xl font-serif font-semibold text-accent-900 dark:text-accent-100 mb-4",
                        "With SSR"
                    ),
                    Ul(:class => "space-y-2 text-accent-800 dark:text-accent-300",
                        Li("✅ Browser downloads HTML (full content)"),
                        Li("✅ User sees content immediately!"),
                        Li("⬜ Browser downloads JavaScript"),
                        Li("⬜ JavaScript hydrates interactive parts"),
                        Li("✅ User can now interact")
                    ),
                    P(:class => "mt-4 text-sm text-accent-700 dark:text-accent-400",
                        "User sees content after just 1 step."
                    )
                )
            )
        ),

        # The Basics
        Section(:class => "py-12 bg-warm-100 dark:bg-warm-900 rounded-lg border border-warm-200 dark:border-warm-700 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "The Basics: render_to_string"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "The ", Code(:class => "text-accent-700 dark:text-accent-400", "render_to_string"),
                " function converts any VNode tree to HTML:"
            ),
            CodeBlock("""using Therapy

# Render a simple component
html = render_to_string(
    Div(:class => "container",
        H1("Welcome!"),
        P("This is server-rendered HTML.")
    )
)

println(html)
# => <div class="container" data-hk="1">
#      <h1 data-hk="2">Welcome!</h1>
#      <p data-hk="3">This is server-rendered HTML.</p>
#    </div>"""),
            P(:class => "text-warm-600 dark:text-warm-400 mt-4",
                "Notice the ", Code(:class => "text-accent-700 dark:text-accent-400", "data-hk"),
                " attributes? These are ", Em("hydration keys"), "—unique identifiers that let ",
                "client-side JavaScript find and attach to specific DOM nodes."
            )
        ),

        # Rendering Components
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Rendering Components"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Components are just functions that return VNodes. You can render them exactly the same way:"
            ),
            CodeBlock("""# Define a component
function UserCard(; name::String, email::String)
    Div(:class => "bg-warm-50 rounded-lg p-4 shadow",
        H2(:class => "text-xl font-bold", name),
        P(:class => "text-gray-600", email)
    )
end

# Render it
html = render_to_string(
    UserCard(name = "Alice", email = "alice@example.com")
)

# Render multiple
html = render_to_string(
    Div(:class => "space-y-4",
        UserCard(name = "Alice", email = "alice@example.com"),
        UserCard(name = "Bob", email = "bob@example.com")
    )
)"""),
            InfoBox("Components with State",
                "When components contain signals (create_signal), the SSR renders their " *
                "initial values. The reactive behavior only activates after hydration."
            )
        ),

        # Full Page Rendering
        Section(:class => "py-12 bg-warm-100 dark:bg-warm-900 rounded-lg border border-warm-200 dark:border-warm-700 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Full Page Rendering"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "For complete pages with DOCTYPE, head, and body, use ",
                Code(:class => "text-accent-700 dark:text-accent-400", "render_page"), ":"
            ),
            CodeBlock("""function MyApp()
    Div(:class => "min-h-screen bg-gray-100",
        Header(:class => "bg-warm-50 shadow p-4",
            H1("My Application")
        ),
        Main(:class => "container mx-auto p-8",
            P("Welcome to my app!")
        )
    )
end

html = render_page(
    MyApp();
    title = "My Application",
    description = "A Therapy.jl application",
    head_extra = tailwind_cdn()
)

# Produces:
# <!DOCTYPE html>
# <html>
#   <head>
#     <meta charset="UTF-8">
#     <title>My Application</title>
#     <meta name="description" content="A Therapy.jl application">
#     <script src="https://cdn.tailwindcss.com">...</script>
#   </head>
#   <body>
#     <div class="min-h-screen bg-gray-100" data-hk="1">
#       ...
#     </div>
#   </body>
# </html>"""),
            H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-300 mt-8 mb-4",
                "render_page Options"
            ),
            Div(:class => "overflow-x-auto",
                Table(:class => "w-full text-left",
                    Thead(
                        Tr(
                            Th(:class => "py-2 px-4 text-warm-800 dark:text-warm-300", "Option"),
                            Th(:class => "py-2 px-4 text-warm-800 dark:text-warm-300", "Type"),
                            Th(:class => "py-2 px-4 text-warm-800 dark:text-warm-300", "Description")
                        )
                    ),
                    Tbody(:class => "text-warm-600 dark:text-warm-400",
                        Tr(
                            Td(:class => "py-2 px-4", Code(:class => "text-accent-700 dark:text-accent-400", "title")),
                            Td(:class => "py-2 px-4", "String"),
                            Td(:class => "py-2 px-4", "Page title (shown in browser tab)")
                        ),
                        Tr(
                            Td(:class => "py-2 px-4", Code(:class => "text-accent-700 dark:text-accent-400", "description")),
                            Td(:class => "py-2 px-4", "String"),
                            Td(:class => "py-2 px-4", "Meta description for SEO")
                        ),
                        Tr(
                            Td(:class => "py-2 px-4", Code(:class => "text-accent-700 dark:text-accent-400", "head_extra")),
                            Td(:class => "py-2 px-4", "VNode"),
                            Td(:class => "py-2 px-4", "Additional elements for <head> (scripts, styles)")
                        ),
                        Tr(
                            Td(:class => "py-2 px-4", Code(:class => "text-accent-700 dark:text-accent-400", "lang")),
                            Td(:class => "py-2 px-4", "String"),
                            Td(:class => "py-2 px-4", "HTML lang attribute (default: \"en\")")
                        )
                    )
                )
            )
        ),

        # Hydration: Bringing Static HTML to Life
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Hydration: Bringing Static HTML to Life"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "SSR produces static HTML. To make interactive components work, they need to be ",
                Em("hydrated"), "—connected to client-side JavaScript that handles events and updates."
            ),
            Div(:class => "grid md:grid-cols-2 gap-8 mt-8",
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-300 mb-4",
                        "How Hydration Works"
                    ),
                    Ol(:class => "list-decimal list-inside space-y-2 text-warm-600 dark:text-warm-400",
                        Li("Server renders component with ", Code(:class => "text-accent-700 dark:text-accent-400", "data-hk"), " keys"),
                        Li("Browser receives HTML, displays immediately"),
                        Li("JavaScript loads and executes"),
                        Li("Hydration script finds elements by ", Code(:class => "text-accent-700 dark:text-accent-400", "data-hk")),
                        Li("Event handlers are attached to those elements"),
                        Li("Component becomes interactive!")
                    )
                ),
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-300 mb-4",
                        "The Islands Pattern"
                    ),
                    P(:class => "text-warm-600 dark:text-warm-400",
                        "Not all components need interactivity. Therapy.jl uses the ",
                        Strong("islands architecture"), ": only components marked with ",
                        Code(:class => "text-accent-700 dark:text-accent-400", "@island"),
                        " get hydrated. Everything else stays as static HTML."
                    ),
                    CodeBlock("""# Static - no JavaScript
function Header()
    Nav(:class => "p-4",
        A(:href => "/", "Home"),
        A(:href => "/about", "About")
    )
end

# Interactive - compiled to Wasm
@island function Counter()
    count, set_count = create_signal(0)
    Button(
        :on_click => () -> set_count(count() + 1),
        "Clicks: ", count
    )
end""", "neutral")
                )
            )
        ),

        # SSR Context
        Section(:class => "py-12 bg-warm-100 dark:bg-warm-900 rounded-lg border border-warm-200 dark:border-warm-700 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "SSR Context"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "The SSR context tracks state during rendering, including hydration key generation:"
            ),
            CodeBlock("""# SSRContext tracks:
# - hydration_key::Int  — Current key counter
# - signals::Dict       — Signal values for hydration
# - in_raw_text_element — Whether inside <script>/<style>

# Usually you don't need to manage this directly.
# render_to_string creates and manages the context.

# But if you need shared context across multiple renders:
ctx = SSRContext()
html1 = render_to_string(Component1(), ctx)
html2 = render_to_string(Component2(), ctx)
# Keys continue from where html1 left off"""),
            InfoBox("Void Elements",
                "HTML void elements (img, input, br, hr, etc.) are automatically rendered " *
                "with self-closing syntax and don't receive hydration keys."
            )
        ),

        # HTML Escaping
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "HTML Escaping & Security"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Therapy.jl automatically escapes text content to prevent XSS attacks:"
            ),
            CodeBlock("""# User input is automatically escaped
user_input = "<script>alert('XSS')</script>"

html = render_to_string(P(user_input))
# => <p data-hk="1">&lt;script&gt;alert('XSS')&lt;/script&gt;</p>
# The script is displayed as text, not executed!

# If you NEED raw HTML (use with caution!):
html = render_to_string(RawHtml("<b>Bold text</b>"))
# => <b>Bold text</b>
# ⚠️ Only use RawHtml with trusted content!"""),
            WarnBox("Security Warning",
                "Never use RawHtml with user-provided content. Always sanitize untrusted " *
                "input before including it in your pages."
            )
        ),

        # Development Server
        Section(:class => "py-12 bg-warm-100 dark:bg-warm-900 rounded-lg border border-warm-200 dark:border-warm-700 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Development Server"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Therapy.jl includes a built-in development server that handles SSR automatically:"
            ),
            CodeBlock("""# In your app.jl
using Therapy

# Define your app with routes
app = App(
    routes_dir = "src/routes",
    layout = :Layout
)

# Start the dev server
if ARGS == ["dev"]
    serve(app; port=8080, hot_reload=true)
elseif ARGS == ["build"]
    build(app; output_dir="dist")
end

# Run with:
# julia --project=. app.jl dev    # Development
# julia --project=. app.jl build  # Production build"""),
            P(:class => "text-warm-600 dark:text-warm-400 mt-4",
                "The development server provides:"
            ),
            Ul(:class => "list-disc list-inside space-y-1 text-warm-600 dark:text-warm-400 mt-2",
                Li("Automatic file-based routing"),
                Li("SSR for all pages"),
                Li("WebSocket for server signals"),
                Li("Hot reload on file changes (planned)"),
                Li("Client-side SPA navigation")
            )
        ),

        # Key Takeaways
        Section(:class => "py-12 bg-warm-50 dark:bg-warm-900/30 rounded-lg border border-warm-200 dark:border-warm-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-accent-900 dark:text-accent-200 mb-6",
                "Key Takeaways"
            ),
            Ul(:class => "space-y-3 text-accent-800 dark:text-accent-300",
                Li(Strong("render_to_string"), " converts any VNode tree to HTML"),
                Li(Strong("render_page"), " creates a complete HTML document with DOCTYPE and head"),
                Li(Strong("Hydration keys"), " (data-hk) connect server HTML to client JavaScript"),
                Li(Strong("Islands architecture"), " means only interactive components need JavaScript"),
                Li(Strong("Automatic escaping"), " protects against XSS attacks"),
                Li(Strong("Dev server"), " handles SSR, routing, and WebSocket automatically")
            )
        ),

    )
end

# Helper Components

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

function WarnBox(title, content)
    Div(:class => "mt-8 bg-amber-50 dark:bg-amber-950/30 rounded-lg border border-amber-200 dark:border-amber-900 p-6",
        H3(:class => "text-lg font-serif font-semibold text-amber-900 dark:text-amber-200 mb-2", title),
        P(:class => "text-amber-800 dark:text-amber-300", content)
    )
end

# Export the page component
SSRPage
