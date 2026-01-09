# Counter Example with WebAssembly
# This demonstrates REAL Julia code compiled to Wasm via WasmTarget.jl
#
# The counter logic is written in pure Julia and compiled to WebAssembly.
# JavaScript just handles DOM updates and calls the compiled Julia functions.

using Therapy
using WasmTarget

# =============================================================================
# JULIA COUNTER LOGIC - This gets compiled to WebAssembly!
# =============================================================================

# Pure Julia functions for counter operations
# These will be compiled to Wasm using WasmTarget.jl

@noinline function increment(count::Int32)::Int32
    return count + Int32(1)
end

@noinline function decrement(count::Int32)::Int32
    return count - Int32(1)
end

@noinline function double_count(count::Int32)::Int32
    return count * Int32(2)
end

@noinline function reset_count()::Int32
    return Int32(0)
end

@noinline function is_positive(count::Int32)::Int32
    # Returns 1 if positive, 0 otherwise (Wasm uses i32 for bools)
    return count > Int32(0) ? Int32(1) : Int32(0)
end

# =============================================================================
# COMPILE JULIA TO WEBASSEMBLY
# =============================================================================

println("Compiling Julia functions to WebAssembly...")
println("  - increment(count::Int32)::Int32")
println("  - decrement(count::Int32)::Int32")
println("  - double_count(count::Int32)::Int32")
println("  - reset_count()::Int32")
println("  - is_positive(count::Int32)::Int32")

wasm_bytes = compile_multi([
    (increment, (Int32,)),
    (decrement, (Int32,)),
    (double_count, (Int32,)),
    (reset_count, ()),
    (is_positive, (Int32,)),
])

println("Compiled $(length(wasm_bytes)) bytes of WebAssembly")

# =============================================================================
# THERAPY.JL COMPONENT FOR SSR
# =============================================================================

Counter = component(:Counter) do props
    initial = get_prop(props, :initial, 0)

    Div(:id => "app", :class => "counter",
        H1("Therapy.jl Counter"),
        P(:class => "subtitle", "Pure Julia compiled to WebAssembly"),
        P(:class => "count-display",
            "Count: ",
            Span(:id => "count-value", initial)
        ),
        Div(:class => "buttons",
            Button(:id => "btn-decrement", "-"),
            Button(:id => "btn-increment", "+"),
            Button(:id => "btn-double", "×2"),
            Button(:id => "btn-reset", "Reset")
        ),
        P(:id => "status", :class => "status", ""),
        Div(:class => "code-info",
            H3("Julia Source Code:"),
            Pre(:class => "code", """
function increment(count::Int32)::Int32
    return count + Int32(1)
end

function decrement(count::Int32)::Int32
    return count - Int32(1)
end

function double_count(count::Int32)::Int32
    return count * Int32(2)
end""")
        ),
        P(:class => "info", "This counter runs Julia code compiled to WebAssembly!")
    )
end

# =============================================================================
# STYLES
# =============================================================================

const STYLES = """
<style>
    body {
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        max-width: 700px;
        margin: 50px auto;
        padding: 20px;
        text-align: center;
        background: #1a1a2e;
        color: #eee;
    }
    .counter {
        background: #16213e;
        border-radius: 12px;
        padding: 30px;
        box-shadow: 0 4px 20px rgba(0,0,0,0.3);
    }
    h1 {
        color: #e94560;
        margin-bottom: 5px;
    }
    .subtitle {
        color: #888;
        margin-top: 0;
    }
    .count-display {
        font-size: 24px;
        margin: 30px 0;
    }
    #count-value {
        font-weight: bold;
        color: #0f3460;
        background: #e94560;
        padding: 10px 30px;
        border-radius: 8px;
        font-size: 48px;
    }
    .buttons {
        display: flex;
        justify-content: center;
        gap: 10px;
        margin: 20px 0;
    }
    button {
        font-size: 18px;
        padding: 12px 24px;
        border: none;
        border-radius: 8px;
        cursor: pointer;
        transition: all 0.2s;
        font-weight: bold;
    }
    button:hover {
        transform: scale(1.05);
    }
    #btn-decrement { background: #ff6b6b; color: white; }
    #btn-increment { background: #51cf66; color: white; }
    #btn-double { background: #ffd43b; color: #333; }
    #btn-reset { background: #748ffc; color: white; }
    .status {
        color: #51cf66;
        font-family: monospace;
        min-height: 24px;
    }
    .code-info {
        text-align: left;
        margin-top: 30px;
        background: #0f3460;
        padding: 20px;
        border-radius: 8px;
    }
    .code-info h3 {
        color: #e94560;
        margin-top: 0;
    }
    .code {
        background: #1a1a2e;
        padding: 15px;
        border-radius: 6px;
        overflow-x: auto;
        font-size: 14px;
        color: #51cf66;
    }
    .info {
        color: #888;
        font-size: 14px;
        margin-top: 20px;
    }
</style>
"""

# =============================================================================
# JAVASCRIPT - Minimal glue to connect Wasm to DOM
# =============================================================================

const CUSTOM_JS = """
<script>
(async function() {
    console.log('%c━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', 'color: #e94560');
    console.log('%c  Therapy.jl - Julia → WebAssembly Counter', 'color: #e94560; font-weight: bold; font-size: 16px');
    console.log('%c━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', 'color: #e94560');

    // Load the WebAssembly module (compiled from Julia!)
    console.log('%c[Loading] Fetching WebAssembly module...', 'color: #748ffc');
    const response = await fetch('/counter.wasm');
    const bytes = await response.arrayBuffer();
    console.log('%c[Loading] Module size: ' + bytes.byteLength + ' bytes', 'color: #748ffc');

    const { instance } = await WebAssembly.instantiate(bytes);
    console.log('%c[Loaded] ✓ Julia functions compiled to Wasm!', 'color: #51cf66; font-weight: bold');
    console.log('%c[Exports]', 'color: #ffd43b', Object.keys(instance.exports));

    // Get the Julia functions from Wasm
    const {
        increment,      // Julia: increment(count::Int32)::Int32
        decrement,      // Julia: decrement(count::Int32)::Int32
        double_count,   // Julia: double_count(count::Int32)::Int32
        reset_count,    // Julia: reset_count()::Int32
        is_positive     // Julia: is_positive(count::Int32)::Int32
    } = instance.exports;

    // State (managed in JS, operated on by Wasm)
    let count = 0;

    // DOM elements
    const display = document.getElementById('count-value');
    const status = document.getElementById('status');

    function updateDisplay() {
        display.textContent = count;
        const positive = is_positive(count);
        status.textContent = positive ? '✓ Positive' : (count === 0 ? '○ Zero' : '✗ Negative');
    }

    // Connect buttons to Wasm functions
    document.getElementById('btn-increment').onclick = () => {
        const before = count;
        count = increment(count);  // Call Julia function!
        console.log('%c[WASM] increment(' + before + ') → ' + count, 'color: #51cf66');
        updateDisplay();
    };

    document.getElementById('btn-decrement').onclick = () => {
        const before = count;
        count = decrement(count);  // Call Julia function!
        console.log('%c[WASM] decrement(' + before + ') → ' + count, 'color: #ff6b6b');
        updateDisplay();
    };

    document.getElementById('btn-double').onclick = () => {
        const before = count;
        count = double_count(count);  // Call Julia function!
        console.log('%c[WASM] double_count(' + before + ') → ' + count, 'color: #ffd43b');
        updateDisplay();
    };

    document.getElementById('btn-reset').onclick = () => {
        const before = count;
        count = reset_count();  // Call Julia function!
        console.log('%c[WASM] reset_count() → ' + count, 'color: #748ffc');
        updateDisplay();
    };

    updateDisplay();
    console.log('%c[Ready] 🚀 Click buttons to call Julia functions!', 'color: #51cf66; font-weight: bold');
    console.log('%c━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', 'color: #e94560');
})();
</script>
"""

# =============================================================================
# SERVER
# =============================================================================

# Create temp directory and write Wasm file
const SERVE_DIR = mktempdir()
const WASM_PATH = joinpath(SERVE_DIR, "counter.wasm")
write(WASM_PATH, wasm_bytes)
println("Wrote Wasm to: $WASM_PATH")

println("\nStarting server...")
println("Open http://127.0.0.1:8080 in your browser")
println("Open DevTools Console to see Julia→Wasm calls!\n")

serve(8080, static_dir=SERVE_DIR) do path
    if path == "/" || path == "/index.html"
        body_html = render_to_string(Counter(:initial => 0))
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Therapy.jl Counter - Julia to Wasm</title>
            $(STYLES)
        </head>
        <body>
            $(body_html)
            $(CUSTOM_JS)
        </body>
        </html>
        """
    end
    nothing
end
