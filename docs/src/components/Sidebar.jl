# Sidebar.jl - Left navigation sidebar for tutorials and documentation
#
# Parchment theme with sage/amber accents

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

    Div(:class => "mb-8",
        # Section title
        H3(:class => "text-xs font-semibold text-neutral-500 dark:text-neutral-400 uppercase tracking-widest mb-3 px-3 font-sans",
            title
        ),
        # Section items
        Ul(:class => "space-y-0.5",
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

    # Only exact match for highlighting - prevents "Overview" from being
    # highlighted on all subpages
    is_active = current_path == href

    Li(
        A(:href => href,
          :class => is_active ?
              "block px-3 py-2 text-sm font-medium rounded bg-emerald-50 dark:bg-emerald-950/40 text-emerald-700 dark:text-emerald-400 border-l-2 border-emerald-600 dark:border-emerald-500" :
              "block px-3 py-2 text-sm text-neutral-600 dark:text-neutral-400 hover:bg-neutral-200/50 dark:hover:bg-neutral-800/50 rounded border-l-2 border-transparent transition-colors",
          label
        )
    )
end

# Base tutorial sections (always shown)
const TUTORIAL_SECTION = (
    title = "Tutorial",
    items = [
        (href = "learn/", label = "Overview"),
        (href = "learn/tutorial-tic-tac-toe/", label = "Tutorial: Tic-Tac-Toe"),
        (href = "learn/thinking-in-therapy/", label = "Thinking in Therapy.jl"),
    ]
)

# TicTacToe-specific section (only shown on that tutorial)
const TICTACTOE_SECTION = (
    title = "Building the Game",
    items = [
        (href = "learn/tutorial-tic-tac-toe/#setup", label = "1. Setup"),
        (href = "learn/tutorial-tic-tac-toe/#board", label = "2. Building the Board"),
        (href = "learn/tutorial-tic-tac-toe/#state", label = "3. Adding State"),
        (href = "learn/tutorial-tic-tac-toe/#turns", label = "4. Taking Turns"),
        (href = "learn/tutorial-tic-tac-toe/#winner", label = "5. Declaring a Winner"),
        (href = "learn/tutorial-tic-tac-toe/#complete", label = "6. Complete Game"),
    ]
)

const CORE_CONCEPTS_SECTION = (
    title = "Core Concepts",
    items = [
        (href = "learn/describing-ui/", label = "Describing the UI"),
        (href = "learn/adding-interactivity/", label = "Adding Interactivity"),
        (href = "learn/managing-state/", label = "Managing State"),
    ]
)

"""
Build sidebar sections based on current path.
Context-specific sections only appear on relevant pages.
"""
function get_tutorial_sidebar(current_path::String)
    sections = [TUTORIAL_SECTION]

    # Only show "Building the Game" section on the TicTacToe tutorial
    if startswith(current_path, "learn/tutorial-tic-tac-toe")
        push!(sections, TICTACTOE_SECTION)
    end

    push!(sections, CORE_CONCEPTS_SECTION)
    return sections
end

"""
Tutorial layout with sidebar navigation.
"""
function TutorialLayout(children...; current_path::String="learn/")
    Layout(
        Div(:class => "flex gap-8",
            # Sidebar - dynamically built based on current path
            Sidebar(get_tutorial_sidebar(current_path); current_path=current_path),

            # Main content
            Div(:class => "flex-1 min-w-0 max-w-3xl",
                children...
            )
        )
    )
end
