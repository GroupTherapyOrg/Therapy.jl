# Memo.jl - Cached computed values

# Global memo ID counter
const MEMO_ID_COUNTER = Ref{UInt64}(0)

function next_memo_id()::UInt64
    MEMO_ID_COUNTER[] += 1
    return MEMO_ID_COUNTER[]
end

# ─── Analysis-mode memo getter ───

"""
Callable getter returned by create_memo during @island analysis mode.
Parametric to preserve return type for compilation (avoids Any erasure).
Used in VNode tree for DOM bindings and in handler/effect closures.
"""
struct MemoAnalysisGetter{T}
    memo_idx::Int
    cached_value::T
end

@noinline function (g::MemoAnalysisGetter{T})()::T where T
    # During analysis, record this memo as a dependency (read by create_effect)
    if is_signal_analysis_mode()
        push!(EFFECT_MEMO_DEPS[], g.memo_idx)
    end
    return g.cached_value
end

"""
    create_memo(fn::Function) -> getter

Create a memoized computation that automatically tracks dependencies
and caches its result.

Returns a getter function that returns the cached value.
The value is only recomputed when dependencies change.

# Examples
```julia
count, set_count = create_signal(0)

# Doubled is a cached computation
doubled = create_memo(() -> count() * 2)

doubled()  # => 0
set_count(5)
doubled()  # => 10 (recomputed because count changed)
doubled()  # => 10 (cached, no recomputation)
```
"""
function create_memo(fn::Function)
    # During @island analysis: record the memo and return a trackable getter
    if is_signal_analysis_mode()
        idx = MEMO_ANALYSIS_COUNTER[]
        MEMO_ANALYSIS_COUNTER[] += 1

        # Run fn once with tracking to discover signal dependencies
        tracking_deps = Set{Any}()
        tracking_ctx = TrackingContext(tracking_deps)
        push_effect_context!(tracking_ctx)
        local initial_value
        try
            initial_value = fn()
        catch
            initial_value = nothing
        finally
            pop_effect_context!()
        end

        # Map tracked Signal objects to signal IDs
        dep_ids = UInt64[]
        for dep in tracking_deps
            if dep isa Signal
                push!(dep_ids, dep.id)
            end
        end

        getter = MemoAnalysisGetter(idx, initial_value)
        push!(ANALYZED_MEMOS_LIST[], (idx=idx, fn=fn, dependencies=dep_ids, initial_value=initial_value, getter=getter))
        MEMO_GETTER_MAP[][getter] = idx

        return getter
    end

    # Normal runtime path: compute initial value while tracking dependencies
    dependencies = Set{Any}()
    initial_value = compute_with_tracking(fn, dependencies)

    memo = Memo(
        next_memo_id(),
        fn,
        initial_value,
        false,  # Not dirty initially
        dependencies,
        Set{Any}()
    )

    # Subscribe to all dependencies to mark dirty on change
    for signal in dependencies
        push!(signal.subscribers, MemoSubscriber(memo))
    end

    # Return a getter function
    return function()
        # Track if we're inside an effect
        effect = current_effect()
        if effect !== nothing
            push!(memo.subscribers, effect)
            push!(effect.dependencies, memo)
        end

        # Recompute if dirty
        if memo.dirty
            recompute_memo!(memo)
        end

        return memo.value
    end
end

"""
Compute a function while tracking its dependencies.
"""
function compute_with_tracking(fn::Function, dependencies::Set{Any})
    # Create a temporary effect-like context just for tracking
    tracking_context = TrackingContext(dependencies)
    push_effect_context!(tracking_context)
    try
        return fn()
    finally
        pop_effect_context!()
    end
end

"""
Recompute a memo's value and update dependencies.

Note: This function does NOT notify effect subscribers — that is handled
by mark_memo_dirty! which checks if the value actually changed before
propagating (Leptos glitch-free model).
"""
function recompute_memo!(memo::Memo)
    # Clear old subscriptions
    for signal in memo.dependencies
        delete!(signal.subscribers, MemoSubscriber(memo))
    end
    empty!(memo.dependencies)

    # Recompute with tracking
    old_value = memo.value
    memo.value = compute_with_tracking(memo.fn, memo.dependencies)
    memo.dirty = false

    # Subscribe to new dependencies
    for signal in memo.dependencies
        push!(signal.subscribers, MemoSubscriber(memo))
    end

    # Return whether the value changed (used by mark_memo_dirty! for glitch-free)
    return old_value != memo.value
end

"""
Mark a memo as dirty (called when a dependency changes).

Eagerly recomputes the memo and only propagates to downstream subscribers
(effects and other memos) if the value actually changed. This implements
Leptos's glitch-free reactive propagation model:
- If the memo produces the same value, downstream effects are NOT re-run
- Effects are queued via the batch system for deduplication
"""
function mark_memo_dirty!(memo::Memo)
    if !memo.dirty
        memo.dirty = true

        # Eagerly recompute to check if value actually changed (Leptos glitch-free)
        value_changed = recompute_memo!(memo)

        if value_changed
            # Value changed — propagate to downstream subscribers
            for subscriber in collect(memo.subscribers)
                if subscriber isa MemoSubscriber
                    mark_memo_dirty!(subscriber.memo)
                elseif subscriber isa Effect
                    if is_batching()
                        queue_update!(subscriber)
                    else
                        run_effect!(subscriber)
                    end
                end
            end
        end
    end
end

# Extend notify_subscribers! to handle MemoSubscriber
function notify_memo_subscriber!(subscriber::MemoSubscriber)
    mark_memo_dirty!(subscriber.memo)
end
