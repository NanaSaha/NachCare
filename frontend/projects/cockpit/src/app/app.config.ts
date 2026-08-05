import { ApplicationConfig, provideBrowserGlobalErrorListeners, provideZoneChangeDetection } from '@angular/core';
import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { provideRouter } from '@angular/router';
import { provideAppTranslation, provideApiOrigin } from 'shared';
import { environment } from '../environments/environment';
import { authInterceptor } from './auth/auth.interceptor';

import { routes } from './app.routes';

export const appConfig: ApplicationConfig = {
  providers: [
    provideBrowserGlobalErrorListeners(),
    provideZoneChangeDetection({ eventCoalescing: true }),
    provideRouter(routes),
    provideHttpClient(withInterceptors([ authInterceptor ])),
    provideAppTranslation('en'),
    provideApiOrigin(environment.apiOrigin),
  ]
};
