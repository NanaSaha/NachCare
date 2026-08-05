EN and DE are hand-written (DE is `MACHINE_DRAFT`, see `docs/OPEN_DECISIONS.md`
#2 — needs native review before clinical use). `tr.json`, `ru.json`,
`ar.json` are EN-fallback scaffolds: same keys, English text, so the app
never renders a missing-key placeholder while those languages await real
translation (playbook Section 2, R7).

AR RTL layout (M6, ADR-0008 #9): `document.documentElement.dir` follows the
active language app-wide (`app/language/language.service.ts`, applied at
boot and on every switch from the Care-team page's language switcher), and
a repo-wide audit of caregiver CSS found only one direction-dependent
physical property (`onboarding.css`, fixed to the logical `text-align:
start`) — everything else already mirrors correctly under `dir="rtl"`
via CSS flexbox's automatic inline-direction handling. `tr.json`/`ru.json`
still need real translation (same open item as always); `ar.json`'s text
content is still EN-fallback too, but the *layout* itself is RTL-ready
independent of when real Arabic copy lands.
