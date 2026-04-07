import { defineConfig, devices } from '@playwright/test';

/**
 * Playwright configuration for testing DEPLOYED GitHub Pages site
 *
 * CRITICAL: This tests the actual production deployment, not localhost.
 * Use this config to verify fixes work on GitHub Pages after push.
 *
 * Run with: cd Therapy.jl/browser-tests && npx playwright test --config=playwright.deployed.config.ts
 */
export default defineConfig({
  // Test files are directly in browser-tests/
  testDir: './',
  testMatch: '*.spec.ts',

  // Run tests serially for deployed site (avoid CDN rate limits)
  fullyParallel: false,

  // Fail the build on CI if you accidentally left test.only in the source code
  forbidOnly: !!process.env.CI,

  // More retries for deployed site (network latency)
  retries: process.env.CI ? 3 : 1,

  // Single worker for deployed site tests (avoid CDN issues)
  workers: 1,

  // Reporter to use
  reporter: [
    ['html', { open: 'never' }],
    ['list']
  ],

  // Shared settings for all projects
  use: {
    // Base URL is the DEPLOYED GitHub Pages site
    // IMPORTANT: Must end with trailing slash for path resolution to work correctly
    baseURL: 'https://grouptherapyorg.github.io/Therapy.jl/',

    // Collect trace when retrying the failed test
    trace: 'on-first-retry',

    // Screenshots on failure
    screenshot: 'only-on-failure',

    // Video on failure
    video: 'on-first-retry',
  },

  // Configure projects for major browsers
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],

  // NO webServer - we're testing the already-deployed site
  // This is the key difference from the local config
});
