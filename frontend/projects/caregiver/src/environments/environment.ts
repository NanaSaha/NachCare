export const environment = {
  apiOrigin: 'http://localhost:3001',
  // Dev-only VAPID public key — must match VAPID_PUBLIC_KEY in
  // ops/docker-compose.yml (see backend ADR-0006). Public key only; the
  // private key never leaves the backend.
  vapidPublicKey: 'BOyTQtptL3RxsxpdGPi-vEmSQNDQzeb2saKutyOxsK_H-S511CkSuKqSTHdbV2HMKzQdK3rYMFkkPRnC7DrYwMo',
};
