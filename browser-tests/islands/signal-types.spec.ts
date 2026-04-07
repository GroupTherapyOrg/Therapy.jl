import { test, expect } from '@playwright/test';
import { waitForIslandHydration } from './helpers';

test.describe('SignalTypesDemo Island', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/examples/');
    await waitForIslandHydration(page, 'signaltypesdemo');
  });

  test('Int64: click +/- changes number', async ({ page }) => {
    const island = page.locator('[data-component="signaltypesdemo"]');
    const intMinus = island.locator('[data-hk="5"]');
    const intDisplay = island.locator('[data-hk="6"]');
    const intPlus = island.locator('[data-hk="7"]');

    await expect(intDisplay).toHaveText('0');

    await intPlus.click();
    await expect(intDisplay).toHaveText('1');

    await intPlus.click();
    await expect(intDisplay).toHaveText('2');

    await intMinus.click();
    await expect(intDisplay).toHaveText('1');
  });

  test('Bool: click toggle changes text', async ({ page }) => {
    const island = page.locator('[data-component="signaltypesdemo"]');
    const boolBtn = island.locator('[data-hk="10"]');
    const boolDisplay = island.locator('[data-hk="11"]');

    // Initial state (false/empty or specific text)
    const initial = await boolDisplay.textContent();

    // Toggle
    await boolBtn.click();
    await page.waitForTimeout(200);
    const toggled = await boolDisplay.textContent();
    expect(toggled).not.toBe(initial);

    // Toggle back
    await boolBtn.click();
    await page.waitForTimeout(200);
    const restored = await boolDisplay.textContent();
    expect(restored).toBe(initial);
  });

  test('Float64: click +/- changes decimal', async ({ page }) => {
    const island = page.locator('[data-component="signaltypesdemo"]');
    const floatMinus = island.locator('[data-hk="15"]');
    const floatDisplay = island.locator('[data-hk="16"]');
    const floatPlus = island.locator('[data-hk="17"]');

    await expect(floatDisplay).toHaveText('98.6');

    await floatPlus.click();
    await page.waitForTimeout(200);
    const afterPlus = await floatDisplay.textContent();
    expect(parseFloat(afterPlus!)).toBeGreaterThan(98.6);

    await floatMinus.click();
    await page.waitForTimeout(200);
    // Should be back near 98.6
    const afterMinus = await floatDisplay.textContent();
    expect(parseFloat(afterMinus!)).toBeCloseTo(98.6, 0);
  });

  test('String: typing updates display', async ({ page }) => {
    const island = page.locator('[data-component="signaltypesdemo"]');
    const input = island.locator('[data-hk="21"]');
    const display = island.locator('[data-hk="22"]');

    // Type something
    await input.fill('hello');
    await input.dispatchEvent('input');
    await page.waitForTimeout(300);

    await expect(display).toHaveText('hello');
  });
});
