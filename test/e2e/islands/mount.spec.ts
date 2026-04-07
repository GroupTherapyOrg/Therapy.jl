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
});
