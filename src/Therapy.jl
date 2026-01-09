module Therapy

# Core Reactivity
include("Reactivity/Types.jl")
include("Reactivity/Context.jl")
include("Reactivity/Effect.jl")
include("Reactivity/Memo.jl")
include("Reactivity/Signal.jl")

# DOM
include("DOM/VNode.jl")
include("DOM/Elements.jl")
include("DOM/Events.jl")

# Components
include("Components/Props.jl")
include("Components/Component.jl")
include("Components/Island.jl")
include("Components/Lifecycle.jl")

# SSR
include("SSR/Render.jl")

# Router
include("Router/Router.jl")

# Tailwind
include("Styles/Tailwind.jl")

# Server
include("Server/DevServer.jl")

# Compiler
include("Compiler/Compile.jl")

# Static Site Generator
include("SSG/StaticSite.jl")

# App Framework
include("App/App.jl")

# Exports - Reactivity
export create_signal, create_effect, create_memo, batch, dispose!
export create_compilable_signal, CompilableSignal, CompilableSetter

# Exports - DOM Elements (Capitalized like JSX)
export VNode, Fragment, Show, RawHtml
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

# Exports - SSR
export render_to_string, render_page

# Exports - Router
export create_router, match_route, handle_request, NavLink, router_script, print_routes

# Exports - Tailwind
export tailwind_cdn, tailwind_config

# Exports - Server
export serve, serve_static

# Exports - Compiler
export compile_component, compile_and_serve, compile_multi

# Exports - Static Site Generator
export SiteConfig, PageRoute, BuildResult, build_static_site

# Exports - App Framework
export App, InteractiveComponent
export dev, build, run

end # module
