import { Injectable } from '@angular/core';

const DB_NAME = 'nachcare-caregiver';
const STORE_NAME = 'pending-check-ins';
const DB_VERSION = 1;

export interface QueuedCheckIn {
  clientUuid: string;
  payload: unknown;
  queuedAt: string;
}

/**
 * FR-C15: if a check-in submit fails due to network, persist it (keyed by
 * client_uuid, the same field the backend uses for idempotency) and retry
 * later rather than losing it. The backend dedupes on client_uuid, so a
 * retry after a partial success (request landed, response didn't) is safe.
 */
@Injectable({ providedIn: 'root' })
export class OfflineQueue {
  private dbPromise: Promise<IDBDatabase> | null = null;

  private db(): Promise<IDBDatabase> {
    this.dbPromise ??= new Promise((resolve, reject) => {
      const request = indexedDB.open(DB_NAME, DB_VERSION);
      request.onupgradeneeded = () => {
        request.result.createObjectStore(STORE_NAME, { keyPath: 'clientUuid' });
      };
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
    return this.dbPromise;
  }

  async enqueue(item: QueuedCheckIn): Promise<void> {
    const db = await this.db();
    return new Promise((resolve, reject) => {
      const tx = db.transaction(STORE_NAME, 'readwrite');
      tx.objectStore(STORE_NAME).put(item);
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
    });
  }

  async dequeue(clientUuid: string): Promise<void> {
    const db = await this.db();
    return new Promise((resolve, reject) => {
      const tx = db.transaction(STORE_NAME, 'readwrite');
      tx.objectStore(STORE_NAME).delete(clientUuid);
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
    });
  }

  async all(): Promise<QueuedCheckIn[]> {
    const db = await this.db();
    return new Promise((resolve, reject) => {
      const tx = db.transaction(STORE_NAME, 'readonly');
      const request = tx.objectStore(STORE_NAME).getAll();
      request.onsuccess = () => resolve(request.result as QueuedCheckIn[]);
      request.onerror = () => reject(request.error);
    });
  }
}
