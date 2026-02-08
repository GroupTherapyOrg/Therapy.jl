# Sidebar.jl - Left navigation sidebar for tutorials and documentation
#
# Uses Suite.jl Collapsible for section groups.
# Uses NavLink for active state highlighting (SPA navigation).

import Suite

"""
Sidebar navigation component with sections and links.
Uses Suite.Collapsible for expandable sections.
"""
function Sidebar(sections::Vector; current_path::String="")
    Nav(:class => "w-64 shrink-0 hidden lg:block",
        Div(:class => "sticky top-20 overflow-y-auto max-h-[calc(100vh-5rem)] pb-8 py-6 px-2",
            [SidebarSection(section, current_path) for section in sections]...
        )
    )
end

"""
A collapsible section in the sidebar.
Uses Suite.Collapsible for expand/collapse behavior.
"""
function SidebarSection(section::NamedTuple, current_path::String)
    title = section.title
    items = section.items

    Suite.Collapsible(open=true,
        Suite.CollapsibleTrigger(
            :class => "w-full flex items-center justify-between px-3 py-2 group cursor-pointer",
            H3(:class => "text-xs font-semibold uppercase tracking-wider text-warm-600 dark:text-warm-400",
                title
            ),
            # Chevron indicator
            Svg(:class => "w-3.5 h-3.5 text-warm-400 transition-transform group-hover:text-warm-600 dark:group-hover:text-warm-300",
                :fill => "none", :viewBox => "0 0 24 24", :stroke => "currentColor", :stroke_width => "2",
                Path(:stroke_linecap => "round", :stroke_linejoin => "round", :d => "M19 9l-7 7-7-7")
            ),
        ),
        Suite.CollapsibleContent(
            Ul(:class => "space-y-0.5",
                [SidebarItem(item, current_path) for item in items]...
            )
        ),
    )
end

"""
A single item in the sidebar.
Uses NavLink for SPA navigation and active class support.
"""
function SidebarItem(item::NamedTuple, current_path::String)
    href = item.href
    label = item.label

    Li(
        NavLink(href, label;
            class = "block px-3 py-2 text-sm text-warm-600 dark:text-warm-400 hover:bg-warm-200/50 dark:hover:bg-warm-900/50 rounded transition-colors",
            active_class = "font-medium bg-warm-100 dark:bg-warm-900 text-accent-700 dark:text-accent-400 border-l-2 border-accent-600 dark:border-accent-500",
            exact = true
        )
    )
end

# Base tutorial sections (always shown)
const TUTORIAL_SECTION = (
    title = "Tutorial",
    items = [
        (href = "./learn/", label = "Overview"),
        (href = "./learn/tutorial-tic-tac-toe/", label = "Tutorial: Tic-Tac-Toe"),
        (href = "./learn/thinking-in-therapy/", label = "Thinking in Therapy.jl"),
    ]
)

# TicTacToe-specific section (only shown on that tutorial)
const TICTACTOE_SECTION = (
    title = "Building the Game",
    items = [
        (href = "./learn/tutorial-tic-tac-toe/#setup", label = "1. Setup"),
        (href = "./learn/tutorial-tic-tac-toe/#board", label = "2. Building the Board"),
        (href = "./learn/tutorial-tic-tac-toe/#state", label = "3. Adding State"),
        (href = "./learn/tutorial-tic-tac-toe/#turns", label = "4. Taking Turns"),
        (href = "./learn/tutorial-tic-tac-toe/#winner", label = "5. Declaring a Winner"),
        (href = "./learn/tutorial-tic-tac-toe/#complete", label = "6. Complete Game"),
    ]
)

const CORE_CONCEPTS_SECTION = (
    title = "Core Concepts",
    items = [
        (href = "./learn/describing-ui/", label = "Describing the UI"),
        (href = "./learn/adding-interactivity/", label = "Adding Interactivity"),
        (href = "./learn/managing-state/", label = "Managing State"),
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
Layout is applied at app level - this just provides sidebar structure.
"""
function TutorialLayout(children...; current_path::String="learn/")
    # Content only - Layout applied at app level for true SPA navigation
    Div(:class => "flex gap-8",
        # Sidebar - dynamically built based on current path
        Sidebar(get_tutorial_sidebar(current_path); current_path=current_path),

        # Main content
        Div(:class => "flex-1 min-w-0 max-w-3xl",
            children...
        )
    )
end
