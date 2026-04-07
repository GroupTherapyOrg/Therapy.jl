import { defineConfig, devices } from '@playwright/test';

/**
 * Playwright config for Therapy.jl island E2E tests.
 * Tests the static build (docs/dist) served at /Therapy.jl/.
 *
 * Run: cd test/e2e && npx playwright test --config=playwright.islands.config.ts
 */
export default defineConfig({
  testDir: './islands',
  testMatch: '*.spec.ts',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [['html', { open: 'never' }], ['list']],
  timeout: 30_000,

  use: {
    baseURL: 'http://localhost:8081/Therapy.jl',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],

  webServer: {
    command: 'node serve-static.js',
    cwd: __dirname,
    url: 'http://localhost:8081/Therapy.jl/',
    reuseExistingServer: !process.env.CI,
    timeout: 10_000,
  },
});
