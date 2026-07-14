import { test, expect, type Locator } from '@playwright/test';
import { waitForIslandHydration } from './helpers';

const checksum = async (canvas: Locator) =>
  canvas.evaluate((cv: HTMLCanvasElement) => {
    const data = cv.getContext('2d')!.getImageData(0, 0, cv.width, cv.height).data;
    let hash = 2166136261;
    for (let i = 0; i < data.length; i += 97)
      hash = Math.imul(hash ^ data[i], 16777619) >>> 0;
    return hash;
  });

test('WasmMakie presents rapid Therapy updates on one persistent canvas', async ({ page }) => {
  await page.goto('/Therapy.jl/examples/');
  const island = await waitForIslandHydration(page, 'interactiveplotdashboard', { timeout: 30_000 });
  const canvas = island.locator('canvas').first();
  await expect(canvas).toHaveAttribute('data-wasmmakie-done', '1', { timeout: 30_000 });

  const before = await checksum(canvas);
  const firstFrame = Number(await canvas.getAttribute('data-wasmmakie-frame'));
  expect(Number.isFinite(firstFrame)).toBe(true);
  await canvas.evaluate((cv: HTMLCanvasElement) => {
    (window as any).__wmFront = cv;
    (window as any).__wmRemoved = 0;
    (window as any).__wmBlankFrames = 0;
    new MutationObserver(() => {
      if (!(window as any).__wmFront?.isConnected) (window as any).__wmRemoved++;
    }).observe(document.documentElement, { childList: true, subtree: true });
    let samples = 0;
    const sample = () => {
      const front = (window as any).__wmFront as HTMLCanvasElement;
      if (front?.isConnected) {
        const pixels = front.getContext('2d')!.getImageData(0, 0, front.width, front.height).data;
        let opaque = false;
        for (let i = 3; i < pixels.length; i += 389) if (pixels[i] !== 0) { opaque = true; break; }
        if (!opaque) (window as any).__wmBlankFrames++;
      }
      if (++samples < 30) requestAnimationFrame(sample);
    };
    requestAnimationFrame(sample);
  });

  // Prove one ordinary Therapy handler reaches both the reactive effect and
  // the presenter before exercising same-task coalescing.
  const plus = island.locator('[data-hk="9"]');
  const freq = island.locator('[data-hk="8"]');
  await plus.click();
  await expect(freq).toHaveText('4');
  await page.waitForFunction(
    (previous) => Number((window as any).__wmFront?.dataset.wasmmakieFrame || 0) > previous,
    firstFrame,
  );
  const frameAfterOne = Number(await canvas.getAttribute('data-wasmmakie-frame'));
  const presentationsAfterOne = Number(await canvas.getAttribute('data-wasmmakie-presentation'));

  // Dispatch a true same-task burst so the rAF presenter must coalesce it.
  await plus.evaluate((button: HTMLButtonElement) => {
    for (let i = 0; i < 3; i++) button.click();
  });
  await expect(freq).toHaveText('7');
  await page.waitForFunction(
    (previous) => Number((window as any).__wmFront?.dataset.wasmmakieFrame || 0) > previous,
    frameAfterOne,
  );
  await page.waitForTimeout(500);

  expect(await checksum(canvas)).not.toBe(before);
  // The frame token records the latest request; the presentation counter
  // records actual front-buffer commits. Three requests in this JS task must
  // therefore advance the visible canvas exactly once.
  expect(Number(await canvas.getAttribute('data-wasmmakie-frame'))).toBe(frameAfterOne + 3);
  expect(Number(await canvas.getAttribute('data-wasmmakie-presentation'))).toBe(presentationsAfterOne + 1);
  const lifecycle = await page.evaluate(() => ({
    same: (window as any).__wmFront?.isConnected,
    removed: (window as any).__wmRemoved,
    blanks: (window as any).__wmBlankFrames,
  }));
  expect(lifecycle).toEqual({ same: true, removed: 0, blanks: 0 });
  expect(await island.locator('canvas').count()).toBe(1);
});
