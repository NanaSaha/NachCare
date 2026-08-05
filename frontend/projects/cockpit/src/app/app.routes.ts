import { Routes } from '@angular/router';
import { authGuard } from './auth/auth.guard';

export const routes: Routes = [
  { path: 'login', loadComponent: () => import('./login/login').then((m) => m.Login) },
  {
    path: 'enroll',
    loadComponent: () => import('./enrollment/enrollment').then((m) => m.Enrollment),
    canActivate: [ authGuard ],
  },
  {
    path: 'triage',
    loadComponent: () => import('./triage/triage-queue').then((m) => m.TriageQueue),
    canActivate: [ authGuard ],
  },
  {
    path: 'triage/:id',
    loadComponent: () => import('./triage/flag-detail').then((m) => m.FlagDetail),
    canActivate: [ authGuard ],
  },
  {
    path: 'patients',
    loadComponent: () => import('./patients/patient-list').then((m) => m.PatientList),
    canActivate: [ authGuard ],
  },
  {
    path: 'patients/:id',
    loadComponent: () => import('./patients/patient-detail').then((m) => m.PatientDetail),
    canActivate: [ authGuard ],
  },
  {
    path: 'analytics',
    loadComponent: () => import('./analytics/analytics-dashboard').then((m) => m.AnalyticsDashboard),
    canActivate: [ authGuard ],
  },
  {
    path: 'risk-model',
    loadComponent: () => import('./risk-model/risk-model').then((m) => m.RiskModel),
    canActivate: [ authGuard ],
  },
  { path: '', pathMatch: 'full', redirectTo: 'triage' },
];
