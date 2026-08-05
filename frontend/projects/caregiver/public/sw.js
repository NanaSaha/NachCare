// Plain (non-Angular) service worker: receives web push events and shows
// a notification, then POSTs a "confirm beacon" back to the backend so
// PushConfirmWatchJob knows the push actually arrived (Section 8 M4 RED
// chain: push -> unconfirmed 5min -> SMS). Kept deliberately separate from
// any Angular-CLI-generated ngsw-worker.js (asset caching) — this file
// only deals with push.

const DB_NAME = 'nachcare-caregiver-sw';
const STORE_NAME = 'config';
const CONFIG_KEY = 'config';

function readConfig() {
  return new Promise((resolve, reject) => {
    const openRequest = indexedDB.open(DB_NAME, 1);
    openRequest.onupgradeneeded = () => {
      openRequest.result.createObjectStore(STORE_NAME);
    };
    openRequest.onsuccess = () => {
      const db = openRequest.result;
      const tx = db.transaction(STORE_NAME, 'readonly');
      const getRequest = tx.objectStore(STORE_NAME).get(CONFIG_KEY);
      getRequest.onsuccess = () => resolve(getRequest.result || null);
      getRequest.onerror = () => reject(getRequest.error);
    };
    openRequest.onerror = () => reject(openRequest.error);
  });
}

self.addEventListener('push', (event) => {
  // Body is always generic text (R5: no health data in payloads) — see
  // backend Domain::Notifications::Templates.
  let payload = { id: null, body: 'Open the app for an update.' };
  try {
    if (event.data) payload = event.data.json();
  } catch {
    // Non-JSON payload: fall back to the default generic body above.
  }

  event.waitUntil(
    (async () => {
      await self.registration.showNotification('NachCareAI', {
        body: payload.body,
        tag: payload.id || undefined,
      });

      if (!payload.id) return;

      try {
        const config = await readConfig();
        if (!config) return;

        await fetch(`${config.apiOrigin}/api/v1/caregiver/notification_attempts/${payload.id}/confirm`, {
          method: 'POST',
          headers: { Authorization: `Bearer ${config.deviceToken}` },
        });
      } catch {
        // Best-effort: if the confirm beacon fails (offline, etc.),
        // PushConfirmWatchJob's SMS fallback is the intended safety net —
        // do not retry here.
      }
    })(),
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(self.clients.openWindow('/'));
});
