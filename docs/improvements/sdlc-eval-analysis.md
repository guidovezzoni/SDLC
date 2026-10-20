# SDLC Evals Analysis

Systematic analysis of eval coverage for all eight SDLC commands. Each table maps every
task/operation to the types of eval that can test it and whether that eval currently exists.

## Eval Type Legend

| Code | Eval Type | Description | Cost |
|------|-----------|-------------|------|
| **STATIC_GUARDR** | Static Guardrail | `grep`-based check that required patterns exist in the command MD file | Free |
| **EX-HAPPYP** | Execution: Happy Path | Run the command to completion with everything in place, assert correct output and side effects | Moderate–High |
| **EX-EDGE** | Execution: Edge Case | Run with specific abnormal conditions (dirty state, wrong branch, missing files, empty backlog) | Moderate |
| **EX-FAIL** | Execution: Failure Handling | Verify correct behaviour when a sub-agent or external tool fails (retry, escalate, report) | Moderate |
| **EX-BLOCKINGGT** | Execution: Blocking Gate | Verify the command stops and reports when a gate condition fails | Moderate |
| **EX-SIDEFX** | Execution: Side-Effect Verification | Verify files created, renamed, modified, or deleted correctly (git mv, index updates, report files) | Moderate |
| **EX-OUTPUTQ** | Execution: Output Quality | Verify the output structure and content meets expectations (refinement sections, BDD task format, report format) | Moderate |

---

## 1. `sdlc_open_story`

| # | Task / Operation | Eval Types | Implemented? | Priority |
|---|-----------------|------------|-----------------|----------|
| 1 | Check for uncommitted changes | STATIC_GUARDR: `git status`, `DO NOT DELETE DATA` guardrail present | Yes | MEDIUM |
|   |                               | EX-EDGE: dirty state warns user, names dirty files | Yes (`open_story_dirty_state`) | MEDIUM |
|   |                               | EX-EDGE: clean state proceeds without warning | No | LOW |
| 2 | Handle current branch (on main) | STATIC_GUARDR: `git branch --show-current` present | Yes | LOW |
|   |                                  | EX-HAPPYP: on main, fetch/pull succeeds, proceeds | No | LOW |
|   |                                  | EX-EDGE: on main, pull fails (conflict) — asks user | No | MEDIUM |
| 3 | Handle current branch (not on main) | EX-EDGE: detects non-main branch, asks proceed/switch | Yes (`open_story_not_on_main`) | MEDIUM |
|   |                                      | EX-EDGE: user chooses proceed — skips branch creation (step 5) | No | LOW |
|   |                                      | EX-EDGE: user chooses switch — switches to main, pulls | No | LOW |
| 4 | Resolve user story argument | STATIC_GUARDR: references `guidelines-userstories.md` | Yes | LOW |
|   |                              | EX-HAPPYP: auto-selects next story when no argument given | No | HIGH |
|   |                              | EX-EDGE: no actionable story exists — informs user and stops | No | MEDIUM |
|   |                              | EX-EDGE: specific story argument matches correctly | No | MEDIUM |
| 5 | Locate user story and validate preconditions | EX-EDGE: partial name match resolves correctly | No | MEDIUM |
|   |                                               | EX-EDGE: no match — asks user | No | MEDIUM |
|   |                                               | EX-BLOCKINGGT: preconditions not met — stops | No | HIGH |
| 6 | Create feature branch | EX-SIDEFX: branch created under `feature/` with ticket number prefix | No | LOW |
|   |                        | EX-EDGE: skip when user chose to stay on current branch | No | LOW |
| 7 | Open the user story (sub-agent, Haiku) | STATIC_GUARDR: Haiku model, `git mv`, failure handling, verification | Yes | MEDIUM |
|   |                                         | EX-SIDEFX: story file renamed correctly (status change) | No | HIGH |
|   |                                         | EX-SIDEFX: index.md updated with new filename | No | HIGH |
|   |                                         | EX-FAIL: sub-agent fails — retries with Sonnet, then inline | No | MEDIUM |
| 8 | Refine the user story (sub-agent, Opus) | STATIC_GUARDR: Opus model, failure handling, verification | Yes | MEDIUM |
|   |                                          | EX-OUTPUTQ: refined content at top, original at bottom under `## Original user story` | No | CRITICAL |
|   |                                          | EX-OUTPUTQ: refinement includes all 12 required sections (analytics, security, GDPR, etc.) | No | CRITICAL |
|   |                                          | EX-OUTPUTQ: stays at "what" level, does not prescribe architecture | No | HIGH |
|   |                                          | EX-FAIL: sub-agent fails — retries with Opus, then inline | No | MEDIUM |
| 9 | Add a report (sub-agent, Haiku) | STATIC_GUARDR: references `guidelines-reports.md` | Yes | LOW |
|   |                                  | EX-SIDEFX: report file exists and contains opening section | No | MEDIUM |
|   |                                  | EX-FAIL: sub-agent fails — retries, then inline | No | LOW |
| 10 | Display summary | EX-OUTPUTQ: output includes story name, branch, refinement highlights | No | LOW |
| 11 | Suggest commit message | STATIC_GUARDR: `Suggest a commit message`, references `guidelines-git.md` | Yes | LOW |
|    |                         | EX-OUTPUTQ: commit message follows git guidelines format (prefixed with issue reference) | No | LOW |
| — | Sub-agent orchestration (cross-cutting) | STATIC_GUARDR: `DO NOT MAKE ASSUMPTIONS`, sub-agent orchestration declaration | Yes | MEDIUM |

**Summary:** 14 static guardrails (all exist), 20 potential execution evals (2 exist).

---

## 2. `sdlc_propose_change`

| # | Task / Operation | Eval Types | Implemented? | Priority |
|---|-----------------|------------|-----------------|----------|
| 1 | Locate user story | EX-HAPPYP: matches by number or partial name | Partially (`propose_change_surfaces_questions` covers identification) | HIGH |
|   |                    | EX-EDGE: no match — asks user | No | MEDIUM |
|   |                    | EX-BLOCKINGGT: story not in WIP status — stops | No | HIGH |
| 2 | Explore codebase (sub-agent, Sonnet) | STATIC_GUARDR: Sonnet model, `opsx:explore`, read-only guardrail | Yes | MEDIUM |
|   |                                       | EX-OUTPUTQ: structured output with required sections (Architecture, Integration Points, Questions, Risks, Recommendations) | No | HIGH |
|   |                                       | EX-SIDEFX: no files created or modified (read-only) | No | MEDIUM |
|   |                                       | EX-FAIL: sub-agent fails or returns incomplete — retries with Sonnet, then inline | No | MEDIUM |
| 3 | Clarify all doubts | STATIC_GUARDR: `DO NOT MAKE ASSUMPTIONS` guardrail | Yes | HIGH |
|   |                     | EX-EDGE: surfaces questions for ambiguous requirements, does not assume | Yes (`propose_change_surfaces_questions`) | CRITICAL |
|   |                     | EX-EDGE: with unambiguous story — proceeds without excessive questions | No | LOW |
|   |                     | EX-OUTPUTQ: all questions include WHY explanation | No | MEDIUM |
| 4 | Propose change with BDD tasks (sub-agent, Sonnet) | STATIC_GUARDR: BDD, GIVEN/WHEN/THEN, test-first, `test task (write the test first)`, `implementation task`, `opsx:propose` | Yes | HIGH |
|   |                                                    | EX-SIDEFX: change directory created under `openspec/changes/` with all artifacts (proposal, design, specs, tasks) | No | CRITICAL |
|   |                                                    | EX-OUTPUTQ: tasks follow BDD structure — test task + implementation task pairs | No | CRITICAL |
|   |                                                    | EX-OUTPUTQ: each test task includes GIVEN/WHEN/THEN and target test class | No | HIGH |
|   |                                                    | EX-OUTPUTQ: non-testable tasks grouped separately (prerequisites, integration) | No | MEDIUM |
|   |                                                    | EX-OUTPUTQ: ordering: prerequisites first, BDD pairs middle, integration last, verification end | No | MEDIUM |
|   |                                                    | EX-FAIL: sub-agent fails — retries with Sonnet, then Opus escalation | No | MEDIUM |
| 5 | Add report (sub-agent, Haiku) | STATIC_GUARDR: references `guidelines-reports.md`, Haiku model | Yes | LOW |
|   |                                | EX-SIDEFX: report file contains proposal section with exploration summary, Q&A, artifacts list | No | MEDIUM |
|   |                                | EX-FAIL: sub-agent fails — retries, then inline | No | LOW |
| 6 | Display summary | EX-OUTPUTQ: output includes change name, artifact list, task structure summary | No | LOW |
| 7 | Suggest commit message | STATIC_GUARDR: `Suggest a commit message` | Yes | LOW |
|   |                         | EX-OUTPUTQ: commit message follows git guidelines format | No | LOW |
| — | Sub-agent orchestration (cross-cutting) | STATIC_GUARDR: sub-agent orchestration declaration, failure handling | Yes | MEDIUM |

**Summary:** 15 static guardrails (all exist), 18 potential execution evals (1 exists).

---

## 3. `sdlc_implement_change`

| # | Task / Operation | Eval Types | Implemented? | Priority |
|---|-----------------|------------|-----------------|----------|
| 1a | Identify the change (`openspec status`) | STATIC_GUARDR: `openspec status` present | Yes | LOW |
|    |                                          | EX-HAPPYP: correctly identifies active change and parses JSON | No | HIGH |
|    |                                          | EX-EDGE: all tasks already complete — skips to step 2 | No | MEDIUM |
| 1b | Read and parse task list | STATIC_GUARDR: checkbox tracking `[x]` | Yes | MEDIUM |
|    |                           | EX-HAPPYP: correctly parses sections, counts pending vs complete | No | HIGH |
|    |                           | EX-EDGE: resume support — skips sections with all `[x]` | No | MEDIUM |
| 1c | Classify sections and assign model tier | STATIC_GUARDR: Sonnet for BDD, Haiku for mechanical | Yes | MEDIUM |
|    |                                          | EX-OUTPUTQ: execution plan displays correct model assignment per section | No | MEDIUM |
|    |                                          | EX-OUTPUTQ: BDD sections assigned Sonnet, mechanical (wire, pass, wrap) assigned Haiku | No | MEDIUM |
| 1d | Execute sections sequentially (sub-agents) | STATIC_GUARDR: `RED confirmed`, `GREEN confirmed`, BDD Execution Discipline, `Verify RED`, `Verify GREEN` | Yes | HIGH |
|    |                                              | EX-HAPPYP: sub-agent completes all tasks in section, checkboxes updated | No | CRITICAL |
|    |                                              | EX-SIDEFX: BDD cycle: test written, RED confirmed, implementation written, GREEN confirmed | No | CRITICAL |
|    |                                              | EX-BLOCKINGGT: test unexpectedly passes at RED — stops and reports | No | CRITICAL |
|    |                                              | EX-BLOCKINGGT: test still fails at GREEN (last impl task) — iterates or stops | No | HIGH |
|    |                                              | EX-FAIL: sub-agent fails — retries; Haiku escalates to Sonnet | No | HIGH |
|    |                                              | EX-FAIL: checkboxes missed but implementation exists — Haiku checkbox fix agent | No | MEDIUM |
| 1e | Final verification | EX-SIDEFX: every task in file is `[x]` after all sections processed | No | HIGH |
|    |                     | EX-OUTPUTQ: progress report shows correct counts and model distribution | No | LOW |
| 2 | Review unresolved TODOs | STATIC_GUARDR: `TODO`, `RESOLVE NOW`, `ACKNOWLEDGED` | Yes | MEDIUM |
|   |                          | EX-HAPPYP: scans `app/src/`, classifies TODOs correctly | No | HIGH |
|   |                          | EX-EDGE: TODO whose precondition is met by this story — classified as RESOLVE NOW | No | HIGH |
|   |                          | EX-EDGE: unrelated TODO — classified as ACKNOWLEDGED | No | MEDIUM |
| 3 | Resolve RESOLVE NOW TODOs (loop) | EX-SIDEFX: OpenSpec artifacts updated with new tasks for TODO resolution | No | HIGH |
|   |                                   | EX-HAPPYP: re-runs implementation for new tasks, then re-checks TODOs | No | HIGH |
|   |                                   | EX-HAPPYP: loop terminates when no RESOLVE NOW TODOs remain | No | MEDIUM |
| 4 | Run Compose UI tests on device | STATIC_GUARDR: `connectedDebugAndroidTest`, device gate, `BLOCK` | Yes | MEDIUM |
|   |                                 | EX-BLOCKINGGT: no device connected — blocks and asks user | No | MEDIUM |
|   |                                 | EX-HAPPYP: device connected, tests pass — proceeds | No | HIGH |
|   |                                 | EX-FAIL: tests fail — presents failures, fixes, re-runs | No | HIGH |
| 5 | Run security review (sub-agent, Sonnet) | STATIC_GUARDR: `security-review`, sub-agent delegation, `Do NOT invoke` inline | Yes | MEDIUM |
|   |                                          | EX-HAPPYP: PASS — proceeds | No | MEDIUM |
|   |                                          | EX-FAIL: findings found — fixes, re-runs until clean | No | HIGH |
| 6 | Update README.md if required | STATIC_GUARDR: `README.md` present | Yes | LOW |
|   |                               | EX-SIDEFX: README updated when changes affect documented sections | No | MEDIUM |
|   |                               | EX-EDGE: README already accurate — skip | No | LOW |
| 7 | Update AGENTS.md if required | STATIC_GUARDR: `AGENTS.md` present | Yes | LOW |
|   |                               | EX-SIDEFX: AGENTS.md updated when changes affect documented sections | No | MEDIUM |
|   |                               | EX-EDGE: AGENTS.md already accurate — skip | No | LOW |
| 8 | Add report | STATIC_GUARDR: references `guidelines-reports.md` | Yes | LOW |
|   |             | EX-SIDEFX: report contains implementation summary, iteration count, acknowledged TODOs, security result | No | MEDIUM |
| 9 | Display summary | EX-OUTPUTQ: output matches report content | No | LOW |
| 10 | Suggest commit message | STATIC_GUARDR: `Suggest a commit message` | Yes | LOW |
|    |                         | EX-OUTPUTQ: follows git guidelines | No | LOW |
| — | Device gate (cross-cutting) | STATIC_GUARDR: `adb devices`, device gate protocol | Yes | MEDIUM |
|   |                              | EX-BLOCKINGGT: blocks until device confirmed, re-checks after user response | No | MEDIUM |
| — | Early device reminder | EX-OUTPUTQ: non-blocking reminder at start about device needed later | No | LOW |
| — | Sub-agent orchestration (cross-cutting) | STATIC_GUARDR: sub-agent orchestration declaration, retry/failure handling | Yes | MEDIUM |

**Summary:** 24 static guardrails (all exist), 30 potential execution evals (0 exist).

---

## 4. `sdlc_verify_story`

| # | Task / Operation | Eval Types | Implemented? | Priority |
|---|-----------------|------------|-----------------|----------|
| — | Orchestrator pre-work | EX-HAPPYP: gathers modified files, story data, active change name | No | HIGH |
| 1 | Locate user story and validate closing preconditions | EX-HAPPYP: matches story by number/name | Partially (`verify_story_precondition_fail`) | HIGH |
|   |                                                       | EX-BLOCKINGGT: preconditions for closing not met — stops | Yes (`verify_story_precondition_fail`) | CRITICAL |
| 2 | OpenSpec verify (blocking gate, Sonnet) | STATIC_GUARDR: `opsx:verify`, `BLOCKING GATE`, `PASS`/proceed, `FAIL`/`STOP` | Yes | MEDIUM |
|   |                                          | EX-BLOCKINGGT: FAIL — stops, presents issues, does not proceed | Yes (`verify_story_blocks_on_gate_failure`) | CRITICAL |
|   |                                          | EX-HAPPYP: PASS — proceeds to next gate | No | MEDIUM |
|   |                                          | EX-FAIL: sub-agent itself fails — retries with Sonnet | No | MEDIUM |
| 3 | TODO scan (blocking gate, Sonnet) | STATIC_GUARDR: `TODO scan` present | Yes | MEDIUM |
|   |                                    | EX-BLOCKINGGT: RESOLVE NOW TODOs found — stops | No | HIGH |
|   |                                    | EX-HAPPYP: all TODOs ACKNOWLEDGED or none — PASS | No | MEDIUM |
|   |                                    | EX-FAIL: sub-agent fails — retries | No | MEDIUM |
| 4 | Security review (blocking gate, Sonnet) | STATIC_GUARDR: `security-review` present | Yes | MEDIUM |
|   |                                          | EX-BLOCKINGGT: critical/high findings — stops | No | CRITICAL |
|   |                                          | EX-HAPPYP: no critical findings — PASS | No | MEDIUM |
|   |                                          | EX-FAIL: sub-agent fails — retries | No | MEDIUM |
| 5 | Clean build + static analysis (blocking gate, Haiku) | STATIC_GUARDR: `gradlew clean check` present | Yes | MEDIUM |
|   |                                                       | EX-BLOCKINGGT: build fails — stops with errors | No | CRITICAL |
|   |                                                       | EX-HAPPYP: build succeeds — PASS | No | MEDIUM |
|   |                                                       | EX-FAIL: sub-agent fails — retries, Haiku escalates to Sonnet | No | MEDIUM |
| 6 | Unit tests (blocking gate, Haiku) | STATIC_GUARDR: `gradlew test` present | Yes | MEDIUM |
|   |                                    | EX-BLOCKINGGT: tests fail — stops with failure list | No | CRITICAL |
|   |                                    | EX-HAPPYP: all tests pass — PASS | No | MEDIUM |
|   |                                    | EX-FAIL: sub-agent fails — retries, escalates | No | MEDIUM |
| 7 | Coverage report (non-blocking, Sonnet) | STATIC_GUARDR: `koverXmlReport` present | Yes | LOW |
|   |                                         | EX-OUTPUTQ: coverage table produced with all 5 categories | No | MEDIUM |
|   |                                         | EX-FAIL: Gradle command errors — FAIL but does not block | No | LOW |
| 8 | Test file coverage (blocking gate, Sonnet) | STATIC_GUARDR: `Test file coverage` present | Yes | MEDIUM |
|   |                                              | EX-BLOCKINGGT: source class without test file — FAIL, stops | No | HIGH |
|   |                                              | EX-HAPPYP: all classes have test files — PASS | No | MEDIUM |
| 9 | Compose preview coverage (blocking gate, Sonnet) | STATIC_GUARDR: `preview coverage` present | Yes | MEDIUM |
|   |                                                    | EX-BLOCKINGGT: composable without preview or uncovered UiState field — FAIL, stops | No | HIGH |
|   |                                                    | EX-HAPPYP: all composables have previews, all fields covered — PASS | No | MEDIUM |
| 10 | On-device tests (blocking gate, Haiku) | STATIC_GUARDR: `connectedDebugAndroidTest`, `adb devices`, `NOT_FEASIBLE` | Yes | MEDIUM |
|    |                                         | EX-BLOCKINGGT: instrumented tests fail — stops | No | HIGH |
|    |                                         | EX-BLOCKINGGT: NOT_FEASIBLE — asks user for manual verification, blocks | No | MEDIUM |
|    |                                         | EX-HAPPYP: tests pass, app exercise confirms feature — PASS | No | MEDIUM |
|    |                                         | EX-FAIL: sub-agent fails — retries, Haiku escalates to Sonnet | No | MEDIUM |
| 11 | Definition of Done (blocking gate, Sonnet) | STATIC_GUARDR: `Definition of Done` present | Yes | HIGH |
|    |                                              | EX-BLOCKINGGT: criterion not met — FAIL, stops | No | CRITICAL |
|    |                                              | EX-HAPPYP: all criteria met — PASS | No | MEDIUM |
| 12 | Close user story (sub-agent, Haiku) | STATIC_GUARDR: `git mv` present | Yes | MEDIUM |
|    |                                      | EX-SIDEFX: story file renamed to DONE status | No | HIGH |
|    |                                      | EX-SIDEFX: index.md updated with new filename | No | HIGH |
|    |                                      | EX-FAIL: sub-agent fails — retries, escalates | No | MEDIUM |
| 13 | Sync delta specs (sub-agent, Sonnet) | STATIC_GUARDR: `opsx:sync` present | Yes | MEDIUM |
|    |                                       | EX-SIDEFX: delta specs merged into main specs | No | HIGH |
|    |                                       | EX-HAPPYP: no delta specs — reports "nothing to sync" | No | LOW |
|    |                                       | EX-FAIL: sub-agent fails — retries | No | MEDIUM |
| 14 | Archive change (sub-agent, Haiku) | STATIC_GUARDR: `opsx:archive` present | Yes | LOW |
|    |                                    | EX-SIDEFX: change directory moved to archive | No | MEDIUM |
|    |                                    | EX-FAIL: sub-agent fails — retries, escalates | No | LOW |
| 15 | Verify README/AGENTS sync (sub-agent, Sonnet) | EX-SIDEFX: docs updated if story changes affect them | No | MEDIUM |
|    |                                                | EX-EDGE: no changes needed — reports "in sync" | No | LOW |
| 16 | Add report (sub-agent, Haiku) | STATIC_GUARDR: references `guidelines-reports.md` | Yes | LOW |
|    |                                | EX-SIDEFX: report contains all gate results, coverage table as HTML `<table>` | No | MEDIUM |
|    |                                | EX-OUTPUTQ: report includes all 13 data points listed in prompt | No | MEDIUM |
| 17 | Display summary | EX-OUTPUTQ: includes coverage table rendered as markdown | No | LOW |
| 18 | Suggest commit message | STATIC_GUARDR: `Suggest a commit message` | Yes | LOW |
|    |                         | EX-OUTPUTQ: follows git guidelines format | No | LOW |
| — | Device gate (cross-cutting) | STATIC_GUARDR: `adb devices`, device gate protocol | Yes | MEDIUM |
|   |                              | EX-BLOCKINGGT: blocks until device confirmed | No | MEDIUM |
| — | Early device reminder | EX-OUTPUTQ: non-blocking reminder at start | No | LOW |
| — | Blocking gate protocol (cross-cutting) | STATIC_GUARDR: `BLOCKING GATE`, `PASS`, `FAIL`, `STOP` | Yes | HIGH |
|   |                                          | EX-BLOCKINGGT: gate N fails — gates N+1..end never reached | Yes (`verify_story_blocks_on_gate_failure`) | CRITICAL |
| — | Sub-agent orchestration (cross-cutting) | STATIC_GUARDR: sub-agent orchestration declaration, failure handling | Yes | MEDIUM |

**Summary:** 27 static guardrails (all exist), 40 potential execution evals (3 exist).

---

## 5. `sdlc_doctor`

| # | Task / Operation | Eval Types | Implemented? | Priority |
|---|-----------------|------------|-----------------|----------|
| 1 | Spawn parallel Haiku sub-agents | STATIC_GUARDR: Haiku model, parallel execution | Yes | MEDIUM |
|   |                                  | EX-HAPPYP: all agents spawn, run, and return results | Yes (`doctor_all_pass`) | HIGH |
|   |                                  | EX-FAIL: sub-agent fails — no explicit retry defined | No | LOW |
| 2 | OpenSpec category checks | STATIC_GUARDR: `OpenSpec`, `openspec/config.yaml` | Yes | MEDIUM |
|   |                           | EX-HAPPYP: config present, CLI installed, all opsx commands present — passes | Yes (`doctor_all_pass`) | HIGH |
|   |                           | EX-EDGE: config.yaml missing — fails that check, others pass | Yes (`doctor_missing_openspec_config`) | MEDIUM |
|   |                           | EX-EDGE: 2 opsx command files missing — fails those 2, others pass | Yes (`doctor_missing_opsx_commands`) | MEDIUM |
| 3 | Security Review category check | STATIC_GUARDR: `Security Review`, `security-guidance` | Yes | MEDIUM |
|   |                                 | EX-HAPPYP: plugin enabled — passes | Yes (`doctor_all_pass`) | MEDIUM |
|   |                                 | EX-EDGE: plugin disabled or set to false — fails | Yes (`doctor_security_disabled`) | MEDIUM |
| 4 | SDLC Commands category checks | STATIC_GUARDR: `SDLC Commands` | Yes | LOW |
|   |                                | EX-HAPPYP: all 8 command files present — passes | Yes (`doctor_all_pass`) | LOW |
|   |                                | EX-EDGE: command files missing — fails for missing | Partially (`doctor_everything_broken`) | LOW |
| 5 | Guidelines category checks | EX-HAPPYP: all guidelines present and wired in AGENTS.md | Yes (`doctor_all_pass`) | MEDIUM |
|   |                             | EX-EDGE: guidelines missing or not referenced | Partially (`doctor_everything_broken`) | LOW |
| 6 | All checks fail scenario | EX-EDGE: every checked file/config absent — all fail, correct failure count | Yes (`doctor_everything_broken`) | MEDIUM |
| 7 | Read-only enforcement | STATIC_GUARDR: `must not modify any files`, `Do NOT modify any files` | Yes | HIGH |
|   |                        | EX-SIDEFX: no files created or modified in fixture after run | Partially (asserted in all scenarios) | MEDIUM |
| 8 | Output format and summary | STATIC_GUARDR: summary with pass/fail count | Yes | LOW |
|   |                            | EX-OUTPUTQ: ✅/❌ lines per check, correct summary count | Partially (`doctor_all_pass`) | MEDIUM |

**Summary:** 10 static guardrails (all exist), 12 potential execution evals (5 exist, 3 partially).

---

## 6. `sdlc_project_doctor`

| # | Task / Operation | Eval Types | Implemented? | Priority |
|---|-----------------|------------|-----------------|----------|
| 1 | Spawn parallel Haiku sub-agents | STATIC_GUARDR: Haiku model, parallel execution | Yes | MEDIUM |
|   |                                  | EX-HAPPYP: all agents spawn and return results | Yes (`project_doctor_all_pass`) | HIGH |
|   |                                  | EX-FAIL: sub-agent fails — no explicit retry defined | No | LOW |
| 2 | Detekt category checks | STATIC_GUARDR: `Detekt` category | Yes | MEDIUM |
|   |                          | EX-HAPPYP: plugin, config, version 2.x, zero tolerance, validation, compose rules — all pass | Yes (`project_doctor_all_pass`) | HIGH |
|   |                          | EX-EDGE: config file missing — fails detekt checks | Yes (`project_doctor_missing_detekt`) | MEDIUM |
|   |                          | EX-EDGE: detekt 1.x detected — fails with upgrade message | No | HIGH |
|   |                          | EX-EDGE: compose rules version mismatch — fails | No | MEDIUM |
| 3 | Kover category checks | STATIC_GUARDR: `Kover`, `minBound` | Yes | MEDIUM |
|   |                         | EX-HAPPYP: plugin present, minBound(95) — passes | Yes (`project_doctor_all_pass`) | MEDIUM |
|   |                         | EX-EDGE: minBound set to 50 — fails | Yes (`project_doctor_low_coverage`) | MEDIUM |
| 4 | Unit Tests category checks | STATIC_GUARDR: `Unit Tests` | Yes | LOW |
|   |                              | EX-HAPPYP: JUnit, MockK, coroutines-test, test directory — all present | Yes (`project_doctor_all_pass`) | LOW |
|   |                              | EX-EDGE: test dependencies missing | No | LOW |
| 5 | Analytics category checks | EX-HAPPYP: tracking plan exists, has required sections, wired in AGENTS.md and open_story | Yes (`project_doctor_all_pass`) | MEDIUM |
|   |                            | EX-EDGE: tracking plan missing or incomplete | No | MEDIUM |
|   |                            | EX-EDGE: analytics hook missing from sdlc_open_story.md | No | HIGH |
| 6 | Fastlane category checks | STATIC_GUARDR: `Fastlane` | Yes | LOW |
|   |                            | EX-HAPPYP: Fastfile, Gemfile, CLIs present — passes | Yes (`project_doctor_all_pass`) | LOW |
|   |                            | EX-EDGE: Fastfile or Gemfile missing | No | LOW |
| 7 | CI/CD category checks | STATIC_GUARDR: `CI/CD` | Yes | LOW |
|   |                         | EX-HAPPYP: workflow file with check and koverVerify steps — passes | Yes (`project_doctor_all_pass`) | LOW |
|   |                         | EX-EDGE: CI workflow missing or incomplete | No | LOW |
| 8 | Gradle category checks | STATIC_GUARDR: `Gradle` | Yes | LOW |
|   |                          | EX-HAPPYP: Gradle wrapper resolves — passes | Yes (`project_doctor_all_pass`) | LOW |
|   |                          | EX-EDGE: Gradle wrapper broken or missing | No | LOW |
| 9 | Read-only enforcement | STATIC_GUARDR: `must not modify any files`, `Do NOT modify any files` | Yes | HIGH |
|   |                        | EX-SIDEFX: no files modified after run | Partially (asserted in all scenarios) | MEDIUM |
| 10 | Output format and summary | STATIC_GUARDR: summary with pass/fail count | Yes | LOW |
|    |                            | EX-OUTPUTQ: correct summary count | Partially (`project_doctor_all_pass`) | MEDIUM |
| — | Everything broken scenario | EX-EDGE: all checked files/config absent | No | LOW |

**Summary:** 12 static guardrails (all exist), 18 potential execution evals (3 exist, 2 partially).

---

## 7. `sdlc_exp_four_in_one`

| # | Task / Operation | Eval Types | Implemented? | Priority |
|---|-----------------|------------|-----------------|----------|
| — | Git safety checks (delegated to Phase 1) | EX-EDGE: dirty state — warns user, names dirty files | Yes (`exp_four_in_one_dirty_state`) | MEDIUM |
|   |                                            | EX-EDGE: not on main — asks proceed/switch | No | LOW |
| 1 | Phase 1: Open & Refine (sub-agent, Opus) | STATIC_GUARDR: Opus model, refs `sdlc_open_story.md` | Yes | MEDIUM |
|   |                                            | EX-HAPPYP: sub-agent runs open_story to completion | No | HIGH |
|   |                                            | EX-SIDEFX: story file renamed to -WIP | No | HIGH |
|   |                                            | EX-FAIL: sub-agent fails or reports blocker — stops | No | MEDIUM |
| — | Post-Phase 1 verification and commit | STATIC_GUARDR: `-WIP` verification, `git add -A`, `git commit`, `Co-Authored-By`, `{REF}` | Yes | MEDIUM |
|   |                                       | EX-SIDEFX: commit created with correct message format | No | LOW |
| 2 | Phase 2: Propose Change (sub-agent, Opus) | STATIC_GUARDR: refs `sdlc_propose_change.md` | Yes | MEDIUM |
|   |                                              | EX-HAPPYP: sub-agent runs propose_change to completion | No | HIGH |
|   |                                              | EX-SIDEFX: change directory created under `openspec/changes/` | No | HIGH |
|   |                                              | EX-FAIL: sub-agent fails or reports blocker — stops | No | MEDIUM |
| — | Post-Phase 2 verification and commit | STATIC_GUARDR: `openspec/changes/` verification | Yes | LOW |
|   |                                       | EX-SIDEFX: commit created | No | LOW |
| 3 | Phase 3: Implement Change (sub-agent, Sonnet) | STATIC_GUARDR: Sonnet model, refs `sdlc_implement_change.md` | Yes | MEDIUM |
|   |                                                  | EX-HAPPYP: sub-agent runs implement_change to completion | No | CRITICAL |
|   |                                                  | EX-SIDEFX: all tasks `[x]` | No | HIGH |
|   |                                                  | EX-FAIL: sub-agent fails or reports blocker — stops | No | MEDIUM |
| — | Post-Phase 3 verification and commit | STATIC_GUARDR: all tasks `[x]` verification | Yes | MEDIUM |
|   |                                       | EX-SIDEFX: commit created | No | LOW |
| 4 | Phase 4: Verify & Archive (sub-agent, Sonnet) | STATIC_GUARDR: refs `sdlc_verify_story.md` | Yes | MEDIUM |
|   |                                                  | EX-HAPPYP: sub-agent runs verify_story to completion | No | CRITICAL |
|   |                                                  | EX-SIDEFX: story file renamed to -DONE | No | HIGH |
|   |                                                  | EX-FAIL: sub-agent fails or reports blocker — stops | No | MEDIUM |
| — | Post-Phase 4 verification and commit | STATIC_GUARDR: `-DONE` verification | Yes | MEDIUM |
|   |                                       | EX-SIDEFX: commit created | No | LOW |
| 5 | Blocker handling (cross-cutting) | STATIC_GUARDR: `blocker`, `STOP` | Yes | HIGH |
|   |                                   | EX-BLOCKINGGT: blocker in any phase — relay to user and stop | No | HIGH |
| 6 | Final summary | STATIC_GUARDR: `Vibe Complete`, `Total commits: 4`, PR/merge | Yes | LOW |
|   |                | EX-OUTPUTQ: summary table shows all 4 phases DONE | No | LOW |

**Summary:** 19 static guardrails (all exist), 18 potential execution evals (1 exists).

---

## 8. `sdlc_exp_vibe_a_story`

| # | Task / Operation | Eval Types | Implemented? | Priority |
|---|-----------------|------------|-----------------|----------|
| 1.1 | Git safety checks | STATIC_GUARDR: `git status`, `git branch --show-current`, `DO NOT MAKE ASSUMPTIONS`, `DO NOT DELETE DATA` | Yes | MEDIUM |
|     |                    | EX-EDGE: dirty state — warns user, names dirty files | Yes (`exp_vibe_a_story_dirty_state`) | MEDIUM |
|     |                    | EX-EDGE: not on main — asks proceed/switch | No | LOW |
| 1.2 | Resolve user story | STATIC_GUARDR: references `guidelines-userstories.md` | Yes | LOW |
|     |                     | EX-HAPPYP: auto-selects or matches story | No | HIGH |
|     |                     | EX-EDGE: no actionable story — stops | No | MEDIUM |
| 1.3 | Create feature branch | EX-SIDEFX: branch created under `feature/` | No | LOW |
| 1.4 | Open story (sub-agent, Haiku) | STATIC_GUARDR: Haiku model, `git mv`, failure handling | Yes | MEDIUM |
|     |                                | EX-SIDEFX: story file renamed to -WIP, index updated | No | HIGH |
|     |                                | EX-FAIL: Haiku fails — escalates to Sonnet | No | MEDIUM |
| 1.5 | Analyze, explore, plan (sub-agent, Opus) | STATIC_GUARDR: Opus model, failure handling | Yes | MEDIUM |
|     |                                            | EX-OUTPUTQ: refinement at top, original under `## Original user story` | No | CRITICAL |
|     |                                            | EX-SIDEFX: task file created at `vibe/{STORY_ID}-tasks.md` with structured sections | No | CRITICAL |
|     |                                            | EX-OUTPUTQ: sections ordered: prerequisites → core → UI → integration | No | MEDIUM |
|     |                                            | EX-FAIL: Opus fails — retries once | No | MEDIUM |
| 1.6 | Clarify doubts (interactive) | EX-EDGE: questions surfaced — asks user, does not assume | No | HIGH |
|     |                               | EX-EDGE: no questions — proceeds | No | LOW |
| 1.7 | Phase 1 commit | STATIC_GUARDR: `git add -A`, `git commit`, `Co-Authored-By`, `{REF}` | Yes | LOW |
|     |                  | EX-SIDEFX: commit created with correct format | No | LOW |
| 2.1 | Parse and classify task list | STATIC_GUARDR: checkbox tracking `[x]` | Yes | MEDIUM |
|     |                               | EX-HAPPYP: sections parsed, model assigned correctly (Sonnet for BDD, Haiku for mechanical) | No | HIGH |
|     |                               | EX-EDGE: resume — fully completed sections skipped | No | MEDIUM |
| 2.2 | Execute sections (sub-agents, Sonnet/Haiku) | STATIC_GUARDR: Sonnet model for implementation sections | Yes | MEDIUM |
|     |                                               | EX-HAPPYP: all tasks in section completed, checkboxes updated | No | CRITICAL |
|     |                                               | EX-FAIL: sub-agent fails — retries; Haiku escalates to Sonnet | No | HIGH |
|     |                                               | EX-FAIL: checkboxes missed — Haiku fix agent | No | MEDIUM |
| 2.3 | Verify all tasks complete | EX-SIDEFX: every task in file is `[x]` | No | HIGH |
| 2.4 | Build, static analysis, unit tests | EX-HAPPYP: `./gradlew clean check test` passes | No | HIGH |
|     |                                      | EX-FAIL: failures — fixes iteratively, re-runs | No | MEDIUM |
| 2.5 | Security review | STATIC_GUARDR: `security-review` | Yes | MEDIUM |
|     |                  | EX-HAPPYP: clean — proceeds | No | MEDIUM |
|     |                  | EX-FAIL: findings — fixes, re-runs until clean | No | HIGH |
| 2.6 | On-device tests | STATIC_GUARDR: `adb devices`, device gate, `BLOCK`, `connectedDebugAndroidTest` | Yes | MEDIUM |
|     |                  | EX-BLOCKINGGT: no device — blocks and asks user | No | MEDIUM |
|     |                  | EX-HAPPYP: tests pass, feature exercised via adb | No | MEDIUM |
|     |                  | EX-FAIL: NOT_FEASIBLE — asks user, blocks | No | MEDIUM |
| 2.7 | Close story (sub-agent, Haiku) | STATIC_GUARDR: `-WIP` → `-DONE` lifecycle | Yes | MEDIUM |
|     |                                 | EX-SIDEFX: story file renamed to -DONE, index updated | No | HIGH |
|     |                                 | EX-FAIL: Haiku fails — escalates to Sonnet | No | MEDIUM |
| 2.8 | Phase 2 commit | STATIC_GUARDR: commit policy | Yes | LOW |
|     |                  | EX-SIDEFX: commit created | No | LOW |
| — | Intentional omissions | STATIC_GUARDR (negative): no `Definition of Done verification`, no `RESOLVE NOW` loop | Yes | MEDIUM |
| — | Final summary | STATIC_GUARDR: `Vibe Complete`, `Total commits: 2`, PR/merge | Yes | LOW |
|   |                | EX-OUTPUTQ: summary table shows both phases DONE | No | LOW |

**Summary:** 30 static guardrails (all exist, including 2 negative assertions), 28 potential execution evals (1 exists).

---

## Overall Coverage

| Command | Static Guardrails | Execution Evals (potential) | Execution Evals (exist) | Coverage | Uncovered CRITICAL | Uncovered HIGH |
|---------|------------------|-----------------------------|-------------------------|----------|--------------------|----------------|
| `sdlc_open_story` | 14 / 14 | 20 | 2 | 10% | 2 | 5 |
| `sdlc_propose_change` | 15 / 15 | 18 | 1 | 6% | 2 | 3 |
| `sdlc_implement_change` | 24 / 24 | 30 | 0 | 0% | 3 | 12 |
| `sdlc_verify_story` | 27 / 27 | 40 | 3 | 8% | 4 | 8 |
| `sdlc_doctor` | 10 / 10 | 12 | 5 | 42% | 0 | 1 |
| `sdlc_project_doctor` | 12 / 12 | 18 | 3 | 17% | 0 | 3 |
| `sdlc_exp_four_in_one` | 19 / 19 | 18 | 1 | 6% | 2 | 5 |
| `sdlc_exp_vibe_a_story` | 30 / 30 | 28 | 1 | 4% | 3 | 9 |
| **Total** | **151 / 151** | **184** | **16** | **9%** | **16** | **46** |

### Cross-command consistency checks

In addition to per-command guardrails, `check_guardrails.sh` includes 5 cross-command assertion
loops (23 total assertions) verifying: commit message suggestion on all 4 main commands, sub-agent
failure handling on all 4 main commands, report generation on all 4 main commands, sub-agent
orchestration across all 8 commands, and device connectivity on the 3 device-aware commands. These
overlap with per-command assertions and are not counted separately above.

### Observations

1. **Static guardrails are at 100%.** All 151 per-command guardrails pass, plus 23 cross-command
   consistency checks. This remains the cheapest and most reliable layer.

2. **Execution evals are at 9% overall** (16 out of 184 potential), up from 6% in the previous
   analysis. The improvement comes from the doctor command evals (Phase 2), which have the best
   coverage of any command group at 42% for `sdlc_doctor`.

3. **Doctor commands have the strongest execution coverage.** `sdlc_doctor` at 42% is the
   best-covered command — its 5 scenarios test happy path, individual check failures, and total
   failure. `sdlc_project_doctor` at 17% covers happy path plus two specific failure modes. Both
   are lightweight (Haiku-only sub-agents) and highly deterministic, making them ideal eval targets.

4. **`sdlc_implement_change` still has zero execution evals.** This is the most complex command
   (sub-agent orchestration per section, BDD red/green cycles, TODO resolution loops, device gates).
   The README notes this as deferred because it requires a full openspec change with task artifacts.

5. **Experimental commands have minimal coverage** (1 scenario each, both testing git dirty-state
   detection). `sdlc_exp_vibe_a_story` is particularly exposed — 28 potential execution evals with
   only 1 implemented, and it has its own implementation logic rather than delegating to existing
   commands like `sdlc_exp_four_in_one` does.

6. **Highest-value gaps** (highest risk with no execution eval):
    - Happy-path completion for any of the 4 main commands (none exists)
    - BDD red/green discipline enforcement (`sdlc_implement_change`)
    - Blocking-gate cascade (`sdlc_verify_story` — only first gate failure is tested)
    - Sub-agent retry/escalation paths (none tested for any command)
    - Side-effect correctness: `git mv` renames, index updates, report file creation
    - `sdlc_exp_vibe_a_story` task-list generation and section execution
    - `sdlc_exp_four_in_one` phase chaining and inter-phase commit policy
    - `sdlc_project_doctor` detekt version detection (version 1.x → 2.x upgrade message)

7. **Coverage distribution is bottom-heavy.** The cheapest commands (doctors) have the best coverage;
   the most complex and risky commands (implement_change, verify_story, exp_vibe_a_story) have the
   least. This is rational given rate-limit constraints but leaves the highest-consequence behaviours
   untested.
