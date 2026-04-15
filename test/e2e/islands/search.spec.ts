import { test, expect } from '@playwright/test';
import { waitForIslandHydration } from './helpers';

test.describe('SearchableList Island', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/examples/');
    await waitForIslandHydration(page, 'searchablelist');
  });

  test('renders initial items', async ({ page }) => {
    const island = page.locator('[data-component="searchablelist"]');
    const grid = island.locator('[data-hk="5"]');
    const items = grid.locator('> div');

    await expect(items).toHaveCount(12);
    await expect(items.first()).toContainText('Julia');
  });

  test('search filters items by query', async ({ page }) => {
    const island = page.locator('[data-component="searchablelist"]');
    const input = island.locator('[data-hk="3"]');
    const grid = island.locator('[data-hk="5"]');

    await input.fill('ju');
    await input.dispatchEvent('input');
    await page.waitForTimeout(500);

    const items = grid.locator('> div');
    const count = await items.count();
    expect(count).toBeGreaterThanOrEqual(1);
    await expect(grid).toContainText('Julia');
  });

  test('clearing search restores items', async ({ page }) => {
    const island = page.locator('[data-component="searchablelist"]');
    const input = island.locator('[data-hk="3"]');
    const grid = island.locator('[data-hk="5"]');

    await input.fill('ju');
    await input.dispatchEvent('input');
    await page.waitForTimeout(500);

    await input.fill('');
    await input.dispatchEvent('input');
    await page.waitForTimeout(500);

    const items = grid.locator('> div');
    await expect(items).toHaveCount(12);
  });

  test('show more button increases item count', async ({ page }) => {
    const island = page.locator('[data-component="searchablelist"]');
    const showMore = island.locator('[data-hk="8"]');
    const grid = island.locator('[data-hk="5"]');

    await expect(showMore).toBeVisible();

    // Click show more — grid should gain items
    await showMore.click();
    const items = grid.locator('> div');
    const newCount = await items.count();
    expect(newCount).toBeGreaterThan(12);
  });
});
