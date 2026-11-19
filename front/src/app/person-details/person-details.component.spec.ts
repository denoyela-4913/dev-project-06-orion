import { ComponentFixture, TestBed } from '@angular/core/testing';

import { PersonDetailsComponent } from './person-details.component';
import { provideHttpClientTesting } from '@angular/common/http/testing';
import { RouterTestingModule } from "@angular/router/testing";
import { provideHttpClient, withInterceptorsFromDi, withXhr } from '@angular/common/http';
import { OrganizationService } from '../organization.service';
import { PersonService } from '../person.service';


describe('IndividualDetailsComponent', () => {
  let component: PersonDetailsComponent;
  let fixture: ComponentFixture<PersonDetailsComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
    imports: [PersonDetailsComponent, RouterTestingModule],
    providers: [provideHttpClient(withXhr(), withInterceptorsFromDi()), provideHttpClientTesting()]
})
      .compileComponents();

    fixture = TestBed.createComponent(PersonDetailsComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  describe('email field', () => {
    const typeEmail = async (value: string) => {
      const input: HTMLInputElement = fixture.nativeElement.querySelector('input[name="email"]');
      input.value = value;
      input.dispatchEvent(new Event('input'));
      fixture.detectChanges();
      await fixture.whenStable();
      fixture.detectChanges();
      return input;
    };
    const errorText = () => fixture.nativeElement.querySelector('input[name="email"]')
      .closest('.field').querySelector('.help.is-danger')?.textContent ?? '';

    it('should reject a value that is not an email address', async () => {
      const input = await typeEmail('not-an-email');

      expect(input.classList).toContain('is-danger');
      expect(errorText()).toContain('Email must be a valid email address.');
    });

    it('should accept a valid email address', async () => {
      const input = await typeEmail('jdoe@example.net');

      expect(input.classList).not.toContain('is-danger');
      expect(errorText()).toBe('');
    });

    it('should accept an empty email address (the field is optional)', async () => {
      const input = await typeEmail('');

      expect(input.classList).not.toContain('is-danger');
    });
  });

  describe('organization links', () => {
    const org = { id: 1, name: 'Orion', createdAt: new Date(), persons: [] };
    let finishLink: () => void;
    let organizationService: OrganizationService;
    let personService: PersonService;

    beforeEach(() => {
      organizationService = TestBed.inject(OrganizationService);
      personService = TestBed.inject(PersonService);
      // Appel d'API qui ne se termine que quand le test le décide.
      const pending = new Promise<void>(resolve => (finishLink = resolve));
      spyOn(organizationService, 'addPerson').and.returnValue(pending);
      spyOn(organizationService, 'removePerson').and.returnValue(pending);
      spyOn(personService, 'fetchById').and.resolveTo({ ...component.person, id: 2, organizations: [org] });
      component.person.id = 2;
    });

    it('should list only the organizations of the person, not all of them', async () => {
      const other = { id: 3, name: 'Other', createdAt: new Date(), persons: [] };
      component.organizations = [org, other];
      component.person.organizations = [org];
      fixture.detectChanges();

      const rows = fixture.nativeElement.querySelectorAll('table tbody tr');
      expect(rows.length).toBe(1);
      expect(rows[0].textContent).toContain('Orion');
    });

    it('should reload the person only once the organization has been added', async () => {
      component.selectedOrganization = org;
      const done = component.addSelectedOrganization();

      expect(organizationService.addPerson).toHaveBeenCalledWith(1, 2);
      expect(personService.fetchById).not.toHaveBeenCalled();

      finishLink();
      await done;
      expect(personService.fetchById).toHaveBeenCalledWith(2);
      expect(component.person.organizations).toEqual([org]);
    });

    it('should reload the person only once the organization has been removed', async () => {
      const done = component.removeOrganization(org);

      expect(organizationService.removePerson).toHaveBeenCalledWith(1, 2);
      expect(personService.fetchById).not.toHaveBeenCalled();

      finishLink();
      await done;
      expect(personService.fetchById).toHaveBeenCalledWith(2);
    });
  });
});
