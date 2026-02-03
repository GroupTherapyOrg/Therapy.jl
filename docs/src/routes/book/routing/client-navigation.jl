# Client-Side Navigation - Chapter 3 of Part 6
#
# SPA-style navigation with NavLink and the TherapyRouter.

function ClientNavigation()
    BookLayout("/book/routing/client-navigation/",
        # Header
        Div(:class => "py-8 border-b border-neutral-300 dark:border-neutral-800",
            Span(:class => "text-sm text-emerald-700 dark:text-emerald-400 font-medium", "Part 6 · Chapter 3"),
            H1(:class => "text-4xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mt-2 mb-4",
                "Client-Side Navigation"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 max-w-3xl",
                "Navigate between pages without full page reloads. NavLink provides SPA-style navigation ",
                "with automatic active state styling."
            )
        ),

        # Why Client-Side Navigation?
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Why Client-Side Navigation?"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "Traditional websites reload the entire page on every link click. Client-side navigation ",
                "only fetches the new content, keeping the shell (navigation, sidebar) intact."
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(:class => "bg-white dark:bg-neutral-800 rounded-lg border border-neutral-300 dark:border-neutral-700 p-6",
                    H3(:class => "text-lg font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-4",
                        "Full Page Reload"
                    ),
                    Ul(:class => "space-y-2 text-neutral-600 dark:text-neutral-400 text-sm",
                        Li("❌ Browser fetches entire HTML document"),
                        Li("❌ CSS and JavaScript reload"),
                        Li("❌ Flash of white during transition"),
                        Li("❌ Loses scroll position"),
                        Li("❌ Resets component state")
                    )
                ),
                Div(:class => "bg-emerald-50 dark:bg-emerald-950/30 rounded-lg border border-emerald-200 dark:border-emerald-700 p-6",
                    H3(:class => "text-lg font-serif font-semibold text-emerald-900 dark:text-emerald-200 mb-4",
                        "Client-Side Navigation"
                    ),
                    Ul(:class => "space-y-2 text-emerald-800 dark:text-emerald-300 text-sm",
                        Li("✅ Only fetches page content"),
                        Li("✅ No CSS/JS reload needed"),
                        Li("✅ Smooth, instant transitions"),
                        Li("✅ Preserves layout state"),
                        Li("✅ Back/forward buttons work")
                    )
                )
            ),
            InfoBox("Progressive Enhancement",
                "Client-side navigation is an enhancement. If JavaScript fails to load or is disabled, " *
                "links work as normal HTML—they just do full page loads."
            )
        ),

        # NavLink Component
        Section(:class => "py-12 bg-neutral-50 dark:bg-neutral-900 rounded-lg border border-neutral-300 dark:border-neutral-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "The NavLink Component"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                Code(:class => "text-emerald-700 dark:text-emerald-400", "NavLink"),
                " is a drop-in replacement for ", Code(:class => "text-emerald-700 dark:text-emerald-400", "A"),
                " that intercepts clicks and navigates client-side:"
            ),
            CodeBlock("""# Basic usage
NavLink("/about/", "About")

# With classes
NavLink("/users/", "Users";
    class = "text-neutral-600 hover:text-neutral-900"
)

# With active state styling
NavLink("/dashboard/", "Dashboard";
    class = "text-neutral-600",
    active_class = "text-emerald-700 font-semibold"
)"""),
            H3(:class => "text-xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mt-8 mb-4",
                "Active Class Options"
            ),
            CodeBlock("""# Default behavior: active if current path starts with href
NavLink("/users/", "Users";
    class = "text-neutral-600",
    active_class = "text-emerald-700 font-bold"
)
# Active on: /users/, /users/123, /users/new, etc.

# Exact matching: only active on exact path
NavLink("/", "Home";
    class = "text-neutral-600",
    active_class = "text-emerald-700 font-bold",
    exact = true
)
# Active on: / only (not /about, /users, etc.)

# This is important for the home link, which would otherwise
# match every path (everything starts with /)""", "neutral")
        ),

        # Building a Navigation Bar
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Building a Navigation Bar"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "Here's a complete navigation bar with responsive styling:"
            ),
            CodeBlock("""function Navigation()
    Nav(:class => "bg-white dark:bg-neutral-900 border-b border-neutral-200",
        Div(:class => "container mx-auto px-4",
            Div(:class => "flex items-center justify-between h-16",
                # Logo
                A(:href => "/", :class => "text-xl font-bold",
                    "MyApp"
                ),

                # Navigation links
                Div(:class => "flex items-center gap-6",
                    NavLink("/", "Home";
                        class = "text-neutral-600 hover:text-neutral-900",
                        active_class = "text-emerald-700 font-semibold",
                        exact = true  # Only active on /
                    ),
                    NavLink("/features/", "Features";
                        class = "text-neutral-600 hover:text-neutral-900",
                        active_class = "text-emerald-700 font-semibold"
                    ),
                    NavLink("/docs/", "Documentation";
                        class = "text-neutral-600 hover:text-neutral-900",
                        active_class = "text-emerald-700 font-semibold"
                    ),
                    NavLink("/pricing/", "Pricing";
                        class = "text-neutral-600 hover:text-neutral-900",
                        active_class = "text-emerald-700 font-semibold"
                    )
                )
            )
        )
    )
end""")
        ),

        # How It Works
        Section(:class => "py-12 bg-neutral-50 dark:bg-neutral-900 rounded-lg border border-neutral-300 dark:border-neutral-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "How Client-Side Navigation Works"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "Therapy.jl uses a partial rendering strategy for smooth navigation:"
            ),
            Div(:class => "space-y-6",
                FlowStep("1", "Full Page Load", "Browser requests page. Server renders Layout + route content. All HTML, CSS, JS sent."),
                FlowStep("2", "JavaScript Loads", "TherapyRouter initializes. Intercepts NavLink clicks."),
                FlowStep("3", "NavLink Clicked", "Instead of browser navigation, TherapyRouter takes over."),
                FlowStep("4", "Partial Fetch", "Fetch request with X-Therapy-Partial: 1 header."),
                FlowStep("5", "Server Response", "Server detects partial header. Returns only route content (no Layout)."),
                FlowStep("6", "DOM Update", "TherapyRouter swaps #page-content with new content."),
                FlowStep("7", "Hydration", "Islands in new content are discovered and hydrated."),
                FlowStep("8", "History Update", "pushState updates URL. Back/forward buttons work.")
            )
        ),

        # JavaScript API
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "JavaScript API"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "TherapyRouter exposes a JavaScript API for programmatic navigation:"
            ),
            CodeBlock("""// Navigate to a new page
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
}""", "javascript"),
            H3(:class => "text-xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mt-8 mb-4",
                "Using from Julia (SSR)"
            ),
            CodeBlock("""# In a button handler (rendered as onclick attribute)
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
)""", "neutral")
        ),

        # Layout Requirements
        Section(:class => "py-12 bg-neutral-50 dark:bg-neutral-900 rounded-lg border border-neutral-300 dark:border-neutral-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Layout Requirements"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "For client-side navigation to work, your Layout must have a ",
                Code(:class => "text-emerald-700 dark:text-emerald-400", "#page-content"),
                " container:"
            ),
            CodeBlock("""function Layout(; children...)
    BookLayout(
        # DOCTYPE is added by render_page

        # Head content
        Head(
            Title("My App"),
            Meta(:charset => "UTF-8"),
            Meta(:name => "viewport", :content => "width=device-width, initial-scale=1")
        ),

        # Body
        Body(:class => "min-h-screen bg-white dark:bg-neutral-950",
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
end"""),
            WarnBox("Required: #page-content",
                "Without an element with id=\"page-content\", TherapyRouter won't know where to " *
                "insert new page content. Client-side navigation will fall back to full page loads."
            )
        ),

        # Handling External Links
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Handling External Links"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 mb-6",
                "NavLink is only for internal navigation. Use regular ",
                Code(:class => "text-emerald-700 dark:text-emerald-400", "A"),
                " tags for external links:"
            ),
            CodeBlock("""# Internal link - uses client-side navigation
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
A(:href => "#features", "Jump to Features")""")
        ),

        # Advanced Patterns
        Section(:class => "py-12 bg-neutral-50 dark:bg-neutral-900 rounded-lg border border-neutral-300 dark:border-neutral-800 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "Advanced Patterns"
            ),
            H3(:class => "text-xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-4",
                "Tabs with NavLink"
            ),
            CodeBlock("""function ProfileTabs(; user_id)
    Div(:class => "border-b border-neutral-200 mb-6",
        Nav(:class => "flex gap-4 -mb-px",
            NavLink("/users/\$user_id/", "Profile";
                class = "py-2 px-1 border-b-2 border-transparent",
                active_class = "border-emerald-500 text-emerald-700",
                exact = true
            ),
            NavLink("/users/\$user_id/posts/", "Posts";
                class = "py-2 px-1 border-b-2 border-transparent",
                active_class = "border-emerald-500 text-emerald-700"
            ),
            NavLink("/users/\$user_id/settings/", "Settings";
                class = "py-2 px-1 border-b-2 border-transparent",
                active_class = "border-emerald-500 text-emerald-700"
            )
        )
    )
end"""),
            H3(:class => "text-xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mt-8 mb-4",
                "Breadcrumbs"
            ),
            CodeBlock("""function Breadcrumb(; segments)
    Nav(:class => "flex items-center gap-2 text-sm text-neutral-500",
        NavLink("/", "Home";
            class = "hover:text-neutral-700",
            active_class = "text-neutral-900"
        ),
        For(() -> segments) do segment
            BookLayout(
                Span("/"),
                NavLink(segment.path, segment.label;
                    class = "hover:text-neutral-700",
                    active_class = "text-neutral-900"
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
])""", "neutral")
        ),

        # Key Takeaways
        Section(:class => "py-12 bg-emerald-50 dark:bg-emerald-950/30 rounded-lg border border-emerald-200 dark:border-emerald-900 px-8",
            H2(:class => "text-2xl font-serif font-semibold text-emerald-900 dark:text-emerald-200 mb-6",
                "Key Takeaways"
            ),
            Ul(:class => "space-y-3 text-emerald-800 dark:text-emerald-300",
                Li("🔗 ", Strong("NavLink"), " — Drop-in replacement for A with client-side navigation"),
                Li("✨ ", Strong("active_class"), " — Automatic styling for current/matching routes"),
                Li("🎯 ", Strong("exact = true"), " — Only match the exact path (use for home link)"),
                Li("📦 ", Strong("#page-content"), " — Required container ID in your Layout"),
                Li("🛠️ ", Strong("TherapyRouter.navigate()"), " — Programmatic navigation from JavaScript"),
                Li("⬇️ ", Strong("Progressive enhancement"), " — Works without JS, better with it")
            )
        ),

    )
end

# Helper Components

function FlowStep(number, title, description)
    Div(:class => "flex gap-4",
        Span(:class => "flex-shrink-0 w-8 h-8 bg-emerald-700 dark:bg-emerald-600 text-white rounded-full flex items-center justify-center font-semibold text-sm", number),
        Div(
            H4(:class => "font-semibold text-neutral-900 dark:text-neutral-100", title),
            P(:class => "text-sm text-neutral-600 dark:text-neutral-400 mt-1", description)
        )
    )
end

function CodeBlock(code, style="default")
    bg_class = if style == "emerald"
        "bg-emerald-900 dark:bg-emerald-950 border-emerald-700"
    elseif style == "neutral"
        "bg-neutral-700 dark:bg-neutral-800 border-neutral-600"
    elseif style == "javascript"
        "bg-amber-900 dark:bg-amber-950 border-amber-700"
    else
        "bg-neutral-900 dark:bg-neutral-950 border-neutral-800"
    end

    Div(:class => "$bg_class rounded border p-6 overflow-x-auto",
        Pre(:class => "text-sm text-neutral-100",
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
ClientNavigation
