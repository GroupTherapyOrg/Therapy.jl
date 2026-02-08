# Server-Side Rendering - Part 5.1 of the Therapy.jl Book
#
# Render components to HTML on the server with automatic hydration.

import Suite

function SSRPage()
    BookLayout("/book/server/ssr/",
        # Header
        Div(:class => "py-8 border-b border-warm-200 dark:border-warm-700",
            Suite.Badge(variant="outline", "Part 5 · Server"),
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
                Suite.Card(
                    Suite.CardHeader(
                        Suite.CardTitle("Client-Side Only")
                    ),
                    Suite.CardContent(
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
                    )
                ),
                Suite.Card(
                    Suite.CardHeader(
                        Suite.CardTitle("With SSR")
                    ),
                    Suite.CardContent(
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
            )
        ),

        Suite.Separator(),

        # The Basics
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "The Basics: render_to_string"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "The ", Code(:class => "text-accent-700 dark:text-accent-400", "render_to_string"),
                " function converts any VNode tree to HTML:"
            ),
            Suite.CodeBlock(
                code="""using Therapy

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
#    </div>""",
                language="julia"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-4",
                "Notice the ", Code(:class => "text-accent-700 dark:text-accent-400", "data-hk"),
                " attributes? These are ", Em("hydration keys"), "—unique identifiers that let ",
                "client-side JavaScript find and attach to specific DOM nodes."
            )
        ),

        Suite.Separator(),

        # Rendering Components
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Rendering Components"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Components are just functions that return VNodes. You can render them exactly the same way:"
            ),
            Suite.CodeBlock(
                code="""# Define a component
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
)""",
                language="julia"
            ),
            Suite.Alert(class="mt-8",
                Suite.AlertTitle("Components with State"),
                Suite.AlertDescription(
                    "When components contain signals (create_signal), the SSR renders their " *
                    "initial values. The reactive behavior only activates after hydration."
                )
            )
        ),

        Suite.Separator(),

        # Full Page Rendering
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Full Page Rendering"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "For complete pages with DOCTYPE, head, and body, use ",
                Code(:class => "text-accent-700 dark:text-accent-400", "render_page"), ":"
            ),
            Suite.CodeBlock(
                code="""function MyApp()
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
# </html>""",
                language="julia"
            ),
            H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-300 mt-8 mb-4",
                "render_page Options"
            ),
            Suite.Table(
                Suite.TableHeader(
                    Suite.TableRow(
                        Suite.TableHead("Option"),
                        Suite.TableHead("Type"),
                        Suite.TableHead("Description")
                    )
                ),
                Suite.TableBody(
                    Suite.TableRow(
                        Suite.TableCell(Code(:class => "text-accent-700 dark:text-accent-400", "title")),
                        Suite.TableCell("String"),
                        Suite.TableCell("Page title (shown in browser tab)")
                    ),
                    Suite.TableRow(
                        Suite.TableCell(Code(:class => "text-accent-700 dark:text-accent-400", "description")),
                        Suite.TableCell("String"),
                        Suite.TableCell("Meta description for SEO")
                    ),
                    Suite.TableRow(
                        Suite.TableCell(Code(:class => "text-accent-700 dark:text-accent-400", "head_extra")),
                        Suite.TableCell("VNode"),
                        Suite.TableCell("Additional elements for <head> (scripts, styles)")
                    ),
                    Suite.TableRow(
                        Suite.TableCell(Code(:class => "text-accent-700 dark:text-accent-400", "lang")),
                        Suite.TableCell("String"),
                        Suite.TableCell("HTML lang attribute (default: \"en\")")
                    )
                )
            )
        ),

        Suite.Separator(),

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
                    Suite.CodeBlock(
                        code="""# Static - no JavaScript
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
end""",
                        language="julia",
                        show_copy=false
                    )
                )
            )
        ),

        Suite.Separator(),

        # SSR Context
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "SSR Context"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "The SSR context tracks state during rendering, including hydration key generation:"
            ),
            Suite.CodeBlock(
                code="""# SSRContext tracks:
# - hydration_key::Int  — Current key counter
# - signals::Dict       — Signal values for hydration
# - in_raw_text_element — Whether inside <script>/<style>

# Usually you don't need to manage this directly.
# render_to_string creates and manages the context.

# But if you need shared context across multiple renders:
ctx = SSRContext()
html1 = render_to_string(Component1(), ctx)
html2 = render_to_string(Component2(), ctx)
# Keys continue from where html1 left off""",
                language="julia"
            ),
            Suite.Alert(class="mt-8",
                Suite.AlertTitle("Void Elements"),
                Suite.AlertDescription(
                    "HTML void elements (img, input, br, hr, etc.) are automatically rendered " *
                    "with self-closing syntax and don't receive hydration keys."
                )
            )
        ),

        Suite.Separator(),

        # HTML Escaping
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "HTML Escaping & Security"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Therapy.jl automatically escapes text content to prevent XSS attacks:"
            ),
            Suite.CodeBlock(
                code="""# User input is automatically escaped
user_input = "<script>alert('XSS')</script>"

html = render_to_string(P(user_input))
# => <p data-hk="1">&lt;script&gt;alert('XSS')&lt;/script&gt;</p>
# The script is displayed as text, not executed!

# If you NEED raw HTML (use with caution!):
html = render_to_string(RawHtml("<b>Bold text</b>"))
# => <b>Bold text</b>
# ⚠️ Only use RawHtml with trusted content!""",
                language="julia"
            ),
            Suite.Alert(class="mt-8", variant="destructive",
                Suite.AlertTitle("Security Warning"),
                Suite.AlertDescription(
                    "Never use RawHtml with user-provided content. Always sanitize untrusted " *
                    "input before including it in your pages."
                )
            )
        ),

        Suite.Separator(),

        # Development Server
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Development Server"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Therapy.jl includes a built-in development server that handles SSR automatically:"
            ),
            Suite.CodeBlock(
                code="""# In your app.jl
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
# julia --project=. app.jl build  # Production build""",
                language="julia"
            ),
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
        Suite.Alert(class="mt-12",
            Suite.AlertTitle("Key Takeaways"),
            Suite.AlertDescription(
                Ul(:class => "space-y-2 list-disc pl-5 mt-2",
                    Li(Strong("render_to_string"), " converts any VNode tree to HTML"),
                    Li(Strong("render_page"), " creates a complete HTML document with DOCTYPE and head"),
                    Li(Strong("Hydration keys"), " (data-hk) connect server HTML to client JavaScript"),
                    Li(Strong("Islands architecture"), " means only interactive components need JavaScript"),
                    Li(Strong("Automatic escaping"), " protects against XSS attacks"),
                    Li(Strong("Dev server"), " handles SSR, routing, and WebSocket automatically")
                )
            )
        ),

    )
end

# Export the page component
SSRPage
