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
    await expect(remaining).toHaveText('4');

    await removeBtn.click();
    await expect(remaining).toHaveText('3');
  });

  test('add back button appears after removing items', async ({ page }) => {
    const island = page.locator('[data-component="todolist"]');
    const remaining = island.locator('[data-hk="5"]');
    const removeBtn = island.locator('[data-hk="9"]');

    // Remove 2 items
    await removeBtn.click();
    await removeBtn.click();
    await expect(remaining).toHaveText('3');

    // Add back button should be visible (remaining < total)
    const addBackBtn = island.locator('[data-hk="11"]');
    await expect(addBackBtn).toBeVisible();

    // Click add back — count should increase
    await addBackBtn.click();
    await expect(remaining).toHaveText('4');
  });
});
