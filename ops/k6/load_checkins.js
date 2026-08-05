// M7 hardening (Section 8, ADR-0009 #9): "load script: 300 concurrent
// check-ins < 2 s p95." Posts against the real dev backend container
// (idempotent-on-client_uuid POST /api/v1/caregiver/check_ins, already
// proven correct in backend/spec/requests/api/v1/caregiver/check_ins_spec.rb)
// using device tokens for real, already-activated caregivers seeded by
// `bin/rails load_test:seed[N]` (backend/lib/tasks/load_test.rake).
//
// Run via ops/verify_m7.sh, or manually:
//   docker compose -f ops/docker-compose.yml run --rm backend \
//     bin/rails 'load_test:seed[300]'
//   docker run --rm --network nachcare_default \
//     -v "$(pwd)/ops/k6:/scripts" -e BASE_URL=http://backend:3000 \
//     grafana/k6 run /scripts/load_checkins.js
import http from 'k6/http';
import { check } from 'k6';
import { SharedArray } from 'k6/data';

// `client_uuid` is a native Postgres `uuid` column (backend/db/migrate/
// 20260802160011_create_check_ins.rb) — Rails silently casts anything
// that isn't valid UUID format to NULL rather than raising, which fails
// the `presence: true` validation with a plain 422 (found the hard way
// while building this M7 gate: every earlier debug attempt using a
// non-UUID placeholder string reproduced exactly this, and it looked
// like an app bug until isolated down to invalid test input). A minimal
// local v4 generator, not a remote jslib import: the k6 container this
// runs in has no guaranteed network access to fetch one at gate time.
function uuidv4() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3001';

const tokens = new SharedArray('caregiver tokens', function () {
  return JSON.parse(open('./load_test_tokens.json'));
});

export const options = {
  scenarios: {
    checkins: {
      executor: 'per-vu-iterations',
      vus: Math.min(300, tokens.length),
      iterations: 1,
      maxDuration: '60s',
    },
  },
  thresholds: {
    // The gate itself: p95 < 2s (Section 8/M7's exact wording).
    http_req_duration: [ 'p(95)<2000' ],
    checks: [ 'rate>0.99' ],
  },
};

export default function () {
  const entry = tokens[__VU % tokens.length];
  const payload = JSON.stringify({
    client_uuid: uuidv4(),
    effective_date: new Date().toISOString().slice(0, 10),
    weight_kg: 70.0,
    med_status: {},
    symptoms: {},
  });

  const res = http.post(`${BASE_URL}/api/v1/caregiver/check_ins`, payload, {
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${entry.device_token}`,
    },
  });

  check(res, {
    'status is 200 or 201': (r) => r.status === 200 || r.status === 201,
  });
}
