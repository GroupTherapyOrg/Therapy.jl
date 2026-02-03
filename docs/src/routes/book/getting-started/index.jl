# Getting Started - Part 1 of the Therapy.jl Book
#
# Quick start guide for building your first Therapy.jl application.

function Index()
    Fragment(
        # Header
        Div(:class => "py-8 border-b border-neutral-300 dark:border-neutral-800",
            Span(:class => "text-sm text-emerald-700 dark:text-emerald-400 font-medium", "Part 1"),
            H1(:class => "text-4xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mt-2 mb-4",
                "Getting Started"
            ),
            P(:class => "text-lg text-neutral-600 dark:text-neutral-300 max-w-3xl",
                "Set up your development environment and build your first interactive Therapy.jl application."
            )
        ),

        # Coming Soon Notice
        Section(:class => "py-12",
            Div(:class => "bg-amber-50 dark:bg-amber-950/20 rounded-lg border border-amber-200 dark:border-amber-900 p-8 text-center",
                H2(:class => "text-2xl font-serif font-semibold text-amber-900 dark:text-amber-200 mb-4",
                    "Coming Soon"
                ),
                P(:class => "text-amber-800 dark:text-amber-300",
                    "This section is currently being written. Check back soon for installation instructions, project setup, and your first Therapy.jl app!"
                )
            )
        ),

        # Topics Preview
        Section(:class => "py-8",
            H2(:class => "text-2xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-6",
                "What You'll Learn"
            ),
            Ul(:class => "space-y-3 text-neutral-600 dark:text-neutral-400",
                Li("Installing Therapy.jl and its dependencies"),
                Li("Creating a new project with the recommended structure"),
                Li("Building your first reactive counter component"),
                Li("Running the development server with hot reload"),
                Li("Understanding the islands architecture")
            )
        ),

        # Navigation
        Div(:class => "py-8 flex justify-between border-t border-neutral-300 dark:border-neutral-800",
            A(:href => "../",
              :class => "inline-flex items-center text-neutral-600 dark:text-neutral-400 hover:text-emerald-700 dark:hover:text-emerald-400 transition-colors",
                Svg(:class => "mr-2 w-5 h-5", :fill => "none", :viewBox => "0 0 24 24", :stroke => "currentColor",
                    Path(:stroke_linecap => "round", :stroke_linejoin => "round", :stroke_width => "2", :d => "M11 17l-5-5m0 0l5-5m-5 5h12")
                ),
                "Introduction"
            ),
            A(:href => "../reactivity/",
              :class => "inline-flex items-center text-neutral-600 dark:text-neutral-400 hover:text-emerald-700 dark:hover:text-emerald-400 transition-colors",
                "Reactivity",
                Svg(:class => "ml-2 w-5 h-5", :fill => "none", :viewBox => "0 0 24 24", :stroke => "currentColor",
                    Path(:stroke_linecap => "round", :stroke_linejoin => "round", :stroke_width => "2", :d => "M13 7l5 5m0 0l-5 5m5-5H6")
                )
            )
        )
    )
end

Index
