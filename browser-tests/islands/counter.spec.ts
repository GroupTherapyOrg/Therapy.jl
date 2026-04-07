import { test, expect } from '@playwright/test';
import { waitForIslandHydration } from './helpers';

test.describe('InteractiveCounter Island', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/examples/');
    await waitForIslandHydration(page, 'interactivecounter');
  });

  test('renders SSR with initial count 0', async ({ page }) => {
    const island = page.locator('[data-component="interactivecounter"]').first();
    const count = island.locator('[data-hk="4"]');
    await expect(count).toHaveText('0');
  });

  test('increments on + click', async ({ page }) => {
    const island = page.locator('[data-component="interactivecounter"]').first();
    const count = island.locator('[data-hk="4"]');
    const plus = island.locator('[data-hk="5"]');

    await plus.click();
    await expect(count).toHaveText('1');

    await plus.click();
    await expect(count).toHaveText('2');

    await plus.click();
    await expect(count).toHaveText('3');
  });

  test('decrements on - click', async ({ page }) => {
    const island = page.locator('[data-component="interactivecounter"]').first();
    const count = island.locator('[data-hk="4"]');
    const minus = island.locator('[data-hk="3"]');
    const plus = island.locator('[data-hk="5"]');

    // Go up to 3
    await plus.click();
    await plus.click();
    await plus.click();
    await expect(count).toHaveText('3');

    // Back down
    await minus.click();
    await expect(count).toHaveText('2');

    await minus.click();
    await expect(count).toHaveText('1');
  });

  test('doubled memo updates correctly', async ({ page }) => {
    const island = page.locator('[data-component="interactivecounter"]').first();
    const doubled = island.locator('[data-hk="7"]');
    const plus = island.locator('[data-hk="5"]');

    await expect(doubled).toHaveText('0');

    await plus.click();
    await expect(doubled).toHaveText('2');

    await plus.click();
    await expect(doubled).toHaveText('4');

    await plus.click();
    await expect(doubled).toHaveText('6');
  });
});
