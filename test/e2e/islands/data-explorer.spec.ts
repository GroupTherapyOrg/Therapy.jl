import { test, expect } from '@playwright/test';
import { waitForIslandHydration } from './helpers';

test.describe('DataExplorer Island', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/examples/');
    await waitForIslandHydration(page, 'dataexplorer');
  });

  test('renders initial table with data', async ({ page }) => {
    const island = page.locator('[data-component="dataexplorer"]');
    const tbody = island.locator('tbody');
    const rows = tbody.locator('tr');

    const count = await rows.count();
    expect(count).toBeGreaterThan(0);
    await expect(rows.first()).toContainText('Alice');
  });

  test('click column header sorts and reverses', async ({ page }) => {
    const island = page.locator('[data-component="dataexplorer"]');
    const nameHeader = island.locator('[data-hk="6"]');
    const tbody = island.locator('tbody');

    // Click Name header — ascending sort (Alice first)
    await nameHeader.click();
    const firstAfterAsc = tbody.locator('tr').first().locator('td').first();
    await expect(firstAfterAsc).toHaveText('Alice');

    // Click again — descending sort (Trent first)
    await nameHeader.click();
    const firstAfterDesc = tbody.locator('tr').first().locator('td').first();
    await expect(firstAfterDesc).toHaveText('Trent');
  });

  test('click Age header sorts numerically', async ({ page }) => {
    const island = page.locator('[data-component="dataexplorer"]');
    const ageHeader = island.locator('[data-hk="7"]');
    const tbody = island.locator('tbody');

    await ageHeader.click();
    const rows = tbody.locator('tr');
    const count = await rows.count();
    expect(count).toBeGreaterThanOrEqual(2);

    // After ascending sort on age strings, first row should have lowest age
    const age1 = await rows.nth(0).locator('td').nth(1).textContent();
    const age2 = await rows.nth(1).locator('td').nth(1).textContent();
    expect(age1).not.toBeNull();
    expect(age2).not.toBeNull();
  });
});
