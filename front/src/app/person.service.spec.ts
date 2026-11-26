import { TestBed } from '@angular/core/testing';

import { PersonService } from './person.service';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideHttpClient, withInterceptorsFromDi, withXhr } from '@angular/common/http';
import { API_BASE_URL } from './config';

// Le service fait `await` sur l'observable avant de s'y abonner: la requête part un tour d'événements plus tard.
const requestSent = () => new Promise<void>(resolve => setTimeout(resolve));

describe('PersonService', () => {
  let service: PersonService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
    imports: [],
    providers: [provideHttpClient(withXhr(), withInterceptorsFromDi()), provideHttpClientTesting()]
});
    service = TestBed.inject(PersonService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  // Envoie la réponse à la requête attendue, en vérifiant sa méthode et son URL.
  const answer = async (method: string, path: string, response: object | null) => {
    await requestSent();
    const req = http.expectOne(`${API_BASE_URL}${path}`);
    expect(req.request.method).toBe(method);
    req.flush(response);
    return req.request;
  };
  const orion = { id: 1, name: 'Orion' };
  const fields = { firstName: 'John', lastName: 'Doe', email: 'jdoe@example.net', phone: '123', bio: 'Developer' };
  const draft = { ...fields, createdAt: new Date(), organizations: [] };

  it('should be created', () => {
    expect(service).toBeTruthy();
  });

  it('fetchById should return the person with its organizations', async () => {
    const result = service.fetchById(7);
    await answer('GET', '/persons/7', { id: 7, ...fields });
    await answer('GET', '/persons/7/organizations', { _embedded: { organizations: [orion] } });

    expect(await result).toEqual({ id: 7, ...fields, organizations: [orion] });
  });

  it('fetchAll should return the persons of the HAL response', async () => {
    const result = service.fetchAll();
    await answer('GET', '/persons', { _embedded: { persons: [{ id: 7, ...fields }] } });

    expect(await result).toEqual([{ id: 7, ...fields }]);
  });

  it('deleteById should DELETE the person', async () => {
    const done = service.deleteById(7);
    await answer('DELETE', '/persons/7', null);

    await done;
  });

  // Le corps ne contient que les champs du formulaire: ni les dates ni les organisations.
  it('save should POST a new person with the form fields only', async () => {
    const result = service.save({ ...draft });
    const sent = await answer('POST', '/persons', { id: 7, ...fields });
    await answer('GET', '/persons/7/organizations', { _embedded: { organizations: [] } });

    expect(sent.body).toEqual(fields);
    expect(await result).toEqual({ id: 7, ...fields, organizations: [] });
  });

  it('save should PUT an existing person and reload its organizations', async () => {
    const result = service.save({ ...draft, id: 7 });
    const sent = await answer('PUT', '/persons/7', { id: 7, ...fields });
    await answer('GET', '/persons/7/organizations', { _embedded: { organizations: [orion] } });

    expect(sent.body).toEqual(fields);
    expect(await result).toEqual({ id: 7, ...fields, organizations: [orion] });
  });
});
