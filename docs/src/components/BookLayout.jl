# BookLayout.jl - Layout wrapper for book pages
#
# Uses Suite.jl Sheet for mobile sidebar navigation.
# Desktop sidebar is sticky with collapsible chapter groups.

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
        # Desktop sidebar - hidden on mobile, visible on lg+
        Aside(:class => "hidden lg:block w-64 shrink-0 border-r border-warm-200 dark:border-warm-700 bg-warm-100/50 dark:bg-warm-900/50 overflow-y-auto",
            :style => "position: sticky; top: 0; height: calc(100vh - 4rem);",
            BookSidebar()
        ),

        # Mobile sidebar - Suite.Sheet (visible on small screens)
        Div(:class => "lg:hidden fixed bottom-4 left-4 z-50",
            Suite.Sheet(
                Suite.SheetTrigger(
                    :class => "p-3 bg-accent-600 hover:bg-accent-700 text-white rounded-full shadow-lg transition-colors cursor-pointer",
                    Svg(:class => "w-6 h-6", :fill => "none", :stroke => "currentColor", :viewBox => "0 0 24 24",
                        Path(:stroke_linecap => "round", :stroke_linejoin => "round", :stroke_width => "2",
                             :d => "M4 6h16M4 12h16M4 18h16")
                    )
                ),
                Suite.SheetContent(side="left",
                    Suite.SheetHeader(
                        Suite.SheetTitle("Therapy.jl Book"),
                        Suite.SheetDescription("Chapter navigation"),
                    ),
                    Div(:class => "mt-4 overflow-y-auto",
                        BookSidebar()
                    ),
                ),
            )
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
