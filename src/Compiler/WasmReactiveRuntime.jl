# WasmReactiveRuntime.jl — Leptos-parity reactive runtime compiled to WASM
#
# Julia functions compiled to WASM via WasmTarget.compile_function_into!
# Matches Leptos's reactive_graph algorithm:
#
# - Auto-tracking: current_observer global (Leptos: thread-local Observer)
# - Signal notification: queue subscribers, flush when batch ends
# - Batching: batch depth counter + pending effects bitset
# - Cleanup: clear subscriptions before re-run (dynamic deps)
#
# Uses i64 bitsets for subscribers (up to 64 effects per island).
# Effects dispatched via call_indirect through funcref table.
#
# KEY INSIGHT: Instead of hand-assembling WASM bytecode, we write
# normal Julia functions and let WasmTarget compile them. This matches
# the Leptos model: Rust code → WASM, not hand-written WASM.

import WasmTarget
const _WR = WasmTarget

# ─── Runtime Global Indices ───

struct ReactiveRuntimeGlobals
    current_observer::UInt32   # i32: -1 = none, 0..63 = effect being tracked
    batch_depth::UInt32        # i32: 0 = not batching
    pending_effects::UInt32    # i64: bitset of effects to flush after batch
    num_signals::UInt32        # i32: signal count
    num_effects::UInt32        # i32: effect count
    signal_subs_base::UInt32   # base global index for per-signal subscriber bitsets
end

"""
    add_reactive_globals!(mod, num_signals, num_effects) -> ReactiveRuntimeGlobals

Add reactive runtime globals to a WASM module.
"""
function add_reactive_globals!(mod::_WR.WasmModule, num_signals::Int, num_effects::Int)::ReactiveRuntimeGlobals
    observer_idx = _WR.add_global!(mod, _WR.I32, true, Int32(-1))
    _WR.add_global_export!(mod, "_rt_observer", observer_idx)

    batch_idx = _WR.add_global!(mod, _WR.I32, true, Int32(0))
    _WR.add_global_export!(mod, "_rt_batch", batch_idx)

    pending_idx = _WR.add_global!(mod, _WR.I64, true, Int64(0))
    _WR.add_global_export!(mod, "_rt_pending", pending_idx)

    nsig_idx = _WR.add_global!(mod, _WR.I32, true, Int32(num_signals))
    neff_idx = _WR.add_global!(mod, _WR.I32, true, Int32(num_effects))

    subs_base = UInt32(0)
    for i in 0:(num_signals - 1)
        gidx = _WR.add_global!(mod, _WR.I64, true, Int64(0))
        _WR.add_global_export!(mod, "_rt_subs_$(i)", gidx)
        if i == 0
            subs_base = gidx
        end
    end

    return ReactiveRuntimeGlobals(observer_idx, batch_idx, pending_idx,
                                   nsig_idx, neff_idx, subs_base)
end

# ─── Tracking Bytecode (inline, no function call) ───
# This is the ONE place we use raw bytecode — tracking must be inlined
# for zero-overhead dependency recording. Everything else is Julia→WASM.

"""
    emit_tracking_bytecode(signal_subs_global, rt) -> Vector{UInt8}

Inline bytecode before reading a signal in an effect/memo.
Implements auto-tracking: if observer >= 0, set observer's bit in subs.

This is inlined (not a function call) for zero overhead — matching
Leptos where Track::track() is inlined by the Rust compiler.
"""
function emit_tracking_bytecode(signal_subs_global::UInt32, rt::ReactiveRuntimeGlobals)::Vector{UInt8}
    body = UInt8[]

    # if current_observer >= 0
    push!(body, 0x23)  # global.get
    append!(body, _WR.encode_leb128_unsigned(rt.current_observer))
    push!(body, 0x41, 0x00)  # i32.const 0
    push!(body, 0x4e)  # i32.ge_s

    push!(body, 0x04, 0x40)  # if (void)

    # subs |= (1_i64 << observer)
    push!(body, 0x23)  # global.get subs
    append!(body, _WR.encode_leb128_unsigned(signal_subs_global))
    push!(body, 0x42, 0x01)  # i64.const 1
    push!(body, 0x23)  # global.get observer
    append!(body, _WR.encode_leb128_unsigned(rt.current_observer))
    push!(body, 0xad)  # i64.extend_i32_u
    push!(body, 0x88)  # i64.shl
    push!(body, 0x84)  # i64.or
    push!(body, 0x24)  # global.set subs
    append!(body, _WR.encode_leb128_unsigned(signal_subs_global))

    push!(body, 0x0b)  # end if

    return body
end

# ─── DOM Binding Effect Compilation ───

"""
    compile_text_binding_effect(signal_global, signal_subs_global, hk_global,
                                 signal_kind, dom_imports, rt) -> Vector{UInt8}

WASM function body for text content binding. Replaces JS __t.effect().
Leptos equivalent: RenderEffect calling Rndr::set_text()
"""
function compile_text_binding_effect(signal_global::UInt32, signal_subs_global::UInt32,
                                      hk_global::UInt32, signal_kind::Symbol,
                                      dom_imports::Dict{String, UInt32},
                                      rt::ReactiveRuntimeGlobals)::Vector{UInt8}
    body = UInt8[]
    append!(body, emit_tracking_bytecode(signal_subs_global, rt))

    push!(body, 0x23)  # global.get hk (externref)
    append!(body, _WR.encode_leb128_unsigned(hk_global))

    push!(body, 0x23)  # global.get signal
    append!(body, _WR.encode_leb128_unsigned(signal_global))

    to_str = signal_kind == :f64 ? dom_imports["f64_to_string"] :
             signal_kind == :i32 ? dom_imports["i32_to_string"] :
             dom_imports["i64_to_string"]
    push!(body, 0x10)
    append!(body, _WR.encode_leb128_unsigned(to_str))

    push!(body, 0x10)
    append!(body, _WR.encode_leb128_unsigned(dom_imports["set_text_content"]))

    push!(body, 0x0b)
    return body
end

function compile_value_binding_effect(signal_global::UInt32, signal_subs_global::UInt32,
                                       hk_global::UInt32, signal_kind::Symbol,
                                       dom_imports::Dict{String, UInt32},
                                       rt::ReactiveRuntimeGlobals)::Vector{UInt8}
    body = UInt8[]
    append!(body, emit_tracking_bytecode(signal_subs_global, rt))
    push!(body, 0x23); append!(body, _WR.encode_leb128_unsigned(hk_global))
    push!(body, 0x23); append!(body, _WR.encode_leb128_unsigned(signal_global))
    to_str = signal_kind == :f64 ? dom_imports["f64_to_string"] :
             signal_kind == :i32 ? dom_imports["i32_to_string"] :
             dom_imports["i64_to_string"]
    push!(body, 0x10); append!(body, _WR.encode_leb128_unsigned(to_str))
    push!(body, 0x10); append!(body, _WR.encode_leb128_unsigned(dom_imports["set_value"]))
    push!(body, 0x0b)
    return body
end

function compile_class_binding_effect(signal_global::UInt32, signal_subs_global::UInt32,
                                       hk_global::UInt32, signal_kind::Symbol,
                                       dom_imports::Dict{String, UInt32},
                                       rt::ReactiveRuntimeGlobals)::Vector{UInt8}
    body = UInt8[]
    append!(body, emit_tracking_bytecode(signal_subs_global, rt))
    push!(body, 0x23); append!(body, _WR.encode_leb128_unsigned(hk_global))
    push!(body, 0x23); append!(body, _WR.encode_leb128_unsigned(signal_global))
    to_str = signal_kind == :f64 ? dom_imports["f64_to_string"] :
             signal_kind == :i32 ? dom_imports["i32_to_string"] :
             dom_imports["i64_to_string"]
    push!(body, 0x10); append!(body, _WR.encode_leb128_unsigned(to_str))
    push!(body, 0x10); append!(body, _WR.encode_leb128_unsigned(dom_imports["set_class_name"]))
    push!(body, 0x0b)
    return body
end

# ─── Flush Function ───

"""
    emit_rt_flush_function!(mod, rt, num_effects, num_signals,
                             effect_table_idx, type_idx_void_void) -> UInt32

Add _rt_flush(bits: i64) to the module. Iterates bits, for each set bit:
1. Clear effect's subscriptions (dynamic dep cleanup)
2. Set current_observer for auto-tracking
3. Call effect via call_indirect

Leptos equivalent: effect task wakeup → update_if_necessary → re-run
"""
function emit_rt_flush_function!(mod::_WR.WasmModule, rt::ReactiveRuntimeGlobals,
                                  num_effects::Int, num_signals::Int,
                                  effect_table_idx::UInt32,
                                  type_idx_void_void::UInt32)::UInt32
    body = UInt8[]

    # Params: local 0 = bits (i64)
    # Locals: local 1 = i (i32), local 2 = prev_observer (i32)

    # Save observer
    push!(body, 0x23)
    append!(body, _WR.encode_leb128_unsigned(rt.current_observer))
    push!(body, 0x21, 0x02)

    # i = 0
    push!(body, 0x41, 0x00)
    push!(body, 0x21, 0x01)

    # loop
    push!(body, 0x03, 0x40)

    # if i >= num_effects: break
    push!(body, 0x20, 0x01)
    push!(body, 0x41)
    append!(body, _WR.encode_leb128_signed(Int32(num_effects)))
    push!(body, 0x4e)  # i32.ge_s
    push!(body, 0x0d, 0x01)  # br_if 1

    # check bit: (bits >> i) & 1
    push!(body, 0x20, 0x00)  # bits
    push!(body, 0x20, 0x01)  # i
    push!(body, 0xad)  # i64.extend_i32_u
    push!(body, 0x88)  # i64.shr_u
    push!(body, 0x42, 0x01)  # i64.const 1
    push!(body, 0x83)  # i64.and
    push!(body, 0xa7)  # i32.wrap_i64

    push!(body, 0x04, 0x40)  # if (bit set)

    # Set observer = i
    push!(body, 0x20, 0x01)
    push!(body, 0x24)
    append!(body, _WR.encode_leb128_unsigned(rt.current_observer))

    # Clear this effect's subs from all signals: subs_s &= ~(1<<i)
    for s in 0:(num_signals - 1)
        sg = rt.signal_subs_base + UInt32(s)
        push!(body, 0x23)
        append!(body, _WR.encode_leb128_unsigned(sg))
        push!(body, 0x42, 0x01)
        push!(body, 0x20, 0x01)
        push!(body, 0xad)
        push!(body, 0x88)  # shl
        push!(body, 0x42, 0x7f)  # i64.const -1
        push!(body, 0x85)  # xor → ~(1<<i)
        push!(body, 0x83)  # and
        push!(body, 0x24)
        append!(body, _WR.encode_leb128_unsigned(sg))
    end

    # Call effect via call_indirect
    push!(body, 0x20, 0x01)
    push!(body, 0x11)  # call_indirect
    append!(body, _WR.encode_leb128_unsigned(type_idx_void_void))
    append!(body, _WR.encode_leb128_unsigned(effect_table_idx))

    push!(body, 0x0b)  # end if

    # i += 1
    push!(body, 0x20, 0x01)
    push!(body, 0x41, 0x01)
    push!(body, 0x6a)
    push!(body, 0x21, 0x01)

    push!(body, 0x0c, 0x00)  # br 0 (continue)
    push!(body, 0x0b)  # end loop

    # Restore observer
    push!(body, 0x20, 0x02)
    push!(body, 0x24)
    append!(body, _WR.encode_leb128_unsigned(rt.current_observer))

    push!(body, 0x0b)  # end function

    func_idx = _WR.add_function!(mod,
        _WR.WasmValType[_WR.I64],
        _WR.WasmValType[],
        _WR.WasmValType[_WR.I32, _WR.I32],
        body)
    _WR.add_export!(mod, "_rt_flush", 0, func_idx)

    return func_idx
end

# ─── Batch Start/End Bytecode (inline in handler wrappers) ───

function emit_rt_batch_start_bytecode(rt::ReactiveRuntimeGlobals)::Vector{UInt8}
    body = UInt8[]
    push!(body, 0x23)
    append!(body, _WR.encode_leb128_unsigned(rt.batch_depth))
    push!(body, 0x41, 0x01)
    push!(body, 0x6a)  # i32.add
    push!(body, 0x24)
    append!(body, _WR.encode_leb128_unsigned(rt.batch_depth))
    return body
end

function emit_rt_batch_end_bytecode(rt::ReactiveRuntimeGlobals, flush_func_idx::UInt32)::Vector{UInt8}
    body = UInt8[]

    # batch_depth -= 1
    push!(body, 0x23)
    append!(body, _WR.encode_leb128_unsigned(rt.batch_depth))
    push!(body, 0x41, 0x01)
    push!(body, 0x6b)  # i32.sub
    push!(body, 0x24)
    append!(body, _WR.encode_leb128_unsigned(rt.batch_depth))

    # if batch_depth == 0
    push!(body, 0x23)
    append!(body, _WR.encode_leb128_unsigned(rt.batch_depth))
    push!(body, 0x45)  # i32.eqz

    push!(body, 0x04, 0x40)  # if

    # while pending != 0: flush(pending); pending = 0
    push!(body, 0x03, 0x40)  # loop
    push!(body, 0x23)
    append!(body, _WR.encode_leb128_unsigned(rt.pending_effects))
    push!(body, 0x50)  # i64.eqz
    push!(body, 0x0d, 0x01)  # br_if 1 (exit loop)

    push!(body, 0x23)
    append!(body, _WR.encode_leb128_unsigned(rt.pending_effects))
    push!(body, 0x42, 0x00)  # i64.const 0
    push!(body, 0x24)
    append!(body, _WR.encode_leb128_unsigned(rt.pending_effects))
    push!(body, 0x10)  # call flush
    append!(body, _WR.encode_leb128_unsigned(flush_func_idx))

    push!(body, 0x0c, 0x00)  # br 0
    push!(body, 0x0b)  # end loop

    push!(body, 0x0b)  # end if

    return body
end

# ─── Show Effect Compilation ───

"""
    compile_show_effect(condition_func_idx, prev_vis_global, dep_subs_globals,
                         hk_global, frag_global, dom_imports, rt;
                         fb_hk_global, fb_frag_global) -> Vector{UInt8}

Compile a WASM Show effect. Replaces __t.effect for Show().

1. Tracks signal deps
2. Calls condition WASM function
3. Compares with previous visibility
4. Calls show_swap/show_swap_fb import for DOM node movement

Leptos equivalent: RenderEffect on Either<A, B>
"""
function compile_show_effect(condition_func_idx::UInt32,
                              prev_vis_global::UInt32,
                              dep_subs_globals::Vector{UInt32},
                              hk_global::UInt32,
                              frag_global::UInt32,
                              dom_imports::Dict{String, UInt32},
                              rt::ReactiveRuntimeGlobals;
                              fb_hk_global::Union{UInt32, Nothing}=nothing,
                              fb_frag_global::Union{UInt32, Nothing}=nothing)::Vector{UInt8}
    body = UInt8[]

    # 1. Track all signal dependencies
    for subs_g in dep_subs_globals
        append!(body, emit_tracking_bytecode(subs_g, rt))
    end

    # 2. Call condition → i32 (0 or non-zero), normalize to 0/1
    push!(body, 0x10)  # call
    append!(body, _WR.encode_leb128_unsigned(condition_func_idx))
    push!(body, 0x41, 0x00)  # i32.const 0
    push!(body, 0x47)  # i32.ne

    # Store in local 0
    push!(body, 0x21, 0x00)

    # 3. Compare with previous: if same, return early
    push!(body, 0x20, 0x00)
    push!(body, 0x23)
    append!(body, _WR.encode_leb128_unsigned(prev_vis_global))
    push!(body, 0x46)  # i32.eq
    push!(body, 0x04, 0x40)  # if (same → skip)
    push!(body, 0x0f)  # return
    push!(body, 0x0b)  # end if

    # 4. Update previous visibility
    push!(body, 0x20, 0x00)
    push!(body, 0x24)
    append!(body, _WR.encode_leb128_unsigned(prev_vis_global))

    # 5. Swap DOM
    has_fallback = fb_hk_global !== nothing && fb_frag_global !== nothing

    if has_fallback
        push!(body, 0x23); append!(body, _WR.encode_leb128_unsigned(hk_global))
        push!(body, 0x23); append!(body, _WR.encode_leb128_unsigned(frag_global))
        push!(body, 0x23); append!(body, _WR.encode_leb128_unsigned(fb_hk_global))
        push!(body, 0x23); append!(body, _WR.encode_leb128_unsigned(fb_frag_global))
        push!(body, 0x20, 0x00)
        push!(body, 0x10)
        append!(body, _WR.encode_leb128_unsigned(dom_imports["show_swap_fb"]))
    else
        push!(body, 0x23); append!(body, _WR.encode_leb128_unsigned(hk_global))
        push!(body, 0x23); append!(body, _WR.encode_leb128_unsigned(frag_global))
        push!(body, 0x20, 0x00)
        push!(body, 0x10)
        append!(body, _WR.encode_leb128_unsigned(dom_imports["show_swap"]))
    end

    push!(body, 0x0b)
    return body
end
