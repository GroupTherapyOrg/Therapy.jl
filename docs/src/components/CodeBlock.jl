# CodeBlock.jl - Syntax-highlighted code block component
#
# Uses Prism.js for syntax highlighting (loaded in App.jl)
# Supports: julia, bash, javascript, html, css

"""
    CodeBlock(code; lang="julia")

Render a syntax-highlighted code block using Prism.js.

# Arguments
- `code`: The source code to display
- `lang`: Language for syntax highlighting (default: "julia")
        Supported: julia, bash, javascript, js, html, css

# Examples
```julia
CodeBlock(\"\"\"
function hello()
    println("Hello!")
end
\"\"\")

CodeBlock("npm install", lang="bash")
```
"""
function CodeBlock(code::String; lang::String="julia")
    # Map common aliases
    language = if lang in ["js", "javascript"]
        "javascript"
    elseif lang in ["sh", "shell", "bash", "zsh"]
        "bash"
    else
        lang
    end

    Pre(:class => "rounded-lg overflow-x-auto my-4",
        Code(:class => "language-$language text-sm", code)
    )
end

# Convenience method for inline code
function InlineCode(text::String)
    Code(:class => "bg-neutral-200 dark:bg-neutral-700 px-1.5 py-0.5 rounded text-sm font-mono", text)
end
