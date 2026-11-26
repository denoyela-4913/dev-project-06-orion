import type { Mock, MockedObject } from 'vitest';
import { Type } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideHttpClient, withInterceptorsFromDi, withXhr } from '@angular/common/http';
import { provideHttpClientTesting } from '@angular/common/http/testing';
import { ActivatedRoute, convertToParamMap, provideRouter, Router } from '@angular/router';

import { MainDashboardComponent } from './main-dashboard/main-dashboard.component';
import { OrganizationDetailsComponent } from './organization-details/organization-details.component';
import { PersonDetailsComponent } from './person-details/person-details.component';
import { Organization, OrganizationService } from './organization.service';
import { Person, PersonService } from './person.service';

// Chaque appel asynchrone des composants doit traiter son échec: message à l'écran et cause dans la console.
describe('error handling', () => {
  const cause = new Error('API down');
  // `mockImplementation`: la promesse rejetée n'est créée qu'au moment de l'appel.
  const fail = () => Promise.reject(cause);

  const org: Organization = { id: 1, name: 'Orion', createdAt: new Date(), persons: [] };
  const person: Person = {
    id: 2, firstName: 'John', lastName: 'Doe', email: '', phone: '', bio: '',
    createdAt: new Date(), organizations: [org]
  };

  let routeParams: Record<string, string>;
  let persons: MockedObject<PersonService>;
  let organizations: MockedObject<OrganizationService>;
  let navigate: Mock;
  let consoleError: Mock;
  let fixture: ComponentFixture<unknown>;

  beforeEach(() => {
    routeParams = {};
    // Tous les appels réussissent par défaut; chaque test fait échouer celui qu'il vérifie.
    // Faux services: seules les méthodes publiques utilisées par les composants sont simulées, d'où la
    // conversion de type.
    persons = {
      fetchAll: vi.fn().mockResolvedValue([]),
      fetchById: vi.fn().mockResolvedValue({ ...person }),
      save: vi.fn().mockResolvedValue({ ...person }),
      deleteById: vi.fn().mockResolvedValue(undefined),
    } as unknown as MockedObject<PersonService>;
    organizations = {
      fetchAll: vi.fn().mockResolvedValue([]),
      fetchById: vi.fn().mockResolvedValue({ ...org }),
      save: vi.fn().mockResolvedValue({ ...org }),
      deleteById: vi.fn().mockResolvedValue(undefined),
      addPerson: vi.fn().mockResolvedValue(undefined),
      removePerson: vi.fn().mockResolvedValue(undefined),
    } as unknown as MockedObject<OrganizationService>;

    TestBed.configureTestingModule({
      providers: [
        provideHttpClient(withXhr(), withInterceptorsFromDi()),
        provideHttpClientTesting(),
        provideRouter([]),
        { provide: PersonService, useValue: persons },
        { provide: OrganizationService, useValue: organizations },
        { provide: ActivatedRoute, useFactory: () => ({ snapshot: { paramMap: convertToParamMap(routeParams) } }) },
      ]
    });
    navigate = vi.spyOn(TestBed.inject(Router), 'navigate').mockResolvedValue(true);
    consoleError = vi.spyOn(console, 'error').mockImplementation(() => undefined);
  });

  // Laisse les promesses en cours se terminer, puis met l'affichage à jour.
  const settle = async () => {
    await new Promise<void>(resolve => setTimeout(resolve));
    fixture.detectChanges();
  };

  const create = async <T>(type: Type<T>, params: Record<string, string> = {}) => {
    routeParams = params;
    const created = TestBed.createComponent(type);
    fixture = created;
    created.detectChanges();
    await settle();
    return created.componentInstance;
  };

  const alerts = (): string[] =>
    Array.from<HTMLElement>(fixture.nativeElement.querySelectorAll('[role="alert"]'))
      .map(element => element.textContent!.trim());

  const expectReported = (message: string) => {
    expect(alerts()).toEqual([message]);
    expect(consoleError).toHaveBeenCalledWith(message, cause);
  };

  describe('main dashboard', () => {
    it('should show no error when the lists are loaded', async () => {
      await create(MainDashboardComponent);

      expect(alerts()).toEqual([]);
    });

    it('should report that the persons cannot be loaded', async () => {
      persons.fetchAll.mockImplementation(fail);
      await create(MainDashboardComponent);

      expectReported('Could not load the persons.');
    });

    it('should report that the organizations cannot be loaded', async () => {
      organizations.fetchAll.mockImplementation(fail);
      await create(MainDashboardComponent);

      expectReported('Could not load the organizations.');
    });

    it('should report both lists when both fail', async () => {
      persons.fetchAll.mockImplementation(fail);
      organizations.fetchAll.mockImplementation(fail);
      await create(MainDashboardComponent);

      // L'ordre d'arrivée des deux échecs n'importe pas.
      expect([...alerts()].sort()).toEqual(['Could not load the organizations.', 'Could not load the persons.']);
    });
  });

  describe('organization details', () => {
    it('should report that the organization cannot be loaded', async () => {
      organizations.fetchById.mockImplementation(fail);
      await create(OrganizationDetailsComponent, { orgId: '1' });

      expectReported('Could not load the organization.');
    });

    it('should report that the organization cannot be saved, and stay on the page', async () => {
      organizations.save.mockImplementation(fail);
      const component = await create(OrganizationDetailsComponent, { orgId: 'new' });

      await component.saveOrg();
      await settle();

      expectReported('Could not save the organization.');
      expect(navigate).not.toHaveBeenCalled();
    });

    it('should clear the previous error when saving succeeds', async () => {
      organizations.save.mockImplementation(fail);
      const component = await create(OrganizationDetailsComponent, { orgId: '1' });
      await component.saveOrg();
      organizations.save.mockResolvedValue({ ...org });

      await component.saveOrg();
      await settle();

      expect(alerts()).toEqual([]);
    });

    it('should report that the page of the saved organization cannot be opened', async () => {
      navigate.mockImplementation(fail);
      const component = await create(OrganizationDetailsComponent, { orgId: 'new' });

      await component.saveOrg();
      await settle();

      expectReported('The organization is saved, but its page could not be opened.');
    });

    it('should report that the organization cannot be deleted, and stay on the page', async () => {
      organizations.deleteById.mockImplementation(fail);
      const component = await create(OrganizationDetailsComponent, { orgId: '1' });

      await component.deleteOrg();
      await settle();

      expectReported('Could not delete the organization.');
      expect(navigate).not.toHaveBeenCalled();
    });

    it('should report that the home page cannot be opened after a deletion', async () => {
      navigate.mockImplementation(fail);
      const component = await create(OrganizationDetailsComponent, { orgId: '1' });

      await component.deleteOrg();
      await settle();

      expectReported('The organization is deleted, but the home page could not be opened.');
    });
  });

  describe('person details', () => {
    it('should report that the list of organizations cannot be loaded', async () => {
      organizations.fetchAll.mockImplementation(fail);
      await create(PersonDetailsComponent, { personId: 'new' });

      expectReported('Could not load the organizations.');
    });

    it('should report that the person cannot be loaded', async () => {
      persons.fetchById.mockImplementation(fail);
      await create(PersonDetailsComponent, { personId: '2' });

      expectReported('Could not load the person.');
    });

    it('should report that the person cannot be saved, and stay on the page', async () => {
      persons.save.mockImplementation(fail);
      const component = await create(PersonDetailsComponent, { personId: 'new' });

      await component.savePerson();
      await settle();

      expectReported('Could not save the person.');
      expect(navigate).not.toHaveBeenCalled();
    });

    it('should report that the page of the saved person cannot be opened', async () => {
      navigate.mockImplementation(fail);
      const component = await create(PersonDetailsComponent, { personId: 'new' });

      await component.savePerson();
      await settle();

      expectReported('The person is saved, but its page could not be opened.');
    });

    it('should report that the person cannot be deleted, and stay on the page', async () => {
      persons.deleteById.mockImplementation(fail);
      const component = await create(PersonDetailsComponent, { personId: '2' });

      await component.deletePerson();
      await settle();

      expectReported('Could not delete the person.');
      expect(navigate).not.toHaveBeenCalled();
    });

    it('should report that the home page cannot be opened after a deletion', async () => {
      navigate.mockImplementation(fail);
      const component = await create(PersonDetailsComponent, { personId: '2' });

      await component.deletePerson();
      await settle();

      expectReported('The person is deleted, but the home page could not be opened.');
    });

    it('should report that the organization cannot be added, without reloading the person', async () => {
      organizations.addPerson.mockImplementation(fail);
      const component = await create(PersonDetailsComponent, { personId: '2' });
      persons.fetchById.mockClear();
      component.selectedOrganization = org;

      await component.addSelectedOrganization();
      await settle();

      expectReported('Could not add the organization.');
      expect(persons.fetchById).not.toHaveBeenCalled();
    });

    it('should report that the organization cannot be removed, without reloading the person', async () => {
      organizations.removePerson.mockImplementation(fail);
      const component = await create(PersonDetailsComponent, { personId: '2' });
      persons.fetchById.mockClear();

      await component.removeOrganization(org);
      await settle();

      expectReported('Could not remove the organization.');
      expect(persons.fetchById).not.toHaveBeenCalled();
    });

    // L'ajout a réussi: le message ne doit pas dire le contraire.
    it('should report a failed reload as such after an organization has been added', async () => {
      const component = await create(PersonDetailsComponent, { personId: '2' });
      persons.fetchById.mockImplementation(fail);
      component.selectedOrganization = org;

      await component.addSelectedOrganization();
      await settle();

      expectReported('Could not reload the person.');
    });

    it('should report a failed reload as such after an organization has been removed', async () => {
      const component = await create(PersonDetailsComponent, { personId: '2' });
      persons.fetchById.mockImplementation(fail);

      await component.removeOrganization(org);
      await settle();

      expectReported('Could not reload the person.');
    });
  });
});
