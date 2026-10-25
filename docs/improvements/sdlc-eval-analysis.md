# SDLC Evals Analysis

Systematic analysis of eval coverage for all eight SDLC commands. Each table maps every
task/operation to the types of eval that can test it and whether that eval currently exists.

## Eval Layer Legend

| Layer | Name | Description | Cost |
|-------|------|-------------|------|
| **L1** | Guardrail | `grep`-based check that required patterns exist in the command MD file | Free |
| **L2** | Structural | Deterministic assertions on command output — file existence, section presence, side effects, content preservation | Free |
| **L3** | Judge | LLM-as-judge scoring against golden reference on quality rubrics | Moderate (1 LLM call per command) |
| **L4** | Functional | Build and test verification — `gradlew check`, coverage thresholds | High (requires Android SDK) |
| **L5** | Behavioural | Scenario testing abnormal conditions — edge cases, gate failures, failure handling | Moderate |

Layers are independent — no dependency between them, any combination can run.

---

## 1. `sdlc_open_story`

| # | Task / Operation | Eval Types | Implemented? | Priority |
|---|-----------------|------------|-----------------|----------|
| 1 | Check for uncommitted changes | L1: `git status`, `DO NOT DELETE DATA` guardrail present | Yes | MEDIUM |
|   |                               | L5: dirty state warns user, names dirty files | Yes (`open_story_dirty_state`) | MEDIUM |
|   |                               | L5: clean state proceeds without warning | No | LOW |
| 2 | Handle current branch (on main) | L1: `git branch --show-current` present | Yes | LOW |
|   |                                  | L2: on main, fetch/pull succeeds, proceeds | No | LOW |
|   |                                  | L5: on main, pull fails (conflict) — asks user | No | MEDIUM |
| 3 | Handle current branch (not on main) | L5: detects non-main branch, asks proceed/switch | Yes (`open_story_not_on_main`) | MEDIUM |
|   |                                      | L5: user chooses proceed — skips branch creation (step 5) | No | LOW |
|   |                                      | L5: user chooses switch — switches to main, pulls | No | LOW |
| 4 | Resolve user story argument | L1: references `guidelines-userstories.md` | Yes | LOW |
|   |                              | L2: auto-selects next story when no argument given | No | HIGH |
|   |                              | L5: no actionable story exists — informs user and stops | No | MEDIUM |
|   |                              | L5: specific story argument matches correctly | No | MEDIUM |
| 5 | Locate user story and validate preconditions | L5: partial name match resolves correctly | No | MEDIUM |
|   |                                               | L5: no match — asks user | No | MEDIUM |
|   |                                               | L5: preconditions not met — stops | No | HIGH |
| 6 | Create feature branch | L2: branch created under `feature/` with ticket number prefix | No | LOW |
|   |                        | L5: skip when user chose to stay on current branch | No | LOW |
| 7 | Open the user story (sub-agent, Haiku) | L1: Haiku model, `git mv`, failure handling, verification | Yes | MEDIUM |
|   |                                         | L2: story file renamed correctly (status change) | Yes (`open_story_golden_quality`) | HIGH |
|   |                                         | L2: index.md updated with new filename | Yes (`open_story_golden_quality`) | HIGH |
|   |                                         | L5: sub-agent fails — retries with Sonnet, then inline | No | MEDIUM |
| 8 | Refine the user story (sub-agent, Opus) | L1: Opus model, failure handling, verification | Yes | MEDIUM |
|   |                                          | L3: refined content at top, original at bottom under `## Original user story` | Yes (`open_story_golden_quality` L3 judge: content_preservation) | CRITICAL |
|   |                                          | L3: refinement includes all 12 required sections (analytics, security, GDPR, etc.) | Yes (`open_story_golden_quality` L2 structural + L3 judge: section_completeness) | CRITICAL |
|   |                                          | L3: stays at "what" level, does not prescribe architecture | Yes (`open_story_golden_quality` L3 judge: what_not_how) | HIGH |
|   |                                          | L5: sub-agent fails — retries with Opus, then inline | No | MEDIUM |
| 9 | Add a report (sub-agent, Haiku) | L1: references `guidelines-reports.md` | Yes | LOW |
|   |                                  | L2: report file exists and contains opening section | Yes (`open_story_golden_quality`) | MEDIUM |
|   |                                  | L5: sub-agent fails — retries, then inline | No | LOW |
| 10 | Display summary | L2: output includes story name, branch, refinement highlights | No | LOW |
| 11 | Suggest commit message | L1: `Suggest a commit message`, references `guidelines-git.md` | Yes | LOW |
|    |                         | L2: commit message follows git guidelines format (prefixed with issue reference) | No | LOW |
| — | Sub-agent orchestration (cross-cutting) | L1: `DO NOT MAKE ASSUMPTIONS`, sub-agent orchestration declaration | Yes | MEDIUM |

**Summary:** 14 L1 guardrails (all exist), 20 potential L2–L5 evals (8 exist).

---

## 2. `sdlc_propose_change`

| # | Task / Operation | Eval Types | Implemented? | Priority |
|---|-----------------|------------|-----------------|----------|
| 1 | Locate user story | L2: matches by number or partial name | Partially (`propose_change_surfaces_questions` covers identification) | HIGH |
|   |                    | L5: no match — asks user | No | MEDIUM |
|   |                    | L5: story not in WIP status — stops | No | HIGH |
| 2 | Explore codebase (sub-agent, Sonnet) | L1: Sonnet model, `opsx:explore`, read-only guardrail | Yes | MEDIUM |
|   |                                       | L3: structured output with required sections (Architecture, Integration Points, Questions, Risks, Recommendations) | No | HIGH |
|   |                                       | L2: no files created or modified (read-only) | No | MEDIUM |
|   |                                       | L5: sub-agent fails or returns incomplete — retries with Sonnet, then inline | No | MEDIUM |
| 3 | Clarify all doubts | L1: `DO NOT MAKE ASSUMPTIONS` guardrail | Yes | HIGH |
|   |                     | L5: surfaces questions for ambiguous requirements, does not assume | Yes (`propose_change_surfaces_questions`) | CRITICAL |
|   |                     | L5: with unambiguous story — proceeds without excessive questions | No | LOW |
|   |                     | L3: all questions include WHY explanation | No | MEDIUM |
| 4 | Propose change with BDD tasks (sub-agent, Sonnet) | L1: BDD, GIVEN/WHEN/THEN, test-first, `test task (write the test first)`, `implementation task`, `opsx:propose` | Yes | HIGH |
|   |                                                    | L2: change directory created under `openspec/changes/` with all artifacts (proposal, design, specs, tasks) | Yes (`propose_change_golden_quality`) | CRITICAL |
|   |                                                    | L3: tasks follow BDD structure — test task + implementation task pairs | Yes (`propose_change_golden_quality` L2 structural + L3 judge: bdd_task_structure) | CRITICAL |
|   |                                                    | L3: each test task includes GIVEN/WHEN/THEN and target test class | Yes (`propose_change_golden_quality` L2 GIVEN/WHEN/THEN check + L3 judge) | HIGH |
|   |                                                    | L3: non-testable tasks grouped separately (prerequisites, integration) | Yes (`propose_change_golden_quality` L3 judge: task_granularity) | MEDIUM |
|   |                                                    | L3: ordering: prerequisites first, BDD pairs middle, integration last, verification end | Yes (`propose_change_golden_quality` L3 judge: bdd_task_structure) | MEDIUM |
|   |                                                    | L5: sub-agent fails — retries with Sonnet, then Opus escalation | No | MEDIUM |
| 5 | Add report (sub-agent, Haiku) | L1: references `guidelines-reports.md`, Haiku model | Yes | LOW |
|   |                                | L2: report file contains proposal section with exploration summary, Q&A, artifacts list | Yes (`propose_change_golden_quality`) | MEDIUM |
|   |                                | L5: sub-agent fails — retries, then inline | No | LOW |
| 6 | Display summary | L2: output includes change name, artifact list, task structure summary | No | LOW |
| 7 | Suggest commit message | L1: `Suggest a commit message` | Yes | LOW |
|   |                         | L2: commit message follows git guidelines format | No | LOW |
| — | Sub-agent orchestration (cross-cutting) | L1: sub-agent orchestration declaration, failure handling | Yes | MEDIUM |

**Summary:** 15 L1 guardrails (all exist), 18 potential L2–L5 evals (7 exist).

---

## 3. `sdlc_implement_change`

| # | Task / Operation | Eval Types | Implemented? | Priority |
|---|-----------------|------------|-----------------|----------|
| 1a | Identify the change (`openspec status`) | L1: `openspec status` present | Yes | LOW |
|    |                                          | L2: correctly identifies active change and parses JSON | No | HIGH |
|    |                                          | L5: all tasks already complete — skips to step 2 | No | MEDIUM |
| 1b | Read and parse task list | L1: checkbox tracking `[x]` | Yes | MEDIUM |
|    |                           | L2: correctly parses sections, counts pending vs complete | No | HIGH |
|    |                           | L5: resume support — skips sections with all `[x]` | No | MEDIUM |
| 1c | Classify sections and assign model tier | L1: Sonnet for BDD, Haiku for mechanical | Yes | MEDIUM |
|    |                                          | L2: execution plan displays correct model assignment per section | No | MEDIUM |
|    |                                          | L2: BDD sections assigned Sonnet, mechanical (wire, pass, wrap) assigned Haiku | No | MEDIUM |
| 1d | Execute sections sequentially (sub-agents) | L1: `RED confirmed`, `GREEN confirmed`, BDD Execution Discipline, `Verify RED`, `Verify GREEN` | Yes | HIGH |
|    |                                              | L2: sub-agent completes all tasks in section, checkboxes updated | Yes (`implement_change_golden_quality` L2 checkbox check + L3 judge: task_completion) | CRITICAL |
|    |                                              | L2: BDD cycle: test written, RED confirmed, implementation written, GREEN confirmed | Partially (`implement_change_golden_quality` L3 judge: bdd_discipline assesses quality, not actual RED/GREEN execution) | CRITICAL |
|    |                                              | L5: test unexpectedly passes at RED — stops and reports | No | CRITICAL |
|    |                                              | L5: test still fails at GREEN (last impl task) — iterates or stops | No | HIGH |
|    |                                              | L5: sub-agent fails — retries; Haiku escalates to Sonnet | No | HIGH |
|    |                                              | L5: checkboxes missed but implementation exists — Haiku checkbox fix agent | No | MEDIUM |
| 1e | Final verification | L2: every task in file is `[x]` after all sections processed | Yes (`implement_change_golden_quality` tolerates ≤2 unchecked) | HIGH |
|    |                     | L2: progress report shows correct counts and model distribution | No | LOW |
| 2 | Review unresolved TODOs | L1: `TODO`, `RESOLVE NOW`, `ACKNOWLEDGED` | Yes | MEDIUM |
|   |                          | L2: scans `app/src/`, classifies TODOs correctly | No | HIGH |
|   |                          | L5: TODO whose precondition is met by this story — classified as RESOLVE NOW | No | HIGH |
|   |                          | L5: unrelated TODO — classified as ACKNOWLEDGED | No | MEDIUM |
| 3 | Resolve RESOLVE NOW TODOs (loop) | L2: OpenSpec artifacts updated with new tasks for TODO resolution | No | HIGH |
|   |                                   | L2: re-runs implementation for new tasks, then re-checks TODOs | No | HIGH |
|   |                                   | L2: loop terminates when no RESOLVE NOW TODOs remain | No | MEDIUM |
| 4 | Run Compose UI tests on device | L1: `connectedDebugAndroidTest`, device gate, `BLOCK` | Yes | MEDIUM |
|   |                                 | L5: no device connected — blocks and asks user | No | MEDIUM |
|   |                                 | L4: device connected, tests pass — proceeds | No | HIGH |
|   |                                 | L5: tests fail — presents failures, fixes, re-runs | No | HIGH |
| 5 | Run security review (sub-agent, Sonnet) | L1: `security-review`, sub-agent delegation, `Do NOT invoke` inline | Yes | MEDIUM |
|   |                                          | L2: PASS — proceeds | No | MEDIUM |
|   |                                          | L5: findings found — fixes, re-runs until clean | No | HIGH |
| 6 | Update README.md if required | L1: `README.md` present | Yes | LOW |
|   |                               | L2: README updated when changes affect documented sections | No | MEDIUM |
|   |                               | L5: README already accurate — skip | No | LOW |
| 7 | Update AGENTS.md if required | L1: `AGENTS.md` present | Yes | LOW |
|   |                               | L2: AGENTS.md updated when changes affect documented sections | No | MEDIUM |
|   |                               | L5: AGENTS.md already accurate — skip | No | LOW |
| 8 | Add report | L1: references `guidelines-reports.md` | Yes | LOW |
|   |             | L2: report contains implementation summary, iteration count, acknowledged TODOs, security result | Yes (`implement_change_golden_quality`) | MEDIUM |
| 9 | Display summary | L2: output matches report content | No | LOW |
| 10 | Suggest commit message | L1: `Suggest a commit message` | Yes | LOW |
|    |                         | L2: follows git guidelines | No | LOW |
| — | Device gate (cross-cutting) | L1: `adb devices`, device gate protocol | Yes | MEDIUM |
|   |                              | L5: blocks until device confirmed, re-checks after user response | No | MEDIUM |
| — | Early device reminder | L2: non-blocking reminder at start about device needed later | No | LOW |
| — | Sub-agent orchestration (cross-cutting) | L1: sub-agent orchestration declaration, retry/failure handling | Yes | MEDIUM |

**Summary:** 24 L1 guardrails (all exist), 30 potential L2–L5 evals (3 exist, 1 partially).

---

## 4. `sdlc_verify_story`

| # | Task / Operation | Eval Types | Implemented? | Priority |
|---|-----------------|------------|-----------------|----------|
| — | Orchestrator pre-work | L2: gathers modified files, story data, active change name | No | HIGH |
| 1 | Locate user story and validate closing preconditions | L2: matches story by number/name | Partially (`verify_story_precondition_fail`) | HIGH |
|   |                                                       | L5: preconditions for closing not met — stops | Yes (`verify_story_precondition_fail`) | CRITICAL |
| 2 | OpenSpec verify (blocking gate, Sonnet) | L1: `opsx:verify`, `BLOCKING GATE`, `PASS`/proceed, `FAIL`/`STOP` | Yes | MEDIUM |
|   |                                          | L5: FAIL — stops, presents issues, does not proceed | Yes (`verify_story_blocks_on_gate_failure`) | CRITICAL |
|   |                                          | L2: PASS — proceeds to next gate | No | MEDIUM |
|   |                                          | L5: sub-agent itself fails — retries with Sonnet | No | MEDIUM |
| 3 | TODO scan (blocking gate, Sonnet) | L1: `TODO scan` present | Yes | MEDIUM |
|   |                                    | L5: RESOLVE NOW TODOs found — stops | No | HIGH |
|   |                                    | L2: all TODOs ACKNOWLEDGED or none — PASS | No | MEDIUM |
|   |                                    | L5: sub-agent fails — retries | No | MEDIUM |
| 4 | Security review (blocking gate, Sonnet) | L1: `security-review` present | Yes | MEDIUM |
|   |                                          | L5: critical/high findings — stops | No | CRITICAL |
|   |                                          | L2: no critical findings — PASS | No | MEDIUM |
|   |                                          | L5: sub-agent fails — retries | No | MEDIUM |
| 5 | Clean build + static analysis (blocking gate, Haiku) | L1: `gradlew clean check` present | Yes | MEDIUM |
|   |                                                       | L5: build fails — stops with errors | No | CRITICAL |
|   |                                                       | L4: build succeeds — PASS | No | MEDIUM |
|   |                                                       | L5: sub-agent fails — retries, Haiku escalates to Sonnet | No | MEDIUM |
| 6 | Unit tests (blocking gate, Haiku) | L1: `gradlew test` present | Yes | MEDIUM |
|   |                                    | L5: tests fail — stops with failure list | No | CRITICAL |
|   |                                    | L4: all tests pass — PASS | No | MEDIUM |
|   |                                    | L5: sub-agent fails — retries, escalates | No | MEDIUM |
| 7 | Coverage report (non-blocking, Sonnet) | L1: `koverXmlReport` present | Yes | LOW |
|   |                                         | L2: coverage table produced with all 5 categories | No | MEDIUM |
|   |                                         | L5: Gradle command errors — FAIL but does not block | No | LOW |
| 8 | Test file coverage (blocking gate, Sonnet) | L1: `Test file coverage` present | Yes | MEDIUM |
|   |                                              | L5: source class without test file — FAIL, stops | No | HIGH |
|   |                                              | L2: all classes have test files — PASS | No | MEDIUM |
| 9 | Compose preview coverage (blocking gate, Sonnet) | L1: `preview coverage` present | Yes | MEDIUM |
|   |                                                    | L5: composable without preview or uncovered UiState field — FAIL, stops | No | HIGH |
|   |                                                    | L2: all composables have previews, all fields covered — PASS | No | MEDIUM |
| 10 | On-device tests (blocking gate, Haiku) | L1: `connectedDebugAndroidTest`, `adb devices`, `NOT_FEASIBLE` | Yes | MEDIUM |
|    |                                         | L5: instrumented tests fail — stops | No | HIGH |
|    |                                         | L5: NOT_FEASIBLE — asks user for manual verification, blocks | No | MEDIUM |
|    |                                         | L4: tests pass, app exercise confirms feature — PASS | No | MEDIUM |
|    |                                         | L5: sub-agent fails — retries, Haiku escalates to Sonnet | No | MEDIUM |
| 11 | Definition of Done (blocking gate, Sonnet) | L1: `Definition of Done` present | Yes | HIGH |
|    |                                              | L5: criterion not met — FAIL, stops | No | CRITICAL |
|    |                                              | L2: all criteria met — PASS | No | MEDIUM |
| 12 | Close user story (sub-agent, Haiku) | L1: `git mv` present | Yes | MEDIUM |
|    |                                      | L2: story file renamed to DONE status | Yes (`verify_story_golden_quality`) | HIGH |
|    |                                      | L2: index.md updated with new filename | Yes (`verify_story_golden_quality`) | HIGH |
|    |                                      | L5: sub-agent fails — retries, escalates | No | MEDIUM |
| 13 | Sync delta specs (sub-agent, Sonnet) | L1: `opsx:sync` present | Yes | MEDIUM |
|    |                                       | L2: delta specs merged into main specs | Yes (`verify_story_golden_quality`) | HIGH |
|    |                                       | L2: no delta specs — reports "nothing to sync" | No | LOW |
|    |                                       | L5: sub-agent fails — retries | No | MEDIUM |
| 14 | Archive change (sub-agent, Haiku) | L1: `opsx:archive` present | Yes | LOW |
|    |                                    | L2: change directory moved to archive | Yes (`verify_story_golden_quality`) | MEDIUM |
|    |                                    | L5: sub-agent fails — retries, escalates | No | LOW |
| 15 | Verify README/AGENTS sync (sub-agent, Sonnet) | L2: docs updated if story changes affect them | No | MEDIUM |
|    |                                                | L5: no changes needed — reports "in sync" | No | LOW |
| 16 | Add report (sub-agent, Haiku) | L1: references `guidelines-reports.md` | Yes | LOW |
|    |                                | L2: report contains all gate results, coverage table as HTML `<table>` | Yes (`verify_story_golden_quality` L2 gate keywords + L3 judge: report_completeness) | MEDIUM |
|    |                                | L3: report includes all 13 data points listed in prompt | Yes (`verify_story_golden_quality` L3 judge: report_completeness) | MEDIUM |
| 17 | Display summary | L2: includes coverage table rendered as markdown | No | LOW |
| 18 | Suggest commit message | L1: `Suggest a commit message` | Yes | LOW |
|    |                         | L2: follows git guidelines format | No | LOW |
| — | Device gate (cross-cutting) | L1: `adb devices`, device gate protocol | Yes | MEDIUM |
|   |                              | L5: blocks until device confirmed | No | MEDIUM |
| — | Early device reminder | L2: non-blocking reminder at start | No | LOW |
| — | Blocking gate protocol (cross-cutting) | L1: `BLOCKING GATE`, `PASS`, `FAIL`, `STOP` | Yes | HIGH |
|   |                                          | L5: gate N fails — gates N+1..end never reached | Yes (`verify_story_blocks_on_gate_failure`) | CRITICAL |
| — | Sub-agent orchestration (cross-cutting) | L1: sub-agent orchestration declaration, failure handling | Yes | MEDIUM |

**Summary:** 27 L1 guardrails (all exist), 40 potential L2–L5 evals (9 exist).

---

## 5. `sdlc_doctor`

| # | Task / Operation | Eval Types | Implemented? | Priority |
|---|-----------------|------------|-----------------|----------|
| 1 | Spawn parallel Haiku sub-agents | L1: Haiku model, parallel execution | Yes | MEDIUM |
|   |                                  | L2: all agents spawn, run, and return results | Yes (`doctor_all_pass`) | HIGH |
|   |                                  | L5: sub-agent fails — no explicit retry defined | No | LOW |
| 2 | OpenSpec category checks | L1: `OpenSpec`, `openspec/config.yaml` | Yes | MEDIUM |
|   |                           | L2: config present, CLI installed, all opsx commands present — passes | Yes (`doctor_all_pass`) | HIGH |
|   |                           | L5: config.yaml missing — fails that check, others pass | Yes (`doctor_missing_openspec_config`) | MEDIUM |
|   |                           | L5: 2 opsx command files missing — fails those 2, others pass | Yes (`doctor_missing_opsx_commands`) | MEDIUM |
| 3 | Security Review category check | L1: `Security Review`, `security-guidance` | Yes | MEDIUM |
|   |                                 | L2: plugin enabled — passes | Yes (`doctor_all_pass`) | MEDIUM |
|   |                                 | L5: plugin disabled or set to false — fails | Yes (`doctor_security_disabled`) | MEDIUM |
| 4 | SDLC Commands category checks | L1: `SDLC Commands` | Yes | LOW |
|   |                                | L2: all 8 command files present — passes | Yes (`doctor_all_pass`) | LOW |
|   |                                | L5: command files missing — fails for missing | Partially (`doctor_everything_broken`) | LOW |
| 5 | Guidelines category checks | L2: all guidelines present and wired in AGENTS.md | Yes (`doctor_all_pass`) | MEDIUM |
|   |                             | L5: guidelines missing or not referenced | Partially (`doctor_everything_broken`) | LOW |
| 6 | All checks fail scenario | L5: every checked file/config absent — all fail, correct failure count | Yes (`doctor_everything_broken`) | MEDIUM |
| 7 | Read-only enforcement | L1: `must not modify any files`, `Do NOT modify any files` | Yes | HIGH |
|   |                        | L2: no files created or modified in fixture after run | Partially (asserted in all scenarios) | MEDIUM |
| 8 | Output format and summary | L1: summary with pass/fail count | Yes | LOW |
|   |                            | L2: ✅/❌ lines per check, correct summary count | Partially (`doctor_all_pass`) | MEDIUM |

**Summary:** 10 L1 guardrails (all exist), 12 potential L2–L5 evals (5 exist, 3 partially).

---

## 6. `sdlc_project_doctor`

| # | Task / Operation | Eval Types | Implemented? | Priority |
|---|-----------------|------------|-----------------|----------|
| 1 | Spawn parallel Haiku sub-agents | L1: Haiku model, parallel execution | Yes | MEDIUM |
|   |                                  | L2: all agents spawn and return results | Yes (`project_doctor_all_pass`) | HIGH |
|   |                                  | L5: sub-agent fails — no explicit retry defined | No | LOW |
| 2 | Detekt category checks | L1: `Detekt` category | Yes | MEDIUM |
|   |                          | L2: plugin, config, version 2.x, zero tolerance, validation, compose rules — all pass | Yes (`project_doctor_all_pass`) | HIGH |
|   |                          | L5: config file missing — fails detekt checks | Yes (`project_doctor_missing_detekt`) | MEDIUM |
|   |                          | L5: detekt 1.x detected — fails with upgrade message | No | HIGH |
|   |                          | L5: compose rules version mismatch — fails | No | MEDIUM |
| 3 | Kover category checks | L1: `Kover`, `minBound` | Yes | MEDIUM |
|   |                         | L2: plugin present, minBound(95) — passes | Yes (`project_doctor_all_pass`) | MEDIUM |
|   |                         | L5: minBound set to 50 — fails | Yes (`project_doctor_low_coverage`) | MEDIUM |
| 4 | Unit Tests category checks | L1: `Unit Tests` | Yes | LOW |
|   |                              | L2: JUnit, MockK, coroutines-test, test directory — all present | Yes (`project_doctor_all_pass`) | LOW |
|   |                              | L5: test dependencies missing | No | LOW |
| 5 | Analytics category checks | L2: tracking plan exists, has required sections, wired in AGENTS.md and open_story | Yes (`project_doctor_all_pass`) | MEDIUM |
|   |                            | L5: tracking plan missing or incomplete | No | MEDIUM |
|   |                            | L5: analytics hook missing from sdlc_open_story.md | No | HIGH |
| 6 | Fastlane category checks | L1: `Fastlane` | Yes | LOW |
|   |                            | L2: Fastfile, Gemfile, CLIs present — passes | Yes (`project_doctor_all_pass`) | LOW |
|   |                            | L5: Fastfile or Gemfile missing | No | LOW |
| 7 | CI/CD category checks | L1: `CI/CD` | Yes | LOW |
|   |                         | L2: workflow file with check and koverVerify steps — passes | Yes (`project_doctor_all_pass`) | LOW |
|   |                         | L5: CI workflow missing or incomplete | No | LOW |
| 8 | Gradle category checks | L1: `Gradle` | Yes | LOW |
|   |                          | L2: Gradle wrapper resolves — passes | Yes (`project_doctor_all_pass`) | LOW |
|   |                          | L5: Gradle wrapper broken or missing | No | LOW |
| 9 | Read-only enforcement | L1: `must not modify any files`, `Do NOT modify any files` | Yes | HIGH |
|   |                        | L2: no files modified after run | Partially (asserted in all scenarios) | MEDIUM |
| 10 | Output format and summary | L1: summary with pass/fail count | Yes | LOW |
|    |                            | L2: correct summary count | Partially (`project_doctor_all_pass`) | MEDIUM |
| — | Everything broken scenario | L5: all checked files/config absent | No | LOW |

**Summary:** 12 L1 guardrails (all exist), 18 potential L2–L5 evals (3 exist, 2 partially).

---

## 7. `sdlc_exp_four_in_one`

| # | Task / Operation | Eval Types | Implemented? | Priority |
|---|-----------------|------------|-----------------|----------|
| — | Git safety checks (delegated to Phase 1) | L5: dirty state — warns user, names dirty files | Yes (`exp_four_in_one_dirty_state`) | MEDIUM |
|   |                                            | L5: not on main — asks proceed/switch | No | LOW |
| 1 | Phase 1: Open & Refine (sub-agent, Opus) | L1: Opus model, refs `sdlc_open_story.md` | Yes | MEDIUM |
|   |                                            | L2: sub-agent runs open_story to completion | No | HIGH |
|   |                                            | L2: story file renamed to -WIP | No | HIGH |
|   |                                            | L5: sub-agent fails or reports blocker — stops | No | MEDIUM |
| — | Post-Phase 1 verification and commit | L1: `-WIP` verification, `git add -A`, `git commit`, `Co-Authored-By`, `{REF}` | Yes | MEDIUM |
|   |                                       | L2: commit created with correct message format | No | LOW |
| 2 | Phase 2: Propose Change (sub-agent, Opus) | L1: refs `sdlc_propose_change.md` | Yes | MEDIUM |
|   |                                              | L2: sub-agent runs propose_change to completion | No | HIGH |
|   |                                              | L2: change directory created under `openspec/changes/` | No | HIGH |
|   |                                              | L5: sub-agent fails or reports blocker — stops | No | MEDIUM |
| — | Post-Phase 2 verification and commit | L1: `openspec/changes/` verification | Yes | LOW |
|   |                                       | L2: commit created | No | LOW |
| 3 | Phase 3: Implement Change (sub-agent, Sonnet) | L1: Sonnet model, refs `sdlc_implement_change.md` | Yes | MEDIUM |
|   |                                                  | L2: sub-agent runs implement_change to completion | No | CRITICAL |
|   |                                                  | L2: all tasks `[x]` | No | HIGH |
|   |                                                  | L5: sub-agent fails or reports blocker — stops | No | MEDIUM |
| — | Post-Phase 3 verification and commit | L1: all tasks `[x]` verification | Yes | MEDIUM |
|   |                                       | L2: commit created | No | LOW |
| 4 | Phase 4: Verify & Archive (sub-agent, Sonnet) | L1: refs `sdlc_verify_story.md` | Yes | MEDIUM |
|   |                                                  | L2: sub-agent runs verify_story to completion | No | CRITICAL |
|   |                                                  | L2: story file renamed to -DONE | No | HIGH |
|   |                                                  | L5: sub-agent fails or reports blocker — stops | No | MEDIUM |
| — | Post-Phase 4 verification and commit | L1: `-DONE` verification | Yes | MEDIUM |
|   |                                       | L2: commit created | No | LOW |
| 5 | Blocker handling (cross-cutting) | L1: `blocker`, `STOP` | Yes | HIGH |
|   |                                   | L5: blocker in any phase — relay to user and stop | No | HIGH |
| 6 | Final summary | L1: `Vibe Complete`, `Total commits: 4`, PR/merge | Yes | LOW |
|   |                | L2: summary table shows all 4 phases DONE | No | LOW |

**Summary:** 19 L1 guardrails (all exist), 18 potential L2–L5 evals (1 exists).

---

## 8. `sdlc_exp_vibe_a_story`

| # | Task / Operation | Eval Types | Implemented? | Priority |
|---|-----------------|------------|-----------------|----------|
| 1.1 | Git safety checks | L1: `git status`, `git branch --show-current`, `DO NOT MAKE ASSUMPTIONS`, `DO NOT DELETE DATA` | Yes | MEDIUM |
|     |                    | L5: dirty state — warns user, names dirty files | Yes (`exp_vibe_a_story_dirty_state`) | MEDIUM |
|     |                    | L5: not on main — asks proceed/switch | No | LOW |
| 1.2 | Resolve user story | L1: references `guidelines-userstories.md` | Yes | LOW |
|     |                     | L2: auto-selects or matches story | No | HIGH |
|     |                     | L5: no actionable story — stops | No | MEDIUM |
| 1.3 | Create feature branch | L2: branch created under `feature/` | No | LOW |
| 1.4 | Open story (sub-agent, Haiku) | L1: Haiku model, `git mv`, failure handling | Yes | MEDIUM |
|     |                                | L2: story file renamed to -WIP, index updated | No | HIGH |
|     |                                | L5: Haiku fails — escalates to Sonnet | No | MEDIUM |
| 1.5 | Analyze, explore, plan (sub-agent, Opus) | L1: Opus model, failure handling | Yes | MEDIUM |
|     |                                            | L3: refinement at top, original under `## Original user story` | No | CRITICAL |
|     |                                            | L2: task file created at `vibe/{STORY_ID}-tasks.md` with structured sections | No | CRITICAL |
|     |                                            | L3: sections ordered: prerequisites → core → UI → integration | No | MEDIUM |
|     |                                            | L5: Opus fails — retries once | No | MEDIUM |
| 1.6 | Clarify doubts (interactive) | L5: questions surfaced — asks user, does not assume | No | HIGH |
|     |                               | L5: no questions — proceeds | No | LOW |
| 1.7 | Phase 1 commit | L1: `git add -A`, `git commit`, `Co-Authored-By`, `{REF}` | Yes | LOW |
|     |                  | L2: commit created with correct format | No | LOW |
| 2.1 | Parse and classify task list | L1: checkbox tracking `[x]` | Yes | MEDIUM |
|     |                               | L2: sections parsed, model assigned correctly (Sonnet for BDD, Haiku for mechanical) | No | HIGH |
|     |                               | L5: resume — fully completed sections skipped | No | MEDIUM |
| 2.2 | Execute sections (sub-agents, Sonnet/Haiku) | L1: Sonnet model for implementation sections | Yes | MEDIUM |
|     |                                               | L2: all tasks in section completed, checkboxes updated | No | CRITICAL |
|     |                                               | L5: sub-agent fails — retries; Haiku escalates to Sonnet | No | HIGH |
|     |                                               | L5: checkboxes missed — Haiku fix agent | No | MEDIUM |
| 2.3 | Verify all tasks complete | L2: every task in file is `[x]` | No | HIGH |
| 2.4 | Build, static analysis, unit tests | L4: `./gradlew clean check test` passes | No | HIGH |
|     |                                      | L5: failures — fixes iteratively, re-runs | No | MEDIUM |
| 2.5 | Security review | L1: `security-review` | Yes | MEDIUM |
|     |                  | L2: clean — proceeds | No | MEDIUM |
|     |                  | L5: findings — fixes, re-runs until clean | No | HIGH |
| 2.6 | On-device tests | L1: `adb devices`, device gate, `BLOCK`, `connectedDebugAndroidTest` | Yes | MEDIUM |
|     |                  | L5: no device — blocks and asks user | No | MEDIUM |
|     |                  | L4: tests pass, feature exercised via adb | No | MEDIUM |
|     |                  | L5: NOT_FEASIBLE — asks user, blocks | No | MEDIUM |
| 2.7 | Close story (sub-agent, Haiku) | L1: `-WIP` → `-DONE` lifecycle | Yes | MEDIUM |
|     |                                 | L2: story file renamed to -DONE, index updated | No | HIGH |
|     |                                 | L5: Haiku fails — escalates to Sonnet | No | MEDIUM |
| 2.8 | Phase 2 commit | L1: commit policy | Yes | LOW |
|     |                  | L2: commit created | No | LOW |
| — | Intentional omissions | L1 (negative): no `Definition of Done verification`, no `RESOLVE NOW` loop | Yes | MEDIUM |
| — | Final summary | L1: `Vibe Complete`, `Total commits: 2`, PR/merge | Yes | LOW |
|   |                | L2: summary table shows both phases DONE | No | LOW |

**Summary:** 30 L1 guardrails (all exist, including 2 negative assertions), 28 potential L2–L5 evals (1 exists).

---

## Overall Coverage

| Command | L1 Guardrails | L2–L5 Evals (potential) | L2–L5 Evals (exist) | Coverage | Uncovered CRITICAL | Uncovered HIGH |
|---------|--------------|-------------------------|---------------------|----------|--------------------|----------------|
| `sdlc_open_story` | 14 / 14 | 20 | 8 | 40% | 0 | 2 |
| `sdlc_propose_change` | 15 / 15 | 18 | 7 | 39% | 0 | 2 |
| `sdlc_implement_change` | 24 / 24 | 30 | 3 | 10% | 2 | 11 |
| `sdlc_verify_story` | 27 / 27 | 40 | 9 | 23% | 4 | 5 |
| `sdlc_doctor` | 10 / 10 | 12 | 5 | 42% | 0 | 1 |
| `sdlc_project_doctor` | 12 / 12 | 18 | 3 | 17% | 0 | 3 |
| **Active total** | **102 / 102** | **138** | **35** | **25%** | **6** | **24** |
| `sdlc_exp_four_in_one` *(exp)* | 19 / 19 | 18 | 1 | 6% | 2 | 5 |
| `sdlc_exp_vibe_a_story` *(exp)* | 30 / 30 | 28 | 1 | 4% | 3 | 9 |
| **Grand total** | **151 / 151** | **184** | **37** | **20%** | **11** | **38** |

> Experimental commands (`sdlc_exp_*`) are excluded from the active total. Their eval coverage
> will not be expanded until they graduate from experimental status.

### Uncovered CRITICAL evals (active commands)

The 6 uncovered CRITICAL evals across the 4 main commands and 2 doctor commands, ranked by
command execution order. The golden-quality scenarios (added October 2026) covered 5 of the
original 11 CRITICALs — all in the L2/L3 output-quality category.

| # | Command | Operation | Layer | What it would verify |
|---|---------|-----------|-------|---------------------|
| 1 | `sdlc_implement_change` | Execute sections (sub-agents) | L2 | BDD cycle: test written, RED confirmed, implementation written, GREEN confirmed *(partially covered by L3 judge: bdd_discipline assesses quality, but not actual RED/GREEN execution)* |
| 2 | `sdlc_implement_change` | Execute sections (sub-agents) | L5 | Test unexpectedly passes at RED — stops and reports |
| 3 | `sdlc_verify_story` | Security review gate | L5 | Critical/high findings — stops |
| 4 | `sdlc_verify_story` | Clean build gate | L5 | Build fails — stops with errors |
| 5 | `sdlc_verify_story` | Unit tests gate | L5 | Tests fail — stops with failure list |
| 6 | `sdlc_verify_story` | Definition of Done gate | L5 | Criterion not met — FAIL, stops |

**Pattern in the remaining gaps:**

- **L5 behavioural gates** (#2–#6): five of the six remaining gaps are gates that should halt
  progress. Only the OpenSpec verify gate has a behavioural eval (`verify_story_blocks_on_gate_failure`);
  the remaining gates are untested. A gate that fails to stop is worse than no gate at all — it
  creates false confidence.
- **L2 BDD cycle verification** (#1): the golden-quality L3 judge assesses whether the code *looks like*
  it followed test-first discipline, but no eval verifies the actual RED→GREEN execution sequence.
  This is the hardest gap to close — it requires a scenario where a test is designed to pass at RED.

### Cross-command consistency checks

In addition to per-command guardrails, `check_guardrails.sh` includes 5 cross-command assertion
loops (23 total assertions) verifying: commit message suggestion on all 4 main commands, sub-agent
failure handling on all 4 main commands, report generation on all 4 main commands, sub-agent
orchestration across all 8 commands, and device connectivity on the 3 device-aware commands. These
overlap with per-command assertions and are not counted separately above.

### Observations

1. **L1 guardrails are at 100%.** All 151 per-command guardrails pass, plus 23 cross-command
   consistency checks. This remains the cheapest and most reliable layer.

2. **L2–L5 coverage for active commands is 25%** (35 out of 138 potential). The golden-quality
   scenarios (October 2026) raised coverage from 10% to 25% — the 4 main commands moved from
   6/108 (6%) to 27/108 (25%).

3. **Output quality is now covered for all 4 main commands.** The golden-quality scenarios provide
   L2 structural assertions and L3 LLM-as-judge scoring against golden reference artifacts from
   a real pipeline run. This closed the original 5 highest-priority CRITICALs (#1–#5) and shifted
   the remaining gap entirely to L5 behavioural gates.

4. **`sdlc_implement_change` remains the weakest main command** at 10% coverage (3/30) with
   2 uncovered CRITICALs. The golden-quality scenario covers task completion and has an L3 judge
   for BDD discipline, but the actual RED→GREEN execution cycle (#1) and the test-passes-at-RED
   gate (#2) remain untested. These are the core BDD discipline — if they fail silently, the
   test-first methodology is theatre.

5. **`sdlc_verify_story` has 4 uncovered CRITICAL L5 behavioural gates.** Only the OpenSpec verify gate
   is tested. The security, build, unit test, and Definition of Done gates are untested — a
   broken gate that passes when it should block is the highest-consequence failure mode in
   the verification pipeline.

6. **Highest-value next evals** (ordered by risk reduction per eval):
    1. **L5 blocking-gate cascade** (`sdlc_verify_story`): one scenario with a build or test failure
       would cover #4 or #5 and confirm the gate-stops-everything protocol beyond the first gate.
    2. **L5 BDD red/green enforcement** (`sdlc_implement_change`): a scenario where a test passes at
       RED would cover #2 — the most dangerous silent failure in the framework.
    3. **L5 `sdlc_project_doctor` detekt version detection**: not CRITICAL but HIGH — the silent-failure
       mode when detekt 1.x meets AGP 8+ makes this a high-value low-cost addition.

7. **Coverage distribution has improved but L5 gates remain the blind spot.** The golden-quality
   scenarios addressed the L2/L3 output-quality gap across all commands. The remaining 6 uncovered
   CRITICALs are all L5 behavioural — gates that should halt progress but have no eval confirming
   they do. This is the next frontier.
