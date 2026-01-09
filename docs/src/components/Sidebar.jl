# Sidebar.jl - Left navigation sidebar for tutorials and documentation
#
# Inspired by React docs sidebar with collapsible sections

"""
Sidebar navigation component with sections and links.
"""
function Sidebar(sections::Vector; current_path::String="")
    Nav(:class => "w-64 shrink-0 hidden lg:block",
        Div(:class => "sticky top-20 overflow-y-auto max-h-[calc(100vh-5rem)] pb-8",
            [SidebarSection(section, current_path) for section in sections]...
        )
    )
end

"""
A collapsible section in the sidebar.
"""
function SidebarSection(section::NamedTuple, current_path::String)
    title = section.title
    items = section.items

    Div(:class => "mb-6",
        # Section title
        H3(:class => "text-xs font-semibold text-stone-500 dark:text-stone-400 uppercase tracking-wider mb-2 px-3",
            title
        ),
        # Section items
        Ul(:class => "space-y-1",
            [SidebarItem(item, current_path) for item in items]...
        )
    )
end

"""
A single item in the sidebar.
"""
function SidebarItem(item::NamedTuple, current_path::String)
    href = item.href
    label = item.label
    is_active = current_path == href || startswith(current_path, rstrip(href, '/') * "/")

    Li(
        A(:href => href,
          :class => is_active ?
              "block px-3 py-2 text-sm font-medium rounded-lg bg-orange-100 dark:bg-yellow-950/40 text-orange-600 dark:text-yellow-500" :
              "block px-3 py-2 text-sm text-stone-600 dark:text-stone-400 hover:bg-stone-100 dark:hover:bg-stone-800 rounded-lg transition-colors",
          label
        )
    )
end

# Tutorial sidebar configuration
const TUTORIAL_SIDEBAR = [
    (
        title = "Tutorial",
        items = [
            (href = "/learn/", label = "Overview"),
            (href = "/learn/tutorial-tic-tac-toe/", label = "Tutorial: Tic-Tac-Toe"),
            (href = "/learn/thinking-in-therapy/", label = "Thinking in Therapy.jl"),
        ]
    ),
    (
        title = "Building the Game",
        items = [
            (href = "/learn/tutorial-tic-tac-toe/#setup", label = "1. Setup"),
            (href = "/learn/tutorial-tic-tac-toe/#board", label = "2. Building the Board"),
            (href = "/learn/tutorial-tic-tac-toe/#state", label = "3. Adding State"),
            (href = "/learn/tutorial-tic-tac-toe/#turns", label = "4. Taking Turns"),
            (href = "/learn/tutorial-tic-tac-toe/#winner", label = "5. Declaring a Winner"),
            (href = "/learn/tutorial-tic-tac-toe/#complete", label = "6. Complete Game"),
        ]
    ),
    (
        title = "Core Concepts",
        items = [
            (href = "/learn/describing-ui/", label = "Describing the UI"),
            (href = "/learn/adding-interactivity/", label = "Adding Interactivity"),
            (href = "/learn/managing-state/", label = "Managing State"),
        ]
    ),
]

"""
Tutorial layout with sidebar navigation.
"""
function TutorialLayout(children...; current_path::String="/learn/")
    Layout(
        Div(:class => "flex gap-8",
            # Sidebar
            Sidebar(TUTORIAL_SIDEBAR; current_path=current_path),

            # Main content
            Div(:class => "flex-1 min-w-0 max-w-3xl",
                children...
            )
        )
    )
end
