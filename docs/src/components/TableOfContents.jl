# TableOfContents.jl — Pluto-style floating right-hand TOC
#
# Fixed position on the right side, doesn't affect content layout.
# Links use # anchors with scroll behavior.

function TableOfContents(sections::Vector{Tuple{String,String}})
    Nav(:class => "hidden xl:block fixed right-8 top-24 w-44",
        Div(:class => "space-y-1.5 border-l border-warm-200 dark:border-warm-800 pl-3",
            P(:class => "text-[11px] font-semibold text-warm-400 dark:text-warm-500 uppercase tracking-wider mb-3", "On this page"),
            For(sections) do (id, label)
                A(:href => "#$id",
                  :class => "block text-[12px] leading-relaxed text-warm-500 dark:text-warm-400 hover:text-accent-500 dark:hover:text-accent-400 transition-colors",
                  label)
            end
        )
    )
end

function PageWithTOC(sections::Vector{Tuple{String,String}}, content)
    # Content stays full width. TOC floats fixed on the right, outside the flow.
    Fragment(
        content,
        TableOfContents(sections)
    )
end
