\# Release Decision — v1.0.0



\## What the gate checked



The release gate CI (`.github/workflows/release-gate.yml`) runs on every version tag and executes:

1\. Full backend test suite (RSpec) against a fresh Postgres + Redis instance on Linux (GitHub Actions runner).

2\. Full frontend build + test suite (Vitest) on Node 20.



It does \*\*not\*\* and \*\*cannot\*\* currently verify:

\- The real-time voice interview flow end-to-end (WebSocket → Gemini Live → audio playback), because this requires a live Gemini API key and cannot be meaningfully simulated in CI without incurring real API costs and non-determinism.

\- Behavior specifically on Windows, since the CI runner is Linux-based.



\## What it found



\- All automated backend and frontend tests pass (see CI run attached to this tag).

\- 5 of 7 audit findings (BUG-001, 002, 003, 004, 006, 007) are fixed and covered by regression tests.

\- \*\*BUG-005 remains open\*\*: the WebSocket audio infrastructure is fully implemented (reconnect logic, audio ring buffer, coverage-based auto-end, time-ceiling handling — see `/assessment/01-audit.md`) but crashes fatally on Windows due to an EventMachine + SSL native-extension limitation. This is a well-known, long-standing compatibility gap for EventMachine on Windows, not a defect in the application's own logic.



\## My recommendation: \*\*BLOCK the release of the voice-interview feature specifically, ship everything else.\*\*



\### Reasoning



Per the quality bar in this case study's brief: a known risk you disclose, with a mitigation and a named owner, is professional; hiding it behind a passing build is the failure mode we screen for. I have not been able to verify BUG-005 in a Linux/production-representative environment within this exercise, so I cannot honestly claim it works in production — even though there is good reason to believe it likely will (EventMachine + SSL is far more stable on Linux than Windows, which is the deployment target for virtually all production Rails apps).



Rather than either (a) claiming full "all green" release readiness I can't actually back up, or (b) blocking the entire release over one feature that may well work fine in the real deployment environment, I'm scoping the block to exactly what's unverified.



\### What ships now (releasable)

\- Fixed onboarding flow (correct ports, working seed data).

\- Fixed internet speed check (no longer false-blocking candidates).

\- Fixed data integrity issue where failed sessions were indistinguishable from successful ones.

\- Quality gate infrastructure (Definition of Ready CI, test suites) protecting future changes.



\### What's blocked

\- The real-time voice interview feature itself, pending verification on a Linux/staging environment that mirrors production.



\### Mitigation \& owner

\- \*\*Immediate mitigation\*\*: deploy to a Linux-based staging environment and manually run one full interview session end-to-end before enabling this feature for real candidates.

\- \*\*Owner\*\*: whoever owns the deployment/infra for this project should run that verification; I was unable to do so within this Windows-only case study environment.

\- \*\*If it fails on Linux too\*\*: the fix would involve either (a) replacing `faye-websocket` + `EventMachine` with a more actively maintained WebSocket stack (e.g. `async-websocket` or Rails' native `ActionCable` with a protocol adapter), which is a larger refactor, or (b) pinning to a known-working EventMachine build with explicit OpenSSL linkage.



\## Honest self-assessment of this case study's scope



Two audit findings (BUG-005 fully, and the underlying "why does no one see this until now" — BUG-007, absence of tests) turned out to be linked: without any test coverage and without CI running on a representative platform, this class of environment-specific crash could easily have shipped completely unnoticed. The Definition of Ready gate and test suites added in this exercise are aimed at preventing exactly that in the future.

