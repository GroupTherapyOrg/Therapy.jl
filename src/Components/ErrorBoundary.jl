# ErrorBoundary.jl - Component that catches errors in children
# Follows the leptos.rs ErrorBoundary pattern

"""
    ErrorBoundaryNode

A virtual node representing an ErrorBoundary. When rendered:
- Tries to render children content
- If an error occurs, renders the fallback with error info
- Provides a reset mechanism to retry

This enables graceful error handling at component boundaries,
preventing a single error from crashing the entire application.
"""
struct ErrorBoundaryNode
    children::Any          # Content to render normally (VNode, Function, etc.)
    fallback::Any          # Function (error, reset) -> VNode to render on error
    error::Union{Exception, Nothing}  # Captured error, if any
    error_info::Union{String, Nothing}  # Additional error context
end

"""
    ErrorBoundaryContext

Context for tracking error state within an ErrorBoundary.
Allows nested components to propagate errors up to the boundary.
"""
struct ErrorBoundaryContext
    error_signal::Tuple{Any, Any}  # (getter, setter) for reactive error state
    boundary::Ref{Union{ErrorBoundaryNode, Nothing}}
end

# Global stack for tracking current error boundary during render
const ERROR_BOUNDARY_STACK = Vector{ErrorBoundaryContext}()

"""
    push_error_boundary!(ctx::ErrorBoundaryContext)

Push an error boundary context onto the stack during render.
"""
function push_error_boundary!(ctx::ErrorBoundaryContext)
    push!(ERROR_BOUNDARY_STACK, ctx)
end

"""
    pop_error_boundary!()

Pop the current error boundary context from the stack.
"""
function pop_error_boundary!()
    if !isempty(ERROR_BOUNDARY_STACK)
        pop!(ERROR_BOUNDARY_STACK)
    end
end

"""
    current_error_boundary()

Get the current error boundary context, or nothing if not inside an ErrorBoundary.
"""
function current_error_boundary()::Union{ErrorBoundaryContext, Nothing}
    return isempty(ERROR_BOUNDARY_STACK) ? nothing : last(ERROR_BOUNDARY_STACK)
end

"""
    throw_to_boundary(error::Exception)

Throw an error to the nearest ErrorBoundary.
If no boundary exists, the error propagates normally.
"""
function throw_to_boundary(error::Exception)
    ctx = current_error_boundary()
    if ctx !== nothing
        error_sig, set_error = ctx.error_signal
        set_error(error)
    else
        rethrow(error)
    end
end

"""
    ErrorBoundary(children; fallback) -> ErrorBoundaryNode
    ErrorBoundary(; fallback, children) -> ErrorBoundaryNode

Create an ErrorBoundary that catches errors from children and displays fallback UI.

Similar to Leptos's `<ErrorBoundary>` and React's `ErrorBoundary` class component.

# Arguments
- `children`: Function to render normally
- `fallback`: Function `(error, reset) -> VNode` to render when an error occurs
  - `error`: The caught exception
  - `reset`: A function that can be called to retry rendering children

# Examples

```julia
# Basic error handling with do-block
ErrorBoundary(
    fallback = (error, reset) -> Div(
        P("Something went wrong: ", string(error)),
        Button(:on_click => reset, "Try Again")
    )
) do
    DangerousComponent()
end

# Keyword argument style
ErrorBoundary(
    fallback = (e, r) -> P("Error"),
    children = () -> P("OK")
)

# With conditional fallback
ErrorBoundary(
    fallback = (error, reset) -> begin
        if error isa NetworkError
            P("Network error. ", Button(:on_click => reset, "Retry"))
        else
            P("Unexpected error: ", string(error))
        end
    end
) do
    FetchData()
end

# Nested error boundaries
ErrorBoundary(fallback = (e, r) -> P("App error")) do
    Header()
    ErrorBoundary(fallback = (e, r) -> P("Content error")) do
        MainContent()
    end
    Footer()
end
```

# How it works

1. When `ErrorBoundary` is rendered, it tries to evaluate children
2. If children throw an error, it's caught and stored
3. The fallback is rendered with the error and a reset function
4. Calling reset clears the error and re-renders children
5. Errors in event handlers are NOT caught (per React/Leptos convention)

# SSR Integration

During SSR:
- If children render successfully: children HTML is output
- If children throw: fallback HTML is output with error info
- Client hydration maintains the same error state

# Important Notes

- Only catches errors during render, not in event handlers
- Errors in the fallback itself will propagate up (or crash)
- Use nested ErrorBoundaries for granular error handling
"""
function ErrorBoundary(children::Function; fallback::Any)
    _make_error_boundary(children, fallback)
end

# Keyword-only syntax: ErrorBoundary(fallback=..., children=...)
function ErrorBoundary(; fallback::Any, children::Function)
    _make_error_boundary(children, fallback)
end

# Alternative constructor for cleaner syntax
function ErrorBoundary(fallback::Function, children::Function)
    _make_error_boundary(children, fallback)
end

# Internal implementation
function _make_error_boundary(children::Function, fallback::Any)
    # Create error tracking signal
    error_sig, set_error = create_signal(nothing)
    boundary_ref = Ref{Union{ErrorBoundaryNode, Nothing}}(nothing)
    ctx = ErrorBoundaryContext((error_sig, set_error), boundary_ref)

    # Reset function to clear error and retry
    reset_fn = () -> set_error(nothing)

    # Try to render children within error boundary context
    children_content = nothing
    caught_error::Union{Exception, Nothing} = nothing
    error_info::Union{String, Nothing} = nothing

    push_error_boundary!(ctx)
    try
        children_content = children()
    catch e
        caught_error = e
        error_info = string(e)
        # Don't rethrow - we caught it
    finally
        pop_error_boundary!()
    end

    # Create the node
    node = ErrorBoundaryNode(
        caught_error === nothing ? children_content : nothing,
        fallback,
        caught_error,
        error_info
    )

    boundary_ref[] = node
    return node
end

"""
    has_error(node::ErrorBoundaryNode) -> Bool

Check if the error boundary has caught an error.
"""
function has_error(node::ErrorBoundaryNode)::Bool
    return node.error !== nothing
end

"""
    get_error(node::ErrorBoundaryNode) -> Union{Exception, Nothing}

Get the caught error, or nothing if no error occurred.
"""
function get_error(node::ErrorBoundaryNode)::Union{Exception, Nothing}
    return node.error
end
