# ADR-0004: Prawn (not Grover) for the A5 activation code sheet

**Status:** Accepted
**Date:** 2026-08-03

## Context

Section 8 (M1) leaves the PDF renderer as an open choice: "printable A5 code
sheet (server-rendered PDF via `grover` or `prawn` — ADR)". Grover renders
HTML/CSS via a headless Chromium (through `puppeteer`), which means baking
a Chromium install into `backend/Dockerfile` — a few hundred MB, plus
sandboxing flags to get right in a container. Prawn draws the PDF directly
in Ruby with no external process or browser dependency.

## Decision

Use Prawn (+ `prawn-table` for the layout grid). The code sheet is simple —
a code, a QR-free instruction block, a patient pseudonym/site line — nothing
that needs full CSS layout or web fonts. Prawn covers it with zero added
container footprint.

## Consequences

If a future PDF (e.g., the day-90 report, M5/M6) needs richer layout that's
painful in Prawn's coordinate-based API, revisit with Grover for that
specific document rather than switching everything — the two aren't
mutually exclusive across the codebase.
