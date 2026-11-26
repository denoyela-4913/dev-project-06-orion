import { DatePipe } from '@angular/common';
import { Component, OnInit, ChangeDetectionStrategy } from '@angular/core';
import { RouterLink } from '@angular/router';
import { Person, PersonService } from '../person.service';
import { Organization, OrganizationService } from '../organization.service';

@Component({
    selector: 'app-main-dashboard',
    imports: [RouterLink, DatePipe],
    templateUrl: './main-dashboard.component.html',
    changeDetection: ChangeDetectionStrategy.Eager,
    styleUrl: './main-dashboard.component.css'
})
export class MainDashboardComponent implements OnInit {
  organizations: Organization[] = [];
  persons: Person[] = [];
  errors: string[] = [];

  constructor(private personService: PersonService, private organizationService: OrganizationService) { }


  ngOnInit(): void {
    // Les deux listes sont chargées en parallèle: chacune traite son échec, et les deux messages peuvent s'afficher.
    this.personService.fetchAll()
      .then(persons => this.persons = persons)
      .catch(error => this.reportError('Could not load the persons.', error));
    this.organizationService.fetchAll()
      .then(orgs => this.organizations = orgs)
      .catch(error => this.reportError('Could not load the organizations.', error));
  }

  // Message à l'écran pour l'utilisateur, cause dans la console pour le diagnostic.
  private reportError(message: string, error: unknown) {
    console.error(message, error);
    this.errors.push(message);
  }
}

