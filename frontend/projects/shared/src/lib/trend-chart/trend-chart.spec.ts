import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideTranslateService } from '@ngx-translate/core';
import { TrendChart } from './trend-chart';

describe('TrendChart', () => {
  let fixture: ComponentFixture<TrendChart>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [ TrendChart ],
      providers: [ provideTranslateService({ lang: 'en', fallbackLang: 'en' }) ],
    }).compileComponents();

    fixture = TestBed.createComponent(TrendChart);
  });

  it('renders a polyline through the known points', () => {
    fixture.componentRef.setInput('points', [
      { label: '1', value: 70 },
      { label: '2', value: 71 },
      { label: '3', value: 69 },
    ]);
    fixture.detectChanges();

    const svg: SVGSVGElement = fixture.nativeElement.querySelector('svg');
    const polyline = svg.querySelector('polyline');
    expect(polyline).not.toBeNull();
    expect(polyline!.getAttribute('points')!.split(' ').length).toBe(3);
  });

  it('skips null points but keeps their slot in the x-axis spacing', () => {
    fixture.componentRef.setInput('points', [
      { label: '1', value: 70 },
      { label: '2', value: null },
      { label: '3', value: 72 },
    ]);
    fixture.detectChanges();

    const polyline = fixture.nativeElement.querySelector('polyline');
    expect(polyline!.getAttribute('points')!.split(' ').length).toBe(2);
  });

  it('shows an empty state when every point is null', () => {
    fixture.componentRef.setInput('points', [ { label: '1', value: null } ]);
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('[data-testid="trend-chart-empty"]')).not.toBeNull();
    expect(fixture.nativeElement.querySelector('svg')).toBeNull();
  });
});
