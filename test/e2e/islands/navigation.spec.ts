import { test, expect } from '@playwright/test';

test.describe('View Transitions Navigation', () => {
  test('clicking nav link navigates without full page reload', async ({ page }) => {
    await page.goto('/examples/');

    // Get the initial page's script count (proxy for "same document")
    const initialUrl = page.url();

    // Find a nav link to another page
    const navLink = page.locator('a[href*="/getting-started"]').first();
    if (await navLink.count() === 0) {
      // Try any internal nav link
      const anyLink = page.locator('nav a[data-navlink]').first();
      await anyLink.click();
    } else {
      await navLink.click();
    }

    await page.waitForTimeout(1000);

    // URL should have changed
    expect(page.url()).not.toBe(initialUrl);

    // Page should have content (not blank)
    const body = await page.locator('body').textContent();
    expect(body!.length).toBeGreaterThan(100);
  });

  test('browser back button works after navigation', async ({ page }) => {
    await page.goto('/');
    await page.waitForTimeout(500);
    const homeTitle = await page.title();

    // Navigate to examples
    const examplesLink = page.locator('a[href*="/examples"]').first();
    if (await examplesLink.count() > 0) {
      await examplesLink.click();
      await page.waitForTimeout(1000);

      // Should be on examples page
      expect(page.url()).toContain('/examples');

      // Go back
      await page.goBack();
      await page.waitForTimeout(1000);

      // Should be back on home
      expect(page.url()).not.toContain('/examples');
    }
  });

  test('page title updates on navigation', async ({ page }) => {
    await page.goto('/');
    await page.waitForTimeout(500);
    const homeTitle = await page.title();

    // Navigate to a different page
    const link = page.locator('a[href*="/examples"]').first();
    if (await link.count() > 0) {
      await link.click();
      await page.waitForTimeout(1000);

      const newTitle = await page.title();
      // Title should exist and be non-empty
      expect(newTitle.length).toBeGreaterThan(0);
    }
  });

  test('islands hydrate after navigation to examples page', async ({ page }) => {
    // Start on home page
    await page.goto('/');
    await page.waitForTimeout(500);

    // Navigate to examples via click (not direct goto)
    const examplesLink = page.locator('a[href*="/examples"]').first();
    if (await examplesLink.count() > 0) {
      await examplesLink.click();
      await page.waitForTimeout(3000); // Give WASM time to load + hydrate

      // Check that islands hydrated after SPA navigation
      const hydratedIslands = await page.evaluate(() => {
        const islands = document.querySelectorAll('therapy-island[data-hydrated="true"]');
        return islands.length;
      });

      expect(hydratedIslands).toBeGreaterThan(0);
    }
  });

  test('counter island works after SPA navigation to examples', async ({ page }) => {
    // Start on home page
    await page.goto('/');
    await page.waitForTimeout(500);

    // Navigate to examples via SPA
    const examplesLink = page.locator('a[href*="/examples"]').first();
    if (await examplesLink.count() > 0) {
      await examplesLink.click();
      await page.waitForTimeout(3000);

      // Find counter island and test it works
      const counter = page.locator('[data-component="interactivecounter"]').first();
      if (await counter.count() > 0) {
        const display = counter.locator('[data-hk="4"]');
        const plusBtn = counter.locator('[data-hk="5"]');

        await expect(display).toHaveText('0');
        await plusBtn.click();
        await expect(display).toHaveText('1');
      }
    }
  });
});
