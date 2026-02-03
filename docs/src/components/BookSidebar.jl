# BookSidebar.jl - Sidebar navigation for the Therapy.jl book
#
# Provides chapter navigation with section groupings
# Uses NavLink for active state highlighting

"""
Book chapter structure for sidebar navigation.
"""
const BOOK_CHAPTERS = [
    (section = "Introduction", chapters = [
        (path = "/book/", title = "Welcome"),
        (path = "/book/getting-started/", title = "Getting Started"),
    ]),
    (section = "Reactivity", chapters = [
        (path = "/book/reactivity/", title = "Overview"),
        (path = "/book/reactivity/signals/", title = "Signals"),
        (path = "/book/reactivity/effects/", title = "Effects"),
        (path = "/book/reactivity/memos/", title = "Memos"),
    ]),
    (section = "Components", chapters = [
        (path = "/book/components/", title = "Overview"),
        (path = "/book/components/basics/", title = "Basics"),
        (path = "/book/components/props/", title = "Props"),
        (path = "/book/components/children/", title = "Children"),
        (path = "/book/components/control-flow/", title = "Control Flow"),
    ]),
    (section = "Async", chapters = [
        (path = "/book/async/", title = "Overview"),
        (path = "/book/async/resources/", title = "Resources"),
        (path = "/book/async/suspense/", title = "Suspense"),
        (path = "/book/async/patterns/", title = "Patterns"),
    ]),
    (section = "Server", chapters = [
        (path = "/book/server/", title = "Overview"),
        (path = "/book/server/ssr/", title = "SSR"),
        (path = "/book/server/server-functions/", title = "Server Functions"),
        (path = "/book/server/websocket/", title = "WebSocket"),
    ]),
    (section = "Routing", chapters = [
        (path = "/book/routing/", title = "Overview"),
        (path = "/book/routing/file-routing/", title = "File-Based Routing"),
        (path = "/book/routing/dynamic-routes/", title = "Dynamic Routes"),
        (path = "/book/routing/client-navigation/", title = "Client Navigation"),
        (path = "/book/routing/nested-routes/", title = "Nested Routes"),
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
            A(:href => "/book/", :class => "flex items-center group",
                Span(:class => "text-lg font-serif font-bold text-neutral-900 dark:text-neutral-100 group-hover:text-emerald-700 dark:group-hover:text-emerald-400 transition-colors",
                    "Therapy.jl Book"
                )
            )
        ),
        # Chapter sections
        [SidebarSection(section.section, section.chapters) for section in BOOK_CHAPTERS]...
    )
end

"""
Get a flat list of all book chapters in order.
Returns: Vector of (path, title, section) tuples
"""
function get_all_chapters()
    chapters = Tuple{String, String, String}[]
    for section in BOOK_CHAPTERS
        for ch in section.chapters
            push!(chapters, (ch.path, ch.title, section.section))
        end
    end
    chapters
end

"""
Find the previous and next chapters for a given path.
Returns: (prev, current, next) where each is (path, title, section) or nothing
"""
function find_chapter_navigation(current_path::String)
    chapters = get_all_chapters()

    # Normalize path - ensure trailing slash for comparison
    normalized = endswith(current_path, "/") ? current_path : current_path * "/"

    # Find current chapter index
    idx = findfirst(ch -> ch[1] == normalized, chapters)

    if idx === nothing
        return (nothing, nothing, nothing)
    end

    prev = idx > 1 ? chapters[idx - 1] : nothing
    current = chapters[idx]
    next = idx < length(chapters) ? chapters[idx + 1] : nothing

    return (prev, current, next)
end

"""
Get breadcrumb trail for a given path.
Returns: Vector of (path, title) pairs from Book root to current
"""
function get_breadcrumbs(current_path::String)
    breadcrumbs = [("/book/", "Book")]

    # Normalize path
    normalized = endswith(current_path, "/") ? current_path : current_path * "/"

    if normalized == "/book/"
        return breadcrumbs
    end

    # Find section and chapter info
    for section in BOOK_CHAPTERS
        for ch in section.chapters
            if ch.path == normalized
                # Add section overview if we're in a subsection
                section_path = "/book/$(lowercase(replace(section.section, " " => "-")))/"
                if section_path != normalized
                    # Check if section overview exists
                    section_overview = findfirst(c -> c.path == section_path, section.chapters)
                    if section_overview !== nothing
                        push!(breadcrumbs, (section_path, section.section))
                    end
                end
                push!(breadcrumbs, (ch.path, ch.title))
                return breadcrumbs
            end
        end
    end

    breadcrumbs
end

"""
Prev/Next navigation links for bottom of book pages.
"""
function BookNavigation(current_path::String)
    prev, current, next = find_chapter_navigation(current_path)

    Div(:class => "py-8 flex justify-between border-t border-neutral-300 dark:border-neutral-800",
        # Previous link
        if prev !== nothing
            A(:href => prev[1],
              :class => "inline-flex items-center text-neutral-600 dark:text-neutral-400 hover:text-emerald-700 dark:hover:text-emerald-400 transition-colors group",
                Svg(:class => "mr-2 w-5 h-5 group-hover:-translate-x-1 transition-transform", :fill => "none", :viewBox => "0 0 24 24", :stroke => "currentColor",
                    Path(:stroke_linecap => "round", :stroke_linejoin => "round", :stroke_width => "2", :d => "M11 17l-5-5m0 0l5-5m-5 5h12")
                ),
                Span(:class => "flex flex-col items-start",
                    Span(:class => "text-xs text-neutral-500 dark:text-neutral-500", "Previous"),
                    Span(:class => "font-medium", prev[2])
                )
            )
        else
            Div()  # Empty placeholder
        end,

        # Next link
        if next !== nothing
            A(:href => next[1],
              :class => "inline-flex items-center text-neutral-600 dark:text-neutral-400 hover:text-emerald-700 dark:hover:text-emerald-400 transition-colors group",
                Span(:class => "flex flex-col items-end",
                    Span(:class => "text-xs text-neutral-500 dark:text-neutral-500", "Next"),
                    Span(:class => "font-medium", next[2])
                ),
                Svg(:class => "ml-2 w-5 h-5 group-hover:translate-x-1 transition-transform", :fill => "none", :viewBox => "0 0 24 24", :stroke => "currentColor",
                    Path(:stroke_linecap => "round", :stroke_linejoin => "round", :stroke_width => "2", :d => "M13 7l5 5m0 0l-5 5m5-5H6")
                )
            )
        else
            Div()  # Empty placeholder
        end
    )
end

"""
Breadcrumb navigation for top of book pages.
"""
function BookBreadcrumbs(current_path::String)
    crumbs = get_breadcrumbs(current_path)

    Nav(:class => "mb-4", :aria_label => "Breadcrumb",
        Ol(:class => "flex flex-wrap items-center gap-1 text-sm",
            [begin
                is_last = i == length(crumbs)
                Li(:class => "flex items-center",
                    if i > 1
                        Svg(:class => "mx-2 w-4 h-4 text-neutral-400", :fill => "none", :viewBox => "0 0 24 24", :stroke => "currentColor",
                            Path(:stroke_linecap => "round", :stroke_linejoin => "round", :stroke_width => "2", :d => "M9 5l7 7-7 7")
                        )
                    else
                        Fragment()
                    end,
                    if is_last
                        Span(:class => "text-neutral-600 dark:text-neutral-400", crumb[2])
                    else
                        A(:href => crumb[1],
                          :class => "text-neutral-500 dark:text-neutral-500 hover:text-emerald-700 dark:hover:text-emerald-400 transition-colors",
                            crumb[2]
                        )
                    end
                )
            end for (i, crumb) in enumerate(crumbs)]...
        )
    )
end
