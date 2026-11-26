
import { Component, OnInit, ChangeDetectionStrategy, inject } from '@angular/core';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { Person, PersonService } from '../person.service';
import { Organization, OrganizationService } from '../organization.service';

@Component({
    selector: 'app-person-details',
    imports: [FormsModule, RouterLink],
    templateUrl: './person-details.component.html',
    changeDetection: ChangeDetectionStrategy.Eager,
    styleUrl: './person-details.component.css'
})
export class PersonDetailsComponent implements OnInit {
  private route = inject(ActivatedRoute);
  private personService = inject(PersonService);
  private organizationService = inject(OrganizationService);
  private router = inject(Router);

  person: Person = {
    id: undefined as (number | undefined),
    firstName: '',
    lastName: '',
    phone: '',
    email: '',
    bio: '',
    createdAt: new Date(),
    updatedAt: undefined as (Date | undefined),
    organizations: [] as (Organization[])
  };

  organizations: Organization[] = []
  selectedOrganization: Organization | null = null;
  isNew: boolean = false;
  errors: string[] = [];

  ngOnInit(): void {
    // Chargement ici et non dans le constructeur (Sonar S7059): un constructeur ne doit pas lancer d'appel
    // asynchrone, le composant n'est pas encore initialisé et le test ne peut pas le contrôler.
    this.organizationService.fetchAll()
      .then(orgs => this.organizations = orgs)
      .catch(error => this.reportError('Could not load the organizations.', error))

    const routeParams = this.route.snapshot.paramMap;
    const personIdParam = routeParams.get('personId');

    if (personIdParam === 'new') {
      this.isNew = true
    } else if (typeof personIdParam === 'string') {
      // Number.parseInt avec la base 10 explicite (Sonar S7773): même résultat qu'avant.
      const personId = Number.parseInt(personIdParam, 10)
      this.personService.fetchById(personId)
        .then(p => {
          this.person = p
          this.isNew = false
        })
        .catch(error => this.reportError('Could not load the person.', error))
    }
  }

  // L'action et la suite (navigation, rechargement) sont traitées séparément: si seule la suite échoue, le
  // message ne doit pas annoncer l'échec d'une action qui a réussi.
  async savePerson() {
    this.errors = []
    try {
      this.person = await this.personService.save({ ...this.person })
    } catch (error) {
      this.reportError('Could not save the person.', error)
      return
    }
    if (this.isNew) {
      await this.router.navigate(["persons", this.person.id])
        .catch(error => this.reportError('The person is saved, but its page could not be opened.', error))
    }
  }

  async deletePerson() {
    if (this.person.id === undefined) return
    this.errors = []
    try {
      await this.personService.deleteById(this.person.id)
    } catch (error) {
      this.reportError('Could not delete the person.', error)
      return
    }
    await this.router.navigate([""])
      .catch(error => this.reportError('The person is deleted, but the home page could not be opened.', error))
  }

  // On attend la fin de l'appel avant de recharger: sinon le rechargement peut partir avant que l'API ait
  // enregistré le lien, et l'écran affiche l'ancien état.
  // Appelées par le template: personne n'attend leur promesse, elles doivent donc traiter leurs échecs.
  async addSelectedOrganization() {
    if (this.selectedOrganization?.id === undefined || this.person.id === undefined) return
    this.errors = []
    try {
      await this.organizationService.addPerson(this.selectedOrganization.id, this.person.id)
    } catch (error) {
      this.reportError('Could not add the organization.', error)
      return
    }
    await this.reload()
  }

  async removeOrganization(org: Organization) {
    if (org?.id === undefined || this.person.id === undefined) return
    this.errors = []
    try {
      await this.organizationService.removePerson(org.id, this.person.id)
    } catch (error) {
      this.reportError('Could not remove the organization.', error)
      return
    }
    await this.reload()
  }

  async refresh() {
    if (this.person.id === undefined) return
    this.person = await this.personService.fetchById(this.person.id)
    this.isNew = false
  }

  private async reload() {
    await this.refresh().catch(error => this.reportError('Could not reload the person.', error))
  }

  private reportError(message: string, error: unknown) {
    console.error(message, error)
    this.errors.push(message)
  }
}
