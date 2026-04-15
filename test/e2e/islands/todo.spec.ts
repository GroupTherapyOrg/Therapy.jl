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

  test('effect logs remaining count on remove', async ({ page }) => {
    const logs: string[] = [];
    page.on('console', (msg) => {
      if (msg.type() === 'log') logs.push(msg.text());
    });

    await page.goto('/examples/');
    await waitForIslandHydration(page, 'todolist');
    await page.waitForTimeout(300);

    // Initial effect fires with 5 items
    expect(logs).toContain('todo remaining: 5');

    const island = page.locator('[data-component="todolist"]');
    const removeBtn = island.locator('[data-hk="9"]');

    // Remove one
    await removeBtn.click();
    await page.waitForTimeout(100);
    expect(logs).toContain('todo remaining: 4');

    // Remove another
    await removeBtn.click();
    await page.waitForTimeout(100);
    expect(logs).toContain('todo remaining: 3');
  });
});
