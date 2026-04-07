import { test, expect } from '@playwright/test';
import { waitForIslandHydration } from './helpers';

test.describe('ShowDemo Island', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/examples/');
    await waitForIslandHydration(page, 'showdemo');
  });

  test('initially shows content (visible=1)', async ({ page }) => {
    const island = page.locator('[data-component="showdemo"]');
    // The Show content (hk_4 span) should be visible initially
    await expect(island.locator('[data-hk="5"]')).toBeVisible();
    // Fallback (hk_9 span) should not be visible
    await expect(island.locator('[data-hk="10"]')).not.toBeVisible();
  });

  test('toggle button hides content and shows fallback', async ({ page }) => {
    const island = page.locator('[data-component="showdemo"]');
    const toggleBtn = island.locator('[data-hk="3"]');

    // Click to hide
    await toggleBtn.click();
    await page.waitForTimeout(300);

    // Content should be hidden, fallback should show
    await expect(island.locator('[data-hk="5"]')).not.toBeVisible();
    await expect(island.locator('[data-hk="10"]')).toBeVisible();
  });

  test('toggle back restores content', async ({ page }) => {
    const island = page.locator('[data-component="showdemo"]');
    const toggleBtn = island.locator('[data-hk="3"]');

    // Hide
    await toggleBtn.click();
    await page.waitForTimeout(200);

    // Show again
    await toggleBtn.click();
    await page.waitForTimeout(200);

    await expect(island.locator('[data-hk="5"]')).toBeVisible();
    await expect(island.locator('[data-hk="10"]')).not.toBeVisible();
  });
});
