# WasmPlot API Progress

## API-001: Two-pass autodiscovery (DONE)
Fixed stubbing in WasmTarget.jl `_autodiscover_closure_deps!` — reduced warnings from 25 to 3 (only error paths remain).

## API-002: Math function stubbing (DONE)
Same autodiscovery fix covers math functions.

## API-003: Therapy 'Has effect: false' (DONE)
**Investigation result:** The effect was already compiling and wiring correctly. The diagnostic check `contains(result.js, "effect")` was misleading.

Verified evidence:
- WASM: 65,415 bytes, validates clean with `wasm-tools validate --features=gc`
- Effect `_effect_0` exported at func index 72
- 21 canvas2d imports present (begin_path through set_line_dash_dotted)
- Funcref table has 2 entries (text binding + WasmPlot effect)
- JS calls `_rt_flush(BigInt(3))` to trigger all effects
- Effect body calls canvas2d functions: clear_rect, set_fill_rgba, set_fill_rgb, fill_rect, save, etc.
- All JS↔WASM type signatures match (f64 params, i64/BigInt returns)

The API-001/002 autodiscovery fixes resolved the underlying compilation issue — the effect closure now compiles through WasmTarget without stubbing failures.

## API-004: End-to-end browser verification (DONE)
Full end-to-end browser verification completed via Puppeteer headless Chrome.

Build output:
- Static site builds successfully with all 10 islands compiled
- InteractivePlot: 63.9 KB WASM, 1 signal, 2 handlers
- All other islands compile without errors

Browser verification (headless Chrome):
- WASM validates: 65,415 bytes, 21 canvas2d imports, 14 exports
- InteractivePlot island hydrates: `data-hydrated="true"`
- Canvas renders blue sin wave: pixel sampling confirms `rgb(60,130,246)` (blue data line) + `rgb(128,128,128)` (gray grid)
- + button: freq 3→4, full canvas redraw (320 canvas2d calls)
- - button: freq 4→3, full canvas redraw
- Zero WASM errors, zero page errors
- All 11 islands on the examples page hydrate successfully

Node.js headless WASM test:
- Instantiation: SUCCESS
- Effect produces 223 line_to calls per render (200 data points + 23 grid lines)
- Rendering sequence: clear_rect → fill_rect (background) → grid → data line → stroke
- Handler wiring: `_hw1` (minus), `_hw2` (plus), signal_0 updates correctly
- Multiple freq values (1-5) all render correctly

Regression gate:
- WasmPlot unit tests: 69/69 pass
- WasmPlot WASM compile tests: 11/11 pass
- WasmTarget tests: pass (see separate run)
