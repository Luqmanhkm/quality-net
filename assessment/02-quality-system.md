\# Quality System — What I Built, How to Run It, What It Protects



\## 1. Definition of Ready Gate



\*\*What it is:\*\* A GitHub Actions workflow (`.github/workflows/definition-of-ready.yml`) that runs on every pull request and blocks merging unless the PR description has all three Definition of Ready checkboxes checked: a spec/reference to the problem, acceptance criteria, and a solution/design plan.



\*\*How to run it:\*\* It runs automatically on every PR — no manual invocation needed. Combined with a branch protection rule on `main` (Settings → Branches) requiring the `check-dor` status check to pass before merging.



\*\*What it protects:\*\* Prevents "ghost spec" changes — code landing without anyone being able to say what it's for, how to verify it, or what approach was taken. This is the case study's core problem statement, enforced mechanically rather than relying on discipline alone.



\*\*What it deliberately does NOT cover:\*\* It only checks that the checkboxes are \*checked\* — it cannot verify that the spec/criteria/plan text is actually \*good\* or \*true\*. That still requires human review. It's a floor, not a ceiling.



\*\*Proof it works:\*\*

\- PR #1 (`test/blocked-pr-no-spec`): checklist left unchecked → gate failed, merge blocked by branch protection.

\- PR #2–#6: checklist fully filled → gate passed, merges allowed.



\## 2. Test Suites (previously nonexistent — BUG-007)



\*\*What it is:\*\* RSpec for the backend (`api/spec/`), Vitest for the frontend (`web/src/\*\*/\*.test.ts`). Both were absent at the start of this audit despite `rspec-rails` being listed in the Gemfile.



\*\*How to run it:\*\*

\- Backend: `cd api \&\& bundle exec rspec`

\- Frontend: `cd web \&\& npm run test`



\*\*What it protects:\*\* Each test added is a direct regression test for a specific audit finding (see `01-audit.md` for the BUG-### cross-references) — not blanket coverage for its own sake. Currently covers: seed idempotency (BUG-002), config sanity for `.env.example`/`application.yml.sample` (BUG-001/003), internet speed threshold logic (BUG-004), and the `audio\_complete` reason-handling endpoint (BUG-006).



\*\*What it deliberately does NOT cover:\*\* The real-time voice interview flow itself (WebSocket ↔ Gemini Live audio streaming) is not covered by automated tests — it requires a live Gemini API key and is inherently non-deterministic (real AI conversation). This is a conscious scope decision, not an oversight; see BUG-005 in the audit and the release decision for how this risk is handled instead (manual verification requirement, documented and disclosed rather than silently untested).



\## 3. Release Gate (`.github/workflows/release-gate.yml`)



\*\*What it is:\*\* Runs on every version tag (`v\*`). Spins up Postgres + Redis, runs the full backend and frontend test suites on a clean Linux environment (GitHub Actions runner), and reports a clear `RELEASABLE` / `BLOCKED` status.



\*\*How to run it:\*\* Automatically on `git tag vX.Y.Z \&\& git push origin vX.Y.Z`.



\*\*What it protects:\*\* Ensures a release is only tagged as good when the full suite passes on a platform-representative environment — not just "works on my machine." This is what caught BUG-008: a class-naming bug invisible in local Windows development (where `eager\_load` is off by default) that would have made the app fail to boot entirely in production. Tag `v1.0.0` was rejected by this gate for exactly that reason; `v1.0.1` passed after the fix.



\*\*What it deliberately does NOT cover:\*\* Same limitation as the test suite — the real-time voice feature's actual runtime behavior on Linux is not verified by this gate (no live Gemini key in CI). See `03-release-decision.md` for how that gap is handled in the ship/block decision.



\## Red → Green history (see also 01-audit.md and individual PRs)



| Bug | Red (before) | Green (after) | Verified via |

|---|---|---|---|

| BUG-001/003 | Wrong ports in config templates broke login \& invite links | Correct defaults + regression tests | PR #4, automated test |

| BUG-002/007 | No login possible after fresh seed; zero tests existed | Idempotent seed user + first test suite | PR #3, automated test |

| BUG-004 | Legitimate connections falsely blocked from interview | Threshold fixed + regression test | PR #2, automated test |

| BUG-006 | Session silently stayed "active" forever on connection failure | Session honestly marked "ended"/"error" | PR #5, automated test + manual verification |

| BUG-008 | Release gate itself failed on tag v1.0.0 (app fails to boot in production) | Release gate passed on tag v1.0.1 | PR #6, full CI run on both tags |

