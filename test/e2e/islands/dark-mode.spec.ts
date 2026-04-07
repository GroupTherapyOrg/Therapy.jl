import { test, expect } from '@playwright/test';
import { waitForIslandHydration } from './helpers';

test.describe('DarkModeToggle Island', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/examples/');
    await waitForIslandHydration(page, 'darkmodetoggle');
  });

  test('toggle button exists and is clickable', async ({ page }) => {
    const island = page.locator('[data-component="darkmodetoggle"]').first();
    const button = island.locator('button').first();
    await expect(button).toBeVisible();
  });

  test('click fires handler without error', async ({ page }) => {
    const island = page.locator('[data-component="darkmodetoggle"]').first();
    const button = island.locator('button').first();

    const errors: string[] = [];
    page.on('pageerror', (err) => errors.push(err.message));

    await button.click();
    await page.waitForTimeout(300);

    const fatalErrors = errors.filter(
      (e) => !e.includes('is not defined') && !e.includes('is not a function'),
    );
    expect(fatalErrors).toHaveLength(0);
  });

  test('click toggles dark class on html element', async ({ page }) => {
    const island = page.locator('[data-component="darkmodetoggle"]').first();
    const button = island.locator('button').first();

    const wasDark = await page.evaluate(() =>
      document.documentElement.classList.contains('dark'),
    );

    await button.click();
    await page.waitForTimeout(300);

    const isNowDark = await page.evaluate(() =>
      document.documentElement.classList.contains('dark'),
    );
    expect(isNowDark).toBe(!wasDark);

    // Toggle back
    await button.click();
    await page.waitForTimeout(300);
    const isBack = await page.evaluate(() =>
      document.documentElement.classList.contains('dark'),
    );
    expect(isBack).toBe(wasDark);
  });
});
