import { ApplicationConfig, provideBrowserGlobalErrorListeners, provideZoneChangeDetection } from '@angular/core';
import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { provideRouter } from '@angular/router';
import { provideAppTranslation, provideApiOrigin } from 'shared';
import { environment } from '../environments/environment';
import { deviceAuthInterceptor } from './auth/device-auth.interceptor';

import { routes } from './app.routes';

export const appConfig: ApplicationConfig = {
  providers: [
    provideBrowserGlobalErrorListeners(),
    provideZoneChangeDetection({ eventCoalescing: true }),
    provideRouter(routes),
    provideHttpClient(withInterceptors([ deviceAuthInterceptor ])),
    provideAppTranslation('en'),
    provideApiOrigin(environment.apiOrigin),
  ]
};
