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

## API-004: End-to-end browser verification (OPEN)
Next: serve the InteractivePlot island in a real browser and verify canvas rendering works.
