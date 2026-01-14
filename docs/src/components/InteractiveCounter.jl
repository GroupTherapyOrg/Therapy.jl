# InteractiveCounter.jl - An interactive island compiled to WebAssembly
#
# This is a Therapy.jl island - an interactive component that gets compiled to Wasm.
# The Julia code here IS the source of truth - no hand-written JS/Wasm.
#
# How it works:
#   1. island(:Name) marks this as interactive (will be compiled to Wasm)
#   2. create_signal(0) creates reactive state (becomes Wasm global)
#   3. :on_click handlers are compiled to Wasm functions
#   4. The component auto-registers and auto-discovers in App

"""
Interactive counter island - compiled to WebAssembly.

This demonstrates Therapy.jl's Leptos-style islands architecture:
- `island()` marks this component as interactive (opt-in)
- State lives in signals (compiled to Wasm globals)
- Event handlers are Julia closures (compiled to Wasm functions)
- DOM updates happen automatically when signals change
- Static by default, interactive only where you need it
"""
InteractiveCounter = island(:InteractiveCounter) do
    # Create reactive state - this becomes a Wasm global
    # Use Int32 for Wasm compatibility
    count, set_count = create_signal(Int32(0))

    # Return the component tree
    # The :on_click closures are compiled to Wasm handler functions
    Div(:class => "flex justify-center items-center gap-6",
        # Decrement button
        Button(:class => "w-12 h-12 rounded bg-white dark:bg-neutral-800 text-emerald-700 dark:text-emerald-400 text-2xl font-bold hover:bg-neutral-100 dark:hover:bg-neutral-700 transition border border-neutral-300 dark:border-neutral-700",
               :on_click => () -> set_count(count() - Int32(1)),
               "-"),

        # Display - automatically updates when count changes
        Span(:class => "text-5xl font-serif font-semibold tabular-nums text-neutral-900 dark:text-neutral-100",
             count),

        # Increment button
        Button(:class => "w-12 h-12 rounded bg-white dark:bg-neutral-800 text-emerald-700 dark:text-emerald-400 text-2xl font-bold hover:bg-neutral-100 dark:hover:bg-neutral-700 transition border border-neutral-300 dark:border-neutral-700",
               :on_click => () -> set_count(count() + Int32(1)),
               "+")
    )
end
