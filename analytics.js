/*
 * Google Analytics (GA4) for hallowedgains.com.
 *
 * Every page loads this one file, so the measurement ID lives in exactly one
 * place. The games under /games get it injected at deploy time by
 * scripts/fetch-games.sh (unless their game.json says "analytics": false, as
 * Lily's games do: they're made for young children).
 *
 * Privacy choices, mirrored in privacy.html:
 *   - Usage measurement only: Google signals and ad personalization are off,
 *     and all ad-related consent is denied everywhere.
 *   - In the EEA, the UK and Switzerland, analytics cookies are denied by
 *     default (Consent Mode), since those regions require opt-in.
 *   - Browsers sending Global Privacy Control are not measured at all.
 *   - Only the live site is measured: local copies and Firebase preview
 *     channels load nothing.
 */
(function () {
  'use strict';

  // GA4 measurement ID (Admin -> Data streams -> the hallowedgains.com stream).
  // Measurement IDs are public by design; they appear in every page's source.
  // Empty means analytics is off.
  var MEASUREMENT_ID = 'G-184E2N4YKM';

  var LIVE_HOSTS = ['hallowedgains.com', 'www.hallowedgains.com'];

  // Opt-in-by-law regions: EU member states, the rest of the EEA, the UK and
  // Switzerland (ISO 3166-1 alpha-2).
  var CONSENT_REGIONS = [
    'AT', 'BE', 'BG', 'HR', 'CY', 'CZ', 'DK', 'EE', 'FI', 'FR', 'DE', 'GR', 'HU', 'IE',
    'IT', 'LV', 'LT', 'LU', 'MT', 'NL', 'PL', 'PT', 'RO', 'SK', 'SI', 'ES', 'SE',
    'IS', 'LI', 'NO', 'GB', 'CH',
  ];

  if (!MEASUREMENT_ID) return;
  if (LIVE_HOSTS.indexOf(location.hostname) === -1) return;
  if (navigator.globalPrivacyControl) return;

  window.dataLayer = window.dataLayer || [];
  function gtag() { window.dataLayer.push(arguments); }
  window.gtag = gtag;

  var noAds = { ad_storage: 'denied', ad_user_data: 'denied', ad_personalization: 'denied' };
  gtag('consent', 'default', Object.assign({ analytics_storage: 'denied', region: CONSENT_REGIONS }, noAds));
  gtag('consent', 'default', Object.assign({ analytics_storage: 'granted' }, noAds));

  gtag('js', new Date());
  gtag('config', MEASUREMENT_ID, {
    allow_google_signals: false,
    allow_ad_personalization_signals: false,
  });

  var script = document.createElement('script');
  script.async = true;
  script.src = 'https://www.googletagmanager.com/gtag/js?id=' + encodeURIComponent(MEASUREMENT_ID);
  document.head.appendChild(script);
})();
