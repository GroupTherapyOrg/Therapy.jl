# Server Functions - Part 5.2 of the Therapy.jl Book
#
# Define functions that run on the server but can be called from the client.

function ServerFunctionsPage()
    BookLayout("/book/server/server-functions/",
        # Header
        Div(:class => "py-8 border-b border-warm-200 dark:border-warm-900",
            Span(:class => "text-sm text-accent-700 dark:text-accent-400 font-medium", "Part 5 · Server Features"),
            H1(:class => "text-4xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-2 mb-4",
                "Server Functions"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 max-w-3xl",
                "Server functions let you write Julia code that runs on the server but can be called ",
                "transparently from the client. They're perfect for database access, file operations, ",
                "and any logic that needs to stay on the server."
            )
        ),

        # The Problem
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "The Problem: Client-Server Communication"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 mb-6",
                "In traditional web apps, calling server-side code from the browser requires:",
            ),
            Ol(:class => "list-decimal list-inside space-y-2 text-warm-600 dark:text-warm-400 mb-6",
                Li("Define an API endpoint on the server"),
                Li("Serialize request data to JSON"),
                Li("Make an HTTP request from the client"),
                Li("Deserialize the response"),
                Li("Handle errors and loading states")
            ),
            P(:class => "text-warm-600 dark:text-warm-400",
                "That's a lot of boilerplate for a simple function call! Server functions eliminate this friction."
            )
        ),

        # The @server Macro
        Section(:class => "py-12 bg-warm-100 dark:bg-warm-800 rounded-lg border border-warm-200 dark:border-warm-900 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "The @server Macro"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 mb-6",
                "The ", Code(:class => "text-accent-700 dark:text-accent-400", "@server"),
                " macro transforms a regular Julia function into a server function:"
            ),
            CodeBlock("""# Define a server function
@server function get_user(id::Int)
    # This code runs ONLY on the server
    DB.query("SELECT * FROM users WHERE id = ?", id)
end

@server function create_post(title::String, body::String)
    DB.insert("posts", title=title, body=body)
    Dict("success" => true)
end

# Can still be called directly from server-side Julia
user = get_user(123)
result = create_post("Hello", "World")"""),
            P(:class => "text-warm-600 dark:text-warm-400 mt-4",
                "Behind the scenes, ", Code(:class => "text-accent-700 dark:text-accent-400", "@server"),
                " does two things:"
            ),
            Ol(:class => "list-decimal list-inside space-y-1 text-warm-600 dark:text-warm-400 mt-2",
                Li("Defines the function normally (so you can call it from server code)"),
                Li("Registers it in the server function registry (so clients can call it via WebSocket)")
            )
        ),

        # Calling from the Client
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Calling from the Client"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 mb-6",
                "Clients call server functions via the ", Code(:class => "text-accent-700 dark:text-accent-400", "TherapyWS.callServer"),
                " JavaScript API:"
            ),
            CodeBlock("""// JavaScript on the client

// Basic call - returns a Promise
const user = await TherapyWS.callServer("get_user", [123]);
console.log(user.name, user.email);

// With error handling
try {
    const result = await TherapyWS.callServer("create_post", [
        "My Title",
        "Post content here..."
    ]);
    console.log("Created:", result);
} catch (error) {
    console.error("Failed:", error.message);
}

// With custom timeout (default is 30 seconds)
const data = await TherapyWS.callServer("slow_query", [], 60000);"""),
            InfoBox("WebSocket Required",
                "Server function calls use WebSocket, not HTTP. The WebSocket connection is " *
                "established automatically when you include Therapy.jl's client script. " *
                "If the connection is lost, calls will fail with a 'not_connected' error."
            )
        ),

        # Wire Protocol
        Section(:class => "py-12 bg-warm-100 dark:bg-warm-800 rounded-lg border border-warm-200 dark:border-warm-900 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Wire Protocol"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 mb-6",
                "Under the hood, server functions use a simple JSON protocol over WebSocket:"
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-200 mb-4",
                        "Request (Client → Server)"
                    ),
                    CodeBlock("""{
    "type": "server_function_call",
    "id": "sf_abc123_xyz789",
    "function": "get_user",
    "args": [123]
}""", "neutral")
                ),
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-200 mb-4",
                        "Response (Server → Client)"
                    ),
                    CodeBlock("""// Success
{
    "type": "server_function_result",
    "id": "sf_abc123_xyz789",
    "success": true,
    "result": {"name": "Alice", ...}
}

// Error
{
    "type": "server_function_result",
    "id": "sf_abc123_xyz789",
    "success": false,
    "error": {
        "code": "execution",
        "message": "User not found"
    }
}""", "neutral")
                )
            ),
            H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-200 mt-8 mb-4",
                "Error Codes"
            ),
            Div(:class => "overflow-x-auto",
                Table(:class => "w-full text-left",
                    Thead(
                        Tr(
                            Th(:class => "py-2 px-4 text-warm-800 dark:text-warm-200", "Code"),
                            Th(:class => "py-2 px-4 text-warm-800 dark:text-warm-200", "Meaning")
                        )
                    ),
                    Tbody(:class => "text-warm-600 dark:text-warm-400",
                        Tr(
                            Td(:class => "py-2 px-4", Code(:class => "text-accent-700 dark:text-accent-400", "not_found")),
                            Td(:class => "py-2 px-4", "Function name not registered")
                        ),
                        Tr(
                            Td(:class => "py-2 px-4", Code(:class => "text-accent-700 dark:text-accent-400", "validation")),
                            Td(:class => "py-2 px-4", "Wrong number of arguments")
                        ),
                        Tr(
                            Td(:class => "py-2 px-4", Code(:class => "text-accent-700 dark:text-accent-400", "execution")),
                            Td(:class => "py-2 px-4", "Error thrown during function execution")
                        ),
                        Tr(
                            Td(:class => "py-2 px-4", Code(:class => "text-accent-700 dark:text-accent-400", "timeout")),
                            Td(:class => "py-2 px-4", "Response not received within timeout")
                        ),
                        Tr(
                            Td(:class => "py-2 px-4", Code(:class => "text-accent-700 dark:text-accent-400", "not_connected")),
                            Td(:class => "py-2 px-4", "WebSocket not connected")
                        )
                    )
                )
            )
        ),

        # Type Serialization
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Type Serialization"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 mb-6",
                "Arguments and return values are serialized to JSON. Supported types:"
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-200 mb-4",
                        "Supported Types"
                    ),
                    Ul(:class => "space-y-1 text-warm-600 dark:text-warm-400",
                        Li(Code(:class => "text-accent-700 dark:text-accent-400", "Int, Float64"), " → JSON number"),
                        Li(Code(:class => "text-accent-700 dark:text-accent-400", "String"), " → JSON string"),
                        Li(Code(:class => "text-accent-700 dark:text-accent-400", "Bool"), " → JSON boolean"),
                        Li(Code(:class => "text-accent-700 dark:text-accent-400", "nothing"), " → JSON null"),
                        Li(Code(:class => "text-accent-700 dark:text-accent-400", "Vector{T}"), " → JSON array"),
                        Li(Code(:class => "text-accent-700 dark:text-accent-400", "Dict{String,T}"), " → JSON object"),
                        Li(Code(:class => "text-accent-700 dark:text-accent-400", "Structs"), " → JSON object (with JSON3)")
                    )
                ),
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-200 mb-4",
                        "NOT Supported"
                    ),
                    Ul(:class => "space-y-1 text-warm-600 dark:text-warm-400",
                        Li(Code(:class => "text-red-600 dark:text-red-400", "Function"), " — can't serialize code"),
                        Li(Code(:class => "text-red-600 dark:text-red-400", "IO, Task"), " — runtime handles"),
                        Li(Code(:class => "text-red-600 dark:text-red-400", "Circular refs"), " — no JSON support"),
                        Li(Code(:class => "text-red-600 dark:text-red-400", "Binary data"), " — use Base64 encoding")
                    )
                )
            ),
            CodeBlock("""# Returning a struct
struct User
    id::Int
    name::String
    email::String
end

@server function get_user(id::Int)::User
    User(id, "Alice", "alice@example.com")
end

# Client receives:
# { "id": 1, "name": "Alice", "email": "alice@example.com" }"""),
            InfoBox("Custom Struct Serialization",
                "For structs with special serialization needs, register them with JSON3: " *
                "JSON3.StructType(::Type{MyType}) = JSON3.Struct() and optionally define " *
                "JSON3.omitempties or custom field names."
            )
        ),

        # Security Considerations
        Section(:class => "py-12 bg-amber-50 dark:bg-amber-950/30 rounded-lg border border-amber-200 dark:border-amber-900 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-amber-900 dark:text-amber-200 mb-6",
                "Security Considerations"
            ),
            P(:class => "text-lg text-amber-800 dark:text-amber-300 mb-6",
                "Server functions run with full server permissions. Keep these security principles in mind:"
            ),
            Div(:class => "space-y-4",
                SecurityRule("Explicit Registration Only",
                    "Only functions explicitly marked with @server are callable from clients. " *
                    "Your database connection, file system access, and other server code is never exposed."
                ),
                SecurityRule("Validate Arguments",
                    "Arguments come from untrusted clients. Always validate: check types, ranges, " *
                    "permissions. Never pass arguments directly to SQL or shell commands."
                ),
                SecurityRule("Authorize Users",
                    "Server functions don't automatically check permissions. If a function should " *
                    "only be called by certain users, add explicit authorization logic."
                ),
                SecurityRule("Rate Limit",
                    "Without rate limiting, a malicious client could call expensive functions repeatedly. " *
                    "Implement rate limiting for production deployments."
                )
            ),
            CodeBlock("""# Example: Secure server function
@server function delete_post(user_id::Int, post_id::Int)
    # 1. Validate types (handled by Julia's type system)

    # 2. Verify authorization
    post = DB.query("SELECT author_id FROM posts WHERE id = ?", post_id)
    if isempty(post)
        error("Post not found")
    end
    if post[1].author_id != user_id
        error("Not authorized to delete this post")
    end

    # 3. Perform operation with parameterized query (prevents SQL injection)
    DB.execute("DELETE FROM posts WHERE id = ?", post_id)

    Dict("deleted" => true)
end""")
        ),

        # Using with Resources
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Using with Resources"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 mb-6",
                "Server functions pair naturally with Resources for reactive data loading:"
            ),
            CodeBlock("""# Server: Define the function
@server function get_todos(user_id::Int)
    DB.query("SELECT * FROM todos WHERE user_id = ? ORDER BY created_at", user_id)
end

# Client: Use with a Resource
function TodoList()
    user_id, _ = use_context(:user)

    todos = create_resource(
        () -> user_id(),                           # Reactive source
        id -> TherapyWS.callServer("get_todos", [id])  # Fetcher
    )

    Suspense(fallback = () -> P("Loading todos...")) do
        Ul(
            For(todos) do todo
                Li(todo["title"])
            end
        )
    end
end

# When user_id changes, Resource automatically refetches"""),
            P(:class => "text-warm-600 dark:text-warm-400 mt-4",
                "This pattern gives you reactive data loading with automatic refetch—the same pattern ",
                "as React Query or SWR, but with type-safe Julia on the server."
            )
        ),

        # Advanced: Manual Registration
        Section(:class => "py-12 bg-warm-100 dark:bg-warm-800 rounded-lg border border-warm-200 dark:border-warm-900 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Advanced: Manual Registration"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-200 mb-6",
                "If you need more control, you can register functions manually:"
            ),
            CodeBlock("""# Manual registration (without @server macro)
function my_function(x, y)
    x + y
end

register_server_function("add", my_function; description="Add two numbers")

# List all registered functions
names = list_server_functions()
# => ["add", "get_user", ...]

# Get function info
func = get_server_function("add")
# => ServerFunction("add", my_function, 2, "Add two numbers")

# Unregister
unregister_server_function("add")"""),
            P(:class => "text-warm-600 dark:text-warm-400 mt-4",
                "Manual registration is useful when you want to register existing functions without ",
                "modifying them, or when you need to generate functions dynamically."
            )
        ),

        # Key Takeaways
        Section(:class => "py-12 bg-warm-50 dark:bg-warm-900/30 rounded-lg border border-warm-200 dark:border-warm-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-accent-900 dark:text-accent-200 mb-6",
                "Key Takeaways"
            ),
            Ul(:class => "space-y-3 text-accent-800 dark:text-accent-300",
                Li(Strong("@server"), " creates functions callable from client via WebSocket"),
                Li(Strong("TherapyWS.callServer"), " is the client-side API for calling server functions"),
                Li(Strong("JSON serialization"), " handles arguments and return values automatically"),
                Li(Strong("Security"), " requires explicit validation, authorization, and rate limiting"),
                Li(Strong("Resources"), " + server functions = reactive data loading pattern")
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

function SecurityRule(title, content)
    Div(:class => "flex gap-4",
        Span(:class => "text-2xl", "🔒"),
        Div(
            H3(:class => "text-lg font-semibold text-amber-900 dark:text-amber-200", title),
            P(:class => "text-amber-800 dark:text-amber-300 mt-1", content)
        )
    )
end

# Export the page component
ServerFunctionsPage
