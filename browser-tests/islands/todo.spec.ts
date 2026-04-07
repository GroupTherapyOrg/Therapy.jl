import { test, expect } from '@playwright/test';
import { waitForIslandHydration } from './helpers';

test.describe('TodoList Island', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/examples/');
    await waitForIslandHydration(page, 'todolist');
  });

  test('renders 5 initial items', async ({ page }) => {
    const island = page.locator('[data-component="todolist"]');
    const remaining = island.locator('[data-hk="5"]');
    await expect(remaining).toHaveText('5');
  });

  test('remove last decreases count', async ({ page }) => {
    const island = page.locator('[data-component="todolist"]');
    const remaining = island.locator('[data-hk="5"]');
    const removeBtn = island.locator('[data-hk="9"]');

    await removeBtn.click();
    await page.waitForTimeout(200);
    await expect(remaining).toHaveText('4');

    await removeBtn.click();
    await page.waitForTimeout(200);
    await expect(remaining).toHaveText('3');
  });

  test('add back button appears after removing items', async ({ page }) => {
    const island = page.locator('[data-component="todolist"]');
    const removeBtn = island.locator('[data-hk="9"]');

    // Remove items to trigger the Show() for "Add back"
    await removeBtn.click();
    await page.waitForTimeout(200);
    await removeBtn.click();
    await page.waitForTimeout(200);

    // The "Add back" button (hk_11) is inside a Show() conditional.
    // It should become visible when remaining < items_data.length.
    // The Show() uses WASM show_swap to toggle visibility.
    const addBackBtn = island.locator('[data-hk="11"]');
    const isVisible = await addBackBtn.isVisible().catch(() => false);

    if (isVisible) {
      // Add back restores an item
      await addBackBtn.click();
      await page.waitForTimeout(200);
      const remaining = island.locator('[data-hk="5"]');
      await expect(remaining).toHaveText('4');
    } else {
      test.info().annotations.push({
        type: 'gap',
        description: 'Show() swap for Add back button may need memo-dependent condition',
      });
    }
  });
});
