import { expect, test, type Page } from '@playwright/test';

// Noms propres à chaque exécution : les tests peuvent rejouer sur une base qui garde ses données.
const run = Date.now().toString(36);

// Toute erreur JavaScript de la page fait échouer le test, même si l'écran semble correct.
let pageErrors: Error[] = [];
test.beforeEach(({ page }) => {
  pageErrors = [];
  page.on('pageerror', error => pageErrors.push(error));
});
test.afterEach(() => {
  expect(pageErrors).toEqual([]);
});


async function createOrganization(page: Page, name: string) {
  await page.goto('/organizations/new');
  await page.getByLabel('Name *').fill(name);
  await page.getByRole('button', { name: 'Save' }).click();
  await expect(page).toHaveURL(/\/organizations\/\d+$/);
}

async function createPerson(page: Page, firstName: string, email: string) {
  await page.goto('/persons/new');
  await page.getByLabel('First name *').fill(firstName);
  await page.getByLabel('Last name *').fill('E2E');
  await page.getByLabel('Email').fill(email);
  await page.getByRole('button', { name: 'Save' }).click();
  await expect(page).toHaveURL(/\/persons\/\d+$/);
}

test('the dashboard shows the demonstration data', async ({ page }) => {
  await page.goto('/');

  await expect(page.getByRole('link', { name: 'John Doe' })).toBeVisible();
  await expect(page.getByRole('link', { name: 'Orion Incorporated' })).toBeVisible();
  await expect(page.getByRole('alert')).toHaveCount(0);
});

test('a person is created, modified and deleted', async ({ page }) => {
  const firstName = `Ada-${run}`;
  await createPerson(page, firstName, `ada-${run}@example.net`);

  // Après un rechargement complet, les données viennent bien de l'API et la route est servie (repli SPA).
  await page.reload();
  await expect(page.getByRole('heading', { name: `Person "${firstName} E2E"` })).toBeVisible();

  await page.getByLabel('Last name *').fill('King');
  await page.getByRole('button', { name: 'Save' }).click();
  await expect(page.getByRole('heading', { name: `Person "${firstName} King"` })).toBeVisible();

  await page.getByRole('button', { name: 'Delete' }).first().click();
  await expect(page).toHaveURL(/\/$/);
  await expect(page.getByRole('link', { name: 'John Doe' })).toBeVisible();
  await expect(page.getByRole('link', { name: `${firstName} King` })).toHaveCount(0);
});

test('an organization is added to a person with the keyboard, then removed', async ({ page }) => {
  const organization = `Org-${run}`;
  const firstName = `Linus-${run}`;
  await createOrganization(page, organization);
  const organizationUrl = page.url();
  await createPerson(page, firstName, `linus-${run}@example.net`);
  const personUrl = page.url();

  await page.getByLabel('Organization to add').selectOption({ label: organization });
  const add = page.getByRole('button', { name: 'Add organization' });
  await add.focus();
  await page.keyboard.press('Enter');
  const row = page.getByRole('row').filter({ hasText: organization });
  await expect(row).toBeVisible();

  // Le lien se voit aussi depuis l'organisation.
  await page.goto(organizationUrl);
  await expect(page.getByRole('link', { name: `${firstName} E2E` })).toBeVisible();

  await page.goto(personUrl);
  await row.getByRole('button').click();
  await expect(row).toHaveCount(0);
  await page.goto(organizationUrl);
  await expect(page.getByRole('heading', { name: `Organization "${organization}"` })).toBeVisible();
  await expect(page.getByRole('link', { name: `${firstName} E2E` })).toHaveCount(0);
});

test('an invalid email address cannot be saved', async ({ page }) => {
  await page.goto('/persons/new');
  await page.getByLabel('First name *').fill('Bad');
  await page.getByLabel('Last name *').fill('Email');
  await page.getByLabel('Email').fill('not-an-address');
  await page.getByLabel('Phone').focus();

  await expect(page.getByText('Email must be a valid email address.')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Save' })).toBeDisabled();
});

test('when the API is unavailable, the dashboard reports it instead of showing empty lists', async ({ page }) => {
  await page.route('**/api/**', route => route.abort());

  await page.goto('/');

  await expect(page.getByRole('alert')).toHaveCount(2);
  await expect(page.getByText('No person yet.')).toHaveCount(0);
  await expect(page.getByText('No organization yet.')).toHaveCount(0);
});
