import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideTranslateService } from '@ngx-translate/core';
import { BridgeArc } from './bridge-arc';

describe('BridgeArc', () => {
  let fixture: ComponentFixture<BridgeArc>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [BridgeArc],
      providers: [provideTranslateService({ lang: 'en', fallbackLang: 'en' })],
    }).compileComponents();

    fixture = TestBed.createComponent(BridgeArc);
  });

  it('renders the current day out of the total, clamped, with a traveller marker', () => {
    fixture.componentRef.setInput('currentDay', 17);
    fixture.componentRef.setInput('totalDays', 90);
    fixture.detectChanges();

    const host: HTMLElement = fixture.nativeElement;
    expect(host.querySelector('[data-testid="bridge-arc"]')).not.toBeNull();
    expect(host.querySelector('.bridge-arc__marker')).not.toBeNull();
    expect(host.querySelector('.bridge-arc__flag')).toBeNull();
    expect(host.querySelector('[data-testid="bridge-arc-label"]')!.textContent!.trim().length).toBeGreaterThan(0);
    expect(fixture.componentInstance.clampedDay()).toBe(17);
  });

  it('renders the crossed/graduation state once currentDay reaches totalDays', () => {
    fixture.componentRef.setInput('currentDay', 90);
    fixture.componentRef.setInput('totalDays', 90);
    fixture.detectChanges();

    const host: HTMLElement = fixture.nativeElement;
    expect(host.querySelector('.bridge-arc')!.classList).toContain('bridge-arc--crossed');
    expect(host.querySelector('.bridge-arc__flag')).not.toBeNull();
    expect(host.querySelector('.bridge-arc__marker')).toBeNull();
  });

  it('clamps a currentDay beyond totalDays instead of overshooting the arc', () => {
    fixture.componentRef.setInput('currentDay', 130);
    fixture.componentRef.setInput('totalDays', 90);
    fixture.detectChanges();

    expect(fixture.componentInstance.clampedDay()).toBe(90);
  });
});
