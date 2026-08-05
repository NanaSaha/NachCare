import { Routes } from '@angular/router';
import { deviceAuthGuard } from './auth/device-auth.guard';

export const routes: Routes = [
  { path: 'activate', loadComponent: () => import('./activation/activation').then((m) => m.Activation) },
  {
    path: 'onboarding',
    loadComponent: () => import('./onboarding/onboarding').then((m) => m.Onboarding),
    canActivate: [ deviceAuthGuard ],
  },
  {
    path: 'home',
    loadComponent: () => import('./check-in/check-in').then((m) => m.CheckIn),
    canActivate: [ deviceAuthGuard ],
  },
  {
    path: 'assistant',
    loadComponent: () => import('./assistant/assistant').then((m) => m.Assistant),
    canActivate: [ deviceAuthGuard ],
  },
  {
    path: 'care-plan',
    loadComponent: () => import('./care-plan/care-plan').then((m) => m.CarePlan),
    canActivate: [ deviceAuthGuard ],
  },
  {
    path: 'care-tasks',
    loadComponent: () => import('./care-tasks/care-tasks').then((m) => m.CareTasks),
    canActivate: [ deviceAuthGuard ],
  },
  {
    path: 'trends',
    loadComponent: () => import('./trends/trends').then((m) => m.Trends),
    canActivate: [ deviceAuthGuard ],
  },
  {
    path: 'learn',
    loadComponent: () => import('./learn/learn').then((m) => m.Learn),
    canActivate: [ deviceAuthGuard ],
  },
  {
    path: 'care-team',
    loadComponent: () => import('./care-team/care-team').then((m) => m.CareTeam),
    canActivate: [ deviceAuthGuard ],
  },
  { path: '', pathMatch: 'full', redirectTo: 'activate' },
];
