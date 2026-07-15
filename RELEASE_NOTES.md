\# Release v1.0.0



\## What this version delivers



This release hardens the quality workflow for the AI Interview Platform and fixes several critical bugs found during audit, but does \*\*not\*\* claim the real-time voice interview feature is production-ready on all platforms — see Known Issues below.



\### Fixed

\- \*\*BUG-001 / BUG-003\*\* (P0): Wrong default ports in `.env.example` and `application.yml.sample` caused every fresh setup to fail login and break candidate invite links.

\- \*\*BUG-002\*\* (P1): `db:seed` never created a login user, making a fresh setup impossible to sign into.

\- \*\*BUG-004\*\* (P1): Internet speed check falsely blocked candidates with legitimate connections, due to an overly strict threshold and reliance on an unreliable third-party server for measurement.

\- \*\*BUG-006\*\* (P0, data integrity): Sessions falsely appeared as "Interview Complete" to candidates while remaining `status: active` forever in the database when the WebSocket connection failed. Sessions are now honestly marked as `ended` / `error` in this scenario.

\- \*\*BUG-007\*\*: Initialized RSpec (previously present in the Gemfile but never set up — zero tests existed in the backend).



\### Quality infrastructure added

\- Definition of Ready gate (PR template + CI check) blocking merges without a spec, acceptance criteria, and tests.

\- Backend (RSpec) and frontend (Vitest) test suites, previously nonexistent.

\- Release gate CI (this workflow) running the full test suite on every version tag.



\## Known Issues (see /assessment for full detail)



\- \*\*BUG-005 (P0, OPEN)\*\*: The real-time voice interview feature (WebSocket audio streaming to Gemini Live) is fully implemented but crashes fatally in Windows development environments due to a known EventMachine + SSL limitation. This has \*\*not been verified\*\* on a Linux/production-representative environment within this case study. See `/assessment/01-audit.md` for full root cause analysis and `/assessment/03-release-decision.md` for the ship/block recommendation.

