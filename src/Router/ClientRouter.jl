# ClientRouter.jl - Client-side routing JavaScript generation
#
# Generates JavaScript for SPA-style navigation without page reloads.
# Matches Leptos-style client routing architecture.

"""
Generate the client-side router JavaScript.

The router:
- Intercepts internal link clicks
- Uses history.pushState for navigation
- Fetches partial page content (without layout)
- Re-hydrates islands after page swap
- Handles browser back/forward buttons
- Updates active link styling

# Arguments
- `content_selector`: CSS selector for the content container (default: "#therapy-content")
- `base_path`: Base path for the app (e.g., "/Therapy.jl" for GitHub Pages)
"""
function client_router_script(; content_selector::String="#therapy-content", base_path::String="")
    RawHtml("""
<script>
// Therapy.jl Client-Side Router
(function() {
    'use strict';

    const CONFIG = {
        contentSelector: '$(content_selector)',
        basePath: '$(base_path)',
        partialHeader: 'X-Therapy-Partial',
        // Enable debug logging - can be toggled via TherapyRouter.setDebug(true/false)
        debug: true
    };

    // Track current navigation to cancel on rapid clicks
    let currentNavigation = null;

    function log(...args) {
        if (CONFIG.debug) console.log('%c[Router]', 'color: #748ffc', ...args);
    }

    /**
     * Normalize a path by removing trailing slashes and adding leading slash
     */
    function normalizePath(path) {
        if (!path) return '/';
        path = path.replace(/\\/+\$/g, '') || '/';
        if (!path.startsWith('/')) path = '/' + path;
        return path;
    }

    /**
     * Check if a URL is internal (same origin, not a hash link, etc.)
     */
    function isInternalLink(href, link) {
        if (!href) return false;

        // Skip hash-only links
        if (href.startsWith('#')) return false;

        // Skip javascript: links
        if (href.startsWith('javascript:')) return false;

        // Skip links with download attribute
        if (link.hasAttribute('download')) return false;

        // Skip links targeting new window
        if (link.target === '_blank') return false;

        // Skip links with data-no-router
        if (link.hasAttribute('data-no-router')) return false;

        // External links (different origin)
        if (href.startsWith('http://') || href.startsWith('https://')) {
            try {
                const url = new URL(href);
                if (url.origin !== window.location.origin) return false;
            } catch (e) {
                return false;
            }
        }

        return true;
    }

    /**
     * Resolve a relative URL to absolute path
     */
    function resolveUrl(href) {
        log('resolveUrl input:', href);
        if (href.startsWith('/')) {
            log('resolveUrl: absolute path, returning as-is:', href);
            return href;
        }
        if (href.startsWith('http://') || href.startsWith('https://')) {
            const pathname = new URL(href).pathname;
            log('resolveUrl: full URL, extracted pathname:', pathname);
            return pathname;
        }

        // Relative path - resolve against CURRENT URL for navigation
        // This ensures ../ goes up from the current page, not from base path
        // Example: on /WasmTarget.jl/manual/, "../" should go to /WasmTarget.jl/
        const resolved = new URL(href, window.location.href).pathname;
        log('resolveUrl: relative path resolved:', href, '->', resolved);
        return resolved;
    }

    /**
     * Navigate to a new URL using client-side routing
     */
    async function navigate(href, options = {}) {
        const { replace = false, scroll = true } = options;

        const path = resolveUrl(href);
        log('Navigating to:', path);

        // Update browser history
        if (replace) {
            history.replaceState({ path }, '', path);
        } else {
            history.pushState({ path }, '', path);
        }

        // Load the page content
        await loadPage(path);

        // Scroll to top unless disabled
        if (scroll) {
            window.scrollTo({ top: 0, behavior: 'instant' });
        }

        // Update active link states
        updateActiveLinks();
    }

    /**
     * Fetch page content and swap it into the content container
     */
    async function loadPage(path) {
        const container = document.querySelector(CONFIG.contentSelector);
        if (!container) {
            console.error('[Router] Content container not found:', CONFIG.contentSelector);
            window.location.href = path;
            return;
        }

        // Cancel any in-flight navigation (handles rapid clicking)
        if (currentNavigation) {
            currentNavigation.abort();
            log('Cancelled previous navigation');
        }

        // Create new abort controller for this navigation
        const abortController = new AbortController();
        currentNavigation = abortController;

        // Show loading state (optional)
        container.style.opacity = '0.7';
        container.style.transition = 'opacity 0.1s';

        try {
            const response = await fetch(path, {
                headers: {
                    [CONFIG.partialHeader]: '1',
                    'Accept': 'text/html'
                },
                credentials: 'same-origin',
                signal: abortController.signal
            });

            if (!response.ok) {
                throw new Error('HTTP ' + response.status);
            }

            let html = await response.text();

            // Check if this navigation was cancelled while waiting for response
            if (abortController.signal.aborted) {
                return;
            }

            // Check if we got a full HTML document (static site) or partial content (dev server)
            // Full documents start with <!DOCTYPE or <html
            let scriptsToExecute = [];
            if (html.trim().toLowerCase().startsWith('<!doctype') || html.trim().toLowerCase().startsWith('<html')) {
                log('Got full page, extracting content...');
                // Parse the full document and extract just the content area
                const parser = new DOMParser();
                const doc = parser.parseFromString(html, 'text/html');
                const newContent = doc.querySelector(CONFIG.contentSelector);
                if (newContent) {
                    html = newContent.innerHTML;
                } else {
                    // Fallback: try to get body content
                    log('Content selector not found in response, using body');
                    html = doc.body ? doc.body.innerHTML : html;
                }

                // Extract hydration scripts from the body (they're outside #therapy-content)
                // These contain TherapyHydrate registration functions for islands
                const scripts = doc.querySelectorAll('body script:not([src])');
                log('Found', scripts.length, 'inline scripts in body');
                scripts.forEach((script, idx) => {
                    const content = script.textContent;
                    // Only collect Therapy-related scripts (safety check)
                    if (content && (content.includes('TherapyHydrate') || content.includes('TherapyWS'))) {
                        scriptsToExecute.push(content);
                        log('Script', idx, 'contains Therapy code, length:', content.length);
                    } else {
                        log('Script', idx, 'skipped, length:', content ? content.length : 0);
                    }
                });
                if (scriptsToExecute.length > 0) {
                    log('Collected', scriptsToExecute.length, 'hydration scripts to execute');
                } else {
                    log('WARNING: No hydration scripts found!');
                }
            }

            // Swap content
            container.innerHTML = html;
            container.style.opacity = '1';

            // Clear current navigation tracker
            if (currentNavigation === abortController) {
                currentNavigation = null;
            }

            // Execute any hydration scripts extracted from the full page
            // This registers TherapyHydrate functions before we try to call them
            // Set flag to prevent auto-hydration (router will call hydrateIslands)
            window._therapyRouterHydrating = true;
            for (const scriptContent of scriptsToExecute) {
                try {
                    const script = document.createElement('script');
                    script.textContent = scriptContent;
                    document.head.appendChild(script);
                    document.head.removeChild(script);
                    log('Executed hydration script');
                } catch (e) {
                    console.error('[Router] Failed to execute hydration script:', e);
                }
            }
            window._therapyRouterHydrating = false;

            // Re-hydrate all islands in the new content
            await hydrateIslands();

            // Re-run syntax highlighting for code blocks (Prism.js)
            if (typeof Prism !== 'undefined' && Prism.highlightAll) {
                Prism.highlightAll();
            }

            // Re-discover and subscribe to any new server signals in the content
            if (typeof TherapyWS !== 'undefined' && TherapyWS.discoverAndSubscribe) {
                TherapyWS.discoverAndSubscribe();
            }

            // Show static mode warnings on any new ws-example elements
            if (typeof TherapyWS !== 'undefined' && TherapyWS.showStaticModeWarningOnNewElements) {
                TherapyWS.showStaticModeWarningOnNewElements();
            }

            // Dispatch event for any listeners (e.g., Sessions.jl CodeMirror reinit)
            window.dispatchEvent(new CustomEvent('therapy:router:loaded', {
                detail: { path: path }
            }));

            // Call any registered post-navigation callbacks
            if (Array.isArray(window._therapyRouterCallbacks)) {
                for (const callback of window._therapyRouterCallbacks) {
                    try {
                        callback(path);
                    } catch (e) {
                        console.error('[Router] Post-navigation callback error:', e);
                    }
                }
            }

            log('Page loaded successfully');

        } catch (error) {
            // Ignore abort errors (expected when clicking fast)
            if (error.name === 'AbortError') {
                log('Navigation cancelled');
                return;
            }

            console.error('[Router] Failed to load page:', error);
            container.style.opacity = '1';

            // Clear current navigation tracker
            if (currentNavigation === abortController) {
                currentNavigation = null;
            }

            // Fallback to full page navigation
            window.location.href = path;
        }
    }

    /**
     * Re-hydrate all therapy-island components on the page
     */
    async function hydrateIslands() {
        const islands = document.querySelectorAll('therapy-island');
        log('Re-hydrating', islands.length, 'islands');

        for (const island of islands) {
            const componentName = island.dataset.component;
            if (!componentName) {
                console.warn('[Router] Found therapy-island without data-component attribute');
                continue;
            }

            // Registry uses lowercase keys (see Hydration.jl)
            const registryKey = componentName.toLowerCase();
            log('Looking for hydration function:', componentName, '-> registry key:', registryKey);
            log('TherapyHydrate registry:', window.TherapyHydrate ? Object.keys(window.TherapyHydrate) : 'undefined');

            // Look for registered hydration function (using lowercase key)
            if (window.TherapyHydrate && typeof window.TherapyHydrate[registryKey] === 'function') {
                try {
                    log('Calling hydration function for:', registryKey);
                    await window.TherapyHydrate[registryKey]();
                    log('Hydrated island:', componentName);
                } catch (error) {
                    console.error('[Router] Failed to hydrate island:', componentName, error);
                }
            } else {
                console.warn('[Router] No hydration function found for:', registryKey);
                console.warn('[Router] Available functions:', window.TherapyHydrate ? Object.keys(window.TherapyHydrate) : 'none');
            }
        }
    }

    /**
     * Update active class on navigation links
     */
    function updateActiveLinks() {
        const currentPath = normalizePath(window.location.pathname);

        document.querySelectorAll('[data-navlink]').forEach(link => {
            const href = link.getAttribute('href');
            if (!href) return;

            const linkPath = normalizePath(resolveUrl(href));
            const activeClassAttr = link.dataset.activeClass || 'active';
            // Split by spaces to handle multiple classes like "text-emerald-700 dark:text-emerald-400"
            const activeClasses = activeClassAttr.split(/\\s+/).filter(c => c.length > 0);
            const exact = link.hasAttribute('data-exact');

            let isActive;
            if (exact) {
                isActive = linkPath === currentPath;
            } else {
                // Prefix match for nested routes
                isActive = currentPath === linkPath ||
                          (linkPath !== '/' && currentPath.startsWith(linkPath + '/'));
            }

            if (isActive) {
                link.classList.add(...activeClasses);
            } else {
                link.classList.remove(...activeClasses);
            }
        });
    }

    /**
     * Handle click events on links
     */
    function handleLinkClick(event) {
        // Find the closest anchor tag
        const link = event.target.closest('a[href]');
        if (!link) return;

        const href = link.getAttribute('href');
        log('handleLinkClick: intercepted href=', href, 'from element:', link.tagName);

        // Check if we should handle this link
        if (!isInternalLink(href, link)) {
            log('handleLinkClick: not internal, skipping');
            return;
        }

        log('handleLinkClick: internal link, routing via SPA');

        // Prevent default navigation
        event.preventDefault();

        // Navigate using the router
        navigate(href);
    }

    /**
     * Handle browser back/forward buttons
     */
    function handlePopState(event) {
        const path = window.location.pathname;
        log('Popstate:', path);
        loadPage(path);
    }

    /**
     * Initialize the router
     */
    function init() {
        log('Initializing client-side router');

        // Bind link click handler (delegation on document, capture phase)
        document.addEventListener('click', handleLinkClick, true);

        // Bind popstate for back/forward
        window.addEventListener('popstate', handlePopState);

        // Update active links on initial load
        updateActiveLinks();

        log('Router initialized');
    }

    // Expose API for programmatic navigation
    window.TherapyRouter = {
        navigate,
        loadPage,
        hydrateIslands,
        updateActiveLinks,
        setDebug: (enabled) => { CONFIG.debug = enabled; },
        // Register a callback to run after each navigation
        onNavigate: (callback) => {
            if (!Array.isArray(window._therapyRouterCallbacks)) {
                window._therapyRouterCallbacks = [];
            }
            window._therapyRouterCallbacks.push(callback);
        }
    };

    // Initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
</script>
""")
end

