function Layout(content)
    Div(:class => "min-h-screen flex flex-col bg-warm-50 dark:bg-warm-950 text-warm-800 dark:text-warm-200 transition-colors",
        # Nav
        Nav(:class => "border-b border-warm-200 dark:border-warm-800 px-6 py-4",
            Div(:class => "max-w-5xl mx-auto flex items-center justify-between",
                NavLink("/", "Therapy.jl";
                    class = "text-xl font-serif font-bold text-warm-900 dark:text-warm-100 hover:text-accent-600 dark:hover:text-accent-400 transition-colors no-underline",
                    active_class = ""
                ),
                Div(:class => "flex items-center gap-6",
                    NavLink("/getting-started/", "Getting Started";
                        class = "text-sm text-warm-600 dark:text-warm-400 hover:text-accent-600 dark:hover:text-accent-400 transition-colors no-underline",
                        active_class = "text-accent-600 dark:text-accent-400 font-medium"
                    ),
                    NavLink("/api/", "API";
                        class = "text-sm text-warm-600 dark:text-warm-400 hover:text-accent-600 dark:hover:text-accent-400 transition-colors no-underline",
                        active_class = "text-accent-600 dark:text-accent-400 font-medium"
                    ),
                    NavLink("/examples/", "Examples";
                        class = "text-sm text-warm-600 dark:text-warm-400 hover:text-accent-600 dark:hover:text-accent-400 transition-colors no-underline",
                        active_class = "text-accent-600 dark:text-accent-400 font-medium"
                    ),
                    A(:href => "https://github.com/GroupTherapyOrg/Therapy.jl", :target => "_blank",
                        :class => "text-warm-500 dark:text-warm-400 hover:text-warm-700 dark:hover:text-warm-300 transition-colors",
                        RawHtml("""<svg class="w-5 h-5" viewBox="0 0 24 24" fill="currentColor"><path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/></svg>""")
                    ),
                    # Dark mode toggle - persistent via localStorage
                    Button(:class => "text-warm-500 dark:text-warm-400 hover:text-warm-700 dark:hover:text-warm-300 transition-colors",
                        :onclick => "document.documentElement.classList.toggle('dark'); var k = (document.documentElement.getAttribute('data-base-path') || '') ? 'therapy-theme:' + document.documentElement.getAttribute('data-base-path') : 'therapy-theme'; localStorage.setItem(k, document.documentElement.classList.contains('dark') ? 'dark' : 'light')",
                        RawHtml("""<svg class="w-5 h-5 dark:hidden" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 12.79A9 9 0 1111.21 3 7 7 0 0021 12.79z"/></svg><svg class="w-5 h-5 hidden dark:block" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="5"/><line x1="12" y1="1" x2="12" y2="3"/><line x1="12" y1="21" x2="12" y2="23"/><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/><line x1="1" y1="12" x2="3" y2="12"/><line x1="21" y1="12" x2="23" y2="12"/><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/></svg>""")
                    )
                )
            )
        ),
        # Main content — id="page-content" enables SPA navigation (router swaps this)
        MainEl(:id => "page-content", :class => "flex-1 w-full max-w-5xl mx-auto px-6 py-12",
            content
        ),
        # Footer
        Footer(:class => "border-t border-warm-200 dark:border-warm-800 px-6 py-6",
            Div(:class => "max-w-5xl mx-auto flex flex-col items-center gap-2",
                P(:class => "text-sm text-warm-500 dark:text-warm-400",
                    "Built with ",
                    A(:href => "/", :class => "text-accent-600 dark:text-accent-400 hover:underline", "Therapy.jl"),
                    " — Signals-Based Web Apps in Pure Julia"
                ),
                Div(:class => "flex gap-4 text-xs text-warm-400 dark:text-warm-500",
                    A(:href => "https://github.com/GroupTherapyOrg/Therapy.jl", :class => "hover:text-warm-600 dark:hover:text-warm-300 transition-colors", "GitHub"),
                    A(:href => "https://github.com/GroupTherapyOrg/JavaScriptTarget.jl", :class => "hover:text-warm-600 dark:hover:text-warm-300 transition-colors", "JavaScriptTarget.jl")
                )
            )
        )
    )
end
