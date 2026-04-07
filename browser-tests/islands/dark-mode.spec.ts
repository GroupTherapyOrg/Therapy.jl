import { test, expect } from '@playwright/test';
import { waitForIslandHydration } from './helpers';

test.describe('DarkModeToggle Island', () => {
  test.beforeEach(async ({ page }) => {
    // Clear stored theme to start fresh
    await page.goto('/examples/');
    await page.evaluate(() => {
      localStorage.removeItem('therapy-theme');
      localStorage.removeItem('therapy-theme:/Therapy.jl');
    });
    await page.reload();
    await waitForIslandHydration(page, 'darkmodetoggle');
  });

  test('toggle button exists and is clickable', async ({ page }) => {
    const island = page.locator('[data-component="darkmodetoggle"]').first();
    const button = island.locator('button').first();
    await expect(button).toBeVisible();
  });

  test('click toggles dark class on html element', async ({ page }) => {
    const island = page.locator('[data-component="darkmodetoggle"]').first();
    const button = island.locator('button').first();

    // Get initial state
    const wasDark = await page.evaluate(() =>
      document.documentElement.classList.contains('dark'),
    );

    // Click to toggle
    await button.click();
    await page.waitForTimeout(100);

    const isNowDark = await page.evaluate(() =>
      document.documentElement.classList.contains('dark'),
    );
    expect(isNowDark).toBe(!wasDark);

    // Click again to toggle back
    await button.click();
    await page.waitForTimeout(100);

    const isBackToOriginal = await page.evaluate(() =>
      document.documentElement.classList.contains('dark'),
    );
    expect(isBackToOriginal).toBe(wasDark);
  });
});
