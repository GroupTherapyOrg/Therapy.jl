# Routing - Part 6 of the Therapy.jl Book
#
# File-based routing, client-side navigation, and nested routes.

function Index()
    Fragment(
        # Header
        Div(:class => "py-8 border-b border-neutral-300 dark:border-neutral-800",
            Span(:class => "text-sm text-emerald-700 dark:text-emerald-400 font-medium", "Part 6"),
            H1(:class => "text-4xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mt-2 mb-4",
                "Routing"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 max-w-3xl",
                "Navigate between pages with file-based routing, client-side navigation, and dynamic routes."
            )
        ),

        # Coming Soon Notice
        Section(:class => "py-12",
            Div(:class => "bg-amber-50 dark:bg-amber-950/20 rounded-lg border border-amber-200 dark:border-amber-900 p-8 text-center",
                H2(:class => "text-2xl font-serif font-semibold text-amber-900 dark:text-amber-200 mb-4",
                    "Coming Soon"
                ),
                P(:class => "text-amber-800 dark:text-amber-300",
                    "This section is currently being written. Check back soon for file-based routing, dynamic routes, and SPA navigation!"
                )
            )
        ),

        # Topics Preview
        Section(:class => "py-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "What You'll Learn"
            ),
            Ul(:class => "space-y-3 text-neutral-600 dark:text-neutral-400",
                Li(Strong("File-Based Routing"), " - routes/about.jl maps to /about/"),
                Li(Strong("Dynamic Routes"), " - [id].jl for /users/:id patterns"),
                Li(Strong("Catch-All Routes"), " - [...slug].jl for arbitrary paths"),
                Li(Strong("NavLink"), " - Client-side navigation with active states"),
                Li(Strong("SPA Navigation"), " - No full page reloads between routes"),
                Li(Strong("Layout Persistence"), " - Keep navigation and state during routing")
            )
        ),

        # Quick Preview
        Section(:class => "py-8 bg-neutral-50 dark:bg-neutral-900 rounded-lg border border-neutral-300 dark:border-neutral-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Quick Preview"
            ),
            Div(:class => "bg-neutral-900 dark:bg-neutral-950 rounded border border-neutral-800 p-6 overflow-x-auto",
                Pre(:class => "text-sm text-neutral-100",
                    Code(:class => "language-julia", """# File-based routing (like Next.js)
# routes/
#   index.jl        \u2192 /
#   about.jl        \u2192 /about/
#   users/[id].jl   \u2192 /users/:id
#   docs/[...slug].jl \u2192 /docs/*

# NavLink for client-side navigation
NavLink("./users/", "Users";
    class = "text-neutral-600",
    active_class = "text-emerald-700"
)

# Create router from directory
router = create_router("routes"; layout = Layout)

# Handle incoming requests
html, route, params = handle_request(router, "/users/123")
# params[:id] == "123\"""")
                )
            )
        ),

        # Navigation
        Div(:class => "py-8 flex justify-between border-t border-neutral-300 dark:border-neutral-800",
            A(:href => "../server/",
              :class => "inline-flex items-center text-neutral-600 dark:text-neutral-400 hover:text-emerald-700 dark:hover:text-emerald-400 transition-colors",
                Svg(:class => "mr-2 w-5 h-5", :fill => "none", :viewBox => "0 0 24 24", :stroke => "currentColor",
                    Path(:stroke_linecap => "round", :stroke_linejoin => "round", :stroke_width => "2", :d => "M11 17l-5-5m0 0l5-5m-5 5h12")
                ),
                "Server Features"
            ),
            A(:href => "../",
              :class => "inline-flex items-center text-neutral-600 dark:text-neutral-400 hover:text-emerald-700 dark:hover:text-emerald-400 transition-colors",
                "Back to Book",
                Svg(:class => "ml-2 w-5 h-5", :fill => "none", :viewBox => "0 0 24 24", :stroke => "currentColor",
                    Path(:stroke_linecap => "round", :stroke_linejoin => "round", :stroke_width => "2", :d => "M13 7l5 5m0 0l-5 5m5-5H6")
                )
            )
        )
    )
end

Index
