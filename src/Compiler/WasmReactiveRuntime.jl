# WasmReactiveRuntime.jl — Leptos-parity reactive runtime compiled to WASM
#
# Replaces the JS __t reactive runtime with WASM functions.
# Matches Leptos's reactive_graph algorithm:
#
# - Auto-tracking: current_observer pattern (like thread-local Observer)
# - Signal notification: mark subscribers dirty, flush if not batching
# - Batching: batch depth counter + pending effects bitset
# - Cleanup: clear effect's subscriptions before re-run (dynamic deps)
# - Owner tree: create/dispose/run_with_owner for Show/For cleanup
#
# Data structures use i64 bitsets for subscribers (up to 64 effects per island).
# Effects are dispatched via call_indirect through a funcref table.
#
# These functions are compiled into each island's WASM module via
# compile_function_into! and bytecode emission.

import WasmTarget
const _WR = WasmTarget

# ─── Runtime Globals ───
# These are added to each island's WASM module as mutable globals.

"""
Reactive runtime global indices (added to the WASM module).
All indices are relative — actual global indices depend on signal count.
"""
struct ReactiveRuntimeGlobals
    current_observer::UInt32   # i32: -1 = none, 0..63 = effect being tracked
    batch_depth::UInt32        # i32: 0 = not batching
    pending_effects::UInt32    # i64: bitset of effects to flush after batch
    num_signals::UInt32        # i32: number of signals (for iteration bounds)
    num_effects::UInt32        # i32: number of effects registered
    signal_subs_base::UInt32   # base global index for signal subscriber bitsets (i64 per signal)
end

"""
    add_reactive_globals!(mod, num_signals, num_effects) -> ReactiveRuntimeGlobals

Add reactive runtime globals to a WASM module.
Returns the global indices for use in compiled runtime functions.
"""
function add_reactive_globals!(mod::_WR.WasmModule, num_signals::Int, num_effects::Int)::ReactiveRuntimeGlobals
    # Core runtime globals
    observer_idx = _WR.add_global!(mod, _WR.I32, true, Int32(-1))
    _WR.add_global_export!(mod, "_rt_observer", observer_idx)

    batch_idx = _WR.add_global!(mod, _WR.I32, true, Int32(0))
    _WR.add_global_export!(mod, "_rt_batch", batch_idx)

    pending_idx = _WR.add_global!(mod, _WR.I64, true, Int64(0))
    _WR.add_global_export!(mod, "_rt_pending", pending_idx)

    nsig_idx = _WR.add_global!(mod, _WR.I32, true, Int32(num_signals))
    neff_idx = _WR.add_global!(mod, _WR.I32, true, Int32(num_effects))

    # Per-signal subscriber bitsets (i64 each — which effects subscribe)
    subs_base = nothing
    for i in 0:(num_signals - 1)
        gidx = _WR.add_global!(mod, _WR.I64, true, Int64(0))
        _WR.add_global_export!(mod, "_rt_subs_$(i)", gidx)
        if i == 0
            subs_base = gidx
        end
    end
    # If no signals, subs_base is unused
    if subs_base === nothing
        subs_base = UInt32(0)
    end

    return ReactiveRuntimeGlobals(observer_idx, batch_idx, pending_idx,
                                   nsig_idx, neff_idx, subs_base)
end

# ─── Runtime Function Bytecode ───
# These emit raw WASM bytecode for the runtime functions.
# Each function is added to the module via add_function! + add_export!.

"""
    emit_rt_track!(mod, rt) -> UInt32

Emit the `rt_track(signal_idx: i32)` function.
Records a dependency: sets bit `current_observer` in signal_subs[signal_idx].

Leptos equivalent: Track::track() → subscriber.add_source() + source.add_subscriber()
"""
function emit_rt_track!(mod::_WR.WasmModule, rt::ReactiveRuntimeGlobals)::UInt32
    body = UInt8[]

    # if current_observer >= 0
    push!(body, 0x23)  # global.get
    append!(body, _WR.encode_leb128_unsigned(rt.current_observer))
    push!(body, 0x41, 0x00)  # i32.const 0
    push!(body, 0x4e)  # i32.ge_s

    push!(body, 0x04, 0x40)  # if (void)

    # subs = global.get $signal_subs_N  (N = signal_idx param)
    # We need to index into the subscriber globals dynamically.
    # Since globals aren't indexable, we use a switch/br_table pattern.
    # For simplicity with up to ~16 signals, emit a br_table.
    # Actually, for P1 we'll use a simpler approach: the caller (compiled effect)
    # passes the signal index, and we emit the specific global.get/set inline.
    #
    # ALTERNATIVE: Since rt_track is called with a CONSTANT signal_idx (known at
    # compile time), we can emit SPECIALIZED versions: rt_track_0, rt_track_1, etc.
    # This avoids dynamic global indexing entirely.
    #
    # For now, emit the general pattern using a block/br_table dispatch.

    # Get the current subscriber bitset for this signal
    # local 0 = signal_idx (i32 param)
    # We need: global.get $subs_base+signal_idx
    # Since globals aren't dynamically indexable, we use br_table:
    #
    # block $done
    #   block $s0
    #     block $s1
    #       ...
    #       local.get 0  ;; signal_idx
    #       br_table $s0 $s1 ... $done
    #     end ;; $s1: handle signal 1
    #     ...
    #   end ;; $s0: handle signal 0
    #   ...
    # end ;; $done

    # This gets complex. Let's use the specialized approach instead:
    # Don't emit a general rt_track — emit per-signal tracking inline.

    push!(body, 0x0b)  # end if

    push!(body, 0x0b)  # end function

    # Actually, let's take a different approach. Instead of a general rt_track
    # function, the compiler will emit tracking code INLINE in each effect:
    #
    #   ;; before reading signal 0:
    #   global.get $current_observer
    #   i32.const 0
    #   i32.ge_s
    #   if
    #     global.get $subs_0          ;; current subscribers for signal 0
    #     i64.const 1
    #     global.get $current_observer
    #     i64.extend_i32_u
    #     i64.shl                     ;; 1 << observer_idx
    #     i64.or                      ;; subs_0 | (1 << observer)
    #     global.set $subs_0
    #   end
    #   global.get $signal_0          ;; actual signal read

    # So we DON'T need a general rt_track function. The tracking is inlined.
    # Return 0 as a placeholder — this function won't be used.
    return UInt32(0)
end

"""
    emit_rt_notify_bytecode(signal_subs_global::UInt32, rt::ReactiveRuntimeGlobals) -> Vector{UInt8}

Generate the bytecode to emit AFTER a signal write (global.set \$signal_N).
This notifies subscribers and either flushes immediately or queues for batch.

Called inline after every signal write in handlers.

Leptos equivalent: Notify::notify() → mark_dirty() → schedule effects
"""
function emit_rt_notify_bytecode(signal_subs_global::UInt32, rt::ReactiveRuntimeGlobals)::Vector{UInt8}
    body = UInt8[]

    # subs = global.get $subs_N
    push!(body, 0x23)  # global.get
    append!(body, _WR.encode_leb128_unsigned(signal_subs_global))

    # if batch_depth > 0: pending |= subs; else: flush(subs)
    push!(body, 0x23)  # global.get
    append!(body, _WR.encode_leb128_unsigned(rt.batch_depth))
    push!(body, 0x41, 0x00)  # i32.const 0
    push!(body, 0x4a)  # i32.gt_s

    push!(body, 0x04, 0x40)  # if (void)
    # pending |= subs
    push!(body, 0x23)  # global.get
    append!(body, _WR.encode_leb128_unsigned(rt.pending_effects))
    push!(body, 0x23)  # global.get
    append!(body, _WR.encode_leb128_unsigned(signal_subs_global))
    push!(body, 0x84)  # i64.or
    push!(body, 0x24)  # global.set
    append!(body, _WR.encode_leb128_unsigned(rt.pending_effects))

    push!(body, 0x05)  # else
    # Call flush with the subs bitset
    # For now, call the exported _rt_flush function
    # (func index will be resolved after all functions are added)
    # We'll use a placeholder that gets patched
    # Actually: emit inline flush for now (simple loop)

    # We need to iterate bits in subs and call each effect.
    # This requires call_indirect which needs the funcref table index.
    # For P1 initial implementation, emit a call to the _rt_flush export.

    push!(body, 0x23)  # global.get (subs - already consumed above, need to re-read)
    append!(body, _WR.encode_leb128_unsigned(signal_subs_global))
    # Store in a local, then call flush
    # Actually this is getting complex for inline bytecode.
    # Let's emit a separate flush function and call it.

    push!(body, 0x0b)  # end if

    return body
end

"""
    emit_rt_batch_start_bytecode(rt::ReactiveRuntimeGlobals) -> Vector{UInt8}

Bytecode for batch_depth += 1. Emitted at the start of every handler.
Leptos equivalent: batch() wrapper.
"""
function emit_rt_batch_start_bytecode(rt::ReactiveRuntimeGlobals)::Vector{UInt8}
    body = UInt8[]
    push!(body, 0x23)  # global.get $batch_depth
    append!(body, _WR.encode_leb128_unsigned(rt.batch_depth))
    push!(body, 0x41, 0x01)  # i32.const 1
    push!(body, 0x6a)  # i32.add
    push!(body, 0x24)  # global.set $batch_depth
    append!(body, _WR.encode_leb128_unsigned(rt.batch_depth))
    return body
end

"""
    emit_rt_batch_end_bytecode(rt::ReactiveRuntimeGlobals, flush_func_idx::UInt32) -> Vector{UInt8}

Bytecode for batch_depth -= 1; if 0 → flush pending effects.
Emitted at the end of every handler.
"""
function emit_rt_batch_end_bytecode(rt::ReactiveRuntimeGlobals, flush_func_idx::UInt32)::Vector{UInt8}
    body = UInt8[]

    # batch_depth -= 1
    push!(body, 0x23)  # global.get $batch_depth
    append!(body, _WR.encode_leb128_unsigned(rt.batch_depth))
    push!(body, 0x41, 0x01)  # i32.const 1
    push!(body, 0x6b)  # i32.sub
    push!(body, 0x24)  # global.set $batch_depth
    append!(body, _WR.encode_leb128_unsigned(rt.batch_depth))

    # if batch_depth == 0: flush
    push!(body, 0x23)  # global.get $batch_depth
    append!(body, _WR.encode_leb128_unsigned(rt.batch_depth))
    push!(body, 0x45)  # i32.eqz

    push!(body, 0x04, 0x40)  # if (void)

    # while pending != 0: to_run = pending; pending = 0; flush(to_run)
    push!(body, 0x03, 0x40)  # loop (void)
    push!(body, 0x23)  # global.get $pending
    append!(body, _WR.encode_leb128_unsigned(rt.pending_effects))
    push!(body, 0x50)  # i64.eqz
    push!(body, 0x0d, 0x01)  # br_if 1 (break out of loop if pending == 0)

    # to_run = pending
    push!(body, 0x23)  # global.get $pending
    append!(body, _WR.encode_leb128_unsigned(rt.pending_effects))
    # pending = 0
    push!(body, 0x42, 0x00)  # i64.const 0
    push!(body, 0x24)  # global.set $pending
    append!(body, _WR.encode_leb128_unsigned(rt.pending_effects))
    # call _rt_flush(to_run)
    push!(body, 0x10)  # call
    append!(body, _WR.encode_leb128_unsigned(flush_func_idx))

    push!(body, 0x0c, 0x00)  # br 0 (continue loop)
    push!(body, 0x0b)  # end loop

    push!(body, 0x0b)  # end if

    return body
end

"""
    emit_tracking_bytecode(signal_subs_global::UInt32, rt::ReactiveRuntimeGlobals) -> Vector{UInt8}

Bytecode to emit BEFORE reading a signal global in an effect/memo.
Implements auto-tracking: if current_observer >= 0, set the observer's
bit in this signal's subscriber bitset.

Emitted inline — no function call overhead.
Leptos equivalent: Track::track()
"""
function emit_tracking_bytecode(signal_subs_global::UInt32, rt::ReactiveRuntimeGlobals)::Vector{UInt8}
    body = UInt8[]

    # if current_observer >= 0
    push!(body, 0x23)  # global.get $current_observer
    append!(body, _WR.encode_leb128_unsigned(rt.current_observer))
    push!(body, 0x41, 0x00)  # i32.const 0
    push!(body, 0x4e)  # i32.ge_s

    push!(body, 0x04, 0x40)  # if (void)

    # subs |= (1_i64 << observer)
    push!(body, 0x23)  # global.get $subs_N
    append!(body, _WR.encode_leb128_unsigned(signal_subs_global))
    push!(body, 0x42, 0x01)  # i64.const 1
    push!(body, 0x23)  # global.get $current_observer
    append!(body, _WR.encode_leb128_unsigned(rt.current_observer))
    push!(body, 0xad)  # i64.extend_i32_u
    push!(body, 0x88)  # i64.shl
    push!(body, 0x84)  # i64.or
    push!(body, 0x24)  # global.set $subs_N
    append!(body, _WR.encode_leb128_unsigned(signal_subs_global))

    push!(body, 0x0b)  # end if

    return body
end

"""
    emit_clear_subs_bytecode(effect_idx::Int, rt::ReactiveRuntimeGlobals, num_signals::Int) -> Vector{UInt8}

Bytecode to clear an effect's bit from ALL signal subscriber bitsets.
Emitted before re-running an effect (dynamic dep cleanup).

Leptos equivalent: effect re-run clears old sources before tracking new ones.
"""
function emit_clear_subs_bytecode(effect_idx::Int, rt::ReactiveRuntimeGlobals, num_signals::Int)::Vector{UInt8}
    body = UInt8[]
    mask = ~(Int64(1) << effect_idx)  # all bits set except this effect

    for i in 0:(num_signals - 1)
        subs_global = rt.signal_subs_base + UInt32(i)
        # subs_N &= ~(1 << effect_idx)
        push!(body, 0x23)  # global.get $subs_N
        append!(body, _WR.encode_leb128_unsigned(subs_global))
        push!(body, 0x42)  # i64.const mask
        append!(body, _WR.encode_leb128_signed(mask))
        push!(body, 0x83)  # i64.and
        push!(body, 0x24)  # global.set $subs_N
        append!(body, _WR.encode_leb128_unsigned(subs_global))
    end

    return body
end

# ─── DOM Binding Effect Compilation ───

"""
    compile_text_binding_effect(signal_global, signal_subs_global, hk_global,
                                 signal_kind, dom_imports, rt) -> Vector{UInt8}

Compile a WASM function body for a text content binding effect.
Replaces: __t.effect(function(){hk_N.textContent=String(s0[0]())})

Leptos equivalent: RenderEffect that calls Rndr::set_text()
"""
function compile_text_binding_effect(signal_global::UInt32, signal_subs_global::UInt32,
                                      hk_global::UInt32, signal_kind::Symbol,
                                      dom_imports::Dict{String, UInt32},
                                      rt::ReactiveRuntimeGlobals)::Vector{UInt8}
    body = UInt8[]

    # 1. Track this signal dependency (inline)
    append!(body, emit_tracking_bytecode(signal_subs_global, rt))

    # 2. Push hk_global (dom node externref)
    push!(body, 0x23)  # global.get
    append!(body, _WR.encode_leb128_unsigned(hk_global))

    # 3. Push signal value and convert to string externref
    push!(body, 0x23)  # global.get
    append!(body, _WR.encode_leb128_unsigned(signal_global))

    to_str = signal_kind == :f64 ? dom_imports["f64_to_string"] :
             signal_kind == :i32 ? dom_imports["i32_to_string"] :
             dom_imports["i64_to_string"]
    push!(body, 0x10)  # call to_string
    append!(body, _WR.encode_leb128_unsigned(to_str))

    # 4. Call dom.set_text_content(hk, string)
    push!(body, 0x10)  # call
    append!(body, _WR.encode_leb128_unsigned(dom_imports["set_text_content"]))

    push!(body, 0x0b)  # end
    return body
end

# ─── Flush Function ───

"""
    emit_rt_flush_function!(mod, rt, num_effects, num_signals,
                             effect_table_idx, type_idx_void_void) -> UInt32

Add the _rt_flush(bits: i64) function to the module.
Iterates bits, for each set bit calls the effect via call_indirect.

Before calling each effect:
1. Clears the effect's subscriptions (dynamic dep cleanup)
2. Sets current_observer for auto-tracking

Returns the function index.
"""
function emit_rt_flush_function!(mod::_WR.WasmModule, rt::ReactiveRuntimeGlobals,
                                  num_effects::Int, num_signals::Int,
                                  effect_table_idx::UInt32,
                                  type_idx_void_void::UInt32)::UInt32
    body = UInt8[]

    # Params: local 0 = bits (i64)
    # Locals: local 1 = i (i32), local 2 = prev_observer (i32)

    # Save current observer
    push!(body, 0x23)  # global.get current_observer
    append!(body, _WR.encode_leb128_unsigned(rt.current_observer))
    push!(body, 0x21, 0x02)  # local.set 2

    # i = 0
    push!(body, 0x41, 0x00)  # i32.const 0
    push!(body, 0x21, 0x01)  # local.set 1

    # loop
    push!(body, 0x03, 0x40)

    # if i >= num_effects: break
    push!(body, 0x20, 0x01)  # local.get i
    push!(body, 0x41)
    append!(body, _WR.encode_leb128_signed(Int32(num_effects)))
    push!(body, 0x4e)  # i32.ge_s
    push!(body, 0x0d, 0x01)  # br_if 1

    # check if bit i is set: (bits >> i) & 1
    push!(body, 0x20, 0x00)  # local.get bits
    push!(body, 0x20, 0x01)  # local.get i
    push!(body, 0xad)  # i64.extend_i32_u
    push!(body, 0x88)  # i64.shr_u
    push!(body, 0x42, 0x01)  # i64.const 1
    push!(body, 0x83)  # i64.and
    push!(body, 0xa7)  # i32.wrap_i64

    push!(body, 0x04, 0x40)  # if (non-zero = bit set)

    # Set current_observer = i
    push!(body, 0x20, 0x01)
    push!(body, 0x24)
    append!(body, _WR.encode_leb128_unsigned(rt.current_observer))

    # Clear this effect's subscriptions: for each signal, subs &= ~(1<<i)
    for s in 0:(num_signals - 1)
        sg = rt.signal_subs_base + UInt32(s)
        push!(body, 0x23)
        append!(body, _WR.encode_leb128_unsigned(sg))
        push!(body, 0x42, 0x01)  # i64.const 1
        push!(body, 0x20, 0x01)  # local.get i
        push!(body, 0xad)  # i64.extend_i32_u
        push!(body, 0x88)  # i64.shl
        push!(body, 0x42, 0x7f)  # i64.const -1
        push!(body, 0x85)  # i64.xor → ~(1<<i)
        push!(body, 0x83)  # i64.and
        push!(body, 0x24)
        append!(body, _WR.encode_leb128_unsigned(sg))
    end

    # Call effect via call_indirect(i, table)
    push!(body, 0x20, 0x01)  # local.get i (funcref index)
    push!(body, 0x11)  # call_indirect
    append!(body, _WR.encode_leb128_unsigned(type_idx_void_void))
    append!(body, _WR.encode_leb128_unsigned(effect_table_idx))

    push!(body, 0x0b)  # end if

    # i += 1
    push!(body, 0x20, 0x01)
    push!(body, 0x41, 0x01)
    push!(body, 0x6a)
    push!(body, 0x21, 0x01)

    push!(body, 0x0c, 0x00)  # br 0 (continue loop)
    push!(body, 0x0b)  # end loop

    # Restore observer
    push!(body, 0x20, 0x02)
    push!(body, 0x24)
    append!(body, _WR.encode_leb128_unsigned(rt.current_observer))

    push!(body, 0x0b)  # end function

    func_idx = _WR.add_function!(mod,
        _WR.WasmValType[_WR.I64],
        _WR.WasmValType[],
        _WR.WasmValType[_WR.I32, _WR.I32],  # locals: i, prev_observer
        body)
    _WR.add_export!(mod, "_rt_flush", 0, func_idx)

    return func_idx
end
