import { TestBed } from '@angular/core/testing';

import { OrganizationService } from './organization.service';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideHttpClient, withInterceptorsFromDi, withXhr } from '@angular/common/http';
import { API_BASE_URL } from './config';

// Le service fait `await` sur l'observable avant de s'y abonner: la requête part un tour d'événements plus tard.
const requestSent = () => new Promise<void>(resolve => setTimeout(resolve));

describe('OrganizationService', () => {
  let service: OrganizationService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
    imports: [],
    providers: [provideHttpClient(withXhr(), withInterceptorsFromDi()), provideHttpClientTesting()]
});
    service = TestBed.inject(OrganizationService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  it('should be created', () => {
    expect(service).toBeTruthy();
  });

  it('addPerson should POST the person URI so that the other persons are kept', async () => {
    const done = service.addPerson(1, 7);
    await requestSent();
    const req = http.expectOne(`${API_BASE_URL}/organizations/1/persons`);
    expect(req.request.method).toBe('POST');
    expect(req.request.headers.get('Content-Type')).toBe('text/uri-list');
    expect(req.request.body).toBe(`${API_BASE_URL}/persons/7`);
    req.flush(null);
    await done;
  });

  it('removePerson should DELETE through the organization, owner of the relation', async () => {
    const done = service.removePerson(1, 7);
    await requestSent();
    const req = http.expectOne(`${API_BASE_URL}/organizations/1/persons/7`);
    expect(req.request.method).toBe('DELETE');
    req.flush(null);
    await done;
  });
});
