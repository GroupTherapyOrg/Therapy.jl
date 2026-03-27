module Therapy

# Core Reactivity
include("Reactivity/Types.jl")
include("Reactivity/Context.jl")
include("Reactivity/Effect.jl")
include("Reactivity/Memo.jl")
include("Reactivity/Signal.jl")
include("Reactivity/Resource.jl")
include("Reactivity/JsInterop.jl")

# DOM
include("DOM/VNode.jl")
include("DOM/Elements.jl")
include("DOM/Events.jl")

# Components
include("Components/Props.jl")
include("Components/Component.jl")
include("Components/Island.jl")
include("Components/Lifecycle.jl")
include("Components/Suspense.jl")
include("Components/ErrorBoundary.jl")

# SSR
include("SSR/Render.jl")

# External Library Support (depends on SSR/Render.jl for RawHtml)
include("Components/ExternalLibrary.jl")

# Router
include("Router/Router.jl")

# Tailwind
include("Styles/Tailwind.jl")

# Server
include("Server/DevServer.jl")
include("Server/WebSocket.jl")
include("Server/WebSocketClient.jl")

# Compiler
include("Compiler/Compile.jl")

# Static Site Generator
include("SSG/StaticSite.jl")

# Plotting (PlotlyBase-compatible API)
include("Plotting/Plotting.jl")

# App Framework
include("App/App.jl")

# Exports - Reactivity
export create_signal, create_effect, create_memo, on_mount, batch, dispose!, js
export create_compilable_signal, CompilableSignal, CompilableSetter
export BindBool, BindModal, ShowDescendants

# Exports - Resource (async data primitives)
export Resource, ResourceState, create_resource, refetch!, loading, ready
export RESOURCE_PENDING, RESOURCE_LOADING, RESOURCE_READY, RESOURCE_ERROR

# Exports - Suspense (async loading boundaries)
export Suspense, SuspenseNode, SuspenseContext, Await
export register_resource!, current_suspense_context

# Exports - ErrorBoundary (error handling)
export ErrorBoundary, ErrorBoundaryNode, ErrorBoundaryContext
export has_error, get_error, throw_to_boundary
export current_error_boundary

# Exports - Context API (leptos-style component data sharing)
export Context, ContextProvider
export provide_context, use_context, use_context_signal
export push_context_scope!, pop_context_scope!, set_context_value!, get_context_value
export push_symbol_context_scope!, pop_symbol_context_scope!

# Exports - DOM Elements (Capitalized like JSX)
export VNode, Fragment, Show, For, ForNode, RawHtml
export Div, Span, P, A, Button, Input, Form, Label, Br, Hr
export H1, H2, H3, H4, H5, H6, Strong, Em, Code, Pre, Blockquote
export Ul, Ol, Li, Dl, Dt, Dd
export Table, Thead, Tbody, Tfoot, Tr, Th, Td, Caption
export Img, Video, Audio, Source, Iframe
export Header, Footer, Nav, MainEl, Section, Article, Aside
export Details, Summary, Figure, Figcaption
export Textarea, Select, Option, Fieldset, Legend
export Script, Style, Meta
export Svg, Path, Circle, Rect, Line, Polygon, Polyline, Text, G, Defs, Use

# Exports - Components (DEPRECATED: use plain functions + @island instead)
# component, Props, get_prop, get_children removed from exports in T27.
# Still accessible as Therapy.component etc. for backward compat during transition.
export render_component

# Exports - Islands (interactive components compiled to JavaScript)
export @island, island, IslandDef, IslandVNode, ChildrenSlot, get_islands, clear_islands!, is_island

# Exports - Lifecycle
export on_mount, on_cleanup

# Exports - External Libraries
export register_external_library, external_library_script, register_codemirror_pluto
export ExternalLibraryConfig, EXTERNAL_LIBRARIES

# Exports - SSR
export render_to_string, render_page

# Exports - Router
export create_router, match_route, handle_request, NavLink, router_script, print_routes
export client_router_script  # Client-side routing

# Exports - Router Hooks (reactive route access)
export use_params, use_query, use_location
export set_route_params!, set_route_query!, set_route_path!
export parse_query_string, encode_uri_component, decode_uri_component
export RouteParams, RouteQuery

# Exports - Nested Routing (Outlet)
export Outlet, OutletNode, OutletContext
export with_outlet_context, set_outlet_child!, current_outlet_context
export NestedRoute, match_nested_route, render_nested_routes

# Exports - Tailwind
export tailwind_cdn, tailwind_config, build_tailwind_css
export ensure_tailwind_input

# Exports - Server
export serve, serve_static

# Exports - WebSocket
export handle_websocket, websocket_client_script
export on_ws_connect, on_ws_disconnect
export broadcast_all, send_ws_message
export ws_connection_count, ws_connection_ids
export WSConnection, WS_CONNECTIONS

# Exports - Compiler
export compile_component, compile_and_serve, compile_island
export IslandJSOutput
export signal_runtime_js, signal_runtime_script
export compute_position, SIDE_BOTTOM, SIDE_TOP, SIDE_RIGHT, SIDE_LEFT
export ALIGN_START, ALIGN_CENTER, ALIGN_END, VIEWPORT_PAD

# Exports - Static Site Generator
export SiteConfig, PageRoute, BuildResult, build_static_site

# Exports - App Framework
export App, InteractiveComponent
export dev, build, run

# Module initialization
# PlotlyBase compilations are registered by TherapyPlotlyBaseExt (package extension)
function __init__()
end

end # module
