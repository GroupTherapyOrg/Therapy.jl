import { test, expect } from '@playwright/test';

test('debug: check WASM loading and errors', async ({ page }) => {
  const errors: string[] = [];
  const logs: string[] = [];

  page.on('console', (msg) => {
    logs.push(`[${msg.type()}] ${msg.text()}`);
  });
  page.on('pageerror', (err) => {
    errors.push(err.message);
  });

  await page.goto('/examples/');
  await page.waitForTimeout(5000); // Give WASM plenty of time

  console.log('=== PAGE ERRORS ===');
  errors.forEach((e) => console.log('  ERROR:', e));
  console.log('=== CONSOLE LOGS ===');
  logs.forEach((l) => console.log('  ', l));

  // Check hydration status for all islands
  const islands = await page.evaluate(() => {
    const results: Record<string, { hydrated: boolean; hasClickHandler: boolean }> = {};
    document.querySelectorAll('[data-component]').forEach((el) => {
      const comp = el.getAttribute('data-component')!;
      const hydrated = el.getAttribute('data-hydrated') === 'true';
      const btn = el.querySelector('button');
      const hasClickHandler = btn ? !!(btn as any).$$click : false;
      results[comp] = { hydrated, hasClickHandler };
    });
    return results;
  });

  console.log('=== ISLAND STATUS ===');
  for (const [name, status] of Object.entries(islands)) {
    console.log(`  ${name}: hydrated=${status.hydrated}, $$click=${status.hasClickHandler}`);
  }

  // At minimum, counter island should be hydrated with click handlers
  expect(islands['interactivecounter']?.hydrated).toBe(true);
  // This is the key check: are click handlers wired?
  expect(islands['interactivecounter']?.hasClickHandler).toBe(true);
});
