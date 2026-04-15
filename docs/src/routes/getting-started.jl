() -> begin
    card = "border border-warm-200 dark:border-warm-800 rounded-lg p-5 space-y-3"
    code_block = "bg-warm-900 dark:bg-warm-950 p-4 rounded text-sm font-mono overflow-x-auto"

    sections = [
        ("installation", "Installation"),
        ("project-structure", "Project Structure"),
        ("ssr-components", "SSR Components"),
        ("interactivity", "Adding Interactivity"),
        ("browser-apis", "Browser APIs"),
        ("running", "Running Your App"),
    ]

    PageWithTOC(sections, Div(:class => "space-y-10",
        H1(:class => "text-3xl font-serif font-bold text-warm-900 dark:text-warm-100", "Getting Started"),

        # ── Installation ──
        H2(:id => "installation", :class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Installation"),
        P(:class => "text-warm-600 dark:text-warm-400", "Therapy.jl requires Julia 1.12 (for WasmTarget.jl IR compatibility)."),
        Pre(:class => code_block, Code(:class => "language-julia", """using Pkg
Pkg.add(url="https://github.com/GroupTherapyOrg/Therapy.jl")""")),

        # ── Project Structure ──
        H2(:id => "project-structure", :class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Project Structure"),
        P(:class => "text-warm-600 dark:text-warm-400",
            "A Therapy.jl app uses file-based routing. Each file in ",
            Code(:class => "text-accent-500", "routes/"),
            " becomes a page. Components in ",
            Code(:class => "text-accent-500", "components/"),
            " are available to all pages."),
        Pre(:class => code_block, Code(:class => "language-julia", """my-app/
  app.jl               # Entry point
  routes/
    index.jl           # → /
    about.jl           # → /about
    examples/
      index.jl         # → /examples
  components/
    Counter.jl         # @island component (compiled to WASM)
    Layout.jl          # SSR layout wrapper""")),

        # ── SSR Components ──
        H2(:id => "ssr-components", :class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "SSR Components"),
        P(:class => "text-warm-600 dark:text-warm-400",
            "Components are plain Julia functions that return HTML elements. They run at ",
            Strong("build time"), " with full access to Julia packages. No macro needed."),
        Pre(:class => code_block, Code(:class => "language-julia", """# routes/index.jl — a simple page
() -> begin
    Div(
        H1("Hello, World!"),
        P("This is server-rendered at build time."),
        P("You can use any Julia package here — DataFrames, HTTP, etc.")
    )
end""")),

        # ── Interactive Islands ──
        H2(:id => "interactivity", :class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Adding Interactivity"),
        P(:class => "text-warm-600 dark:text-warm-400",
            "Use ", Code(:class => "text-accent-500", "@island"),
            " to make a component interactive. Island handlers, effects, and memos compile to WebAssembly via ",
            A(:href => "https://github.com/GroupTherapyOrg/WasmTarget.jl", :target => "_blank", :class => "text-accent-500 underline", "WasmTarget.jl"),
            ". Only islands ship WASM to the browser — everything else is static HTML."),
        Pre(:class => code_block, Code(:class => "language-julia", """# components/Counter.jl
@island function Counter(; initial::Int = 0)
    count, set_count = create_signal(initial)
    doubled = create_memo(() -> count() * 2)

    return Div(
        Button(:on_click => () -> set_count(count() - 1), "-"),
        Span(count),
        Button(:on_click => () -> set_count(count() + 1), "+"),
        P("doubled: ", doubled)
    )
end""")),
        P(:class => "text-sm text-warm-500 dark:text-warm-400",
            "Signals become WASM globals. Handlers become WASM exports. Effects and memos compile via ",
            Code(:class => "text-accent-500", "WasmTarget.compile_closure_body()"),
            ". The browser receives a tiny WASM module (1-12 KB per island)."),

        # ── Browser APIs ──
        H2(:id => "browser-apis", :class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Browser APIs"),
        P(:class => "text-warm-600 dark:text-warm-400",
            "Use ", Code(:class => "text-accent-500", "js()"),
            " to call browser APIs from WASM. Signal values are interpolated with ",
            Code(:class => "text-accent-500", raw"$1"), ", ",
            Code(:class => "text-accent-500", raw"$2"), ", etc."),
        Pre(:class => code_block, Code(:class => "language-julia", """# Console logging (re-runs on every signal change)
create_effect(() -> js("console.log('count:', \$1)", count()))

# DOM manipulation
js("document.documentElement.classList.toggle('dark')")

# localStorage
js("localStorage.setItem('key', \$1)", count())""")),

        # ── Running ──
        H2(:id => "running", :class => "text-xl font-semibold text-warm-800 dark:text-warm-200", "Running Your App"),
        Pre(:class => code_block, Code(:class => "language-bash", """# Development server with hot reload
julia +1.12 --project=. app.jl dev

# Build static site for deployment
julia +1.12 --project=. app.jl build

# Add --optim to either command to run Binaryen wasm-opt trim + dead-code
# elimination on every island. Slower to build, substantially smaller WASM.
julia +1.12 --project=. app.jl dev --optim
julia +1.12 --project=. app.jl build --optim""")),
        P(:class => "text-warm-600 dark:text-warm-400",
            "The dev server compiles islands on the fly and serves pages with hot reload. ",
            "The build command generates static HTML + WASM files ready for deployment to GitHub Pages, Netlify, or any static host.")
    ))
end
