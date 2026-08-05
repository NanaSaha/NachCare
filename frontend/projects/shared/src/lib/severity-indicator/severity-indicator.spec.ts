import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideTranslateService } from '@ngx-translate/core';
import { SeverityIndicator } from './severity-indicator';
import { SeverityLevel } from './severity-level';

describe('SeverityIndicator', () => {
  let fixture: ComponentFixture<SeverityIndicator>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [SeverityIndicator],
      providers: [provideTranslateService({ lang: 'en', fallbackLang: 'en' })],
    }).compileComponents();

    fixture = TestBed.createComponent(SeverityIndicator);
  });

  (['green', 'yellow', 'red'] as SeverityLevel[]).forEach((level) => {
    it(`renders the ${level} state with its severity class, an icon, and text`, () => {
      fixture.componentRef.setInput('level', level);
      fixture.detectChanges();

      const host: HTMLElement = fixture.nativeElement;
      const badge = host.querySelector('.severity');

      expect(badge).withContext('badge element').not.toBeNull();
      expect(badge!.classList).toContain(`severity--${level}`);
      expect(badge!.querySelector('svg.severity__icon')).withContext('icon').not.toBeNull();
      expect(badge!.querySelector('.severity__text')!.textContent!.trim().length).toBeGreaterThan(0);
    });
  });

  it('prefers an explicit label override over the translated default', () => {
    fixture.componentRef.setInput('level', 'red');
    fixture.componentRef.setInput('label', 'Custom label');
    fixture.detectChanges();

    const text = fixture.nativeElement.querySelector('.severity__text').textContent.trim();
    expect(text).toBe('Custom label');
  });
});
