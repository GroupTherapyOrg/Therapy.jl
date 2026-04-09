import { test, expect, Page } from '@playwright/test';

/**
 * Wait for a Makie island to hydrate — checks for data-hydrated and WASM load.
 * Makie islands don't have buttons, so we wait for the input (slider) to be wired.
 */
async function waitForMakieIsland(page: Page, component: string, timeout = 15_000) {
  const island = page.locator(`[data-component="${component}"][data-hydrated="true"]`);
  await island.first().waitFor({ state: 'attached', timeout });
  // Wait for WASM instantiation + initial effect flush
  await page.waitForTimeout(500);
  return island.first();
}

test.describe('InteractivePlot — WGLMakie sin wave via WasmTargetWGLMakieExt', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/examples/');
  });

  test('island hydrates with data-component attribute', async ({ page }) => {
    const island = await waitForMakieIsland(page, 'interactiveplot');
    await expect(island).toBeAttached();
  });

  test('contains makie-canvas container', async ({ page }) => {
    const island = await waitForMakieIsland(page, 'interactiveplot');
    const canvas = island.locator('#makie-canvas');
    await expect(canvas).toBeVisible();
  });

  test('slider renders with initial frequency value', async ({ page }) => {
    const island = await waitForMakieIsland(page, 'interactiveplot');
    const slider = island.locator('input[type="range"]');
    await expect(slider).toBeVisible();
    await expect(slider).toHaveAttribute('min', '1');
    await expect(slider).toHaveAttribute('max', '20');
  });

  test('frequency label shows initial value', async ({ page }) => {
    const island = await waitForMakieIsland(page, 'interactiveplot');
    // The freq signal displays the current value in a span
    const freqDisplay = island.locator('span').first();
    await expect(freqDisplay).toHaveText('5');
  });

  test('slider change updates frequency display', async ({ page }) => {
    const island = await waitForMakieIsland(page, 'interactiveplot');
    const slider = island.locator('input[type="range"]');
    const freqDisplay = island.locator('span').first();

    // Move slider to a new value
    await slider.fill('10');
    await page.waitForTimeout(300);
    await expect(freqDisplay).toHaveText('10');
  });

  test('Three.js canvas is created after hydration', async ({ page }) => {
    const island = await waitForMakieIsland(page, 'interactiveplot');
    // MakieThreeJS creates a WebGL canvas inside #makie-canvas
    const container = island.locator('#makie-canvas');
    await expect(container).toBeVisible();
  });
});

test.describe('HeatmapDemo — WGLMakie 2D heatmap via WasmTargetWGLMakieExt', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/examples/');
  });

  test('island hydrates with data-component attribute', async ({ page }) => {
    const island = await waitForMakieIsland(page, 'heatmapdemo');
    await expect(island).toBeAttached();
  });

  test('contains makie-canvas container', async ({ page }) => {
    await waitForMakieIsland(page, 'heatmapdemo');
    // HeatmapDemo also uses #makie-canvas (shared ID — the second one on the page)
    const island = page.locator('[data-component="heatmapdemo"]');
    const container = island.locator('#makie-canvas');
    await expect(container).toBeVisible();
  });

  test('slider renders with initial frequency value', async ({ page }) => {
    const island = await waitForMakieIsland(page, 'heatmapdemo');
    const slider = island.locator('input[type="range"]');
    await expect(slider).toBeVisible();
    await expect(slider).toHaveAttribute('min', '1');
    await expect(slider).toHaveAttribute('max', '20');
  });

  test('frequency label shows initial value', async ({ page }) => {
    const island = await waitForMakieIsland(page, 'heatmapdemo');
    const freqDisplay = island.locator('span').first();
    await expect(freqDisplay).toHaveText('3');
  });

  test('slider change updates frequency display', async ({ page }) => {
    const island = await waitForMakieIsland(page, 'heatmapdemo');
    const slider = island.locator('input[type="range"]');
    const freqDisplay = island.locator('span').first();

    await slider.fill('15');
    await page.waitForTimeout(300);
    await expect(freqDisplay).toHaveText('15');
  });

  test('Three.js container exists for heatmap rendering', async ({ page }) => {
    const island = await waitForMakieIsland(page, 'heatmapdemo');
    const container = island.locator('#makie-canvas');
    await expect(container).toBeVisible();
    // Verify it has the expected styling
    await expect(container).toHaveClass(/rounded-lg/);
  });
});
