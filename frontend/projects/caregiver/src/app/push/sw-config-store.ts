const DB_NAME = 'nachcare-caregiver-sw';
const STORE_NAME = 'config';
const DB_VERSION = 1;
const CONFIG_KEY = 'config';

export interface SwConfig {
  apiOrigin: string;
  deviceToken: string;
}

/**
 * The service worker's `push` handler runs even when no app tab is open,
 * so it can't read the device token out of Angular DI or localStorage
 * (not exposed to SW scope). IndexedDB is the only storage both contexts
 * can reach, so the main thread mirrors what the SW needs here — see
 * PushSubscriptionService.
 */
function openDb(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);
    request.onupgradeneeded = () => {
      request.result.createObjectStore(STORE_NAME);
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

export async function saveSwConfig(config: SwConfig): Promise<void> {
  const db = await openDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, 'readwrite');
    tx.objectStore(STORE_NAME).put(config, CONFIG_KEY);
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
}
