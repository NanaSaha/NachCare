import { Provider } from '@angular/core';
import { provideTranslateService } from '@ngx-translate/core';
import { provideTranslateHttpLoader } from '@ngx-translate/http-loader';

/**
 * Runtime language switching (R7 / Section 2: ngx-translate, not
 * @angular/localize, because caregivers switch language per-user at
 * runtime). Each app ships its own `public/i18n/<lang>.json` files; this
 * just wires the shared loader/service config so both apps configure it
 * identically.
 */
export function provideAppTranslation(defaultLang = 'en'): Provider[] {
  // The loader MUST be passed via `loader:` here, not as a sibling entry in
  // the returned array — provideTranslateService() registers its own
  // (no-op) TranslateLoader provider internally when config.loader is
  // unset, and since providers for the same DI token resolve last-write-
  // wins, a sibling provideTranslateHttpLoader() would silently lose to it
  // and translations would never load over HTTP.
  return [
    provideTranslateService({
      lang: defaultLang,
      fallbackLang: 'en',
      loader: provideTranslateHttpLoader({ prefix: '/i18n/', suffix: '.json' }),
    }),
  ];
}
