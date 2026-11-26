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
  // `callFake`: la promesse rejetée n'est créée qu'au moment de l'appel.
  const fail = () => Promise.reject(cause);

  const org: Organization = { id: 1, name: 'Orion', createdAt: new Date(), persons: [] };
  const person: Person = {
    id: 2, firstName: 'John', lastName: 'Doe', email: '', phone: '', bio: '',
    createdAt: new Date(), organizations: [org]
  };

  let routeParams: Record<string, string>;
  let persons: jasmine.SpyObj<PersonService>;
  let organizations: jasmine.SpyObj<OrganizationService>;
  let navigate: jasmine.Spy;
  let consoleError: jasmine.Spy;
  let fixture: ComponentFixture<unknown>;

  beforeEach(() => {
    routeParams = {};
    // Tous les appels réussissent par défaut; chaque test fait échouer celui qu'il vérifie.
    persons = jasmine.createSpyObj<PersonService>('PersonService', ['fetchAll', 'fetchById', 'save', 'deleteById']);
    persons.fetchAll.and.resolveTo([]);
    persons.fetchById.and.resolveTo({ ...person });
    persons.save.and.resolveTo({ ...person });
    persons.deleteById.and.resolveTo();
    organizations = jasmine.createSpyObj<OrganizationService>('OrganizationService',
      ['fetchAll', 'fetchById', 'save', 'deleteById', 'addPerson', 'removePerson']);
    organizations.fetchAll.and.resolveTo([]);
    organizations.fetchById.and.resolveTo({ ...org });
    organizations.save.and.resolveTo({ ...org });
    organizations.deleteById.and.resolveTo();
    organizations.addPerson.and.resolveTo();
    organizations.removePerson.and.resolveTo();

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
    navigate = spyOn(TestBed.inject(Router), 'navigate').and.resolveTo(true);
    consoleError = spyOn(console, 'error');
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
      persons.fetchAll.and.callFake(fail);
      await create(MainDashboardComponent);

      expectReported('Could not load the persons.');
    });

    it('should report that the organizations cannot be loaded', async () => {
      organizations.fetchAll.and.callFake(fail);
      await create(MainDashboardComponent);

      expectReported('Could not load the organizations.');
    });

    it('should report both lists when both fail', async () => {
      persons.fetchAll.and.callFake(fail);
      organizations.fetchAll.and.callFake(fail);
      await create(MainDashboardComponent);

      expect(alerts()).toEqual(jasmine.arrayWithExactContents(
        ['Could not load the persons.', 'Could not load the organizations.']));
    });
  });

  describe('organization details', () => {
    it('should report that the organization cannot be loaded', async () => {
      organizations.fetchById.and.callFake(fail);
      await create(OrganizationDetailsComponent, { orgId: '1' });

      expectReported('Could not load the organization.');
    });

    it('should report that the organization cannot be saved, and stay on the page', async () => {
      organizations.save.and.callFake(fail);
      const component = await create(OrganizationDetailsComponent, { orgId: 'new' });

      await component.saveOrg();
      await settle();

      expectReported('Could not save the organization.');
      expect(navigate).not.toHaveBeenCalled();
    });

    it('should clear the previous error when saving succeeds', async () => {
      organizations.save.and.callFake(fail);
      const component = await create(OrganizationDetailsComponent, { orgId: '1' });
      await component.saveOrg();
      organizations.save.and.resolveTo({ ...org });

      await component.saveOrg();
      await settle();

      expect(alerts()).toEqual([]);
    });

    it('should report that the page of the saved organization cannot be opened', async () => {
      navigate.and.callFake(fail);
      const component = await create(OrganizationDetailsComponent, { orgId: 'new' });

      await component.saveOrg();
      await settle();

      expectReported('The organization is saved, but its page could not be opened.');
    });

    it('should report that the organization cannot be deleted, and stay on the page', async () => {
      organizations.deleteById.and.callFake(fail);
      const component = await create(OrganizationDetailsComponent, { orgId: '1' });

      await component.deleteOrg();
      await settle();

      expectReported('Could not delete the organization.');
      expect(navigate).not.toHaveBeenCalled();
    });

    it('should report that the home page cannot be opened after a deletion', async () => {
      navigate.and.callFake(fail);
      const component = await create(OrganizationDetailsComponent, { orgId: '1' });

      await component.deleteOrg();
      await settle();

      expectReported('The organization is deleted, but the home page could not be opened.');
    });
  });

  describe('person details', () => {
    it('should report that the list of organizations cannot be loaded', async () => {
      organizations.fetchAll.and.callFake(fail);
      await create(PersonDetailsComponent, { personId: 'new' });

      expectReported('Could not load the organizations.');
    });

    it('should report that the person cannot be loaded', async () => {
      persons.fetchById.and.callFake(fail);
      await create(PersonDetailsComponent, { personId: '2' });

      expectReported('Could not load the person.');
    });

    it('should report that the person cannot be saved, and stay on the page', async () => {
      persons.save.and.callFake(fail);
      const component = await create(PersonDetailsComponent, { personId: 'new' });

      await component.savePerson();
      await settle();

      expectReported('Could not save the person.');
      expect(navigate).not.toHaveBeenCalled();
    });

    it('should report that the page of the saved person cannot be opened', async () => {
      navigate.and.callFake(fail);
      const component = await create(PersonDetailsComponent, { personId: 'new' });

      await component.savePerson();
      await settle();

      expectReported('The person is saved, but its page could not be opened.');
    });

    it('should report that the person cannot be deleted, and stay on the page', async () => {
      persons.deleteById.and.callFake(fail);
      const component = await create(PersonDetailsComponent, { personId: '2' });

      await component.deletePerson();
      await settle();

      expectReported('Could not delete the person.');
      expect(navigate).not.toHaveBeenCalled();
    });

    it('should report that the home page cannot be opened after a deletion', async () => {
      navigate.and.callFake(fail);
      const component = await create(PersonDetailsComponent, { personId: '2' });

      await component.deletePerson();
      await settle();

      expectReported('The person is deleted, but the home page could not be opened.');
    });

    it('should report that the organization cannot be added, without reloading the person', async () => {
      organizations.addPerson.and.callFake(fail);
      const component = await create(PersonDetailsComponent, { personId: '2' });
      persons.fetchById.calls.reset();
      component.selectedOrganization = org;

      await component.addSelectedOrganization();
      await settle();

      expectReported('Could not add the organization.');
      expect(persons.fetchById).not.toHaveBeenCalled();
    });

    it('should report that the organization cannot be removed, without reloading the person', async () => {
      organizations.removePerson.and.callFake(fail);
      const component = await create(PersonDetailsComponent, { personId: '2' });
      persons.fetchById.calls.reset();

      await component.removeOrganization(org);
      await settle();

      expectReported('Could not remove the organization.');
      expect(persons.fetchById).not.toHaveBeenCalled();
    });

    // L'ajout a réussi: le message ne doit pas dire le contraire.
    it('should report a failed reload as such after an organization has been added', async () => {
      const component = await create(PersonDetailsComponent, { personId: '2' });
      persons.fetchById.and.callFake(fail);
      component.selectedOrganization = org;

      await component.addSelectedOrganization();
      await settle();

      expectReported('Could not reload the person.');
    });

    it('should report a failed reload as such after an organization has been removed', async () => {
      const component = await create(PersonDetailsComponent, { personId: '2' });
      persons.fetchById.and.callFake(fail);

      await component.removeOrganization(org);
      await settle();

      expectReported('Could not reload the person.');
    });
  });
});
