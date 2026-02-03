import { defineConfig, devices } from '@playwright/test';

/**
 * Playwright configuration for Therapy.jl browser testing
 *
 * CRITICAL: These tests verify that SPA navigation doesn't cause
 * resource leaks (duplicate WASM fetches, WebSocket connections, etc.)
 *
 * Run from: cd Therapy.jl/browser-tests && npx playwright test
 */
export default defineConfig({
  // Test files are directly in browser-tests/
  testDir: './',
  testMatch: '*.spec.ts',

  // Run tests in parallel
  fullyParallel: true,

  // Fail the build on CI if you accidentally left test.only in the source code
  forbidOnly: !!process.env.CI,

  // Retry on CI only
  retries: process.env.CI ? 2 : 0,

  // Opt out of parallel tests on CI
  workers: process.env.CI ? 1 : undefined,

  // Reporter to use
  reporter: [
    ['html', { open: 'never' }],
    ['list']
  ],

  // Shared settings for all projects
  use: {
    // Base URL for all tests - dev server should be running here
    baseURL: 'http://localhost:8080',

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

  // Web server configuration
  // NOTE: Runs Julia dev server from parent Therapy.jl directory
  webServer: {
    command: 'cd .. && julia +1.12 --project=. docs/app.jl dev',
    url: 'http://localhost:8080',
    reuseExistingServer: !process.env.CI,
    timeout: 120 * 1000, // Julia startup can be slow
    stdout: 'pipe',
    stderr: 'pipe',
  },
});
