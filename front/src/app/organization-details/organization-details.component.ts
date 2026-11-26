import { DatePipe } from '@angular/common';
import { Component, OnInit, ChangeDetectionStrategy } from '@angular/core';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { Person, PersonService } from '../person.service';
import { Organization, OrganizationService } from '../organization.service';

@Component({
    selector: 'app-organization-details',
    imports: [FormsModule, RouterLink, DatePipe],
    templateUrl: './organization-details.component.html',
    changeDetection: ChangeDetectionStrategy.Eager,
    styleUrl: './organization-details.component.css'
})
export class OrganizationDetailsComponent implements OnInit {
  org: Organization = {
    id: undefined as (number | undefined),
    name: '',
    createdAt: new Date(),
    updatedAt: undefined as (Date | undefined),
    persons: [] as Person[]
  };

  isNew: boolean = false;
  errors: string[] = [];

  constructor(private route: ActivatedRoute, private personService: PersonService, private organizationService: OrganizationService, private router: Router) {
  }

  ngOnInit(): void {
    const routeParams = this.route.snapshot.paramMap;
    const orgIdParam = routeParams.get('orgId');

    if (orgIdParam === 'new') {
      this.isNew = true
    } else if (typeof orgIdParam === 'string') {
      const orgId = parseInt(orgIdParam)
      this.organizationService.fetchById(orgId)
        .then(org => {
          this.org = org
          this.isNew = false
        })
        .catch(error => this.reportError('Could not load the organization.', error))
    }
  }

  // L'action et la navigation sont traitées séparément: si seule la navigation échoue, le message ne doit pas
  // annoncer l'échec d'un enregistrement ou d'une suppression qui a réussi.
  async saveOrg() {
    this.errors = []
    try {
      this.org = await this.organizationService.save({ ...this.org })
    } catch (error) {
      this.reportError('Could not save the organization.', error)
      return
    }
    if (this.isNew) {
      await this.router.navigate(["organizations", this.org.id])
        .catch(error => this.reportError('The organization is saved, but its page could not be opened.', error))
    }
  }

  async deleteOrg() {
    if (this.org.id === undefined) return
    this.errors = []
    try {
      await this.organizationService.deleteById(this.org.id)
    } catch (error) {
      this.reportError('Could not delete the organization.', error)
      return
    }
    await this.router.navigate([""])
      .catch(error => this.reportError('The organization is deleted, but the home page could not be opened.', error))
  }

  private reportError(message: string, error: unknown) {
    console.error(message, error)
    this.errors.push(message)
  }
}
