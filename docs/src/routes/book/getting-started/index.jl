# Getting Started - Part 1 of the Therapy.jl Book
#
# Quick start guide for building your first Therapy.jl application.

function BookGettingStarted()
    BookLayout("/book/getting-started/",
        # Header
        Div(:class => "py-8 border-b border-warm-200 dark:border-warm-700",
            Span(:class => "text-sm text-accent-700 dark:text-accent-400 font-medium", "Part 1"),
            H1(:class => "text-4xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-2 mb-4",
                "Getting Started"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 max-w-3xl",
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
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "What You'll Learn"
            ),
            Ul(:class => "space-y-3 text-warm-600 dark:text-warm-400",
                Li("Installing Therapy.jl and its dependencies"),
                Li("Creating a new project with the recommended structure"),
                Li("Building your first reactive counter component"),
                Li("Running the development server with hot reload"),
                Li("Understanding the islands architecture")
            )
        ),

        # Navigation handled by BookLayout via path parameter
    )
end

BookGettingStarted
