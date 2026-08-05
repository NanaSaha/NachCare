import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideTranslateService } from '@ngx-translate/core';
import { EmergencyBlock } from './emergency-block';

describe('EmergencyBlock', () => {
  let fixture: ComponentFixture<EmergencyBlock>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [ EmergencyBlock ],
      providers: [ provideTranslateService({ lang: 'en', fallbackLang: 'en' }) ],
    }).compileComponents();

    fixture = TestBed.createComponent(EmergencyBlock);
    fixture.detectChanges();
  });

  it('renders a static tel:112 link with no bindings that depend on external data', () => {
    const link: HTMLAnchorElement = fixture.nativeElement.querySelector('[data-testid="emergency-call-link"]');
    expect(link).not.toBeNull();
    expect(link.getAttribute('href')).toBe('tel:112');
  });

  it('renders with role="alert" so it is announced regardless of where it is placed', () => {
    const block: HTMLElement = fixture.nativeElement.querySelector('[data-testid="emergency-block"]');
    expect(block.getAttribute('role')).toBe('alert');
  });
});
