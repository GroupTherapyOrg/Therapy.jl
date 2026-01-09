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

using Therapy

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
        # Decrement button - compiled to: global.get, i32.const 1, i32.sub, global.set
        Button(:class => "w-12 h-12 rounded-full bg-white text-indigo-600 text-2xl font-bold hover:bg-indigo-100 transition",
               :on_click => () -> set_count(count() - 1),
               "-"),

        # Display - automatically updates when count changes
        # The Wasm calls update_text_i32(hk, value) after each handler
        Span(:class => "text-5xl font-bold tabular-nums",
             count),

        # Increment button - compiled to: global.get, i32.const 1, i32.add, global.set
        Button(:class => "w-12 h-12 rounded-full bg-white text-indigo-600 text-2xl font-bold hover:bg-indigo-100 transition",
               :on_click => () -> set_count(count() + 1),
               "+")
    )
end
