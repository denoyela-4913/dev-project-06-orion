import { Type } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, convertToParamMap, provideRouter } from '@angular/router';

import { MainDashboardComponent } from './main-dashboard/main-dashboard.component';
import { OrganizationDetailsComponent } from './organization-details/organization-details.component';
import { PersonDetailsComponent } from './person-details/person-details.component';
import { OrganizationService } from './organization.service';
import { PersonService } from './person.service';

// Ce que l'écran affiche pendant et après un chargement, réussi ou non.
describe('display states', () => {
  const fail = () => Promise.reject(new Error('API down'));
  const ok = <T>(value: T) => () => Promise.resolve(value);

  const render = async <T>(type: Type<T>, persons: object, organizations: object, params: Record<string, string> = {}) => {
    TestBed.configureTestingModule({
      providers: [
        provideRouter([]),
        { provide: PersonService, useValue: persons },
        { provide: OrganizationService, useValue: organizations },
        // Seulement pour les pages à paramètre: un faux ActivatedRoute fausserait la résolution des liens relatifs.
        ...(Object.keys(params).length > 0
          ? [{ provide: ActivatedRoute, useValue: { snapshot: { paramMap: convertToParamMap(params) } } }]
          : []),
      ]
    });
    vi.spyOn(console, 'error').mockImplementation(() => undefined);
    const fixture: ComponentFixture<T> = TestBed.createComponent(type);
    fixture.detectChanges();
    await new Promise<void>(resolve => setTimeout(resolve));
    fixture.detectChanges();
    return fixture.nativeElement as HTMLElement;
  };
  const title = (page: HTMLElement) => page.querySelector('h2.title')!.textContent!.trim().replace(/\s+/g, ' ');

  describe('dashboard', () => {
    it('should say that the lists are empty once they are loaded empty', async () => {
      const page = await render(MainDashboardComponent, { fetchAll: ok([]) }, { fetchAll: ok([]) });

      expect(page.textContent).toContain('No person yet.');
      expect(page.textContent).toContain('No organization yet.');
    });

    // Une liste qui n'a pas pu être chargée n'est pas une liste vide.
    it('should not say that a list is empty when it could not be loaded', async () => {
      const page = await render(MainDashboardComponent, { fetchAll: fail }, { fetchAll: fail });

      expect(page.textContent).not.toContain('No person yet.');
      expect(page.textContent).not.toContain('No organization yet.');
    });

    it('should link every "Create one" to an existing page', async () => {
      const page = await render(MainDashboardComponent, { fetchAll: ok([]) }, { fetchAll: ok([]) });

      const links = Array.from(page.querySelectorAll('a'))
        .filter(link => link.textContent!.trim() === 'Create one')
        .map(link => link.getAttribute('href'));
      expect(links).toEqual(['/persons/new', '/organizations/new']);
    });
  });

  it('should not show an empty name in the title of an organization that could not be loaded', async () => {
    const page = await render(OrganizationDetailsComponent, {}, { fetchById: fail }, { orgId: '9' });

    expect(title(page)).toBe('Organization');
  });

  it('should not show an empty name in the title of a person that could not be loaded', async () => {
    const page = await render(PersonDetailsComponent, { fetchById: fail }, { fetchAll: ok([]) }, { personId: '9' });

    expect(title(page)).toBe('Person');
  });

  it('should name the loaded organization in the title', async () => {
    const org = { id: 1, name: 'Orion', createdAt: new Date(), persons: [] };
    const page = await render(OrganizationDetailsComponent, {}, { fetchById: ok(org) }, { orgId: '1' });

    expect(title(page)).toBe('Organization "Orion"');
  });
});
