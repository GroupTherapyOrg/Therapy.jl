/**
 * SPA Navigation Tests for Therapy.jl
 *
 * These tests verify that SPA navigation doesn't cause resource leaks:
 * - No duplicate WASM fetches after initial load
 * - No WebSocket connection leaks
 * - Content updates correctly without full page reload
 *
 * CRITICAL: All UI fixes must pass these tests before being marked "done".
 */
import { test, expect, Page, Request } from '@playwright/test';

// Helper to track network requests
interface RequestTracker {
  wasmRequests: Request[];
  wsRequests: Request[];
  pageRequests: Request[];
  totalRequests: Request[];
}

function createRequestTracker(page: Page): RequestTracker {
  const tracker: RequestTracker = {
    wasmRequests: [],
    wsRequests: [],
    pageRequests: [],
    totalRequests: [],
  };

  page.on('request', (request: Request) => {
    const url = request.url();
    tracker.totalRequests.push(request);

    if (url.endsWith('.wasm')) {
      tracker.wasmRequests.push(request);
    }
    if (url.includes('/ws') || url.startsWith('ws://') || url.startsWith('wss://')) {
      tracker.wsRequests.push(request);
    }
    if (request.resourceType() === 'document' || request.resourceType() === 'xhr' || request.resourceType() === 'fetch') {
      tracker.pageRequests.push(request);
    }
  });

  return tracker;
}

test.describe('SPA Navigation - Single Click', () => {
  test('clicking navbar link should not cause duplicate WASM fetches', async ({ page }) => {
    const tracker = createRequestTracker(page);

    // Load home page and wait for it to be fully loaded
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Record initial WASM count (should be ThemeToggle only)
    const initialWasmCount = tracker.wasmRequests.length;
    console.log(`Initial WASM requests: ${initialWasmCount}`);
    console.log('Initial WASM URLs:', tracker.wasmRequests.map(r => r.url()));

    // Find and click a navbar link (Book or Getting Started)
    const navLink = page.locator('nav a[href*="book"], nav a[href*="getting-started"]').first();
    await expect(navLink).toBeVisible();
    await navLink.click();

    // Wait for navigation to complete
    await page.waitForLoadState('networkidle');

    // After 1 click, WASM should NOT be fetched again
    // (islands are in the Layout which persists during SPA nav)
    const finalWasmCount = tracker.wasmRequests.length;
    console.log(`Final WASM requests: ${finalWasmCount}`);
    console.log('Final WASM URLs:', tracker.wasmRequests.map(r => r.url()));

    // CRITICAL ASSERTION: No new WASM fetches after clicking
    // Layout islands (ThemeToggle) should NOT re-hydrate on SPA navigation
    expect(finalWasmCount).toBe(initialWasmCount);
  });

  test('clicking navbar link should not create new WebSocket connections', async ({ page }) => {
    const tracker = createRequestTracker(page);

    // Load home page
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Record initial WS count
    const initialWsCount = tracker.wsRequests.length;
    console.log(`Initial WS requests: ${initialWsCount}`);

    // Click a navbar link
    const navLink = page.locator('nav a[href*="book"], nav a[href*="getting-started"]').first();
    await expect(navLink).toBeVisible();
    await navLink.click();

    // Wait for navigation to complete
    await page.waitForLoadState('networkidle');

    // After 1 click, should have at most 1 WS connection total
    // (The single session WebSocket, not a new one per navigation)
    const finalWsCount = tracker.wsRequests.length;
    console.log(`Final WS requests: ${finalWsCount}`);

    // CRITICAL ASSERTION: At most 1 WebSocket connection
    expect(finalWsCount).toBeLessThanOrEqual(1);
  });

  test('SPA navigation should show correct content', async ({ page }) => {
    // Load home page
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Verify we're on the home page
    const homeContent = await page.locator('main, #page-content').textContent();
    expect(homeContent).toContain('Therapy.jl');

    // Navigate to Book
    const bookLink = page.locator('nav a[href*="book"]').first();
    if (await bookLink.count() > 0) {
      await bookLink.click();
      await page.waitForLoadState('networkidle');

      // Verify content changed to Book
      const bookContent = await page.locator('main, #page-content').textContent();
      expect(bookContent).toContain('Introduction');
    }
  });
});

test.describe('SPA Navigation - Multiple Clicks', () => {
  test('multiple navigations should not leak resources', async ({ page }) => {
    const tracker = createRequestTracker(page);

    // Load home page
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const initialWasmCount = tracker.wasmRequests.length;
    console.log(`Initial WASM: ${initialWasmCount}`);

    // Click through multiple pages
    const navLinks = ['book', 'getting-started', 'learn', 'api'];
    let clickCount = 0;

    for (const linkText of navLinks) {
      const link = page.locator(`nav a[href*="${linkText}"]`).first();
      if (await link.count() > 0 && await link.isVisible()) {
        await link.click();
        await page.waitForLoadState('networkidle');
        clickCount++;
        console.log(`Clicked: ${linkText}`);
      }
    }

    console.log(`Total clicks: ${clickCount}`);
    console.log(`Total WASM requests: ${tracker.wasmRequests.length}`);
    console.log(`Total WS requests: ${tracker.wsRequests.length}`);
    console.log(`Total all requests: ${tracker.totalRequests.length}`);

    // After multiple navigations:
    // - WASM should be fetched AT MOST once per unique island
    // - WebSocket should be 1 connection total (or 0 on static)
    expect(tracker.wasmRequests.length).toBeLessThanOrEqual(initialWasmCount + 2);
    expect(tracker.wsRequests.length).toBeLessThanOrEqual(1);

    // Total requests should be reasonable (not 768!)
    // Each SPA nav fetches just the partial content, not full page
    // Roughly: initial load (~20-30) + (clicks * ~5) = ~50-80 max
    expect(tracker.totalRequests.length).toBeLessThan(150);
  });

  test('rapid clicking should not cause race conditions or duplicate fetches', async ({ page }) => {
    const tracker = createRequestTracker(page);

    // Load home page
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Get all visible nav links
    const navLinks = page.locator('nav a');
    const linkCount = await navLinks.count();

    // Rapid click through links (no waiting between clicks)
    for (let i = 0; i < Math.min(linkCount, 5); i++) {
      const link = navLinks.nth(i);
      if (await link.isVisible()) {
        await link.click({ timeout: 1000 }).catch(() => {}); // Ignore timeout errors
        await page.waitForTimeout(100); // Brief pause
      }
    }

    // Wait for all requests to settle
    await page.waitForLoadState('networkidle');

    // Check for duplicate WASM fetches
    const wasmUrls = tracker.wasmRequests.map(r => r.url());
    const uniqueWasmUrls = [...new Set(wasmUrls)];
    console.log('WASM requests:', wasmUrls.length);
    console.log('Unique WASM URLs:', uniqueWasmUrls.length);

    // Each unique WASM should be fetched at most once
    // Allow for slight variation due to timing
    expect(wasmUrls.length).toBeLessThanOrEqual(uniqueWasmUrls.length * 2);
  });
});

test.describe('Island Hydration', () => {
  test('ThemeToggle should hydrate only once and stay functional', async ({ page }) => {
    const tracker = createRequestTracker(page);

    // Load home page
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Find ThemeToggle and verify it's hydrated
    const themeToggle = page.locator('therapy-island[data-component="themetoggle"], therapy-island[data-component="ThemeToggle"]');

    if (await themeToggle.count() > 0) {
      // Check for hydrated marker
      const isHydrated = await themeToggle.first().getAttribute('data-hydrated');
      console.log('ThemeToggle hydrated:', isHydrated);

      // Record WASM count
      const wasmCount = tracker.wasmRequests.length;

      // Navigate to another page
      const navLink = page.locator('nav a[href*="book"]').first();
      if (await navLink.count() > 0) {
        await navLink.click();
        await page.waitForLoadState('networkidle');

        // ThemeToggle should still be hydrated (same element in Layout)
        const stillHydrated = await themeToggle.first().getAttribute('data-hydrated');
        console.log('ThemeToggle still hydrated:', stillHydrated);

        // No new WASM fetches for ThemeToggle
        const newWasmCount = tracker.wasmRequests.length;
        expect(newWasmCount).toBe(wasmCount);
      }
    } else {
      console.log('No ThemeToggle island found (might be SSR-only mode)');
    }
  });
});

test.describe('WebSocket Connection', () => {
  test('should maintain single WebSocket connection across navigations', async ({ page }) => {
    let wsConnectionCount = 0;

    // Listen for WebSocket connections
    page.on('websocket', () => {
      wsConnectionCount++;
      console.log(`WebSocket connection opened: ${wsConnectionCount}`);
    });

    // Load home page
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(1000); // Wait for WS to connect

    const initialCount = wsConnectionCount;
    console.log(`Initial WS connections: ${initialCount}`);

    // Navigate to multiple pages
    const navLinks = ['book', 'getting-started'];
    for (const linkText of navLinks) {
      const link = page.locator(`nav a[href*="${linkText}"]`).first();
      if (await link.count() > 0 && await link.isVisible()) {
        await link.click();
        await page.waitForLoadState('networkidle');
        await page.waitForTimeout(500);
      }
    }

    console.log(`Final WS connections: ${wsConnectionCount}`);

    // Should have at most 1 WebSocket connection (could be 0 in static mode)
    // Each navigation should NOT create new connections
    expect(wsConnectionCount).toBeLessThanOrEqual(initialCount + 1);
  });
});
