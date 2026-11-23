# 0129. CI runs goldens alone on macOS and skips what a change can't touch

Status: accepted and in use (`ci.yml` follows it); proposed in pull request 41 (the owner, 2026-11-16: "Is there any way we can improve CI? It seems to have grown and takes a long time now").

## Context
A full CI run took 10–16 minutes (median 12) on 2026-11-16, and `make check` plus `make check-app` 15–18 minutes before each push, with the Flutter suite run twice. The app's suite had grown from 168 test files on 10-30 to 366. The two macOS app shards were always the critical path: each ran half of all files, split every nth file by name, so a shard's slowest files started last. A macOS runner is 1.5–4× slower than a Mac and the account runs five macOS jobs at once. Only 122 files need a Mac: 121 compare goldens, which are drawn with macOS's text rendering, and `tile_mark` reads the Mac's emoji font. Every push ran every job, though of main's last 59 pushes 22 changed only docs, 17 only the app and 12 only Go. The measurements: `nushi-review/2026-11-16-ci-speed/measure.md`, outside the repository.

## Decision
- **Host sets.** `tools/test-shards` puts every app test file (`app/test/**/*_test.dart`, not `test/web`) in one set: macOS for a file with `matchesGoldenFile(`, `Platform.isMacOS` or `/System/Library/`, Linux for the rest. CI's macOS app jobs run the macOS set in 3 shards, without Go's cache or build: with 2, a slow macOS host (three to four times slower than a fast one for the same files) left the run waiting up to 9 minutes. The Linux set runs in 3 Linux shards.
- **Shards by time.** The tool splits a set by `app/test/timings.tsv` (each file's seconds in its CI shard, run plus the shard's median load: a golden file runs about five times slower on CI's macOS runner than on a Mac, the rest about three times, so local times misjudged the golden shards; each shard's report is scaled to its set's mean, since hosts differ up to four times in speed), slowest first to the least loaded shard; a file the table lacks weighs its median. Each shard runs its files slowest first. A shard's count is its matrix's (`strategy.job-total`) and nowhere else. `make test-timings RUN=<id>` rewrites the table from the reports CI's app shards upload; a stale table costs balance, never coverage.
- **No file dropped.** `test-shards -check`, in `make lint-dart`, fails on a split that drops or repeats a file for 1–6 shards of any set, on a macOS-set file that builds Go (`e2e_rig.dart`) or tests Linux, and on a malformed table. On a Linux-set run (`NUSHI_TEST_SET=linux`, which `make test-app` sets) a golden fails instead of passing unseen.
- **What is given up.** A file without goldens no longer runs on a macOS runner. The app under test behaves the same on both hosts (`native = macosNative()` in every test); font metrics differ slightly. `make check` runs every file on the Mac before each push.
- **The other jobs.** The web app's end-to-end test runs on Linux (nushid runs there, ADR 0101). Go's lint and tests on macOS run side by side in one job (`make -j2`, with the window's Swift tests), and Linux's cross-lint is a job of its own. That keeps four macOS jobs per run, leaving one slot for a release or another repository.
- **Path filters.** A changes job runs `tools/ci-changes.sh` on a pull request's whole branch or a push's own commits. Docs (`docs/`, the root's Markdown, `LICENSE`) run nothing; so does `site/` (amended 2026-11-23: only site.yml reads it). Go's folders run Go's four jobs and the jobs that build Go into what they test. The app's and the packages' folders run all but Go's jobs; `app/macos` counts as Go too, for the window's tests. Anything else, any path it can't place, any other event (the release's call) and any git error run everything. Its table has a self-test in the lint job and `make lint`.
- **Two guards for the filters.** The release counts a CI run as passed only if it skipped no job, else it calls CI, which then runs all. Main's runs don't cancel each other (a pull request's still do), so a docs-only push can't cancel the only run that tested the code before it.
- **Caches.** golangci-lint's results: one entry a week, saved by main's pushes only, not one per commit (219 entries, 2.5 GB, which pushed the repository over its 10 GB and evicted Flutter's SDKs).

## Consequences
- The critical path is a golden shard on a slow macOS host, or Go's macOS job.
- A release of a commit whose run skipped jobs runs CI in full first, a few minutes longer.
- A golden reached through a helper that test-shards can't see fails its Linux shard with what to do: call `matchesGoldenFile(` in the test file.
- A burst of pushes to main queues for macOS slots instead of cancelling.

## Alternatives considered
- Two golden shards with Go's lint and tests as two macOS jobs: a slow host's shard took 7.5–9.3 minutes. Five macOS jobs: no slot left for a release or another repository.
- Per-test golden tags: both hosts would compile every golden file, and the tags need upkeep.
- A paths-filter action: a third-party dependency for 30 lines of shell.
- A nightly macOS run of every file, per-commit or daily Go caches, and dropping `-shuffle` for Go's test cache: `make check` covers the first; the others refill the cache quota or lose order checks.

## Amendments
- 2026-11-21 (a review found the Mac app first built once a release was public): **CI builds the Mac app**, as a release does (`tools/release.sh 0.0.0-ci app`: every Runner Swift file, the plugins, the bundle signed ad hoc and checked), in a macOS job of its own, beside the others so it adds nothing to the critical path. It runs only when a change touches what that build reads beyond the Dart and Go the other jobs compile (`app/macos`, `app/pubspec.*`, `cmd/`, and what runs everything: the Makefile, `tools/`, `packaging/`, CI), so most runs keep to four macOS jobs; one that runs everything takes the fifth slot, and a release then waits for it. Not in the release's call: the release's own app job is that build, and its check doesn't count this job skipped.
