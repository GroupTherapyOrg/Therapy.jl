# Effect.jl - Side effects that re-run when dependencies change

# Global effect ID counter
const EFFECT_ID_COUNTER = Ref{UInt64}(0)

function next_effect_id()::UInt64
    EFFECT_ID_COUNTER[] += 1
    return EFFECT_ID_COUNTER[]
end

"""
    create_effect(fn::Function) -> Effect

Create a reactive effect that runs immediately and re-runs whenever
any signal it reads changes.

# Examples
```julia
count, set_count = create_signal(0)

# This runs immediately and again whenever count() changes
create_effect() do
    println("Count is: ", count())
end

set_count(5)  # Prints: "Count is: 5"
```
"""
function create_effect(fn::Function)
    # During @island analysis: record the effect and discover its signal dependencies
    if is_signal_analysis_mode()
        eid = EFFECT_ANALYSIS_COUNTER[]
        EFFECT_ANALYSIS_COUNTER[] += 1

        # Run fn once with a TrackingContext to discover which signals it reads
        tracking_deps = Set{Any}()
        tracking_ctx = TrackingContext(tracking_deps)
        empty!(EFFECT_MEMO_DEPS[])  # Clear stale entries from memo creation
        push_effect_context!(tracking_ctx)
        try
            fn()
        catch
            # Effect may fail during analysis (no DOM, etc.) — OK
        finally
            pop_effect_context!()
        end

        # Map tracked Signal objects to signal IDs
        signal_dep_ids = UInt64[]
        for dep in tracking_deps
            if dep isa Signal
                push!(signal_dep_ids, dep.id)
            end
        end

        # Also track memo dependencies (MemoAnalysisGetter calls set this)
        memo_dep_idxs = copy(EFFECT_MEMO_DEPS[])
        empty!(EFFECT_MEMO_DEPS[])

        push!(ANALYZED_EFFECTS_LIST[], (id=eid, fn=fn, signal_deps=signal_dep_ids, memo_deps=memo_dep_idxs))
        return nothing
    end

    # Normal runtime path
    effect = Effect(next_effect_id(), fn, Set{Any}(), false)
    run_effect!(effect)
    return effect
end

"""
    on_mount(fn::Function)

Run a function once after the component mounts to the DOM.
Unlike `create_effect`, this does NOT track signal dependencies
and will never re-run. Use for one-time initialization:
DOM refs, third-party library setup, focus management, etc.

# Examples
```julia
on_mount() do
    js("document.getElementById('my-input').focus()")
end
```
"""
function on_mount(fn::Function)
    if is_signal_analysis_mode()
        mid = MOUNT_ANALYSIS_COUNTER[]
        MOUNT_ANALYSIS_COUNTER[] += 1
        push!(ANALYZED_MOUNTS_LIST[], (id=mid, fn=fn))
        return nothing
    end

    # Normal runtime: just run immediately (already mounted in SSR context)
    try fn() catch end
    return nothing
end

"""
Run an effect, tracking its dependencies.
"""
function run_effect!(effect::Effect)
    if effect.disposed
        return
    end

    # Clear old dependencies
    cleanup_effect!(effect)

    # Push onto effect stack so signals can register as dependencies
    push_effect_context!(effect)

    try
        effect.fn()
    finally
        pop_effect_context!()
    end
end

"""
Clean up an effect's dependencies.
"""
function cleanup_effect!(effect::Effect)
    # Remove this effect from all signals it was subscribed to
    for signal in effect.dependencies
        delete!(signal.subscribers, effect)
    end
    empty!(effect.dependencies)
end

"""
    dispose!(effect::Effect)

Stop an effect from running again and clean up its dependencies.

# Examples
```julia
count, set_count = create_signal(0)

effect = create_effect() do
    println("Count: ", count())
end

dispose!(effect)
set_count(5)  # No output - effect is disposed
```
"""
function dispose!(effect::Effect)
    effect.disposed = true
    cleanup_effect!(effect)
end
