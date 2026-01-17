# ExternalLibrary.jl - Pattern for integrating external JavaScript libraries
#
# Leptos-style approach: Define what JS is needed, Therapy.jl generates the glue code.
# This keeps external library initialization in Therapy.jl, not scattered in apps.

using JSON3

"""
    ExternalLibraryConfig

Configuration for an external JavaScript library integration.
"""
struct ExternalLibraryConfig
    name::Symbol
    import_url::String
    init_selector::String  # CSS selector for elements to initialize
    init_script::String    # JS code to run for each matched element
    reinit_on_navigate::Bool  # Whether to reinit after SPA navigation
end

# Registry of external libraries
const EXTERNAL_LIBRARIES = Dict{Symbol, ExternalLibraryConfig}()

"""
    register_external_library(name, import_url, init_selector, init_script; reinit_on_navigate=true)

Register an external JavaScript library for use in Therapy.jl apps.

# Example: CodeMirror
```julia
register_external_library(
    :CodeMirror,
    "https://cdn.jsdelivr.net/gh/JuliaPluto/codemirror-pluto-setup@0.19.3/dist/index.es.min.js",
    "[data-codemirror]",
    \"\"\"
    async function(el) {
        const CM = await import('codemirror-pluto');
        const code = el.dataset.code || '';
        const view = new CM.EditorView({
            state: CM.EditorState.create({ doc: code, extensions: [...] }),
            parent: el
        });
        el._cmView = view;
    }
    \"\"\";
    reinit_on_navigate = true
)
```
"""
function register_external_library(
    name::Symbol,
    import_url::String,
    init_selector::String,
    init_script::String;
    reinit_on_navigate::Bool=true
)
    EXTERNAL_LIBRARIES[name] = ExternalLibraryConfig(
        name,
        import_url,
        init_selector,
        init_script,
        reinit_on_navigate
    )
end

"""
    external_library_script(libs::Vector{Symbol}=Symbol[])

Generate JavaScript to initialize registered external libraries.
If `libs` is empty, initializes all registered libraries.
"""
function external_library_script(libs::Vector{Symbol}=Symbol[])
    configs = isempty(libs) ?
        collect(values(EXTERNAL_LIBRARIES)) :
        [EXTERNAL_LIBRARIES[lib] for lib in libs if haskey(EXTERNAL_LIBRARIES, lib)]

    if isempty(configs)
        return RawHtml("")
    end

    # Build import map entries
    imports = Dict{String, String}()
    for config in configs
        imports[string(config.name)] = config.import_url
    end
    imports_json = JSON3.write(imports)

    # Build init code for each library
    init_blocks = String[]
    reinit_selectors = String[]

    for config in configs
        push!(init_blocks, """
        // Initialize $(config.name)
        (async function() {
            const initFn = $(config.init_script);
            document.querySelectorAll('$(config.init_selector)').forEach(async function(el) {
                if (el._therapyLibInitialized) return;
                el._therapyLibInitialized = true;
                try {
                    await initFn(el);
                } catch (e) {
                    console.error('[Therapy] $(config.name) init error:', e);
                }
            });
        })();
        """)

        if config.reinit_on_navigate
            push!(reinit_selectors, config.init_selector)
        end
    end

    # Generate the complete script
    RawHtml("""
<script type="importmap">
{
    "imports": $imports_json
}
</script>
<script type="module">
// Therapy.jl External Library Initialization
(function() {
    'use strict';

    async function initAllLibraries() {
        $(join(init_blocks, "\n\n"))
    }

    // Initialize on page load
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initAllLibraries);
    } else {
        initAllLibraries();
    }

    // Reinitialize after SPA navigation
    window.addEventListener('therapy:router:loaded', function() {
        initAllLibraries();
    });

    // Expose reinit function
    window.TherapyExternalLibs = {
        reinit: initAllLibraries
    };
})();
</script>
""")
end

# Pre-register CodeMirror with Pluto's julia_andrey syntax
function register_codemirror_pluto()
    register_external_library(
        :CodeMirror,
        "https://cdn.jsdelivr.net/gh/JuliaPluto/codemirror-pluto-setup@0.19.3/dist/index.es.min.js",
        "[data-codemirror]",
        """
        async function(el) {
            const CM = await import('https://cdn.jsdelivr.net/gh/JuliaPluto/codemirror-pluto-setup@0.19.3/dist/index.es.min.js');
            const code = el.dataset.code || el.textContent || '';
            const cellId = el.dataset.cellId || '';

            // Clear existing content
            el.textContent = '';

            // Build extensions
            const extensions = [];
            if (CM.pluto_syntax_colors) extensions.push(CM.pluto_syntax_colors());
            else if (CM.julia_andrey) extensions.push(CM.julia_andrey());

            if (CM.lineNumbers) extensions.push(CM.lineNumbers());
            if (CM.highlightSpecialChars) extensions.push(CM.highlightSpecialChars());
            if (CM.history) extensions.push(CM.history());
            if (CM.drawSelection) extensions.push(CM.drawSelection());
            if (CM.indentOnInput) extensions.push(CM.indentOnInput());
            if (CM.bracketMatching) extensions.push(CM.bracketMatching());
            if (CM.closeBrackets) extensions.push(CM.closeBrackets());
            if (CM.highlightSelectionMatches) extensions.push(CM.highlightSelectionMatches());
            if (CM.EditorView && CM.EditorView.lineWrapping) extensions.push(CM.EditorView.lineWrapping);
            if (CM.foldGutter) extensions.push(CM.foldGutter());

            // Keymaps
            const keymaps = [];
            if (CM.defaultKeymap) keymaps.push(...CM.defaultKeymap);
            if (CM.historyKeymap) keymaps.push(...CM.historyKeymap);
            if (CM.closeBracketsKeymap) keymaps.push(...CM.closeBracketsKeymap);

            // Shift+Enter and Cmd/Ctrl+Enter to execute
            // Use window.executeCell if available (Sessions.jl provides this)
            // Otherwise fall back to direct TherapyWS call
            keymaps.push({
                key: 'Shift-Enter',
                run: function() {
                    if (cellId) {
                        if (window.executeCell) {
                            // Use Sessions.jl's executeCell which has the correct notebook context
                            window.executeCell(cellId);
                        } else if (window.TherapyWS && window.TherapyWS.sendMessage) {
                            // Fallback for non-Sessions.jl apps
                            const code = el._cmView.state.doc.toString();
                            window.TherapyWS.sendMessage('execute', {
                                cell_id: cellId,
                                code: code
                            });
                        }
                    }
                    return true;
                }
            });
            keymaps.push({
                key: 'Mod-Enter',
                run: function() {
                    if (cellId) {
                        if (window.executeCell) {
                            window.executeCell(cellId);
                        } else if (window.TherapyWS && window.TherapyWS.sendMessage) {
                            const code = el._cmView.state.doc.toString();
                            window.TherapyWS.sendMessage('execute', {
                                cell_id: cellId,
                                code: code
                            });
                        }
                    }
                    return true;
                }
            });

            if (CM.keymap) extensions.push(CM.keymap.of(keymaps));

            // Track dirty state
            if (CM.EditorView && CM.EditorView.updateListener) {
                const initialCode = code;
                extensions.push(CM.EditorView.updateListener.of(function(update) {
                    if (update.docChanged) {
                        const currentCode = update.state.doc.toString();
                        const isDirty = currentCode !== initialCode;
                        const indicator = el.closest('.cell')?.querySelector('.dirty-indicator');
                        if (indicator) {
                            indicator.classList.toggle('hidden', !isDirty);
                            indicator.classList.toggle('bg-yellow-500', isDirty);
                        }
                    }
                }));
            }

            // Create editor
            const view = new CM.EditorView({
                state: CM.EditorState.create({
                    doc: code,
                    extensions: extensions
                }),
                parent: el
            });

            el._cmView = view;
            el._cmInitialCode = code;

            console.log('[Therapy] CodeMirror initialized for:', cellId || 'element');
        }
        """;
        reinit_on_navigate = true
    )
end
