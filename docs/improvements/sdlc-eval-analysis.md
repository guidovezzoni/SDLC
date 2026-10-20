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

| # | Task / Operation | Eval Types | Currently Have? |
|---|-----------------|------------|-----------------|
| 1 | Check for uncommitted changes | STATIC_GUARDR: `git status`, `DO NOT DELETE DATA` guardrail present | STATIC_GUARDR: Yes. EX: Yes (`open_story_dirty_state`) |
|   |                               | EX-EDGE: dirty state warns user, names dirty files | |
|   |                               | EX-EDGE: clean state proceeds without warning | EX: No |
| 2 | Handle current branch (on main) | STATIC_GUARDR: `git branch --show-current` present | STATIC_GUARDR: Yes |
|   |                                  | EX-HAPPYP: on main, fetch/pull succeeds, proceeds | EX: No |
|   |                                  | EX-EDGE: on main, pull fails (conflict) — asks user | EX: No |
| 3 | Handle current branch (not on main) | EX-EDGE: detects non-main branch, asks proceed/switch | EX: Yes (`open_story_not_on_main`) |
|   |                                      | EX-EDGE: user chooses proceed — skips branch creation (step 5) | EX: No |
|   |                                      | EX-EDGE: user chooses switch — switches to main, pulls | EX: No |
| 4 | Resolve user story argument | STATIC_GUARDR: references `guidelines-userstories.md` | STATIC_GUARDR: Yes |
|   |                              | EX-HAPPYP: auto-selects next story when no argument given | EX: No |
|   |                              | EX-EDGE: no actionable story exists — informs user and stops | EX: No |
|   |                              | EX-EDGE: specific story argument matches correctly | EX: No |
| 5 | Locate user story and validate preconditions | EX-EDGE: partial name match resolves correctly | EX: No |
|   |                                               | EX-EDGE: no match — asks user | EX: No |
|   |                                               | EX-BLOCKINGGT: preconditions not met — stops | EX: No |
| 6 | Create feature branch | EX-SIDEFX: branch created under `feature/` with ticket number prefix | EX: No |
|   |                        | EX-EDGE: skip when user chose to stay on current branch | EX: No |
| 7 | Open the user story (sub-agent, Haiku) | STATIC_GUARDR: Haiku model, `git mv`, failure handling, verification | STATIC_GUARDR: Yes |
|   |                                         | EX-SIDEFX: story file renamed correctly (status change) | EX: No |
|   |                                         | EX-SIDEFX: index.md updated with new filename | EX: No |
|   |                                         | EX-FAIL: sub-agent fails — retries with Sonnet, then inline | EX: No |
| 8 | Refine the user story (sub-agent, Opus) | STATIC_GUARDR: Opus model, failure handling, verification | STATIC_GUARDR: Yes |
|   |                                          | EX-OUTPUTQ: refined content at top, original at bottom under `## Original user story` | EX: No |
|   |                                          | EX-OUTPUTQ: refinement includes all 12 required sections (analytics, security, GDPR, etc.) | EX: No |
|   |                                          | EX-OUTPUTQ: stays at "what" level, does not prescribe architecture | EX: No |
|   |                                          | EX-FAIL: sub-agent fails — retries with Opus, then inline | EX: No |
| 9 | Add a report (sub-agent, Haiku) | STATIC_GUARDR: references `guidelines-reports.md` | STATIC_GUARDR: Yes |
|   |                                  | EX-SIDEFX: report file exists and contains opening section | EX: No |
|   |                                  | EX-FAIL: sub-agent fails — retries, then inline | EX: No |
| 10 | Display summary | EX-OUTPUTQ: output includes story name, branch, refinement highlights | EX: No |
| 11 | Suggest commit message | STATIC_GUARDR: `Suggest a commit message`, references `guidelines-git.md` | STATIC_GUARDR: Yes |
|    |                         | EX-OUTPUTQ: commit message follows git guidelines format (prefixed with issue reference) | EX: No |

**Summary:** 13 static guardrails (all exist), 20 potential execution evals (2 exist).

---

## 2. `sdlc_propose_change`

| # | Task / Operation | Eval Types | Currently Have? |
|---|-----------------|------------|-----------------|
| 1 | Locate user story | EX-HAPPYP: matches by number or partial name | EX: Partially (`propose_change_surfaces_questions` covers identification) |
|   |                    | EX-EDGE: no match — asks user | EX: No |
|   |                    | EX-BLOCKINGGT: story not in WIP status — stops | EX: No |
| 2 | Explore codebase (sub-agent, Sonnet) | STATIC_GUARDR: Sonnet model, `opsx:explore`, read-only guardrail | STATIC_GUARDR: Yes |
|   |                                       | EX-OUTPUTQ: structured output with required sections (Architecture, Integration Points, Questions, Risks, Recommendations) | EX: No |
|   |                                       | EX-SIDEFX: no files created or modified (read-only) | EX: No |
|   |                                       | EX-FAIL: sub-agent fails or returns incomplete — retries with Sonnet, then inline | EX: No |
| 3 | Clarify all doubts | STATIC_GUARDR: `DO NOT MAKE ASSUMPTIONS` guardrail | STATIC_GUARDR: Yes |
|   |                     | EX-EDGE: surfaces questions for ambiguous requirements, does not assume | EX: Yes (`propose_change_surfaces_questions`) |
|   |                     | EX-EDGE: with unambiguous story — proceeds without excessive questions | EX: No |
|   |                     | EX-OUTPUTQ: all questions include WHY explanation | EX: No |
| 4 | Propose change with BDD tasks (sub-agent, Sonnet) | STATIC_GUARDR: BDD, GIVEN/WHEN/THEN, test-first, `opsx:propose` | STATIC_GUARDR: Yes |
|   |                                                    | EX-SIDEFX: change directory created under `openspec/changes/` with all artifacts (proposal, design, specs, tasks) | EX: No |
|   |                                                    | EX-OUTPUTQ: tasks follow BDD structure — test task + implementation task pairs | EX: No |
|   |                                                    | EX-OUTPUTQ: each test task includes GIVEN/WHEN/THEN and target test class | EX: No |
|   |                                                    | EX-OUTPUTQ: non-testable tasks grouped separately (prerequisites, integration) | EX: No |
|   |                                                    | EX-OUTPUTQ: ordering: prerequisites first, BDD pairs middle, integration last, verification end | EX: No |
|   |                                                    | EX-FAIL: sub-agent fails — retries with Sonnet, then Opus escalation | EX: No |
| 5 | Add report (sub-agent, Haiku) | STATIC_GUARDR: references `guidelines-reports.md`, Haiku model | STATIC_GUARDR: Yes |
|   |                                | EX-SIDEFX: report file contains proposal section with exploration summary, Q&A, artifacts list | EX: No |
|   |                                | EX-FAIL: sub-agent fails — retries, then inline | EX: No |
| 6 | Display summary | EX-OUTPUTQ: output includes change name, artifact list, task structure summary | EX: No |
| 7 | Suggest commit message | STATIC_GUARDR: `Suggest a commit message` | STATIC_GUARDR: Yes |
|   |                         | EX-OUTPUTQ: commit message follows git guidelines format | EX: No |

**Summary:** 11 static guardrails (all exist), 18 potential execution evals (1 exists).

---

## 3. `sdlc_implement_change`

| # | Task / Operation | Eval Types | Currently Have? |
|---|-----------------|------------|-----------------|
| 1a | Identify the change (`openspec status`) | STATIC_GUARDR: `openspec status` present | STATIC_GUARDR: Yes |
|    |                                          | EX-HAPPYP: correctly identifies active change and parses JSON | EX: No |
|    |                                          | EX-EDGE: all tasks already complete — skips to step 2 | EX: No |
| 1b | Read and parse task list | STATIC_GUARDR: checkbox tracking `[x]` | STATIC_GUARDR: Yes |
|    |                           | EX-HAPPYP: correctly parses sections, counts pending vs complete | EX: No |
|    |                           | EX-EDGE: resume support — skips sections with all `[x]` | EX: No |
| 1c | Classify sections and assign model tier | STATIC_GUARDR: Sonnet for BDD, Haiku for mechanical | STATIC_GUARDR: Yes |
|    |                                          | EX-OUTPUTQ: execution plan displays correct model assignment per section | EX: No |
|    |                                          | EX-OUTPUTQ: BDD sections assigned Sonnet, mechanical (wire, pass, wrap) assigned Haiku | EX: No |
| 1d | Execute sections sequentially (sub-agents) | STATIC_GUARDR: `RED confirmed`, `GREEN confirmed`, BDD Execution Discipline | STATIC_GUARDR: Yes |
|    |                                              | EX-HAPPYP: sub-agent completes all tasks in section, checkboxes updated | EX: No |
|    |                                              | EX-SIDEFX: BDD cycle: test written, RED confirmed, implementation written, GREEN confirmed | EX: No |
|    |                                              | EX-BLOCKINGGT: test unexpectedly passes at RED — stops and reports | EX: No |
|    |                                              | EX-BLOCKINGGT: test still fails at GREEN (last impl task) — iterates or stops | EX: No |
|    |                                              | EX-FAIL: sub-agent fails — retries; Haiku escalates to Sonnet | EX: No |
|    |                                              | EX-FAIL: checkboxes missed but implementation exists — Haiku checkbox fix agent | EX: No |
| 1e | Final verification | EX-SIDEFX: every task in file is `[x]` after all sections processed | EX: No |
|    |                     | EX-OUTPUTQ: progress report shows correct counts and model distribution | EX: No |
| 2 | Review unresolved TODOs | STATIC_GUARDR: `TODO`, `RESOLVE NOW`, `ACKNOWLEDGED` | STATIC_GUARDR: Yes |
|   |                          | EX-HAPPYP: scans `app/src/`, classifies TODOs correctly | EX: No |
|   |                          | EX-EDGE: TODO whose precondition is met by this story — classified as RESOLVE NOW | EX: No |
|   |                          | EX-EDGE: unrelated TODO — classified as ACKNOWLEDGED | EX: No |
| 3 | Resolve RESOLVE NOW TODOs (loop) | EX-SIDEFX: OpenSpec artifacts updated with new tasks for TODO resolution | EX: No |
|   |                                   | EX-HAPPYP: re-runs implementation for new tasks, then re-checks TODOs | EX: No |
|   |                                   | EX-HAPPYP: loop terminates when no RESOLVE NOW TODOs remain | EX: No |
| 4 | Run Compose UI tests on device | STATIC_GUARDR: `connectedDebugAndroidTest`, device gate, `BLOCK` | STATIC_GUARDR: Yes |
|   |                                 | EX-BLOCKINGGT: no device connected — blocks and asks user | EX: No |
|   |                                 | EX-HAPPYP: device connected, tests pass — proceeds | EX: No |
|   |                                 | EX-FAIL: tests fail — presents failures, fixes, re-runs | EX: No |
| 5 | Run security review (sub-agent, Sonnet) | STATIC_GUARDR: `security-review`, sub-agent delegation, `Do NOT invoke` inline | STATIC_GUARDR: Yes |
|   |                                          | EX-HAPPYP: PASS — proceeds | EX: No |
|   |                                          | EX-FAIL: findings found — fixes, re-runs until clean | EX: No |
| 6 | Update README.md if required | STATIC_GUARDR: `README.md` present | STATIC_GUARDR: Yes |
|   |                               | EX-SIDEFX: README updated when changes affect documented sections | EX: No |
|   |                               | EX-EDGE: README already accurate — skip | EX: No |
| 7 | Update AGENTS.md if required | STATIC_GUARDR: `AGENTS.md` present | STATIC_GUARDR: Yes |
|   |                               | EX-SIDEFX: AGENTS.md updated when changes affect documented sections | EX: No |
|   |                               | EX-EDGE: AGENTS.md already accurate — skip | EX: No |
| 8 | Add report | STATIC_GUARDR: references `guidelines-reports.md` | STATIC_GUARDR: Yes |
|   |             | EX-SIDEFX: report contains implementation summary, iteration count, acknowledged TODOs, security result | EX: No |
| 9 | Display summary | EX-OUTPUTQ: output matches report content | EX: No |
| 10 | Suggest commit message | STATIC_GUARDR: `Suggest a commit message` | STATIC_GUARDR: Yes |
|    |                         | EX-OUTPUTQ: follows git guidelines | EX: No |
| — | Device gate (cross-cutting) | STATIC_GUARDR: `adb devices`, device gate protocol | STATIC_GUARDR: Yes |
|   |                              | EX-BLOCKINGGT: blocks until device confirmed, re-checks after user response | EX: No |
| — | Early device reminder | EX-OUTPUTQ: non-blocking reminder at start about device needed later | EX: No |

**Summary:** 18 static guardrails (all exist), 30 potential execution evals (0 exist).

---

## 4. `sdlc_verify_story`

| # | Task / Operation | Eval Types | Currently Have? |
|---|-----------------|------------|-----------------|
| — | Orchestrator pre-work | EX-HAPPYP: gathers modified files, story data, active change name | EX: No |
| 1 | Locate user story and validate closing preconditions | EX-HAPPYP: matches story by number/name | EX: Partially (`verify_story_precondition_fail`) |
|   |                                                       | EX-BLOCKINGGT: preconditions for closing not met — stops | EX: Yes (`verify_story_precondition_fail`) |
| 2 | OpenSpec verify (blocking gate, Sonnet) | STATIC_GUARDR: `opsx:verify`, `BLOCKING GATE` | STATIC_GUARDR: Yes |
|   |                                          | EX-BLOCKINGGT: FAIL — stops, presents issues, does not proceed | EX: Yes (`verify_story_blocks_on_gate_failure`) |
|   |                                          | EX-HAPPYP: PASS — proceeds to next gate | EX: No |
|   |                                          | EX-FAIL: sub-agent itself fails — retries with Sonnet | EX: No |
| 3 | TODO scan (blocking gate, Sonnet) | STATIC_GUARDR: `TODO scan` present | STATIC_GUARDR: Yes |
|   |                                    | EX-BLOCKINGGT: RESOLVE NOW TODOs found — stops | EX: No |
|   |                                    | EX-HAPPYP: all TODOs ACKNOWLEDGED or none — PASS | EX: No |
|   |                                    | EX-FAIL: sub-agent fails — retries | EX: No |
| 4 | Security review (blocking gate, Sonnet) | STATIC_GUARDR: `security-review` present | STATIC_GUARDR: Yes |
|   |                                          | EX-BLOCKINGGT: critical/high findings — stops | EX: No |
|   |                                          | EX-HAPPYP: no critical findings — PASS | EX: No |
|   |                                          | EX-FAIL: sub-agent fails — retries | EX: No |
| 5 | Clean build + static analysis (blocking gate, Haiku) | STATIC_GUARDR: `gradlew clean check` present | STATIC_GUARDR: Yes |
|   |                                                       | EX-BLOCKINGGT: build fails — stops with errors | EX: No |
|   |                                                       | EX-HAPPYP: build succeeds — PASS | EX: No |
|   |                                                       | EX-FAIL: sub-agent fails — retries, Haiku escalates to Sonnet | EX: No |
| 6 | Unit tests (blocking gate, Haiku) | STATIC_GUARDR: `gradlew test` present | STATIC_GUARDR: Yes |
|   |                                    | EX-BLOCKINGGT: tests fail — stops with failure list | EX: No |
|   |                                    | EX-HAPPYP: all tests pass — PASS | EX: No |
|   |                                    | EX-FAIL: sub-agent fails — retries, escalates | EX: No |
| 7 | Coverage report (non-blocking, Sonnet) | STATIC_GUARDR: `koverXmlReport` present | STATIC_GUARDR: Yes |
|   |                                         | EX-OUTPUTQ: coverage table produced with all 5 categories | EX: No |
|   |                                         | EX-FAIL: Gradle command errors — FAIL but does not block | EX: No |
| 8 | Test file coverage (blocking gate, Sonnet) | STATIC_GUARDR: `Test file coverage` present | STATIC_GUARDR: Yes |
|   |                                              | EX-BLOCKINGGT: source class without test file — FAIL, stops | EX: No |
|   |                                              | EX-HAPPYP: all classes have test files — PASS | EX: No |
| 9 | Compose preview coverage (blocking gate, Sonnet) | STATIC_GUARDR: `preview coverage` present | STATIC_GUARDR: Yes |
|   |                                                    | EX-BLOCKINGGT: composable without preview or uncovered UiState field — FAIL, stops | EX: No |
|   |                                                    | EX-HAPPYP: all composables have previews, all fields covered — PASS | EX: No |
| 10 | On-device tests (blocking gate, Haiku) | STATIC_GUARDR: `connectedDebugAndroidTest`, `adb devices`, `NOT_FEASIBLE` | STATIC_GUARDR: Yes |
|    |                                         | EX-BLOCKINGGT: instrumented tests fail — stops | EX: No |
|    |                                         | EX-BLOCKINGGT: NOT_FEASIBLE — asks user for manual verification, blocks | EX: No |
|    |                                         | EX-HAPPYP: tests pass, app exercise confirms feature — PASS | EX: No |
|    |                                         | EX-FAIL: sub-agent fails — retries, Haiku escalates to Sonnet | EX: No |
| 11 | Definition of Done (blocking gate, Sonnet) | STATIC_GUARDR: `Definition of Done` present | STATIC_GUARDR: Yes |
|    |                                              | EX-BLOCKINGGT: criterion not met — FAIL, stops | EX: No |
|    |                                              | EX-HAPPYP: all criteria met — PASS | EX: No |
| 12 | Close user story (sub-agent, Haiku) | STATIC_GUARDR: `git mv` present | STATIC_GUARDR: Yes |
|    |                                      | EX-SIDEFX: story file renamed to DONE status | EX: No |
|    |                                      | EX-SIDEFX: index.md updated with new filename | EX: No |
|    |                                      | EX-FAIL: sub-agent fails — retries, escalates | EX: No |
| 13 | Sync delta specs (sub-agent, Sonnet) | STATIC_GUARDR: `opsx:sync` present | STATIC_GUARDR: Yes |
|    |                                       | EX-SIDEFX: delta specs merged into main specs | EX: No |
|    |                                       | EX-HAPPYP: no delta specs — reports "nothing to sync" | EX: No |
|    |                                       | EX-FAIL: sub-agent fails — retries | EX: No |
| 14 | Archive change (sub-agent, Haiku) | STATIC_GUARDR: `opsx:archive` present | STATIC_GUARDR: Yes |
|    |                                    | EX-SIDEFX: change directory moved to archive | EX: No |
|    |                                    | EX-FAIL: sub-agent fails — retries, escalates | EX: No |
| 15 | Verify README/AGENTS sync (sub-agent, Sonnet) | EX-SIDEFX: docs updated if story changes affect them | EX: No |
|    |                                                | EX-EDGE: no changes needed — reports "in sync" | EX: No |
| 16 | Add report (sub-agent, Haiku) | STATIC_GUARDR: references `guidelines-reports.md` | STATIC_GUARDR: Yes |
|    |                                | EX-SIDEFX: report contains all gate results, coverage table as HTML `<table>` | EX: No |
|    |                                | EX-OUTPUTQ: report includes all 13 data points listed in prompt | EX: No |
| 17 | Display summary | EX-OUTPUTQ: includes coverage table rendered as markdown | EX: No |
| 18 | Suggest commit message | STATIC_GUARDR: `Suggest a commit message` | STATIC_GUARDR: Yes |
|    |                         | EX-OUTPUTQ: follows git guidelines format | EX: No |
| — | Device gate (cross-cutting) | STATIC_GUARDR: `adb devices`, device gate protocol | STATIC_GUARDR: Yes |
|   |                              | EX-BLOCKINGGT: blocks until device confirmed | EX: No |
| — | Early device reminder | EX-OUTPUTQ: non-blocking reminder at start | EX: No |
| — | Blocking gate protocol (cross-cutting) | STATIC_GUARDR: `BLOCKING GATE`, `PASS`, `FAIL`, `STOP` | STATIC_GUARDR: Yes |
|   |                                          | EX-BLOCKINGGT: gate N fails — gates N+1..end never reached | EX: Yes (`verify_story_blocks_on_gate_failure`) |

**Summary:** 20 static guardrails (all exist), 40 potential execution evals (3 exist).

---

## Overall Coverage

| Command | Static Guardrails | Execution Evals (potential) | Execution Evals (exist) | Coverage |
|---------|------------------|-----------------------------|-------------------------|----------|
| `sdlc_open_story` | 13 / 13 | 20 | 2 | 10% |
| `sdlc_propose_change` | 11 / 11 | 18 | 1 | 6% |
| `sdlc_implement_change` | 18 / 18 | 30 | 0 | 0% |
| `sdlc_verify_story` | 20 / 20 | 40 | 3 | 8% |
| **Total** | **62 / 62** | **108** | **6** | **6%** |

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
