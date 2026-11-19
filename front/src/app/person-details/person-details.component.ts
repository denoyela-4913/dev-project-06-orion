
import { Component, OnInit, ChangeDetectionStrategy } from '@angular/core';
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

  constructor(private route: ActivatedRoute, private personService: PersonService, private organizationService: OrganizationService, private router: Router) {
    this.organizationService.fetchAll().then(orgs => this.organizations = orgs)
  }

  ngOnInit(): void {
    const routeParams = this.route.snapshot.paramMap;
    const personIdParam = routeParams.get('personId');

    if (personIdParam === 'new') {
      this.isNew = true
    } else if (typeof personIdParam === 'string') {
      const personId = parseInt(personIdParam)
      this.personService.fetchById(personId).then(p => {
        this.person = p
        this.isNew = false
      })
    }
  }

  savePerson() {
    this.personService.save({
      ...this.person
    }).then(p => {
      this.person = p
      if (this.isNew) {
        this.router.navigate(["persons", p.id])
      }
    })
  }

  deletePerson() {
    if (this.person.id === undefined) return
    this.personService.deleteById(this.person.id).then(() => {
      this.router.navigate([""])
    })
  }

  // On attend la fin de l'appel avant de recharger: sinon le rechargement peut partir avant que l'API ait
  // enregistré le lien, et l'écran affiche l'ancien état.
  async addSelectedOrganization() {
    if (this.selectedOrganization?.id === undefined || this.person.id === undefined) return
    await this.organizationService.addPerson(this.selectedOrganization.id, this.person.id)
    await this.refresh()
  }

  async removeOrganization(org: Organization) {
    if (org?.id === undefined || this.person.id === undefined) return
    await this.organizationService.removePerson(org.id, this.person.id)
    await this.refresh()
  }

  async refresh() {
    if (this.person.id === undefined) return
    this.person = await this.personService.fetchById(this.person.id)
    this.isNew = false
  }
}
