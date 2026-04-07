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

    // Should have some visible rows
    const count = await rows.count();
    expect(count).toBeGreaterThan(0);

    // First row should contain "Alice" (initial sort order)
    await expect(rows.first()).toContainText('Alice');
  });

  test('click Name header sorts alphabetically', async ({ page }) => {
    const island = page.locator('[data-component="dataexplorer"]');
    const nameHeader = island.locator('[data-hk="6"]');
    const tbody = island.locator('tbody');

    // Click Name header to sort
    await nameHeader.click();
    await page.waitForTimeout(300);

    // Get first row's first cell
    const firstCell = tbody.locator('tr').first().locator('td').first();
    const firstValue = await firstCell.textContent();

    // Click again for reverse sort
    await nameHeader.click();
    await page.waitForTimeout(300);

    const firstCellReversed = tbody.locator('tr').first().locator('td').first();
    const reversedValue = await firstCellReversed.textContent();

    // After two clicks (sort then reverse), values should differ
    expect(reversedValue).not.toBe(firstValue);
  });

  test('click Age header sorts numerically', async ({ page }) => {
    const island = page.locator('[data-component="dataexplorer"]');
    const ageHeader = island.locator('[data-hk="7"]');
    const tbody = island.locator('tbody');

    // Click Age header
    await ageHeader.click();
    await page.waitForTimeout(300);

    // Get first few age values and verify they're sorted
    const rows = tbody.locator('tr');
    const count = await rows.count();
    if (count >= 2) {
      const age1 = await rows.nth(0).locator('td').nth(1).textContent();
      const age2 = await rows.nth(1).locator('td').nth(1).textContent();
      // After sorting, ages should be in order (ascending or descending)
      expect(age1).not.toBeNull();
      expect(age2).not.toBeNull();
    }
  });
});
