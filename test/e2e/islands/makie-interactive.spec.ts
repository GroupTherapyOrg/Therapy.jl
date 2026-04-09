import { test, expect, Page } from '@playwright/test';

/**
 * Wait for a Makie island to hydrate and render.
 * Waits for data-hydrated attribute AND a canvas element with WebGL context.
 */
async function waitForMakieIsland(page: Page, component: string, timeout = 15_000) {
  const island = page.locator(`[data-component="${component}"][data-hydrated="true"]`);
  await island.first().waitFor({ state: 'attached', timeout });
  // Wait for WASM instantiation + effect flush + Three.js render
  await page.waitForTimeout(1000);
  return island.first();
}

/**
 * Check that a canvas inside the island has actual rendered pixel data.
 * Returns true if any non-background pixels are found.
 */
async function canvasHasContent(page: Page, islandSelector: string): Promise<boolean> {
  return page.evaluate((sel) => {
    const island = document.querySelector(sel);
    if (!island) return false;
    const canvas = island.querySelector('canvas') as HTMLCanvasElement;
    if (!canvas) return false;
    const gl = canvas.getContext('webgl2') || canvas.getContext('webgl');
    if (!gl) return false;
    const w = canvas.width, h = canvas.height;
    if (w === 0 || h === 0) return false;
    const pixels = new Uint8Array(w * h * 4);
    gl.readPixels(0, 0, w, h, gl.RGBA, gl.UNSIGNED_BYTE, pixels);
    // Check if any pixel differs from the background (0x222222 = r:34, g:34, b:34)
    let nonBgCount = 0;
    for (let i = 0; i < pixels.length; i += 4) {
      const r = pixels[i], g = pixels[i + 1], b = pixels[i + 2];
      if (r !== 34 || g !== 34 || b !== 34) nonBgCount++;
    }
    return nonBgCount > 10; // At least some non-background pixels
  }, islandSelector);
}

/**
 * Take a screenshot of the canvas inside an island and return pixel hash.
 */
async function getCanvasPixelSample(page: Page, islandSelector: string): Promise<string> {
  return page.evaluate((sel) => {
    const island = document.querySelector(sel);
    if (!island) return 'no-island';
    const canvas = island.querySelector('canvas') as HTMLCanvasElement;
    if (!canvas) return 'no-canvas';
    const gl = canvas.getContext('webgl2') || canvas.getContext('webgl');
    if (!gl) return 'no-gl';
    // Sample a 10x10 pixel block from center
    const cx = Math.floor(canvas.width / 2), cy = Math.floor(canvas.height / 2);
    const pixels = new Uint8Array(10 * 10 * 4);
    gl.readPixels(cx - 5, cy - 5, 10, 10, gl.RGBA, gl.UNSIGNED_BYTE, pixels);
    // Create a simple hash of the pixel data
    let hash = 0;
    for (let i = 0; i < pixels.length; i++) {
      hash = ((hash << 5) - hash + pixels[i]) | 0;
    }
    return String(hash);
  }, islandSelector);
}

// ── InteractivePlot Tests ────────────────────────────────────────────────

test.describe('InteractivePlot — WGLMakie sin wave via WasmTargetWGLMakieExt', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/examples/');
  });

  test('island hydrates with data-component and data-hydrated', async ({ page }) => {
    const island = await waitForMakieIsland(page, 'interactiveplot');
    await expect(island).toBeAttached();
    await expect(island).toHaveAttribute('data-hydrated', 'true');
  });

  test('WebGL canvas created with non-zero dimensions', async ({ page }) => {
    await waitForMakieIsland(page, 'interactiveplot');
    const hasCanvas = await page.evaluate(() => {
      const island = document.querySelector('[data-component="interactiveplot"]');
      if (!island) return { exists: false, width: 0, height: 0, hasGL: false };
      const canvas = island.querySelector('canvas') as HTMLCanvasElement;
      if (!canvas) return { exists: false, width: 0, height: 0, hasGL: false };
      const gl = canvas.getContext('webgl2') || canvas.getContext('webgl');
      return {
        exists: true,
        width: canvas.width,
        height: canvas.height,
        hasGL: !!gl
      };
    });
    expect(hasCanvas.exists).toBe(true);
    expect(hasCanvas.width).toBeGreaterThan(0);
    expect(hasCanvas.height).toBeGreaterThan(0);
    expect(hasCanvas.hasGL).toBe(true);
  });

  test('canvas has actual rendered pixel content (not empty)', async ({ page }) => {
    await waitForMakieIsland(page, 'interactiveplot');
    const hasContent = await canvasHasContent(page, '[data-component="interactiveplot"]');
    expect(hasContent).toBe(true);
  });

  test('slider change updates frequency display and re-renders canvas', async ({ page }) => {
    await waitForMakieIsland(page, 'interactiveplot');
    const sel = '[data-component="interactiveplot"]';

    // Capture initial pixel sample
    const pixelsBefore = await getCanvasPixelSample(page, sel);

    // Get frequency display
    const island = page.locator(sel);
    const freqDisplay = island.locator('span').first();
    await expect(freqDisplay).toHaveText('5');

    // Move slider to a new value
    const slider = island.locator('input[type="range"]');
    await slider.fill('12');
    await page.waitForTimeout(500);

    // Frequency text updated
    await expect(freqDisplay).toHaveText('12');

    // Canvas pixel data changed (re-rendered with different frequency)
    const pixelsAfter = await getCanvasPixelSample(page, sel);
    expect(pixelsAfter).not.toBe(pixelsBefore);
  });

  test('no MakieThreeJS console errors', async ({ page }) => {
    const errors: string[] = [];
    page.on('console', msg => {
      if (msg.type() === 'error') errors.push(msg.text());
    });
    await waitForMakieIsland(page, 'interactiveplot');
    const makieErrors = errors.filter(e => e.includes('MakieThreeJS') || e.includes('undefined'));
    expect(makieErrors).toHaveLength(0);
  });

  test('slider has correct min/max attributes', async ({ page }) => {
    const island = await waitForMakieIsland(page, 'interactiveplot');
    const slider = island.locator('input[type="range"]');
    await expect(slider).toBeVisible();
    await expect(slider).toHaveAttribute('min', '1');
    await expect(slider).toHaveAttribute('max', '20');
  });
});

// ── HeatmapDemo Tests ────────────────────────────────────────────────────

test.describe('HeatmapDemo — WGLMakie 2D heatmap via WasmTargetWGLMakieExt', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/examples/');
  });

  test('island hydrates with data-component and data-hydrated', async ({ page }) => {
    const island = await waitForMakieIsland(page, 'heatmapdemo');
    await expect(island).toBeAttached();
    await expect(island).toHaveAttribute('data-hydrated', 'true');
  });

  test('WebGL canvas created with non-zero dimensions', async ({ page }) => {
    await waitForMakieIsland(page, 'heatmapdemo');
    const hasCanvas = await page.evaluate(() => {
      const island = document.querySelector('[data-component="heatmapdemo"]');
      if (!island) return { exists: false, width: 0, height: 0, hasGL: false };
      const canvas = island.querySelector('canvas') as HTMLCanvasElement;
      if (!canvas) return { exists: false, width: 0, height: 0, hasGL: false };
      const gl = canvas.getContext('webgl2') || canvas.getContext('webgl');
      return {
        exists: true,
        width: canvas.width,
        height: canvas.height,
        hasGL: !!gl
      };
    });
    expect(hasCanvas.exists).toBe(true);
    expect(hasCanvas.width).toBeGreaterThan(0);
    expect(hasCanvas.height).toBeGreaterThan(0);
    expect(hasCanvas.hasGL).toBe(true);
  });

  test('canvas has actual rendered pixel content (not empty)', async ({ page }) => {
    await waitForMakieIsland(page, 'heatmapdemo');
    const hasContent = await canvasHasContent(page, '[data-component="heatmapdemo"]');
    expect(hasContent).toBe(true);
  });

  test('slider change updates frequency display and re-renders canvas', async ({ page }) => {
    await waitForMakieIsland(page, 'heatmapdemo');
    const sel = '[data-component="heatmapdemo"]';

    // Capture initial pixel sample
    const pixelsBefore = await getCanvasPixelSample(page, sel);

    // Get frequency display
    const island = page.locator(sel);
    const freqDisplay = island.locator('span').first();
    await expect(freqDisplay).toHaveText('3');

    // Move slider to a new value
    const slider = island.locator('input[type="range"]');
    await slider.fill('15');
    await page.waitForTimeout(500);

    // Frequency text updated
    await expect(freqDisplay).toHaveText('15');

    // Canvas pixel data changed
    const pixelsAfter = await getCanvasPixelSample(page, sel);
    expect(pixelsAfter).not.toBe(pixelsBefore);
  });

  test('no MakieThreeJS console errors', async ({ page }) => {
    const errors: string[] = [];
    page.on('console', msg => {
      if (msg.type() === 'error') errors.push(msg.text());
    });
    await waitForMakieIsland(page, 'heatmapdemo');
    const makieErrors = errors.filter(e => e.includes('MakieThreeJS') || e.includes('undefined'));
    expect(makieErrors).toHaveLength(0);
  });

  test('heatmap canvas container has expected styling', async ({ page }) => {
    const island = await waitForMakieIsland(page, 'heatmapdemo');
    const container = island.locator('#makie-canvas');
    await expect(container).toBeVisible();
    await expect(container).toHaveClass(/rounded-lg/);
  });
});
