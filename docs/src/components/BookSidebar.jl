# BookSidebar.jl - Sidebar navigation for the Therapy.jl book
#
# Provides chapter navigation with section groupings
# Uses NavLink for active state highlighting

"""
Book chapter structure for sidebar navigation.
"""
const BOOK_CHAPTERS = [
    (section = "Introduction", chapters = [
        (path = "./", title = "Welcome"),
        (path = "./getting-started/", title = "Getting Started"),
    ]),
    (section = "Reactivity", chapters = [
        (path = "./reactivity/", title = "Overview"),
        (path = "./reactivity/signals/", title = "Signals"),
        (path = "./reactivity/effects/", title = "Effects"),
        (path = "./reactivity/memos/", title = "Memos"),
    ]),
    (section = "Components", chapters = [
        (path = "./components/", title = "Overview"),
        (path = "./components/basics/", title = "Basics"),
        (path = "./components/props/", title = "Props"),
        (path = "./components/children/", title = "Children"),
        (path = "./components/control-flow/", title = "Control Flow"),
    ]),
    (section = "Async", chapters = [
        (path = "./async/", title = "Overview"),
        (path = "./async/resources/", title = "Resources"),
        (path = "./async/suspense/", title = "Suspense"),
        (path = "./async/patterns/", title = "Patterns"),
    ]),
    (section = "Server", chapters = [
        (path = "./server/", title = "Overview"),
        (path = "./server/ssr/", title = "SSR"),
        (path = "./server/server-functions/", title = "Server Functions"),
        (path = "./server/websocket/", title = "WebSocket"),
    ]),
    (section = "Routing", chapters = [
        (path = "./routing/", title = "Overview"),
        (path = "./routing/file-routing/", title = "File-Based Routing"),
        (path = "./routing/dynamic-routes/", title = "Dynamic Routes"),
        (path = "./routing/client-navigation/", title = "Client Navigation"),
        (path = "./routing/nested-routes/", title = "Nested Routes"),
    ]),
]

"""
Individual sidebar link with active state highlighting.
Uses NavLink for SPA navigation and active class support.
"""
function SidebarLink(href, label)
    NavLink(href, label;
        class = "block px-3 py-1.5 text-sm text-neutral-600 dark:text-neutral-400 hover:text-neutral-900 dark:hover:text-white hover:bg-neutral-100 dark:hover:bg-neutral-800 rounded transition-colors",
        active_class = "text-emerald-700 dark:text-emerald-400 bg-emerald-50 dark:bg-emerald-950/50 border-l-2 border-emerald-600 -ml-0.5 pl-[calc(0.75rem+2px)]"
    )
end

"""
Section header for chapter groupings.
"""
function SidebarSection(section_name, chapters)
    Div(:class => "mb-6",
        # Section header
        H3(:class => "px-3 py-2 text-xs font-semibold uppercase tracking-wider text-neutral-500 dark:text-neutral-400",
            section_name
        ),
        # Chapter links
        Ul(:class => "space-y-1",
            [Li(SidebarLink(ch.path, ch.title)) for ch in chapters]...
        )
    )
end

"""
Book sidebar navigation component.
Displays all chapters organized by section with active state highlighting.
"""
function BookSidebar()
    Nav(:class => "book-sidebar py-6 px-2",
        # Header
        Div(:class => "px-3 mb-6",
            A(:href => "./", :class => "flex items-center group",
                Span(:class => "text-lg font-serif font-bold text-neutral-900 dark:text-neutral-100 group-hover:text-emerald-700 dark:group-hover:text-emerald-400 transition-colors",
                    "Therapy.jl Book"
                )
            )
        ),
        # Chapter sections
        [SidebarSection(section.section, section.chapters) for section in BOOK_CHAPTERS]...
    )
end
