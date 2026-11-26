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
      vi.spyOn(organizationService, 'addPerson').mockReturnValue(pending);
      vi.spyOn(organizationService, 'removePerson').mockReturnValue(pending);
      vi.spyOn(personService, 'fetchById').mockResolvedValue({ ...component.person, id: 2, organizations: [org] });
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

  // Sonar Web:InputWithoutLabelCheck et Web:S6853: un lecteur d'écran ne peut annoncer un champ que si un
  // <label for> pointe vers son id.
  it('should give every form control a label', () => {
    const controls: HTMLElement[] = Array.from(fixture.nativeElement.querySelectorAll('input, select, textarea'));

    expect(controls.length).toBeGreaterThan(0);
    for (const control of controls) {
      expect(control.id, `control "${control.getAttribute('name')}" has no id`).not.toBe('');
      expect(fixture.nativeElement.querySelector(`label[for="${control.id}"]`),
        `control "${control.id}" has no label`).not.toBeNull();
    }
  });

  // Le clic doit être porté par le bouton: sur le texte seul, un clic au bord du bouton ou son activation au
  // clavier ne faisait rien.
  it('should add the selected organization when the add button itself is activated', () => {
    const add = vi.spyOn(component, 'addSelectedOrganization').mockResolvedValue(undefined);
    const button: HTMLButtonElement = fixture.nativeElement
      .querySelector('#organization-to-add').closest('.has-addons').querySelector('button');

    button.click();

    expect(add).toHaveBeenCalledTimes(1);
    // `type="button"`: le bouton est dans le formulaire de la personne et ne doit pas le soumettre.
    expect(button.type).toBe('button');
    expect(button.getAttribute('aria-label')).toBe('Add organization');
  });

  // Sonar Web:S5256: un tableau de données a besoin d'en-têtes de colonnes.
  it('should give every table a header cell', () => {
    component.person.organizations = [{ id: 1, name: 'Orion', createdAt: new Date(), persons: [] }];
    fixture.detectChanges();

    const tables: HTMLElement[] = Array.from(fixture.nativeElement.querySelectorAll('table'));
    expect(tables.length).toBeGreaterThan(0);
    for (const table of tables) {
      expect(table.querySelector('th')).not.toBeNull();
    }
  });

  // Sonar typescript:S7059: pas d'appel asynchrone dans le constructeur, on charge dans ngOnInit.
  it('should load the organizations in ngOnInit and not in the constructor', () => {
    const organizationService = TestBed.inject(OrganizationService);
    const fetchAll = vi.spyOn(organizationService, 'fetchAll').mockResolvedValue([]);

    const created = TestBed.createComponent(PersonDetailsComponent);
    expect(fetchAll).not.toHaveBeenCalled();

    created.detectChanges();
    expect(fetchAll).toHaveBeenCalledTimes(1);
  });
});
