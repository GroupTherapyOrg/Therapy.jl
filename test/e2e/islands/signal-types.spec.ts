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

  test('Bool: click toggle changes display', async ({ page }) => {
    const island = page.locator('[data-component="signaltypesdemo"]');
    const boolBtn = island.locator('[data-hk="10"]');
    const boolDisplay = island.locator('[data-hk="11"]');

    // Initial SSR value
    await expect(boolDisplay).toHaveText('false');

    // Toggle to true
    await boolBtn.click();
    await expect(boolDisplay).toHaveText('true');

    // Toggle back to false
    await boolBtn.click();
    await expect(boolDisplay).toHaveText('false');
  });

  test('Float64: click +/- changes decimal', async ({ page }) => {
    const island = page.locator('[data-component="signaltypesdemo"]');
    const floatMinus = island.locator('[data-hk="15"]');
    const floatDisplay = island.locator('[data-hk="16"]');
    const floatPlus = island.locator('[data-hk="17"]');

    await expect(floatDisplay).toHaveText('98.6');

    await floatPlus.click();
    await expect(floatDisplay).toHaveText('99.6');

    await floatMinus.click();
    await expect(floatDisplay).toHaveText('98.6');
  });

  test('String: typing updates display', async ({ page }) => {
    const island = page.locator('[data-component="signaltypesdemo"]');
    const input = island.locator('[data-hk="21"]');
    const display = island.locator('[data-hk="22"]');

    await input.fill('hello');
    await input.dispatchEvent('input');
    await expect(display).toHaveText('hello');
  });

  test('effect logs all 4 signal types on interaction', async ({ page }) => {
    const logs: string[] = [];
    page.on('console', (msg) => {
      if (msg.type() === 'log') logs.push(msg.text());
    });

    await page.goto('/examples/');
    await waitForIslandHydration(page, 'signaltypesdemo');
    await page.waitForTimeout(300);

    // Initial effect fires with count=0, active=0 (false), temp=98.6, name=""
    expect(logs.some(l => l.startsWith('signals: 0 0 98.6'))).toBe(true);

    const island = page.locator('[data-component="signaltypesdemo"]');

    // Click Int64 + → count becomes 1
    const intPlus = island.locator('[data-hk="7"]');
    await intPlus.click();
    await page.waitForTimeout(200);
    expect(logs.some(l => l.startsWith('signals: 1 0 98.6'))).toBe(true);

    // Toggle Bool → active becomes 1 (true)
    const boolBtn = island.locator('[data-hk="10"]');
    await boolBtn.click();
    await page.waitForTimeout(200);
    expect(logs.some(l => l.startsWith('signals: 1 1 98.6'))).toBe(true);

    // Click Float64 + → temp becomes 99.6
    const floatPlus = island.locator('[data-hk="17"]');
    await floatPlus.click();
    await page.waitForTimeout(200);
    expect(logs.some(l => l.startsWith('signals: 1 1 99.6'))).toBe(true);

    // Type in String input → name becomes "hi"
    const input = island.locator('[data-hk="21"]');
    await input.fill('hi');
    await input.dispatchEvent('input');
    await page.waitForTimeout(200);
    expect(logs.some(l => l === 'signals: 1 1 99.6 hi')).toBe(true);
  });
});
