# Suspense.jl - Component that shows fallback while children are loading
# Follows the leptos.rs Suspense pattern

"""
    SuspenseNode

A virtual node representing a Suspense boundary. When rendered:
- Shows the fallback content while any tracked Resources are loading
- Shows the children content when all Resources are ready

This enables async data loading patterns where loading states are
handled declaratively at component boundaries.
"""
struct SuspenseNode
    fallback::Any       # Content to show while loading (VNode, Function, etc.)
    children::Any       # Content to show when loaded (VNode, Function, etc.)
    resources::Vector{Resource}  # Resources being tracked for loading state
    initial_loading::Bool  # Whether initially in loading state
end

"""
    SuspenseContext

Context type for tracking Resources within a Suspense boundary.
Components can register their Resources with the nearest Suspense
ancestor so loading states are properly tracked.
"""
struct SuspenseContext
    resources::Vector{Resource}
    loading_signal::Tuple{Any, Any}  # (getter, setter) for reactive loading state
end

# Global for tracking current suspense context during render
const SUSPENSE_CONTEXT_STACK = Vector{SuspenseContext}()

"""
    push_suspense_context!(ctx::SuspenseContext)

Push a new suspense context onto the stack during render.
"""
function push_suspense_context!(ctx::SuspenseContext)
    push!(SUSPENSE_CONTEXT_STACK, ctx)
end

"""
    pop_suspense_context!()

Pop the current suspense context from the stack.
"""
function pop_suspense_context!()
    if !isempty(SUSPENSE_CONTEXT_STACK)
        pop!(SUSPENSE_CONTEXT_STACK)
    end
end

"""
    current_suspense_context()

Get the current suspense context, or nothing if not inside a Suspense boundary.
"""
function current_suspense_context()::Union{SuspenseContext, Nothing}
    return isempty(SUSPENSE_CONTEXT_STACK) ? nothing : last(SUSPENSE_CONTEXT_STACK)
end

"""
    register_resource!(resource::Resource)

Register a Resource with the current Suspense boundary.
Called automatically when a Resource is read during render.
"""
function register_resource!(resource::Resource)
    ctx = current_suspense_context()
    if ctx !== nothing && !(resource in ctx.resources)
        push!(ctx.resources, resource)
    end
end

"""
    is_any_loading(resources::Vector{Resource}) -> Bool

Check if any of the tracked resources are in a loading state.
"""
function is_any_loading(resources::Vector{Resource})::Bool
    for r in resources
        if loading(r)
            return true
        end
    end
    return false
end

"""
    Suspense(children; fallback=nothing) -> SuspenseNode

Create a Suspense boundary that shows fallback content while any child
Resources are loading, and shows children when loaded.

Similar to Leptos's `<Suspense>` and React's `<Suspense>` components.

# Arguments
- `children`: Function or VNode to render when all Resources are ready
- `fallback`: Function or VNode to render while any Resource is loading (default: nothing)

# Examples

```julia
# Basic usage with fallback
user_resource = create_resource(() -> fetch_user(user_id()))

Suspense(fallback = () -> P("Loading user...")) do
    UserCard(user = user_resource())
end

# Multiple resources
posts_resource = create_resource(() -> fetch_posts())
comments_resource = create_resource(() -> fetch_comments())

Suspense(fallback = () -> Div(:class => "spinner", "Loading...")) do
    Div(
        PostList(posts = posts_resource()),
        CommentList(comments = comments_resource())
    )
end

# Nested Suspense for granular loading states
Suspense(fallback = () -> P("Loading page...")) do
    Header(user = user_resource()),
    Suspense(fallback = () -> P("Loading posts...")) do
        PostList(posts = posts_resource())
    end
end
```

# How it works

1. When `Suspense` is rendered, it creates a context for tracking Resources
2. As children render and read from Resources, those Resources are registered
3. If any registered Resource is loading, the fallback is shown
4. When all Resources are ready, children are shown
5. The Suspense re-renders when Resource states change (via effect tracking)

# SSR Integration

During SSR:
- If all Resources are ready: children are rendered to HTML
- If any Resource is loading: fallback is rendered to HTML
- Client hydration will update the DOM when Resources finish loading
"""
function Suspense(children::Function; fallback::Any = nothing)
    # Create a context to track resources during children evaluation
    resources = Resource[]
    loading_sig, set_loading = create_signal(false)
    ctx = SuspenseContext(resources, (loading_sig, set_loading))

    # Push context and evaluate children to discover resources
    push_suspense_context!(ctx)
    children_content = try
        children()
    finally
        pop_suspense_context!()
    end

    # Check initial loading state
    initial_loading = is_any_loading(resources)

    # Set up an effect to track loading state changes (for client-side reactivity)
    if !isempty(resources)
        create_effect() do
            # Track all resource states
            any_loading = false
            for r in resources
                # Reading the resource registers the effect as a subscriber
                _ = r()  # This establishes dependency tracking
                if loading(r)
                    any_loading = true
                end
            end
            set_loading(any_loading)
        end
    end

    # Create the SuspenseNode
    SuspenseNode(
        fallback,
        children_content,
        resources,
        initial_loading
    )
end

# Alternative syntax: Suspense(fallback, children)
function Suspense(fallback::Any, children::Function)
    Suspense(children; fallback = fallback)
end

"""
    Await(resource::Resource, children::Function; fallback=nothing) -> SuspenseNode

Convenience wrapper around Suspense for a single Resource.
Shows fallback while the resource loads, then renders children with the data.

# Examples

```julia
user = create_resource(() -> fetch_user(1))

Await(user; fallback = () -> P("Loading...")) do data
    P("Hello, ", data.name)
end
```
"""
function Await(children::Function, resource::Resource; fallback::Any = nothing)
    Suspense(fallback = fallback) do
        data = resource()
        if data !== nothing
            children(data)
        else
            nothing
        end
    end
end

# Alternative syntax: Await(resource, children)
function Await(resource::Resource, children::Function; fallback::Any = nothing)
    Await(children, resource; fallback = fallback)
end
