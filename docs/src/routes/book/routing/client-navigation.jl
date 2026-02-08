# Client-Side Navigation - Chapter 3 of Part 6
#
# SPA-style navigation with NavLink and the TherapyRouter.

import Suite

function ClientNavigation()
    BookLayout("/book/routing/client-navigation/",
        # Header
        Div(:class => "py-8 border-b border-warm-200 dark:border-warm-700",
            Suite.Badge(variant="outline", "Part 6 · Chapter 3"),
            H1(:class => "text-4xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-2 mb-4",
                "Client-Side Navigation"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 max-w-3xl",
                "Navigate between pages without full page reloads. NavLink provides SPA-style navigation ",
                "with automatic active state styling."
            )
        ),

        # Why Client-Side Navigation?
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Why Client-Side Navigation?"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Traditional websites reload the entire page on every link click. Client-side navigation ",
                "only fetches the new content, keeping the shell (navigation, sidebar) intact."
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Suite.Card(
                    Suite.CardHeader(
                        Suite.CardTitle("Full Page Reload")
                    ),
                    Suite.CardContent(
                        Ul(:class => "space-y-2 text-warm-600 dark:text-warm-400 text-sm",
                            Li("Browser fetches entire HTML document"),
                            Li("CSS and JavaScript reload"),
                            Li("Flash of white during transition"),
                            Li("Loses scroll position"),
                            Li("Resets component state")
                        )
                    )
                ),
                Suite.Card(
                    Suite.CardHeader(
                        Suite.CardTitle("Client-Side Navigation")
                    ),
                    Suite.CardContent(
                        Ul(:class => "space-y-2 text-warm-600 dark:text-warm-400 text-sm",
                            Li("Only fetches page content"),
                            Li("No CSS/JS reload needed"),
                            Li("Smooth, instant transitions"),
                            Li("Preserves layout state"),
                            Li("Back/forward buttons work")
                        )
                    )
                )
            ),
            Suite.Alert(class="mt-8",
                Suite.AlertTitle("Progressive Enhancement"),
                Suite.AlertDescription(
                    "Client-side navigation is an enhancement. If JavaScript fails to load or is disabled, " *
                    "links work as normal HTML—they just do full page loads."
                )
            )
        ),

        Suite.Separator(),

        # NavLink Component
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "The NavLink Component"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                Code(:class => "text-accent-700 dark:text-accent-400", "NavLink"),
                " is a drop-in replacement for ", Code(:class => "text-accent-700 dark:text-accent-400", "A"),
                " that intercepts clicks and navigates client-side:"
            ),
            Suite.CodeBlock(
                code="""# Basic usage
NavLink("/about/", "About")

# With classes
NavLink("/users/", "Users";
    class = "text-warm-600 hover:text-warm-800"
)

# With active state styling
NavLink("/dashboard/", "Dashboard";
    class = "text-warm-600",
    active_class = "text-accent-700 font-semibold"
)""",
                language="julia"
            ),
            H3(:class => "text-xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-8 mb-4",
                "Active Class Options"
            ),
            Suite.CodeBlock(
                code="""# Default behavior: active if current path starts with href
NavLink("/users/", "Users";
    class = "text-warm-600",
    active_class = "text-accent-700 font-bold"
)
# Active on: /users/, /users/123, /users/new, etc.

# Exact matching: only active on exact path
NavLink("/", "Home";
    class = "text-warm-600",
    active_class = "text-accent-700 font-bold",
    exact = true
)
# Active on: / only (not /about, /users, etc.)

# This is important for the home link, which would otherwise
# match every path (everything starts with /)""",
                language="julia",
                show_copy=false
            )
        ),

        Suite.Separator(),

        # Building a Navigation Bar
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Building a Navigation Bar"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Here's a complete navigation bar with responsive styling:"
            ),
            Suite.CodeBlock(
                code="""function Navigation()
    Nav(:class => "bg-warm-50 dark:bg-warm-900 border-b border-warm-200",
        Div(:class => "container mx-auto px-4",
            Div(:class => "flex items-center justify-between h-16",
                # Logo
                A(:href => "/", :class => "text-xl font-bold",
                    "MyApp"
                ),

                # Navigation links
                Div(:class => "flex items-center gap-6",
                    NavLink("/", "Home";
                        class = "text-warm-600 hover:text-warm-800",
                        active_class = "text-accent-700 font-semibold",
                        exact = true  # Only active on /
                    ),
                    NavLink("/features/", "Features";
                        class = "text-warm-600 hover:text-warm-800",
                        active_class = "text-accent-700 font-semibold"
                    ),
                    NavLink("/docs/", "Documentation";
                        class = "text-warm-600 hover:text-warm-800",
                        active_class = "text-accent-700 font-semibold"
                    ),
                    NavLink("/pricing/", "Pricing";
                        class = "text-warm-600 hover:text-warm-800",
                        active_class = "text-accent-700 font-semibold"
                    )
                )
            )
        )
    )
end""",
                language="julia"
            )
        ),

        Suite.Separator(),

        # How It Works
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "How Client-Side Navigation Works"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Therapy.jl uses a partial rendering strategy for smooth navigation:"
            ),
            Div(:class => "space-y-6",
                Div(:class => "flex gap-4",
                    Suite.Badge(variant="default", "1"),
                    Div(
                        H4(:class => "font-semibold text-warm-800 dark:text-warm-50", "Full Page Load"),
                        P(:class => "text-sm text-warm-600 dark:text-warm-400 mt-1", "Browser requests page. Server renders Layout + route content. All HTML, CSS, JS sent.")
                    )
                ),
                Div(:class => "flex gap-4",
                    Suite.Badge(variant="default", "2"),
                    Div(
                        H4(:class => "font-semibold text-warm-800 dark:text-warm-50", "JavaScript Loads"),
                        P(:class => "text-sm text-warm-600 dark:text-warm-400 mt-1", "TherapyRouter initializes. Intercepts NavLink clicks.")
                    )
                ),
                Div(:class => "flex gap-4",
                    Suite.Badge(variant="default", "3"),
                    Div(
                        H4(:class => "font-semibold text-warm-800 dark:text-warm-50", "NavLink Clicked"),
                        P(:class => "text-sm text-warm-600 dark:text-warm-400 mt-1", "Instead of browser navigation, TherapyRouter takes over.")
                    )
                ),
                Div(:class => "flex gap-4",
                    Suite.Badge(variant="default", "4"),
                    Div(
                        H4(:class => "font-semibold text-warm-800 dark:text-warm-50", "Partial Fetch"),
                        P(:class => "text-sm text-warm-600 dark:text-warm-400 mt-1", "Fetch request with X-Therapy-Partial: 1 header.")
                    )
                ),
                Div(:class => "flex gap-4",
                    Suite.Badge(variant="default", "5"),
                    Div(
                        H4(:class => "font-semibold text-warm-800 dark:text-warm-50", "Server Response"),
                        P(:class => "text-sm text-warm-600 dark:text-warm-400 mt-1", "Server detects partial header. Returns only route content (no Layout).")
                    )
                ),
                Div(:class => "flex gap-4",
                    Suite.Badge(variant="default", "6"),
                    Div(
                        H4(:class => "font-semibold text-warm-800 dark:text-warm-50", "DOM Update"),
                        P(:class => "text-sm text-warm-600 dark:text-warm-400 mt-1", "TherapyRouter swaps #page-content with new content.")
                    )
                ),
                Div(:class => "flex gap-4",
                    Suite.Badge(variant="default", "7"),
                    Div(
                        H4(:class => "font-semibold text-warm-800 dark:text-warm-50", "Hydration"),
                        P(:class => "text-sm text-warm-600 dark:text-warm-400 mt-1", "Islands in new content are discovered and hydrated.")
                    )
                ),
                Div(:class => "flex gap-4",
                    Suite.Badge(variant="default", "8"),
                    Div(
                        H4(:class => "font-semibold text-warm-800 dark:text-warm-50", "History Update"),
                        P(:class => "text-sm text-warm-600 dark:text-warm-400 mt-1", "pushState updates URL. Back/forward buttons work.")
                    )
                )
            )
        ),

        Suite.Separator(),

        # JavaScript API
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "JavaScript API"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "TherapyRouter exposes a JavaScript API for programmatic navigation:"
            ),
            Suite.CodeBlock(
                code="""// Navigate to a new page
window.TherapyRouter.navigate('/users/123');

// Navigate and replace history (no back button entry)
window.TherapyRouter.navigate('/login', { replace: true });

// Re-hydrate islands after dynamic content insertion
window.TherapyRouter.hydrateIslands();

// Update active link styling (called automatically)
window.TherapyRouter.updateActiveLinks();

// Check if TherapyRouter is loaded
if (window.TherapyRouter) {
    window.TherapyRouter.navigate('/dashboard');
}""",
                language="javascript"
            ),
            H3(:class => "text-xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-8 mb-4",
                "Using from Julia (SSR)"
            ),
            Suite.CodeBlock(
                code="""# In a button handler (rendered as onclick attribute)
Button(
    :on_click => "TherapyRouter.navigate('/checkout')",
    :class => "btn btn-primary",
    "Proceed to Checkout"
)

# Conditional navigation
Button(
    :on_click => \"\"\"
        if (confirm('Are you sure?')) {
            TherapyRouter.navigate('/deleted');
        }
    \"\"\",
    "Delete Account"
)""",
                language="julia",
                show_copy=false
            )
        ),

        Suite.Separator(),

        # Layout Requirements
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Layout Requirements"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "For client-side navigation to work, your Layout must have a ",
                Code(:class => "text-accent-700 dark:text-accent-400", "#page-content"),
                " container:"
            ),
            Suite.CodeBlock(
                code="""function Layout(; children...)
    BookLayout(
        # DOCTYPE is added by render_page

        # Head content
        Head(
            Title("My App"),
            Meta(:charset => "UTF-8"),
            Meta(:name => "viewport", :content => "width=device-width, initial-scale=1")
        ),

        # Body
        Body(:class => "min-h-screen bg-warm-50 dark:bg-warm-950",
            # Navigation (persists during SPA navigation)
            Navigation(),

            # Page content container - THIS ID IS REQUIRED
            Main(:id => "page-content", :class => "container mx-auto px-4 py-8",
                children...  # Route content renders here
            ),

            # Footer (persists during SPA navigation)
            Footer()
        )
    )
end""",
                language="julia"
            ),
            Suite.Alert(class="mt-8", variant="destructive",
                Suite.AlertTitle("Required: #page-content"),
                Suite.AlertDescription(
                    "Without an element with id=\"page-content\", TherapyRouter won't know where to " *
                    "insert new page content. Client-side navigation will fall back to full page loads."
                )
            )
        ),

        Suite.Separator(),

        # Handling External Links
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Handling External Links"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "NavLink is only for internal navigation. Use regular ",
                Code(:class => "text-accent-700 dark:text-accent-400", "A"),
                " tags for external links:"
            ),
            Suite.CodeBlock(
                code="""# Internal link - uses client-side navigation
NavLink("/about/", "About Us")

# External link - regular anchor tag
A(:href => "https://github.com/myorg/myapp",
  :target => "_blank",
  :rel => "noopener noreferrer",
  "View on GitHub"
)

# Download link - skip client-side navigation
A(:href => "/files/report.pdf",
  :download => true,
  "Download Report"
)

# Anchor link (same page) - regular anchor
A(:href => "#features", "Jump to Features")""",
                language="julia"
            )
        ),

        Suite.Separator(),

        # Advanced Patterns
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Advanced Patterns"
            ),
            H3(:class => "text-xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-4",
                "Tabs with NavLink"
            ),
            Suite.CodeBlock(
                code="""function ProfileTabs(; user_id)
    Div(:class => "border-b border-warm-200 mb-6",
        Nav(:class => "flex gap-4 -mb-px",
            NavLink("/users/\$user_id/", "Profile";
                class = "py-2 px-1 border-b-2 border-transparent",
                active_class = "border-accent-500 text-accent-700",
                exact = true
            ),
            NavLink("/users/\$user_id/posts/", "Posts";
                class = "py-2 px-1 border-b-2 border-transparent",
                active_class = "border-accent-500 text-accent-700"
            ),
            NavLink("/users/\$user_id/settings/", "Settings";
                class = "py-2 px-1 border-b-2 border-transparent",
                active_class = "border-accent-500 text-accent-700"
            )
        )
    )
end""",
                language="julia"
            ),
            H3(:class => "text-xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-8 mb-4",
                "Breadcrumbs"
            ),
            Suite.CodeBlock(
                code="""function Breadcrumb(; segments)
    Nav(:class => "flex items-center gap-2 text-sm text-warm-600",
        NavLink("/", "Home";
            class = "hover:text-warm-800",
            active_class = "text-warm-800"
        ),
        For(() -> segments) do segment
            BookLayout(
                Span("/"),
                NavLink(segment.path, segment.label;
                    class = "hover:text-warm-800",
                    active_class = "text-warm-800"
                )
            )
        end
    )
end

# Usage
Breadcrumb(segments = [
    (path = "/products/", label = "Products"),
    (path = "/products/electronics/", label = "Electronics"),
    (path = "/products/electronics/laptops/", label = "Laptops")
])""",
                language="julia",
                show_copy=false
            )
        ),

        # Key Takeaways
        Suite.Alert(class="mt-12",
            Suite.AlertTitle("Key Takeaways"),
            Suite.AlertDescription(
                Ul(:class => "space-y-2 list-disc pl-5 mt-2",
                    Li(Strong("NavLink"), " — Drop-in replacement for A with client-side navigation"),
                    Li(Strong("active_class"), " — Automatic styling for current/matching routes"),
                    Li(Strong("exact = true"), " — Only match the exact path (use for home link)"),
                    Li(Strong("#page-content"), " — Required container ID in your Layout"),
                    Li(Strong("TherapyRouter.navigate()"), " — Programmatic navigation from JavaScript"),
                    Li(Strong("Progressive enhancement"), " — Works without JS, better with it")
                )
            )
        ),

    )
end

# Export the page component
ClientNavigation
