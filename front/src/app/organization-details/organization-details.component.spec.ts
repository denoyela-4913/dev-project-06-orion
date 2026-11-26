import { ComponentFixture, TestBed } from '@angular/core/testing';

import { OrganizationDetailsComponent } from './organization-details.component';
import { provideHttpClientTesting } from '@angular/common/http/testing';
import { RouterTestingModule } from "@angular/router/testing";
import { provideHttpClient, withInterceptorsFromDi, withXhr } from '@angular/common/http';


describe('IndividualDetailsComponent', () => {
  let component: OrganizationDetailsComponent;
  let fixture: ComponentFixture<OrganizationDetailsComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
    imports: [OrganizationDetailsComponent, RouterTestingModule],
    providers: [provideHttpClient(withXhr(), withInterceptorsFromDi()), provideHttpClientTesting()]
})
      .compileComponents();

    fixture = TestBed.createComponent(OrganizationDetailsComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  // Sonar Web:InputWithoutLabelCheck et Web:S6853: un <label for> doit pointer vers l'id du champ.
  it('should give every form control a label', () => {
    const controls: HTMLElement[] = Array.from(fixture.nativeElement.querySelectorAll('input, select, textarea'));

    expect(controls.length).toBeGreaterThan(0);
    for (const control of controls) {
      expect(control.id, `control "${control.getAttribute('name')}" has no id`).not.toBe('');
      expect(fixture.nativeElement.querySelector(`label[for="${control.id}"]`),
        `control "${control.id}" has no label`).not.toBeNull();
    }
  });
});
