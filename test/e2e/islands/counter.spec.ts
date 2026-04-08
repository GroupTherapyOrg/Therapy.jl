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

  test('doubled memo updates on signal change', async ({ page }) => {
    const island = page.locator('[data-component="interactivecounter"]').first();
    const doubled = island.locator('[data-hk="7"]');
    const plus = island.locator('[data-hk="5"]');

    // Initial doubled value
    await expect(doubled).toHaveText('0');

    // Click + three times, verify doubled updates each time
    await plus.click();
    await expect(doubled).toHaveText('2');

    await plus.click();
    await expect(doubled).toHaveText('4');

    await plus.click();
    await expect(doubled).toHaveText('6');
  });

  test('effect logs count and doubled on each click', async ({ page }) => {
    const logs: string[] = [];
    page.on('console', (msg) => {
      if (msg.type() === 'log') logs.push(msg.text());
    });

    await page.goto('/examples/');
    await waitForIslandHydration(page, 'interactivecounter');
    await page.waitForTimeout(300);

    // Initial hydration effect: count=0, doubled=0
    expect(logs).toContain('count: 0 doubled: 0');

    // Click + twice
    const island = page.locator('[data-component="interactivecounter"]').first();
    const plus = island.locator('[data-hk="5"]');
    await plus.click();
    await page.waitForTimeout(100);
    await plus.click();
    await page.waitForTimeout(100);

    // Verify effect fired with count=1,doubled=2 and count=2,doubled=4
    expect(logs).toContain('count: 1 doubled: 2');
    expect(logs).toContain('count: 2 doubled: 4');
  });
});
