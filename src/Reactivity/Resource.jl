# Resource.jl - Async data primitive for loading data with reactive dependencies
# Follows the leptos.rs Resource pattern

"""
    ResourceState

Enum representing the current state of a Resource.
"""
@enum ResourceState begin
    RESOURCE_PENDING   # Initial state, no fetch has been initiated
    RESOURCE_LOADING   # Fetcher is currently running
    RESOURCE_READY     # Data is available
    RESOURCE_ERROR     # Fetch resulted in an error
end

"""
    Resource{T}

An async data primitive that fetches data based on a source signal and tracks
loading/error states. When the source signal changes, the resource automatically
refetches.

This follows the leptos.rs Resource pattern for async data handling.

# Fields
- `id::UInt64`: Unique identifier for this resource
- `state::ResourceState`: Current state (pending, loading, ready, error)
- `data::Union{T, Nothing}`: The loaded data (nothing if not yet loaded or error)
- `error::Union{Exception, Nothing}`: The error if fetch failed
- `source::Any`: The source signal or function that triggers refetch
- `fetcher::Function`: The async function that fetches data
- `effect::Union{Effect, Nothing}`: The effect that tracks source changes
- `subscribers::Set{Any}`: Effects that depend on this resource

# Example
```julia
user_id, set_user_id = create_signal(1)

# Create a resource that fetches user data when user_id changes
user_resource = create_resource(
    () -> user_id(),
    id -> fetch_user(id)
)

# Check loading state
if user_resource.loading
    println("Loading...")
elseif user_resource.error !== nothing
    println("Error: ", user_resource.error)
else
    println("User: ", user_resource())
end
```
"""
mutable struct Resource{T}
    id::UInt64
    state::ResourceState
    data::Union{T, Nothing}
    error::Union{Exception, Nothing}
    source::Any
    fetcher::Function
    effect::Union{Effect, Nothing}
    subscribers::Set{Any}
end

# Global resource ID counter
const RESOURCE_ID_COUNTER = Ref{UInt64}(0)

function next_resource_id()::UInt64
    RESOURCE_ID_COUNTER[] += 1
    return RESOURCE_ID_COUNTER[]
end

"""
    loading(r::Resource) -> Bool

Check if the resource is currently loading.
"""
function loading(r::Resource)::Bool
    return r.state == RESOURCE_LOADING
end

"""
    ready(r::Resource) -> Bool

Check if the resource has data ready.
"""
function ready(r::Resource)::Bool
    return r.state == RESOURCE_READY
end

"""
    (r::Resource{T})() -> Union{T, Nothing}

Read the resource's data. Returns `nothing` if data is not yet loaded.
This also registers the current effect as a subscriber for reactivity.
"""
function (r::Resource{T})()::Union{T, Nothing} where T
    # Track dependency if inside an effect
    effect = current_effect()
    if effect !== nothing
        push!(r.subscribers, effect)
        push!(effect.dependencies, r)
    end
    return r.data
end

"""
    notify_resource_subscribers!(r::Resource)

Notify all subscribers that the resource state has changed.
"""
function notify_resource_subscribers!(r::Resource)
    for subscriber in r.subscribers
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

"""
    refetch!(r::Resource)

Manually trigger a refetch of the resource data.
"""
function refetch!(r::Resource{T}) where T
    # Get current source value
    source_value = if r.source isa Function
        try
            r.source()
        catch e
            nothing
        end
    else
        r.source
    end

    # Set to loading state and notify
    r.state = RESOURCE_LOADING
    r.error = nothing
    notify_resource_subscribers!(r)

    # Run the fetcher
    try
        result = r.fetcher(source_value)
        r.data = result
        r.state = RESOURCE_READY
        r.error = nothing
    catch e
        r.data = nothing
        r.state = RESOURCE_ERROR
        r.error = e isa Exception ? e : ErrorException(string(e))
    end

    # Notify subscribers of state change
    notify_resource_subscribers!(r)
end

"""
    create_resource(source, fetcher::Function) -> Resource{T}
    create_resource(fetcher::Function) -> Resource{T}

Create a new resource that fetches data using the fetcher function.
If a source is provided, the resource will automatically refetch whenever
the source signal changes.

# Arguments
- `source`: A function or signal that returns the argument for the fetcher.
            When this value changes, the resource automatically refetches.
- `fetcher`: A function that takes the source value and returns the data.
             Can be async in the future, but currently runs synchronously.

# Returns
A `Resource{T}` where T is inferred from the fetcher's return type.

# Examples
```julia
# Resource with reactive source
user_id, set_user_id = create_signal(1)
user = create_resource(() -> user_id(), id -> fetch_user(id))

# Later, changing user_id will trigger a refetch
set_user_id(2)

# Resource without source (one-time fetch)
config = create_resource(() -> nothing, _ -> load_config())

# Reading the resource
if user.loading
    "Loading..."
elseif user.error !== nothing
    "Error: \$(user.error)"
else
    "User: \$(user())"
end
```

# Notes
- The fetcher runs immediately when the resource is created
- When source changes, a new fetch is triggered automatically
- Use `refetch!(resource)` to manually trigger a reload
- The resource tracks effects that read from it and notifies them on state change
"""
function create_resource(source, fetcher::Function)
    # Create the resource with initial pending state
    # We use Any as the type parameter initially since we don't know T yet
    resource = Resource{Any}(
        next_resource_id(),
        RESOURCE_PENDING,
        nothing,
        nothing,
        source,
        fetcher,
        nothing,
        Set{Any}()
    )

    # Create an effect that tracks the source and triggers refetch
    effect = create_effect() do
        # Read from source to establish dependency
        source_value = if source isa Function
            source()
        else
            source
        end

        # Trigger fetch (this runs synchronously for now)
        # Set to loading state
        resource.state = RESOURCE_LOADING
        resource.error = nothing

        # Run the fetcher
        try
            result = fetcher(source_value)
            resource.data = result
            resource.state = RESOURCE_READY
            resource.error = nothing
        catch e
            resource.data = nothing
            resource.state = RESOURCE_ERROR
            resource.error = e isa Exception ? e : ErrorException(string(e))
        end

        # Notify subscribers of state change
        notify_resource_subscribers!(resource)
    end

    resource.effect = effect

    return resource
end

# Convenience method for resources without a reactive source
function create_resource(fetcher::Function)
    return create_resource(() -> nothing, _ -> fetcher())
end

"""
    dispose!(r::Resource)

Dispose of a resource, stopping it from tracking source changes.
"""
function dispose!(r::Resource)
    if r.effect !== nothing
        dispose!(r.effect)
        r.effect = nothing
    end
    # Clear subscribers
    for subscriber in r.subscribers
        if subscriber isa Effect
            delete!(subscriber.dependencies, r)
        end
    end
    empty!(r.subscribers)
end
