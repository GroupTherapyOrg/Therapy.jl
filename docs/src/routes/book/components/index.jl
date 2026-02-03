# Components - Part 3 of the Therapy.jl Book
#
# Building reusable UI components with props, children, and control flow.

function Index()
    Fragment(
        # Header
        Div(:class => "py-8 border-b border-neutral-300 dark:border-neutral-800",
            Span(:class => "text-sm text-emerald-700 dark:text-emerald-400 font-medium", "Part 3"),
            H1(:class => "text-4xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mt-2 mb-4",
                "Components"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 max-w-3xl",
                "Learn to build reusable components with props, children, and conditional rendering."
            )
        ),

        # Coming Soon Notice
        Section(:class => "py-12",
            Div(:class => "bg-amber-50 dark:bg-amber-950/20 rounded-lg border border-amber-200 dark:border-amber-900 p-8 text-center",
                H2(:class => "text-2xl font-serif font-semibold text-amber-900 dark:text-amber-200 mb-4",
                    "Coming Soon"
                ),
                P(:class => "text-amber-800 dark:text-amber-300",
                    "This section is currently being written. Check back soon for component patterns, props, slots, and control flow!"
                )
            )
        ),

        # Topics Preview
        Section(:class => "py-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "What You'll Learn"
            ),
            Ul(:class => "space-y-3 text-neutral-600 dark:text-neutral-400",
                Li(Strong("Function Components"), " - Components are just functions returning VNodes"),
                Li(Strong("Props"), " - Passing data to components with typed properties"),
                Li(Strong("Children & Slots"), " - Composing components with child content"),
                Li(Strong("Show"), " - Conditional rendering based on signals"),
                Li(Strong("For"), " - Efficiently rendering lists with keyed iteration"),
                Li(Strong("Lifecycle Hooks"), " - on_mount and on_cleanup for side effects")
            )
        ),

        # Navigation
        Div(:class => "py-8 flex justify-between border-t border-neutral-300 dark:border-neutral-800",
            A(:href => "../reactivity/",
              :class => "inline-flex items-center text-neutral-600 dark:text-neutral-400 hover:text-emerald-700 dark:hover:text-emerald-400 transition-colors",
                Svg(:class => "mr-2 w-5 h-5", :fill => "none", :viewBox => "0 0 24 24", :stroke => "currentColor",
                    Path(:stroke_linecap => "round", :stroke_linejoin => "round", :stroke_width => "2", :d => "M11 17l-5-5m0 0l5-5m-5 5h12")
                ),
                "Reactivity"
            ),
            A(:href => "../async/",
              :class => "inline-flex items-center text-neutral-600 dark:text-neutral-400 hover:text-emerald-700 dark:hover:text-emerald-400 transition-colors",
                "Async Patterns",
                Svg(:class => "ml-2 w-5 h-5", :fill => "none", :viewBox => "0 0 24 24", :stroke => "currentColor",
                    Path(:stroke_linecap => "round", :stroke_linejoin => "round", :stroke_width => "2", :d => "M13 7l5 5m0 0l-5 5m5-5H6")
                )
            )
        )
    )
end

Index
