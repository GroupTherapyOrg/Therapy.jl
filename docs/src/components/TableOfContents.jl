# TableOfContents.jl — Pluto-style floating right-hand TOC
#
# Usage:
#   PageWithTOC(sections, content)
#
# sections: Vector of (id, label) tuples
# content: the page VNode (with H2s that have matching :id attributes)

function TableOfContents(sections::Vector{Tuple{String,String}})
    Nav(:class => "hidden xl:block w-48 shrink-0",
        Div(:class => "sticky top-24 space-y-1",
            P(:class => "text-xs font-semibold text-warm-400 dark:text-warm-500 uppercase tracking-wider mb-2", "On this page"),
            For(sections) do (id, label)
                A(:href => "#$id",
                  :class => "block text-xs text-warm-500 dark:text-warm-400 hover:text-accent-500 dark:hover:text-accent-400 py-0.5 transition-colors",
                  label)
            end
        )
    )
end

function PageWithTOC(sections::Vector{Tuple{String,String}}, content)
    Div(:class => "flex gap-8 items-start",
        Div(:class => "flex-1 min-w-0", content),
        TableOfContents(sections)
    )
end
