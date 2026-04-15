import { test, expect } from '@playwright/test';
import { waitForIslandHydration } from './helpers';

test.describe('MountDemo Island', () => {
  test('hydrates and renders', async ({ page }) => {
    await page.goto('/examples/');
    await waitForIslandHydration(page, 'mountdemo');

    const island = page.locator('[data-component="mountdemo"]');
    await expect(island).toHaveAttribute('data-hydrated', 'true');
  });

  test('mount effect fires console.log', async ({ page }) => {
    const logs: string[] = [];
    page.on('console', (msg) => {
      if (msg.type() === 'log') logs.push(msg.text());
    });

    await page.goto('/examples/');
    await waitForIslandHydration(page, 'mountdemo');
    await page.waitForTimeout(500);

    // The mount effect should have logged "on_mount: I ran once!"
    const mountLog = logs.find((l) => l.includes('on_mount'));
    expect(mountLog).toBeDefined();
  });

  test('create_effect logs count on every click', async ({ page }) => {
    const logs: string[] = [];
    page.on('console', (msg) => {
      if (msg.type() === 'log') logs.push(msg.text());
    });

    await page.goto('/examples/');
    await waitForIslandHydration(page, 'mountdemo');
    await page.waitForTimeout(300);

    // Initial effect should have fired with count=0
    const initialLog = logs.find((l) => l.includes('create_effect: count is'));
    expect(initialLog).toContain('create_effect: count is 0');

    // Click the "Click me" button 3 times
    const island = page.locator('[data-component="mountdemo"]');
    const btn = island.locator('button:has-text("Click me")');
    await btn.click();
    await page.waitForTimeout(100);
    await btn.click();
    await page.waitForTimeout(100);
    await btn.click();
    await page.waitForTimeout(100);

    // Verify 3 effect logs with N=1,2,3
    const effectLogs = logs.filter((l) => l.includes('create_effect: count is'));
    expect(effectLogs.length).toBeGreaterThanOrEqual(4); // initial + 3 clicks
    expect(effectLogs).toContain('create_effect: count is 0');
    expect(effectLogs).toContain('create_effect: count is 1');
    expect(effectLogs).toContain('create_effect: count is 2');
    expect(effectLogs).toContain('create_effect: count is 3');
  });
});
