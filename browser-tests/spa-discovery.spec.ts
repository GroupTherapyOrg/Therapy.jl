/**
 * THERAPY-800: SPA Navigation Discovery Test
 *
 * PHASE 1: DISCOVERY - Observe and document what IS happening
 * DO NOT attempt fixes in this file. Just observe and document.
 *
 * This test captures detailed network data for analysis:
 * - Total request count per navigation
 * - WASM request breakdown
 * - Document/Fetch/XHR breakdown
 * - Response sizes
 * - Duplicate URLs
 * - Timing
 */
import { test, Page, Request, Response } from '@playwright/test';

interface RequestDetail {
  url: string;
  type: string;
  method: string;
  timestamp: number;
  size?: number;
}

interface NavigationResult {
  path: string;
  totalRequests: number;
  wasmRequests: RequestDetail[];
  fetchRequests: RequestDetail[];
  documentRequests: RequestDetail[];
  otherRequests: RequestDetail[];
  duplicateUrls: string[];
  timeMs: number;
}

async function trackNavigation(page: Page, clickTarget: () => Promise<void>, description: string): Promise<NavigationResult> {
  const requests: RequestDetail[] = [];
  const startTime = Date.now();

  // Track all requests
  const requestHandler = (request: Request) => {
    requests.push({
      url: request.url(),
      type: request.resourceType(),
      method: request.method(),
      timestamp: Date.now() - startTime,
    });
  };

  // Track response sizes
  const responseHandler = (response: Response) => {
    const req = requests.find(r => r.url === response.url());
    if (req) {
      response.body().then(body => {
        req.size = body.length;
      }).catch(() => {});
    }
  };

  page.on('request', requestHandler);
  page.on('response', responseHandler);

  await clickTarget();
  await page.waitForLoadState('networkidle');

  page.off('request', requestHandler);
  page.off('response', responseHandler);

  const endTime = Date.now();

  // Categorize requests
  const wasmRequests = requests.filter(r => r.url.endsWith('.wasm'));
  const fetchRequests = requests.filter(r => r.type === 'fetch' || r.type === 'xhr');
  const documentRequests = requests.filter(r => r.type === 'document');
  const otherRequests = requests.filter(r =>
    !r.url.endsWith('.wasm') && r.type !== 'fetch' && r.type !== 'xhr' && r.type !== 'document'
  );

  // Find duplicate URLs
  const urlCounts = new Map<string, number>();
  requests.forEach(r => urlCounts.set(r.url, (urlCounts.get(r.url) || 0) + 1));
  const duplicateUrls = Array.from(urlCounts.entries())
    .filter(([_, count]) => count > 1)
    .map(([url, count]) => `${url} (${count}x)`);

  return {
    path: description,
    totalRequests: requests.length,
    wasmRequests,
    fetchRequests,
    documentRequests,
    otherRequests,
    duplicateUrls,
    timeMs: endTime - startTime,
  };
}

test.describe('THERAPY-800: SPA Navigation Discovery', () => {
  test('Observation: Initial page load - What requests happen?', async ({ page }) => {
    const result = await trackNavigation(
      page,
      async () => { await page.goto('./'); },
      'Initial load: /'
    );

    console.log('\n====================================');
    console.log('INITIAL PAGE LOAD (/)');
    console.log('====================================');
    console.log(`Total requests: ${result.totalRequests}`);
    console.log(`Time: ${result.timeMs}ms`);
    console.log('\n--- WASM Requests ---');
    result.wasmRequests.forEach(r => console.log(`  ${r.url}`));
    console.log(`WASM count: ${result.wasmRequests.length}`);
    console.log('\n--- Document Requests ---');
    result.documentRequests.forEach(r => console.log(`  ${r.url}`));
    console.log(`Document count: ${result.documentRequests.length}`);
    console.log('\n--- Fetch/XHR Requests ---');
    result.fetchRequests.forEach(r => console.log(`  ${r.url}`));
    console.log(`Fetch/XHR count: ${result.fetchRequests.length}`);
    console.log('\n--- Duplicate URLs ---');
    if (result.duplicateUrls.length > 0) {
      result.duplicateUrls.forEach(d => console.log(`  ${d}`));
    } else {
      console.log('  (none)');
    }
    console.log('====================================\n');
  });

  test('Observation: Single SPA click Home -> Book', async ({ page }) => {
    // Load home first
    await page.goto('./');
    await page.waitForLoadState('networkidle');

    // Now track the SPA navigation
    const result = await trackNavigation(
      page,
      async () => {
        const link = page.locator('nav a[href*="book"]').first();
        await link.click();
      },
      'SPA nav: / -> /book/'
    );

    console.log('\n====================================');
    console.log('SPA NAVIGATION: Home -> Book');
    console.log('====================================');
    console.log(`Total requests: ${result.totalRequests}`);
    console.log(`Time: ${result.timeMs}ms`);
    console.log('\n--- WASM Requests ---');
    result.wasmRequests.forEach(r => console.log(`  ${r.url}`));
    console.log(`WASM count: ${result.wasmRequests.length}`);
    console.log('\n--- Document Requests ---');
    result.documentRequests.forEach(r => console.log(`  ${r.url}`));
    console.log(`Document count: ${result.documentRequests.length}`);
    console.log('\n--- Fetch/XHR Requests ---');
    result.fetchRequests.forEach(r => console.log(`  ${r.url}`));
    console.log(`Fetch/XHR count: ${result.fetchRequests.length}`);
    console.log('\n--- Duplicate URLs ---');
    if (result.duplicateUrls.length > 0) {
      result.duplicateUrls.forEach(d => console.log(`  ${d}`));
    } else {
      console.log('  (none)');
    }
    console.log('====================================\n');

    // Expected for SPA nav: 1-3 fetch requests (partial content)
    // No WASM, no document requests
  });

  test('Observation: SPA navigation Book -> Getting Started', async ({ page }) => {
    await page.goto('./');
    await page.waitForLoadState('networkidle');

    // First navigate to book
    const bookLink = page.locator('nav a[href*="book"]').first();
    await bookLink.click();
    await page.waitForLoadState('networkidle');

    // Now track book -> getting-started
    const result = await trackNavigation(
      page,
      async () => {
        const link = page.locator('nav a[href*="getting-started"]').first();
        await link.click();
      },
      'SPA nav: /book/ -> /getting-started/'
    );

    console.log('\n====================================');
    console.log('SPA NAVIGATION: Book -> Getting Started');
    console.log('====================================');
    console.log(`Total requests: ${result.totalRequests}`);
    console.log(`Time: ${result.timeMs}ms`);
    console.log('\n--- WASM Requests ---');
    result.wasmRequests.forEach(r => console.log(`  ${r.url}`));
    console.log(`WASM count: ${result.wasmRequests.length}`);
    console.log('\n--- Fetch/XHR Requests ---');
    result.fetchRequests.forEach(r => console.log(`  ${r.url}`));
    console.log(`Fetch/XHR count: ${result.fetchRequests.length}`);
    console.log('\n--- Duplicate URLs ---');
    if (result.duplicateUrls.length > 0) {
      result.duplicateUrls.forEach(d => console.log(`  ${d}`));
    } else {
      console.log('  (none)');
    }
    console.log('====================================\n');
  });

  test('Observation: Rapid clicking stress test (5 quick clicks)', async ({ page }) => {
    await page.goto('./');
    await page.waitForLoadState('networkidle');

    const allRequests: RequestDetail[] = [];
    const startTime = Date.now();

    page.on('request', (request) => {
      allRequests.push({
        url: request.url(),
        type: request.resourceType(),
        method: request.method(),
        timestamp: Date.now() - startTime,
      });
    });

    // Rapid click 5 times
    const navLinks = page.locator('nav a');
    const clickTargets = ['book', 'getting-started', 'learn', 'book', 'getting-started'];

    for (const target of clickTargets) {
      const link = page.locator(`nav a[href*="${target}"]`).first();
      if (await link.isVisible().catch(() => false)) {
        await link.click({ timeout: 1000 }).catch(() => {});
        await page.waitForTimeout(50); // Very brief pause
      }
    }

    await page.waitForLoadState('networkidle');
    const endTime = Date.now();

    // Analyze
    const wasmRequests = allRequests.filter(r => r.url.endsWith('.wasm'));
    const wasmUrls = wasmRequests.map(r => r.url);
    const uniqueWasmUrls = [...new Set(wasmUrls)];

    const urlCounts = new Map<string, number>();
    allRequests.forEach(r => urlCounts.set(r.url, (urlCounts.get(r.url) || 0) + 1));
    const duplicates = Array.from(urlCounts.entries())
      .filter(([_, count]) => count > 1)
      .sort((a, b) => b[1] - a[1])
      .map(([url, count]) => `${url.split('/').pop()} (${count}x)`);

    console.log('\n====================================');
    console.log('RAPID CLICKING STRESS TEST (5 clicks)');
    console.log('====================================');
    console.log(`Total requests: ${allRequests.length}`);
    console.log(`Time: ${endTime - startTime}ms`);
    console.log('\n--- WASM Requests ---');
    console.log(`Total WASM requests: ${wasmRequests.length}`);
    console.log(`Unique WASM URLs: ${uniqueWasmUrls.length}`);
    uniqueWasmUrls.forEach(url => {
      const count = wasmUrls.filter(u => u === url).length;
      console.log(`  ${url.split('/').pop()}: ${count}x`);
    });
    console.log('\n--- Top Duplicate URLs ---');
    duplicates.slice(0, 10).forEach(d => console.log(`  ${d}`));
    console.log('====================================\n');
  });

  test('Observation: Full navigation sequence with detailed breakdown', async ({ page }) => {
    const results: string[] = [];

    // Track all requests across entire test
    const allRequests: { url: string; type: string; phase: string }[] = [];
    let currentPhase = 'initial';

    page.on('request', (request) => {
      allRequests.push({
        url: request.url(),
        type: request.resourceType(),
        phase: currentPhase,
      });
    });

    // Phase 1: Initial load
    currentPhase = 'initial-load';
    await page.goto('./');
    await page.waitForLoadState('networkidle');
    const initialCount = allRequests.length;

    // Phase 2: Home -> Book
    currentPhase = 'home-to-book';
    const bookLink = page.locator('nav a[href*="book"]').first();
    if (await bookLink.isVisible().catch(() => false)) {
      await bookLink.click();
      await page.waitForLoadState('networkidle');
    }
    const afterBookCount = allRequests.length;

    // Phase 3: Book -> Getting Started
    currentPhase = 'book-to-getting-started';
    const gsLink = page.locator('nav a[href*="getting-started"]').first();
    if (await gsLink.isVisible().catch(() => false)) {
      await gsLink.click();
      await page.waitForLoadState('networkidle');
    }
    const afterGsCount = allRequests.length;

    // Phase 4: Getting Started -> Learn
    currentPhase = 'getting-started-to-learn';
    const learnLink = page.locator('nav a[href*="learn"]').first();
    if (await learnLink.isVisible().catch(() => false)) {
      await learnLink.click();
      await page.waitForLoadState('networkidle');
    }
    const afterLearnCount = allRequests.length;

    // Phase 5: Learn -> Home
    currentPhase = 'learn-to-home';
    const homeLink = page.locator('nav a[href*="/"]').first();
    if (await homeLink.isVisible().catch(() => false)) {
      await homeLink.click();
      await page.waitForLoadState('networkidle');
    }
    const finalCount = allRequests.length;

    // Summary
    console.log('\n========================================');
    console.log('FULL NAVIGATION SEQUENCE - SUMMARY');
    console.log('========================================');
    console.log(`Phase 1 - Initial Load:           ${initialCount} requests`);
    console.log(`Phase 2 - Home -> Book:           ${afterBookCount - initialCount} requests`);
    console.log(`Phase 3 - Book -> Getting Started: ${afterGsCount - afterBookCount} requests`);
    console.log(`Phase 4 - GS -> Learn:            ${afterLearnCount - afterGsCount} requests`);
    console.log(`Phase 5 - Learn -> Home:          ${finalCount - afterLearnCount} requests`);
    console.log(`-----------------------------------------`);
    console.log(`TOTAL REQUESTS:                    ${finalCount}`);

    // WASM breakdown per phase
    console.log('\n--- WASM per phase ---');
    const phases = ['initial-load', 'home-to-book', 'book-to-getting-started', 'getting-started-to-learn', 'learn-to-home'];
    for (const phase of phases) {
      const phaseWasm = allRequests.filter(r => r.phase === phase && r.url.endsWith('.wasm'));
      console.log(`${phase}: ${phaseWasm.length} WASM requests`);
      phaseWasm.forEach(r => console.log(`  - ${r.url.split('/').pop()}`));
    }

    // Total WASM
    const totalWasm = allRequests.filter(r => r.url.endsWith('.wasm'));
    const uniqueWasm = [...new Set(totalWasm.map(r => r.url))];
    console.log(`\nTotal WASM: ${totalWasm.length} requests for ${uniqueWasm.length} unique files`);

    console.log('========================================\n');
  });
});
