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
function client_router_script(; content_selector::String="#page-content", base_path::String="")
    RawHtml("""
<script>
// Therapy.jl Client-Side Router
(function() {
    'use strict';

    const CONFIG = {
        contentSelector: '$(content_selector)',
        basePath: '$(base_path)',
        partialHeader: 'X-Therapy-Partial',
        debug: true
    };

    console.log('[Router] Script loaded, initializing...');

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
        if (href.startsWith('/')) return href;
        if (href.startsWith('http://') || href.startsWith('https://')) {
            return new URL(href).pathname;
        }

        // Relative path - resolve against current location
        const base = window.location.pathname.replace(/\\/[^\\/]*\$/, '/');
        const resolved = new URL(href, window.location.origin + base).pathname;
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
        console.log('[Router] loadPage called with path:', path);

        const container = document.querySelector(CONFIG.contentSelector);
        console.log('[Router] Container found:', !!container, container?.tagName);
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
            console.log('[Router] Fetching:', path);
            const response = await fetch(path, {
                headers: {
                    [CONFIG.partialHeader]: '1',
                    'Accept': 'text/html'
                },
                credentials: 'same-origin',
                signal: abortController.signal
            });

            console.log('[Router] Fetch response:', response.status, response.ok);
            if (!response.ok) {
                throw new Error('HTTP ' + response.status);
            }

            let html = await response.text();
            console.log('[Router] Got HTML, length:', html.length);

            // Check if this navigation was cancelled while waiting for response
            if (abortController.signal.aborted) {
                return;
            }

            // Check if we got a full HTML document (static site) or partial content (dev server)
            // Full documents start with <!DOCTYPE or <html
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
            }

            // Swap content
            container.innerHTML = html;
            container.style.opacity = '1';

            // Clear current navigation tracker
            if (currentNavigation === abortController) {
                currentNavigation = null;
            }

            // Re-hydrate all islands in the new content
            await hydrateIslands();

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
            if (!componentName) continue;

            // Look for registered hydration function
            if (window.TherapyHydrate && typeof window.TherapyHydrate[componentName] === 'function') {
                try {
                    await window.TherapyHydrate[componentName]();
                    log('Hydrated island:', componentName);
                } catch (error) {
                    console.error('[Router] Failed to hydrate island:', componentName, error);
                }
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
        console.log('[Router] Click detected on:', event.target.tagName);

        // Find the closest anchor tag
        const link = event.target.closest('a[href]');
        if (!link) {
            console.log('[Router] No link found');
            return;
        }

        const href = link.getAttribute('href');
        console.log('[Router] Link href:', href);

        // Check if we should handle this link
        if (!isInternalLink(href, link)) {
            console.log('[Router] Not internal link, skipping');
            return;
        }

        console.log('[Router] Intercepting navigation to:', href);

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

        // Bind link click handler (delegation on document)
        document.addEventListener('click', handleLinkClick);

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
        updateActiveLinks
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

