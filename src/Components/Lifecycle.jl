# Lifecycle.jl - Component lifecycle hooks

"""
Lifecycle scope for a component.
"""
mutable struct LifecycleScope
    on_mount_callbacks::Vector{Function}
    on_cleanup_callbacks::Vector{Function}
    parent::Union{Nothing, LifecycleScope}
    children::Vector{LifecycleScope}
end

LifecycleScope() = LifecycleScope(Function[], Function[], nothing, LifecycleScope[])

"""
Get current lifecycle scope.
"""
function current_scope()
    _reactive_task_state().lifecycle_scope
end

"""
Push a new lifecycle scope.
"""
function push_scope!()
    state = _reactive_task_state()
    parent = state.lifecycle_scope
    scope = LifecycleScope(Function[], Function[], parent, LifecycleScope[])
    if parent !== nothing
        push!(parent.children, scope)
    end
    state.lifecycle_scope = scope
    return scope
end

"""
Pop current lifecycle scope.
"""
function pop_scope!()
    state = _reactive_task_state()
    scope = state.lifecycle_scope
    if scope !== nothing
        state.lifecycle_scope = scope.parent
    end
    return scope
end

"""
    on_mount(fn::Function)

Register a callback to run after the component is mounted to the DOM.

# Examples
```julia
component(:Timer) do props
    elapsed, set_elapsed = create_signal(0)

    on_mount() do
        # Start timer when component mounts
        start_timer(set_elapsed)
    end

    P("Elapsed: ", elapsed(), " seconds")
end
```
"""
function on_mount(fn::Function)
    # During @island analysis: record for JS compilation
    if is_signal_analysis_mode()
        state = _analysis_state()
        mid = state.mount_counter
        state.mount_counter += 1
        push!(state.mounts, (id=mid, fn=fn))
        return nothing
    end

    # During component scope rendering
    scope = current_scope()
    if scope !== nothing
        push!(scope.on_mount_callbacks, fn)
    else
        # If not in a component scope, run immediately
        fn()
    end
end

"""
    on_cleanup(fn::Function)

Register a callback to run when the component is unmounted.

# Examples
```julia
component(:Timer) do props
    on_mount() do
        timer_id = start_timer()

        on_cleanup() do
            stop_timer(timer_id)
        end
    end

    P("Timer running...")
end
```
"""
function on_cleanup(fn::Function)
    scope = current_scope()
    if scope !== nothing
        push!(scope.on_cleanup_callbacks, fn)
    end
    # Ignore if not in a component scope
end

"""
Run all mount callbacks in a scope and its children.
"""
function run_mount_callbacks!(scope::LifecycleScope)
    for cb in scope.on_mount_callbacks
        cb()
    end
    for child in scope.children
        run_mount_callbacks!(child)
    end
end

"""
Run all cleanup callbacks in a scope and its children.
"""
function run_cleanup_callbacks!(scope::LifecycleScope)
    # Cleanup children first (reverse order)
    for child in reverse(scope.children)
        run_cleanup_callbacks!(child)
    end
    for cb in scope.on_cleanup_callbacks
        cb()
    end
end
