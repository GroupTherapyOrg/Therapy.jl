# ThemeToggle.jl - A Therapy.jl component for dark/light mode switching
#
# This is a real Therapy.jl reactive component that gets compiled to Wasm.
# The Julia code here IS the source of truth - no hand-written JS/Wasm.
#
# How it works:
#   1. create_signal(0) creates reactive state (0=light, 1=dark)
#   2. :dark_mode prop binds the signal to document theme
#   3. :on_click handler toggles the signal
#   4. compile_component() generates Wasm that calls set_dark_mode()

"""
Theme toggle component - compiled to WebAssembly.

This demonstrates Therapy.jl's theme binding feature:
- Signal value controls dark mode (0=light, 1=dark)
- :dark_mode prop binds signal to document.documentElement.classList
- TOGGLE operation flips between light and dark
- Theme persists via localStorage
"""
function ThemeToggle()
    # Create reactive state - 0 for light mode, 1 for dark mode
    # This becomes a Wasm global that controls the theme
    dark, set_dark = create_signal(0)

    # The :dark_mode prop tells the compiler to call set_dark_mode(value) when signal changes
    # The button toggles between 0 and 1
    Div(:dark_mode => dark,
        Button(
            :class => "p-2 rounded-lg hover:bg-stone-100 dark:hover:bg-stone-700 transition-colors",
            :on_click => () -> set_dark(dark() == 0 ? 1 : 0),
            :title => "Toggle dark mode",
            # Sun icon (shown in dark mode) / Moon icon (shown in light mode)
            Svg(:class => "w-5 h-5 text-stone-600 dark:text-stone-300",
                :fill => "none",
                :viewBox => "0 0 24 24",
                :stroke => "currentColor",
                :stroke_width => "2",
                # Combined sun/moon path that works for both themes
                Path(:stroke_linecap => "round",
                     :stroke_linejoin => "round",
                     :d => "M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z")
            )
        )
    )
end
