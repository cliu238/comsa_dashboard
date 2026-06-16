import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  timeout: 180_000,
  use: {
    baseURL: 'http://localhost:5173/comsa-dashboard/',
  },
  webServer: {
    // Backend URL is read by the frontend from VITE_API_BASE_URL (see src/api/client.js).
    // Set it in this process's env (e.g. VITE_API_BASE_URL=http://localhost:8001) to point E2E at an alt port.
    command: 'npm run dev',
    url: 'http://localhost:5173/comsa-dashboard/',
    reuseExistingServer: true,
  },
  fullyParallel: false,
  projects: [
    { name: 'chromium', use: { browserName: 'chromium' } },
  ],
});
