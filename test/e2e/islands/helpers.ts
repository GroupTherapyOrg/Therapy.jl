import { Page, Locator } from '@playwright/test';

/**
 * Wait for an island's WASM to fully hydrate.
 * data-hydrated is set BEFORE WASM loads, so we also check for $$click
 * on a button element (set after WebAssembly.instantiate resolves).
 */
export async function waitForIslandHydration(
  page: Page,
  component: string,
  options: { timeout?: number } = {},
): Promise<Locator> {
  const timeout = options.timeout ?? 15_000;
  const island = page.locator(`[data-component="${component}"][data-hydrated="true"]`);
  await island.first().waitFor({ state: 'attached', timeout });

  // Wait for WASM instantiation: $$click on a button means handlers are wired
  await page.waitForFunction(
    (comp) => {
      const el = document.querySelector(
        `[data-component="${comp}"][data-hydrated="true"]`,
      );
      if (!el) return false;
      const btn = el.querySelector('button');
      if (!btn) return true; // Islands without buttons (e.g., MountDemo)
      return !!(btn as any).$$click; // Wait until event handler is wired
    },
    component,
    { timeout },
  );

  // Wait for pending microtasks (_rt_flush)
  await page.waitForTimeout(200);
  return island.first();
}
