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

    // Should show initial visible_init items (12)
    await expect(items).toHaveCount(12);
    await expect(items.first()).toContainText('Julia');
  });

  test('search filters items by query', async ({ page }) => {
    const island = page.locator('[data-component="searchablelist"]');
    const input = island.locator('[data-hk="3"]');
    const grid = island.locator('[data-hk="5"]');

    // Type "ju" to search
    await input.fill('ju');
    // Trigger input event
    await input.dispatchEvent('input');
    await page.waitForTimeout(300);

    // Should show only Julia
    const items = grid.locator('> div');
    const count = await items.count();
    expect(count).toBeGreaterThanOrEqual(1);

    // "Julia" should be in the filtered results
    await expect(grid).toContainText('Julia');
  });

  test('clearing search restores items', async ({ page }) => {
    const island = page.locator('[data-component="searchablelist"]');
    const input = island.locator('[data-hk="3"]');
    const grid = island.locator('[data-hk="5"]');

    // Search then clear
    await input.fill('ju');
    await input.dispatchEvent('input');
    await page.waitForTimeout(300);

    await input.fill('');
    await input.dispatchEvent('input');
    await page.waitForTimeout(300);

    // Should restore to initial 12 items
    const items = grid.locator('> div');
    await expect(items).toHaveCount(12);
  });

  test('show more button increases visible items', async ({ page }) => {
    const island = page.locator('[data-component="searchablelist"]');
    const grid = island.locator('[data-hk="5"]');
    const showMore = island.locator('[data-hk="8"]');

    // Initial: 12 items
    await expect(grid.locator('> div')).toHaveCount(12);

    // Click "show more"
    await showMore.click();
    await page.waitForTimeout(300);

    // Should show more items now
    const newCount = await grid.locator('> div').count();
    expect(newCount).toBeGreaterThan(12);
  });
});
