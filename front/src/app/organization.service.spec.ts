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

  // Envoie la réponse à la requête attendue, en vérifiant sa méthode et son URL.
  const answer = async (method: string, path: string, response: object | null) => {
    await requestSent();
    const req = http.expectOne(`${API_BASE_URL}${path}`);
    expect(req.request.method).toBe(method);
    req.flush(response);
    return req.request;
  };
  const jdoe = { id: 7, firstName: 'John' };

  it('fetchById should return the organization with its persons', async () => {
    const result = service.fetchById(1);
    await answer('GET', '/organizations/1', { id: 1, name: 'Orion' });
    await answer('GET', '/organizations/1/persons', { _embedded: { persons: [jdoe] } });

    expect(await result).toEqual(expect.objectContaining({ id: 1, name: 'Orion', persons: [jdoe] }));
  });

  it('fetchAll should return the organizations of the HAL response', async () => {
    const result = service.fetchAll();
    await answer('GET', '/organizations', { _embedded: { organizations: [{ id: 1, name: 'Orion' }] } });

    expect(await result).toEqual([{ id: 1, name: 'Orion' }]);
  });

  it('deleteById should DELETE the organization', async () => {
    const done = service.deleteById(1);
    await answer('DELETE', '/organizations/1', null);

    await done;
  });

  const draft = { name: 'Orion', createdAt: new Date(), persons: [] };

  it('save should POST a new organization, with its name only', async () => {
    const result = service.save({ ...draft });
    const sent = await answer('POST', '/organizations', { id: 1, name: 'Orion' });
    await answer('GET', '/organizations/1/persons', { _embedded: { persons: [] } });

    expect(sent.body).toEqual({ name: 'Orion' });
    expect(await result).toEqual(expect.objectContaining({ id: 1, persons: [] }));
  });

  it('save should PUT an existing organization and reload its persons', async () => {
    const result = service.save({ ...draft, id: 1 });
    const sent = await answer('PUT', '/organizations/1', { id: 1, name: 'Orion' });
    await answer('GET', '/organizations/1/persons', { _embedded: { persons: [jdoe] } });

    expect(sent.body).toEqual({ name: 'Orion' });
    expect(await result).toEqual(expect.objectContaining({ id: 1, persons: [jdoe] }));
  });
});
