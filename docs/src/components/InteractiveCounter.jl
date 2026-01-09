# InteractiveCounter.jl - A Therapy.jl component compiled to WebAssembly
#
# This is a real Therapy.jl reactive component that gets compiled to Wasm.
# The Julia code here IS the source of truth - no hand-written JS/Wasm.
#
# How it works:
#   1. create_signal(0) creates reactive state
#   2. :on_click handlers reference the signal
#   3. compile_component() analyzes this and generates Wasm bytecode
#   4. The Wasm handles all increment/decrement/DOM-update logic

"""
Interactive counter component - compiled to WebAssembly.

This demonstrates Therapy.jl's Leptos-style reactivity:
- State lives in signals (compiled to Wasm globals)
- Event handlers are Julia closures (compiled to Wasm functions)
- DOM updates happen automatically when signals change
"""
function InteractiveCounter()
    # Create reactive state - this becomes a Wasm global
    count, set_count = create_signal(0)

    # Return the component tree
    # The :on_click closures are compiled to Wasm handler functions
    Div(:class => "flex justify-center items-center gap-6",
        # Decrement button
        Button(:class => "w-12 h-12 rounded-full bg-white dark:bg-stone-700 text-orange-500 dark:text-yellow-500 text-2xl font-bold hover:bg-orange-100 dark:hover:bg-stone-600 transition shadow-sm",
               :on_click => () -> set_count(count() - 1),
               "-"),

        # Display - automatically updates when count changes
        Span(:class => "text-5xl font-bold tabular-nums text-stone-800 dark:text-stone-100",
             count),

        # Increment button
        Button(:class => "w-12 h-12 rounded-full bg-white dark:bg-stone-700 text-orange-500 dark:text-yellow-500 text-2xl font-bold hover:bg-orange-100 dark:hover:bg-stone-600 transition shadow-sm",
               :on_click => () -> set_count(count() + 1),
               "+")
    )
end
