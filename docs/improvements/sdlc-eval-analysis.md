# SDLC Evals Analysis

Systematic analysis of eval coverage for the four main SDLC commands. Each table maps every
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

**Summary:** 13 static guardrails (all exist), 20 potential execution evals (2 exist).

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
| 4 | Propose change with BDD tasks (sub-agent, Sonnet) | STATIC_GUARDR: BDD, GIVEN/WHEN/THEN, test-first, `opsx:propose` | Yes | HIGH |
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

**Summary:** 11 static guardrails (all exist), 18 potential execution evals (1 exists).

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
| 1d | Execute sections sequentially (sub-agents) | STATIC_GUARDR: `RED confirmed`, `GREEN confirmed`, BDD Execution Discipline | Yes | HIGH |
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

**Summary:** 18 static guardrails (all exist), 30 potential execution evals (0 exist).

---

## 4. `sdlc_verify_story`

| # | Task / Operation | Eval Types | Implemented? | Priority |
|---|-----------------|------------|-----------------|----------|
| — | Orchestrator pre-work | EX-HAPPYP: gathers modified files, story data, active change name | No | HIGH |
| 1 | Locate user story and validate closing preconditions | EX-HAPPYP: matches story by number/name | Partially (`verify_story_precondition_fail`) | HIGH |
|   |                                                       | EX-BLOCKINGGT: preconditions for closing not met — stops | Yes (`verify_story_precondition_fail`) | CRITICAL |
| 2 | OpenSpec verify (blocking gate, Sonnet) | STATIC_GUARDR: `opsx:verify`, `BLOCKING GATE` | Yes | MEDIUM |
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

**Summary:** 20 static guardrails (all exist), 40 potential execution evals (3 exist).

---

## Overall Coverage

| Command | Static Guardrails | Execution Evals (potential) | Execution Evals (exist) | Coverage | Uncovered CRITICAL | Uncovered HIGH |
|---------|------------------|-----------------------------|-------------------------|----------|--------------------|----------------|
| `sdlc_open_story` | 13 / 13 | 20 | 2 | 10% | 2 | 5 |
| `sdlc_propose_change` | 11 / 11 | 18 | 1 | 6% | 2 | 3 |
| `sdlc_implement_change` | 18 / 18 | 30 | 0 | 0% | 3 | 12 |
| `sdlc_verify_story` | 20 / 20 | 40 | 3 | 8% | 4 | 8 |
| **Total** | **62 / 62** | **108** | **6** | **6%** | **11** | **28** |

### Observations

1. **Static guardrails are at 100%.** Every critical pattern, model assignment, and cross-command
   consistency rule is checked by `check_guardrails.sh`. This is the cheapest and most reliable layer.

2. **Execution evals are at 6%.** The existing 6 scenarios cover the most critical edge cases
   (dirty state, wrong branch, precondition fail, gate blocking, no-assumptions guardrail) but
   only test entry-point behaviour. No eval currently verifies:
    - A full happy-path run to completion
    - Sub-agent failure/retry/escalation paths
    - Side effects: file renames, index updates, report generation, artifact creation
    - Output quality: refinement structure, BDD task format, report content

3. **`sdlc_implement_change` has zero execution evals.** This is the most complex command (sub-agent
   orchestration per section, BDD red/green cycles, TODO resolution loops, device gates). The README
   notes this as deferred because it requires a full openspec change with task artifacts.

4. **Highest-value gaps** (highest risk with no execution eval):
    - Happy-path completion for any command (none exists)
    - BDD red/green discipline enforcement (`sdlc_implement_change`)
    - Blocking-gate cascade (`sdlc_verify_story` — only first gate failure is tested)
    - Sub-agent retry/escalation paths (none tested for any command)
    - Side-effect correctness: `git mv` renames, index updates, report file creation
