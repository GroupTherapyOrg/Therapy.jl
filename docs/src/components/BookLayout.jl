# BookLayout.jl - Layout wrapper for book pages
#
# This component wraps book page content with sidebar navigation.
# Since App.jl doesn't support _layout.jl, book pages explicitly
# wrap their content with BookLayout.

"""
Wrap book page content with sidebar navigation.

Usage in book pages:
```julia
# Simple usage - no breadcrumbs or automatic prev/next
() -> BookLayout(
    H1("My Page Title"),
    P("Page content here..."),
)

# With path for breadcrumbs and prev/next navigation
() -> BookLayout("/book/reactivity/signals/",
    H1("Signals"),
    P("Signal content..."),
)
```

When a path is provided, BookLayout will:
- Display breadcrumbs at the top (Book > Reactivity > Signals)
- Add automatic Previous/Next navigation at the bottom
"""
function BookLayout(children...)
    BookLayoutWithPath(nothing, children...)
end

function BookLayout(path::String, children...)
    BookLayoutWithPath(path, children...)
end

function BookLayoutWithPath(path::Union{String, Nothing}, children...)
    Div(:class => "flex min-h-[calc(100vh-8rem)]",
        # Sidebar - hidden on mobile, visible on lg+
        Aside(:class => "hidden lg:block w-64 shrink-0 border-r border-neutral-200 dark:border-neutral-800 bg-neutral-50/50 dark:bg-neutral-900/50 overflow-y-auto",
            :style => "position: sticky; top: 0; height: calc(100vh - 4rem);",
            BookSidebar()
        ),

        # Mobile sidebar toggle button (only visible on small screens)
        Div(:class => "lg:hidden fixed bottom-4 left-4 z-50",
            Button(
                :id => "book-sidebar-toggle",
                :class => "p-3 bg-emerald-600 hover:bg-emerald-700 text-white rounded-full shadow-lg transition-colors",
                :on_click => "document.getElementById('book-mobile-sidebar').classList.toggle('translate-x-0'); document.getElementById('book-mobile-sidebar').classList.toggle('-translate-x-full'); document.getElementById('book-sidebar-overlay').classList.toggle('hidden');",
                # Menu icon (hamburger)
                Svg(:class => "w-6 h-6", :fill => "none", :stroke => "currentColor", :viewBox => "0 0 24 24",
                    Path(:stroke_linecap => "round", :stroke_linejoin => "round", :stroke_width => "2",
                         :d => "M4 6h16M4 12h16M4 18h16")
                )
            )
        ),

        # Mobile sidebar overlay
        Div(
            :id => "book-sidebar-overlay",
            :class => "lg:hidden fixed inset-0 z-40 bg-black/50 hidden",
            :on_click => "document.getElementById('book-mobile-sidebar').classList.add('-translate-x-full'); document.getElementById('book-mobile-sidebar').classList.remove('translate-x-0'); this.classList.add('hidden');"
        ),

        # Mobile sidebar drawer
        Aside(
            :id => "book-mobile-sidebar",
            :class => "lg:hidden fixed inset-y-0 left-0 z-50 w-64 bg-neutral-50 dark:bg-neutral-900 border-r border-neutral-200 dark:border-neutral-800 transform -translate-x-full transition-transform duration-200 overflow-y-auto",
            # Close button
            Div(:class => "flex justify-end p-2",
                Button(
                    :class => "p-2 text-neutral-500 hover:text-neutral-700 dark:hover:text-neutral-300",
                    :on_click => "document.getElementById('book-mobile-sidebar').classList.add('-translate-x-full'); document.getElementById('book-mobile-sidebar').classList.remove('translate-x-0'); document.getElementById('book-sidebar-overlay').classList.add('hidden');",
                    Svg(:class => "w-5 h-5", :fill => "none", :stroke => "currentColor", :viewBox => "0 0 24 24",
                        Path(:stroke_linecap => "round", :stroke_linejoin => "round", :stroke_width => "2",
                             :d => "M6 18L18 6M6 6l12 12")
                    )
                )
            ),
            BookSidebar()
        ),

        # Main content area
        Div(:class => "flex-1 min-w-0 px-4 sm:px-6 lg:px-8 py-8 max-w-4xl",
            # Breadcrumbs (if path provided)
            if path !== nothing
                BookBreadcrumbs(path)
            else
                Fragment()
            end,

            # Page content
            children...,

            # Prev/Next navigation (if path provided)
            if path !== nothing
                BookNavigation(path)
            else
                Fragment()
            end
        )
    )
end
