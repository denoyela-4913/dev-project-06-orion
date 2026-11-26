import { defineConfig, devices } from '@playwright/test';

// L'application doit déjà tourner : les tests s'appliquent à une adresse (Compose dev par défaut), la même que
// celle d'un déploiement.
export default defineConfig({
  testDir: './tests',
  // Les scénarios écrivent dans la même base : un seul à la fois.
  workers: 1,
  fullyParallel: false,
  forbidOnly: !!process.env['CI'],
  // Pas de nouvel essai : un test instable doit se voir et se corriger.
  retries: 0,
  timeout: 30_000,
  reporter: process.env['CI'] ? [['list'], ['html', { open: 'never' }]] : 'list',
  use: {
    baseURL: process.env['E2E_BASE_URL'] ?? 'http://localhost:4280',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
});
