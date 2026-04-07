import { test, expect } from '@playwright/test';
import { waitForIslandHydration } from './helpers';

test.describe('BatchDemo Island', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/examples/');
    await waitForIslandHydration(page, 'batchdemo');
  });

  test('renders initial values a=0 b=0', async ({ page }) => {
    const island = page.locator('[data-component="batchdemo"]');
    const aVal = island.locator('[data-hk="4"]');
    const bVal = island.locator('[data-hk="5"]');

    await expect(aVal).toHaveText('0');
    await expect(bVal).toHaveText('0');
  });

  test('increment both updates a and b simultaneously', async ({ page }) => {
    const island = page.locator('[data-component="batchdemo"]');
    const aVal = island.locator('[data-hk="4"]');
    const bVal = island.locator('[data-hk="5"]');
    const incrementBtn = island.locator('[data-hk="7"]');

    await incrementBtn.click();
    await page.waitForTimeout(200);

    await expect(aVal).toHaveText('1');
    await expect(bVal).toHaveText('1');

    await incrementBtn.click();
    await page.waitForTimeout(200);

    await expect(aVal).toHaveText('2');
    await expect(bVal).toHaveText('2');
  });

  test('reset sets both back to 0', async ({ page }) => {
    const island = page.locator('[data-component="batchdemo"]');
    const aVal = island.locator('[data-hk="4"]');
    const bVal = island.locator('[data-hk="5"]');
    const incrementBtn = island.locator('[data-hk="7"]');
    const resetBtn = island.locator('[data-hk="8"]');

    // Increment a few times
    await incrementBtn.click();
    await incrementBtn.click();
    await page.waitForTimeout(200);
    await expect(aVal).toHaveText('2');

    // Reset
    await resetBtn.click();
    await page.waitForTimeout(200);
    await expect(aVal).toHaveText('0');
    await expect(bVal).toHaveText('0');
  });
});
