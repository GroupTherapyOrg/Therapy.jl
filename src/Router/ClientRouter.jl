# ClientRouter.jl - Astro-style View Transitions for islands architecture
#
# Intercepts internal link clicks, fetches the next page, swaps the body
# using the View Transitions API, and re-hydrates islands. Same pattern
# as Astro's `<ViewTransitions />` component (~3-4KB).
#
# This is NOT an SPA router — there's no client-side route table, no JS
# bundle containing all pages. Each page is independently server-rendered.
# The router just makes navigation smooth.

"""
Generate the client-side navigation script (Astro View Transitions pattern).

- Intercepts internal `<a>` clicks
- Fetches next page via `fetch()`
- Swaps `<body>` content using `document.startViewTransition()`
- Diffs `<head>` (updates title, meta, styles)
- Re-hydrates `<therapy-island>` components on the new page
- Handles browser back/forward via `popstate`
- Updates active link styling

# Arguments
- `content_selector`: CSS selector for the content container (default: "#therapy-content")
- `base_path`: Base path for the app (e.g., "/Therapy.jl" for GitHub Pages)
"""
function client_router_script(; content_selector::String="#therapy-content", base_path::String="")
    RawHtml("""
<script>
// Therapy.jl Navigation — Astro View Transitions pattern
(function() {
    'use strict';

    // Prevent re-execution during SPA navigation
    if (window.TherapyRouter) return;

    const CONFIG = {
        contentSelector: '$(content_selector)',
        basePath: '$(base_path)',
        debug: false
    };

    let currentNavigation = null;

    function log(...args) {
        if (CONFIG.debug) console.log('%c[Router]', 'color: #748ffc', ...args);
    }

    function normalizePath(path) {
        if (CONFIG.basePath && path.startsWith(CONFIG.basePath)) {
            path = path.slice(CONFIG.basePath.length) || '/';
        }
        return path.replace(/\\/+\$/, '') || '/';
    }

    function isInternalLink(href, link) {
        if (!href || href.startsWith('#') || href.startsWith('javascript:')) return false;
        if (link.hasAttribute('target') || link.hasAttribute('download')) return false;
        if (link.dataset.external === 'true') return false;
        try {
            const url = new URL(href, window.location.origin);
            return url.origin === window.location.origin;
        } catch { return false; }
    }

    function resolveUrl(href) {
        try {
            const url = new URL(href, window.location.origin);
            let path = url.pathname;
            if (!path.endsWith('/') && !path.includes('.')) path += '/';
            return path;
        } catch { return href; }
    }

    // ─── Head Diffing (Astro pattern) ─────────────────────────────────────
    // Update <title>, <meta>, and page-specific <link>/<style> tags
    function diffHead(newDoc) {
        // Update title
        const newTitle = newDoc.querySelector('title');
        if (newTitle) document.title = newTitle.textContent;

        // Update meta tags (description, og:*, etc.)
        const oldMetas = document.querySelectorAll('head meta[name], head meta[property]');
        const newMetas = newDoc.querySelectorAll('head meta[name], head meta[property]');
        const newMetaMap = new Map();
        newMetas.forEach(m => {
            const key = m.getAttribute('name') || m.getAttribute('property');
            if (key) newMetaMap.set(key, m);
        });
        oldMetas.forEach(m => {
            const key = m.getAttribute('name') || m.getAttribute('property');
            if (key && newMetaMap.has(key)) {
                const newMeta = newMetaMap.get(key);
                if (m.getAttribute('content') !== newMeta.getAttribute('content')) {
                    m.setAttribute('content', newMeta.getAttribute('content'));
                }
                newMetaMap.delete(key);
            }
        });
        // Add any new meta tags
        newMetaMap.forEach(m => document.head.appendChild(m.cloneNode(true)));
    }

    // ─── Navigation ───────────────────────────────────────────────────────
    async function navigate(href, options = {}) {
        const { replace = false, scroll = true } = options;
        const path = resolveUrl(href);
        log('Navigating to:', path);

        if (replace) {
            history.replaceState({ path }, '', path);
        } else {
            history.pushState({ path }, '', path);
        }

        await loadPage(path);

        if (scroll) window.scrollTo({ top: 0, behavior: 'instant' });
        updateActiveLinks();
    }

    // ─── Page Load + Swap ─────────────────────────────────────────────────
    async function loadPage(path) {
        const container = document.querySelector(CONFIG.contentSelector);
        if (!container) {
            window.location.href = path;
            return;
        }

        // Cancel in-flight navigation (rapid clicks)
        if (currentNavigation) {
            currentNavigation.abort();
            log('Cancelled previous navigation');
        }
        const abortController = new AbortController();
        currentNavigation = abortController;

        try {
            const response = await fetch(path, {
                headers: { 'Accept': 'text/html' },
                credentials: 'same-origin',
                signal: abortController.signal
            });
            if (!response.ok) throw new Error('HTTP ' + response.status);

            const html = await response.text();
            if (abortController.signal.aborted) return;

            // Parse the full document
            const parser = new DOMParser();
            const newDoc = parser.parseFromString(html, 'text/html');

            // Diff <head> (title, meta, styles)
            diffHead(newDoc);

            // Extract new content
            const newContent = newDoc.querySelector(CONFIG.contentSelector);
            const newHTML = newContent ? newContent.innerHTML
                : (newDoc.body ? newDoc.body.innerHTML : html);

            // Extract hydration scripts (island IIFEs)
            const scriptsToExecute = [];
            newDoc.querySelectorAll('body script:not([src])').forEach(script => {
                const content = script.textContent;
                if (content && (content.includes('therapy-island') ||
                    content.includes('TherapyHydrate') ||
                    content.includes('__therapy') ||
                    content.includes('__tw'))) {
                    scriptsToExecute.push(content);
                }
            });

            // Swap content — with View Transitions API if available
            const doSwap = () => {
                container.innerHTML = newHTML;

                // Execute hydration scripts
                for (const scriptContent of scriptsToExecute) {
                    try {
                        const script = document.createElement('script');
                        script.textContent = scriptContent;
                        document.head.appendChild(script);
                        document.head.removeChild(script);
                    } catch (e) {
                        console.error('[Router] Hydration script error:', e);
                    }
                }

                // Re-hydrate islands
                hydrateIslands();

                // Re-run syntax highlighting
                if (typeof Prism !== 'undefined' && Prism.highlightAll) Prism.highlightAll();

                // Update NavLink active classes on the FRESHLY-SWAPPED DOM.
                // Earlier the outer `navigate()` called this right after
                // `await loadPage(path)`, but under the View Transitions
                // API `document.startViewTransition(doSwap)` returns the
                // transition object synchronously and schedules doSwap for
                // the next frame — so `updateActiveLinks` ran against the
                // OLD DOM (old sidebar, old NavLinks) before the swap
                // landed, leaving the active-class in its pre-nav state
                // until a full page refresh rebuilt the sidebar at SSR.
                // Running it here (inside doSwap, post-innerHTML-swap)
                // means the same call lands on the new DOM regardless of
                // whether we went through the View Transitions path or
                // the fallback synchronous swap.
                updateActiveLinks();
            };

            if (document.startViewTransition) {
                document.startViewTransition(doSwap);
            } else {
                doSwap();  // Fallback: instant swap, no animation
            }

            if (currentNavigation === abortController) currentNavigation = null;
            log('Page loaded');

        } catch (error) {
            if (error.name === 'AbortError') return;
            console.error('[Router] Failed to load page:', error);
            if (currentNavigation === abortController) currentNavigation = null;
            window.location.href = path;  // Fallback to full navigation
        }
    }

    // ─── Island Hydration ─────────────────────────────────────────────────
    function hydrateIslands() {
        const islands = document.querySelectorAll('therapy-island:not([data-hydrated])');
        log('Hydrating', islands.length, 'new islands');

        islands.forEach(island => {
            const name = island.dataset.component;
            if (!name) return;

            const key = name.toLowerCase();

            if (window.TherapyHydrate && typeof window.TherapyHydrate[key] === 'function') {
                try {
                    window.TherapyHydrate[key]();
                    island.dataset.hydrated = 'true';
                    log('Hydrated:', name);
                } catch (e) {
                    console.error('[Router] Hydration failed:', name, e);
                }
            } else if (window.__hydrateTherapyIsland) {
                try {
                    window.__hydrateTherapyIsland(island);
                    log('Hydrated (v2):', name);
                } catch (e) {
                    console.error('[Router] V2 hydration failed:', name, e);
                }
            }
        });
    }

    // ─── Active Link Styling ──────────────────────────────────────────────
    function updateActiveLinks() {
        const currentPath = normalizePath(window.location.pathname);
        const basePath = normalizePath(CONFIG.basePath || '/');

        document.querySelectorAll('[data-navlink]').forEach(link => {
            const href = link.getAttribute('href');
            if (!href) return;

            const linkPath = normalizePath(resolveUrl(href));
            const activeClasses = (link.dataset.activeClass || 'active').split(/\\s+/).filter(c => c);
            const inactiveClasses = (link.dataset.inactiveClass || '').split(/\\s+/).filter(c => c);
            const exact = link.hasAttribute('data-exact');

            const isActive = exact
                ? linkPath === currentPath
                : currentPath === linkPath ||
                  (linkPath !== '/' && linkPath !== basePath && currentPath.startsWith(linkPath + '/'));

            if (isActive) {
                link.classList.add(...activeClasses);
                if (inactiveClasses.length) link.classList.remove(...inactiveClasses);
            } else {
                link.classList.remove(...activeClasses);
                if (inactiveClasses.length) link.classList.add(...inactiveClasses);
            }
        });
    }

    // ─── Event Handlers ───────────────────────────────────────────────────
    // Astro pattern: intercept clicks, but let hash-only links scroll natively
    function handleLinkClick(event) {
        const link = event.target.closest('a[href]');
        if (!link) return;

        const href = link.getAttribute('href');
        if (!isInternalLink(href, link)) return;

        // Astro samePage check: if navigating to #hash on the same page,
        // let the browser handle it natively (scroll to anchor). No fetch needed.
        try {
            const target = new URL(href, window.location.origin);
            const current = new URL(window.location.href);
            if (target.pathname === current.pathname && target.search === current.search && target.hash) {
                // Same page, just a hash change — browser handles scroll
                return;
            }
        } catch {}

        event.preventDefault();
        navigate(href);
    }

    function handlePopState() {
        loadPage(window.location.pathname);
    }

    // ─── Init ─────────────────────────────────────────────────────────────
    function init() {
        document.addEventListener('click', handleLinkClick, true);
        window.addEventListener('popstate', handlePopState);
        updateActiveLinks();
        log('Router initialized');
    }

    window.TherapyRouter = {
        navigate,
        hydrateIslands,
        updateActiveLinks,
        setDebug: (v) => { CONFIG.debug = v; }
    };

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
</script>
""")
end
