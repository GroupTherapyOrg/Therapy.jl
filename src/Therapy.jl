module Therapy

# Core Reactivity
include("Reactivity/Types.jl")
include("Reactivity/Context.jl")
include("Reactivity/Effect.jl")
include("Reactivity/Memo.jl")
include("Reactivity/Signal.jl")
include("Reactivity/Resource.jl")

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
include("Server/JSONPatch.jl")
include("Server/ServerFunctions.jl")

# Server Signals (depends on Server/WebSocket.jl and JSONPatch.jl)
include("Reactivity/ServerSignal.jl")
include("Reactivity/BidirectionalSignal.jl")
include("Reactivity/Channel.jl")

# Compiler
include("Compiler/Compile.jl")

# Static Site Generator
include("SSG/StaticSite.jl")

# App Framework
include("App/App.jl")

# Exports - Reactivity
export create_signal, create_effect, create_memo, batch, dispose!
export create_compilable_signal, CompilableSignal, CompilableSetter

# Exports - Resource (async data primitives)
export Resource, ResourceState, create_resource, refetch!, loading, ready
export RESOURCE_PENDING, RESOURCE_LOADING, RESOURCE_READY, RESOURCE_ERROR

# Exports - Suspense (async loading boundaries)
export Suspense, SuspenseNode, SuspenseContext, Await
export register_resource!, current_suspense_context

# Exports - Context API (leptos-style component data sharing)
export Context, ContextProvider
export provide_context, use_context
export push_context_scope!, pop_context_scope!, set_context_value!, get_context_value

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

# Exports - Components
export component, Props, get_prop, get_children, render_component

# Exports - Islands (interactive components compiled to Wasm)
export island, IslandDef, IslandVNode, get_islands, clear_islands!, is_island

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

# Exports - Tailwind
export tailwind_cdn, tailwind_config

# Exports - Server
export serve, serve_static

# Exports - WebSocket
export handle_websocket, websocket_client_script
export on_ws_connect, on_ws_disconnect
export broadcast_signal_update, broadcast_signal_patch, broadcast_signal_patch_except, broadcast_all
export compute_patch, apply_patch  # JSON Patch utilities
export ws_connection_count, ws_connection_ids
export WSConnection, WS_CONNECTIONS

# Exports - Server Signals
export ServerSignal, create_server_signal
export set_server_signal!, get_server_signal, update_server_signal!
export get_server_signal_by_name, list_server_signals, delete_server_signal!

# Exports - Bidirectional Signals
export BidirectionalSignal, create_bidirectional_signal
export set_bidirectional_signal!, get_bidirectional_signal, update_bidirectional_signal!
export on_bidirectional_update, handle_client_signal_update
export get_bidirectional_signal_by_name, list_bidirectional_signals, delete_bidirectional_signal!

# Exports - Channels
export Channel, create_channel, on_channel_message, handle_channel_message
export broadcast_channel!, send_channel!, broadcast_channel_except!
export get_channel, list_channels, delete_channel!

# Exports - Server Functions (RPC)
export ServerFunction, register_server_function, unregister_server_function
export list_server_functions, get_server_function
export handle_server_function_call, server_functions_client_script
export @server, generate_client_stub, server_function_stubs_script

# Exports - Compiler
export compile_component, compile_and_serve, compile_multi

# Exports - Static Site Generator
export SiteConfig, PageRoute, BuildResult, build_static_site

# Exports - App Framework
export App, InteractiveComponent
export dev, build, run

end # module
