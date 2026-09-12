---
title: Switch vacalibration from the GitHub SHA pin back to the CRAN snapshot
trigger_condition: vacalibration >= 2.3.1 appears on https://cran.r-project.org/web/packages/vacalibration/index.html (CRAN is still 2.2 as of 2026-09-12)
planted_date: 2026-09-12
---

# Switch vacalibration pin to CRAN

Phase 02.1 installs vacalibration 2.3.1 from GitHub pinned to commit `498df45`
because CRAN still carries 2.2 and the author's CRAN submission has no date.

When 2.3.1 (or later) lands on CRAN:

1. Move `CRAN_SNAPSHOT` in `backend/Dockerfile` to a date on or after the CRAN
   publication date. This is also the first snapshot bump allowed since
   StanHeaders 2.39.1 (2026-09-02) broke 2.2; confirm the Stan models still
   compile at the new snapshot's rstan/StanHeaders.
2. Replace the GitHub install with the plain `install.packages('vacalibration')`
   from the snapshot.
3. Regenerate `backend/package-manifest.csv` and let the Phase 2 manifest diff in
   `deploy.yml` prove the image is reproducible again.

Related note: `.planning/notes/vacalibration-2-3-1-vs-phase-1.md`.
