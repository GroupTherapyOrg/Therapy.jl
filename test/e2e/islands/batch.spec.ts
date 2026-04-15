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

  test('increment both updates a and b', async ({ page }) => {
    const island = page.locator('[data-component="batchdemo"]');
    const aVal = island.locator('[data-hk="4"]');
    const bVal = island.locator('[data-hk="5"]');
    const incrementBtn = island.locator('[data-hk="7"]');

    await incrementBtn.click();
    await expect(aVal).toHaveText('1');
    await expect(bVal).toHaveText('10');

    await incrementBtn.click();
    await expect(aVal).toHaveText('2');
    await expect(bVal).toHaveText('20');
  });

  test('reset sets both back to 0', async ({ page }) => {
    const island = page.locator('[data-component="batchdemo"]');
    const aVal = island.locator('[data-hk="4"]');
    const bVal = island.locator('[data-hk="5"]');
    const incrementBtn = island.locator('[data-hk="7"]');
    const resetBtn = island.locator('[data-hk="8"]');

    await incrementBtn.click();
    await incrementBtn.click();
    await expect(aVal).toHaveText('2');
    await expect(bVal).toHaveText('20');

    await resetBtn.click();
    await expect(aVal).toHaveText('0');
    await expect(bVal).toHaveText('0');
  });

  test('effect logs both signals on increment and reset', async ({ page }) => {
    const logs: string[] = [];
    page.on('console', (msg) => {
      if (msg.type() === 'log') logs.push(msg.text());
    });

    await page.goto('/examples/');
    await waitForIslandHydration(page, 'batchdemo');
    await page.waitForTimeout(300);

    // Initial effect fires with a=0, b=0
    expect(logs).toContain('effect: a= 0 b= 0');

    const island = page.locator('[data-component="batchdemo"]');
    const incrementBtn = island.locator('[data-hk="7"]');
    const resetBtn = island.locator('[data-hk="8"]');

    // Click increment — batched update, one effect log
    await incrementBtn.click();
    await page.waitForTimeout(100);
    expect(logs).toContain('effect: a= 1 b= 10');

    // Click increment again
    await incrementBtn.click();
    await page.waitForTimeout(100);
    expect(logs).toContain('effect: a= 2 b= 20');

    // Click reset
    await resetBtn.click();
    await page.waitForTimeout(100);
    expect(logs).toContain('effect: a= 0 b= 0');
  });
});
