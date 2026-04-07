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

  test('add back restores items', async ({ page }) => {
    const island = page.locator('[data-component="todolist"]');
    const remaining = island.locator('[data-hk="5"]');
    const removeBtn = island.locator('[data-hk="9"]');
    const addBackBtn = island.locator('[data-hk="11"]');

    // Remove some items
    await removeBtn.click();
    await page.waitForTimeout(200);
    await removeBtn.click();
    await page.waitForTimeout(200);
    await expect(remaining).toHaveText('3');

    // Add back
    await addBackBtn.click();
    await page.waitForTimeout(200);
    await expect(remaining).toHaveText('4');
  });
});
