import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  timeout: 180_000,
  use: {
    baseURL: 'http://localhost:5173/comsa-dashboard/',
  },
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:5173/comsa-dashboard/',
    reuseExistingServer: true,
  },
  fullyParallel: false,
  projects: [
    { name: 'chromium', use: { browserName: 'chromium' } },
  ],
});
