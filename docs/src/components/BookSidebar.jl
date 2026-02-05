# BookSidebar.jl - Sidebar navigation for the Therapy.jl book
#
# Provides chapter navigation with section groupings
# Uses NavLink for active state highlighting

"""
Book chapter structure for sidebar navigation.
"""
# Book chapter paths use ./ prefix for base_path compatibility
# This ensures links work on both localhost and GitHub Pages (with /Therapy.jl/ subpath)
# The client-side router's resolveUrl() prepends CONFIG.basePath to ./ paths
const BOOK_CHAPTERS = [
    (section = "Introduction", chapters = [
        (path = "./book/", title = "Welcome"),
        (path = "./book/getting-started/", title = "Getting Started"),
    ]),
    (section = "Reactivity", chapters = [
        (path = "./book/reactivity/", title = "Overview"),
        (path = "./book/reactivity/signals/", title = "Signals"),
        (path = "./book/reactivity/effects/", title = "Effects"),
        (path = "./book/reactivity/memos/", title = "Memos"),
    ]),
    (section = "Components", chapters = [
        (path = "./book/components/", title = "Overview"),
        (path = "./book/components/basics/", title = "Basics"),
        (path = "./book/components/props/", title = "Props"),
        (path = "./book/components/children/", title = "Children"),
        (path = "./book/components/control-flow/", title = "Control Flow"),
    ]),
    (section = "Async", chapters = [
        (path = "./book/async/", title = "Overview"),
        (path = "./book/async/resources/", title = "Resources"),
        (path = "./book/async/suspense/", title = "Suspense"),
        (path = "./book/async/patterns/", title = "Patterns"),
    ]),
    (section = "Server", chapters = [
        (path = "./book/server/", title = "Overview"),
        (path = "./book/server/ssr/", title = "SSR"),
        (path = "./book/server/server-functions/", title = "Server Functions"),
        (path = "./book/server/websocket/", title = "WebSocket"),
    ]),
    (section = "Routing", chapters = [
        (path = "./book/routing/", title = "Overview"),
        (path = "./book/routing/file-routing/", title = "File-Based Routing"),
        (path = "./book/routing/dynamic-routes/", title = "Dynamic Routes"),
        (path = "./book/routing/client-navigation/", title = "Client Navigation"),
        (path = "./book/routing/nested-routes/", title = "Nested Routes"),
    ]),
]

"""
Individual sidebar link with active state highlighting.
Uses NavLink for SPA navigation and active class support.
"""
function SidebarLink(href, label)
    NavLink(href, label;
        class = "block px-3 py-1.5 text-sm text-warm-600 dark:text-warm-400 hover:text-warm-800 dark:hover:text-white hover:bg-warm-50 dark:hover:bg-warm-900 rounded transition-colors",
        active_class = "text-accent-700 dark:text-accent-400 bg-warm-100 dark:bg-warm-900 border-l-2 border-accent-600 -ml-0.5 pl-[calc(0.75rem+2px)]",
        exact = true
    )
end

"""
Section header for chapter groupings.
"""
function SidebarSection(section_name, chapters)
    Div(:class => "mb-6",
        # Section header
        H3(:class => "px-3 py-2 text-xs font-semibold uppercase tracking-wider text-warm-600 dark:text-warm-400",
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
        # Header - use ./ prefix for base_path compatibility
        Div(:class => "px-3 mb-6",
            A(:href => "./book/", :class => "flex items-center group",
                Span(:class => "text-lg font-serif font-bold text-warm-800 dark:text-warm-50 group-hover:text-accent-700 dark:group-hover:text-accent-400 transition-colors",
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
Normalize a chapter path for comparison.
Strips leading "./" if present and ensures trailing slash.
"""
function normalize_chapter_path(path::String)
    p = startswith(path, "./") ? path[3:end] : path
    endswith(p, "/") ? p : p * "/"
end

"""
Find the previous and next chapters for a given path.
Returns: (prev, current, next) where each is (path, title, section) or nothing
"""
function find_chapter_navigation(current_path::String)
    chapters = get_all_chapters()

    # Normalize path - extract /book/... portion and ensure trailing slash
    # current_path could be /book/..., ./book/..., or /Therapy.jl/book/...
    normalized = normalize_chapter_path(current_path)

    # Also extract just the /book/... part if it has a base path prefix
    book_match = match(r"(book/.*)$", normalized)
    if book_match !== nothing
        normalized = book_match.captures[1]
    end

    # Find current chapter index by comparing normalized paths
    idx = findfirst(ch -> normalize_chapter_path(ch[1]) == normalized, chapters)

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
    # Use ./ prefix for base_path compatibility
    breadcrumbs = [("./book/", "Book")]

    # Normalize and extract book portion of path
    normalized = normalize_chapter_path(current_path)
    book_match = match(r"(book/.*)$", normalized)
    if book_match !== nothing
        normalized = book_match.captures[1]
    end

    if normalized == "book/"
        return breadcrumbs
    end

    # Find section and chapter info
    for section in BOOK_CHAPTERS
        for ch in section.chapters
            ch_normalized = normalize_chapter_path(ch.path)
            if ch_normalized == normalized
                # Add section overview if we're in a subsection
                section_slug = lowercase(replace(section.section, " " => "-"))
                section_path = "./book/$(section_slug)/"
                section_path_normalized = normalize_chapter_path(section_path)
                if section_path_normalized != normalized
                    # Check if section overview exists
                    section_overview = findfirst(c -> normalize_chapter_path(c.path) == section_path_normalized, section.chapters)
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

    Div(:class => "py-8 flex justify-between border-t border-warm-200 dark:border-warm-900",
        # Previous link
        if prev !== nothing
            A(:href => prev[1],
              :class => "inline-flex items-center text-warm-600 dark:text-warm-400 hover:text-accent-700 dark:hover:text-accent-400 transition-colors group",
                Svg(:class => "mr-2 w-5 h-5 group-hover:-translate-x-1 transition-transform", :fill => "none", :viewBox => "0 0 24 24", :stroke => "currentColor",
                    Path(:stroke_linecap => "round", :stroke_linejoin => "round", :stroke_width => "2", :d => "M11 17l-5-5m0 0l5-5m-5 5h12")
                ),
                Span(:class => "flex flex-col items-start",
                    Span(:class => "text-xs text-warm-600 dark:text-warm-600", "Previous"),
                    Span(:class => "font-medium", prev[2])
                )
            )
        else
            Div()  # Empty placeholder
        end,

        # Next link
        if next !== nothing
            A(:href => next[1],
              :class => "inline-flex items-center text-warm-600 dark:text-warm-400 hover:text-accent-700 dark:hover:text-accent-400 transition-colors group",
                Span(:class => "flex flex-col items-end",
                    Span(:class => "text-xs text-warm-600 dark:text-warm-600", "Next"),
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
                        Svg(:class => "mx-2 w-4 h-4 text-warm-400", :fill => "none", :viewBox => "0 0 24 24", :stroke => "currentColor",
                            Path(:stroke_linecap => "round", :stroke_linejoin => "round", :stroke_width => "2", :d => "M9 5l7 7-7 7")
                        )
                    else
                        Fragment()
                    end,
                    if is_last
                        Span(:class => "text-warm-600 dark:text-warm-400", crumb[2])
                    else
                        A(:href => crumb[1],
                          :class => "text-warm-600 dark:text-warm-600 hover:text-accent-700 dark:hover:text-accent-400 transition-colors",
                            crumb[2]
                        )
                    end
                )
            end for (i, crumb) in enumerate(crumbs)]...
        )
    )
end
