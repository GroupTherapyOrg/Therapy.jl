# Layout.jl - Therapy.jl documentation layout
#
# Uses Suite.jl SiteNav for shared navbar pattern, SiteFooter, Separator,
# Toaster. Uses Therapy.jl accent colors (Green primary, Blue secondary).

import Suite

# --- Logo ---

function TherapyLogo()
    A(:href => "./", :class => "flex items-center",
        Span(:class => "text-2xl font-bold text-warm-800 dark:text-warm-300", "Therapy"),
        Span(:class => "text-2xl font-light",
            Span(:style => "color: var(--jl-dot)", "."),
            Span(:style => "color: var(--jl-j)", "j"),
            Span(:style => "color: var(--jl-l)", "l")
        )
    )
end

# --- Navigation links ---

const _THERAPY_NAV_LINKS = [
    (href="./", label="Home", exact=true),
    (href="./getting-started/", label="Getting Started"),
    (href="./learn/", label="Learn"),
    (href="./book/", label="Book"),
    (href="./api/", label="API"),
    (href="./examples/", label="Examples"),
]

const _THERAPY_MOBILE_SECTIONS = [
    (title="Getting Started", links=[
        (href="./getting-started/", label="Quick Start"),
        (href="./learn/", label="Learn"),
    ]),
    (title="Book", links=[
        (href="./book/", label="Introduction"),
        (href="./book/reactivity/", label="Reactivity"),
        (href="./book/components/", label="Components"),
        (href="./book/async/", label="Async"),
        (href="./book/server/", label="Server"),
        (href="./book/routing/", label="Routing"),
    ]),
    (title="Reference", links=[
        (href="./api/", label="API"),
        (href="./examples/", label="Examples"),
    ]),
]

const _THERAPY_GITHUB = "https://github.com/GroupTherapyOrg/Therapy.jl"

# --- Main Layout ---

"""
Main documentation layout with Suite.jl SiteNav, footer, and theme support.
"""
function Layout(children...; title="Therapy.jl")
    Div(:class => "min-h-screen flex flex-col bg-warm-50 dark:bg-warm-950 transition-colors duration-200",
        # Navigation bar (Suite.SiteNav handles desktop + mobile + theme controls)
        Suite.SiteNav(
            TherapyLogo(),
            _THERAPY_NAV_LINKS,
            _THERAPY_GITHUB;
            mobile_title="Therapy.jl",
            mobile_sections=_THERAPY_MOBILE_SECTIONS
        ),

        # Main Content — SPA navigation swaps this area
        MainEl(:id => "page-content", :class => "flex-1 w-full max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8",
            children...
        ),

        # Footer separator
        Suite.Separator(),

        # Footer
        Suite.SiteFooter(
            Suite.FooterBrand(
                Span(:class => "text-sm font-medium text-warm-800 dark:text-warm-300", "GroupTherapyOrg"),
            ),
            Suite.FooterLinks(
                Suite.FooterLink("Therapy.jl", href="https://github.com/GroupTherapyOrg/Therapy.jl"),
                Suite.FooterLink("Suite.jl", href="https://github.com/GroupTherapyOrg/Suite.jl"),
                Suite.FooterLink("WasmTarget.jl", href="https://github.com/GroupTherapyOrg/WasmTarget.jl"),
            ),
            Suite.FooterTagline("Built with Therapy.jl — A reactive web framework for Julia"),
        ),

        # Toast notification container
        Suite.Toaster(),

        # Suite.jl JS Runtime (theme toggle + all interactive components)
        Suite.suite_script()
    )
end
