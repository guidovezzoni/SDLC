# Eval Architecture: Golden-Reference Regression Testing for SDLC Commands

## Problem Statement

The SDLC framework has 4 main commands (`open_story`, `propose_change`, `implement_change`,
`verify_story`) plus 2 doctor commands and 2 experimental commands. Each main command orchestrates
AI sub-agents to produce artifacts (refined stories, change proposals, code, verification reports).

**Current state** (from `sdlc-eval-analysis.md`):
- Static guardrails: 100% coverage (151/151) — `grep`-based checks that required patterns exist
  in command `.md` files. Free, instant, catches accidental removal of guardrails.
- Execution evals: 10% coverage (14/138 potential) — actual runs against fixtures, asserting
  output and side effects. The doctor commands are at 42% and 17%; the 4 main commands are at 6%.
- 11 uncovered CRITICAL evals across the main commands, concentrated in output quality (#1, #2, #4),
  side-effect correctness (#3, #6), and blocking gates (#7–#11).

**What's missing:** The existing execution evals test edge cases (dirty state, wrong branch,
precondition failures) but never test the **happy path quality** — did the command produce good
output? This is the highest-consequence gap: the commands can run without structural errors while
producing mediocre refinements, badly structured tasks, or weak verification reports.

### Three regression axes

The eval system must detect regressions across three independent axes:

1. **Command changes** — "I edited `sdlc_open_story.md`; did the refinement quality drop?"
2. **Model changes** — "Opus 5 replaced Opus 4; does the pipeline still produce equivalent output?"
3. **Harness changes** — "I switched from Claude Code to OpenCode/Cursor; same commands, same model,
   but does the output differ because the harness calls tools differently?"

Each axis changes one variable while the others stay fixed. The eval must isolate that variable.

### What to measure

- **Output quality** — per artifact, per criterion, numerically scored
- **Execution time** — wall-clock duration (including human interaction time for now, since only
  `propose_change` has interactive questions), plus token usage if the harness exposes it
- **The commands' own Command Metrics** — the report HTML already embeds start/end time, duration,
  and interaction count, captured by the LLM during execution

---

## Research Findings

A web search for current best practices (October 2026) surfaced consistent guidance from both
academic papers and industry practice. The key findings that shaped this plan:

### 1. Multi-level evaluation is the standard

Evaluate agentic systems at three levels: **end-to-end** (final output), **trajectory** (sequence
of steps), and **component** (individual artifacts). This answers the question "test the final repo,
each artifact, or something else?" — the field says **all three, in layers**, because each catches
different failure modes.

*Source: [Confident AI — LLM Agent Evaluation Metrics in 2026](https://www.confident-ai.com/blog/llm-agent-evaluation-complete-guide)*

### 2. Tiered pipeline: cheap checks first, LLM judges last

A consistent pattern is a tiered evaluation pipeline:

| Tier | What | Cost | Catches |
|------|------|------|---------|
| Deterministic | Structural assertions (grep, file existence, section headings) | Free | Broken structure, missing artifacts, wrong side effects |
| Reference-based metrics | Compare against golden output on specific criteria | Moderate (LLM call) | Semantic regressions — section exists but content is garbage |
| LLM-as-judge | Score open-ended quality on a rubric | Moderate-High | Subtle quality drift, constraint violations, coherence |
| Human review | Sampled spot-checks | Expensive | Judge calibration, edge cases the LLM misses |

We already have the first tier (static guardrails + existing execution evals). This plan adds the
second and third tiers.

*Source: [LLM-as-Judge Got Us This Far — Medium](https://medium.com/@vinayak.talikot/llm-as-judge-got-us-this-far-here-is-what-2026-adds-to-the-toolkit-6922e3b532b3)*

### 3. Reference-based grading works when a reference exists

Reference-based grading (compare candidate against a known-good answer) is more reliable than
reference-free grading (score on absolute criteria) when correct answers exist. We have a reference:
the venice repo branches from a successful pipeline run.

The Autorubric paper separates the two modes and recommends reference-based when the reference is
available. A German legal benchmark demonstrates the pattern: give the judge the task requirements,
the reference solution, and the candidate, then score on multiple dimensions independently.

*Sources: [Autorubric — arXiv](https://arxiv.org/html/2603.00077v1), [BenGER — arXiv](https://arxiv.org/pdf/2605.28183)*

### 4. Per-criterion rubrics with explicit scoring

Analytic (per-criterion) rubrics are preferred over holistic scoring. Examples include boolean
checklists (CheckEval), weighted criterion scoring (RocketEval), and skill-by-skill evaluation
(FLASK). Each criterion gets its own score and rationale, making it possible to pinpoint exactly
which quality dimension regressed.

LLM judges are known to be sensitive to candidate order, output length, and anchoring. Using
structured rubrics with explicit criteria reduces this sensitivity.

*Sources: [Graph-Structured Rubrics — arXiv](https://arxiv.org/pdf/2608.12097), [From Holistic Evaluation to Structured Criteria — arXiv](https://arxiv.org/html/2606.08625v2)*

### 5. Regression testing is an acknowledged gap

Even SWE-bench collects PASS_TO_PASS data (did previously passing tests regress?) but doesn't
surface it in leaderboard rankings. Roughly half of SWE-bench-passing patches would not be merged
by real maintainers. This validates the need for quality measurement beyond "did it produce output."

*Sources: [TDAD — arXiv](https://arxiv.org/html/2603.17973v1), [Rigorous Evaluation of Coding Agents — ACL 2025](https://aclanthology.org/2025.acl-long.189.pdf)*

### 6. Infrastructure noise is real

An Anthropic engineering post on "quantifying infrastructure noise in agentic coding evals" highlights
that variance between runs can distort scores. Single-run comparisons should be interpreted with this
in mind. For our use case, 1 run per configuration change is practical because:
- T1 structural checks are deterministic — 1 run is sufficient
- T2 LLM-as-judge scores are anchored by the golden reference, reducing variance
- Multiple runs (3-5) would only matter for statistical confidence on small score differences

---

## Key Decisions

### Decision 1: Self-contained golden reference

The golden reference is stored in `docs/sdlc/evals/goldenreference/`, with one subdirectory per
command containing input tarballs and expected output files. It was sourced from a real, successful
pipeline run against the venice Android project (story 5.1.2), using 5 branches that capture the
state before and after each command:

```
workshop/00_main ──→ open_story ──→ workshop/01_sdlc_open_story
                                    ──→ propose_change ──→ workshop/02_sdlc_propose_change
                                                           ──→ implement_change ──→ workshop/03_sdlc_implement_changes
                                                                                    ──→ verify_story ──→ workshop/04_sdlc_verify
```

**Why self-contained:** The eval system must not depend on or access the source repo at runtime.
Tarballs are created once via `git archive` (no `.git/` directory, no remotes), and scenario scripts
initialise isolated local-only git repos from them. This prevents any eval run from affecting the
real project, and makes the eval system portable.

**Why a real project:** A real pipeline run against a real Android project produces more realistic
assertions than a synthetic fixture. Each branch boundary is a "before/after" snapshot for one
command, so commands can be tested independently.

**Known deviation:** The source branch names don't match the default naming convention (should be
`feature/5.1.2-...`). This is noted and not asserted on.

### Decision 2: Three evaluation tiers

| Tier | What | Cost | When |
|------|------|------|------|
| **T1: Structural** | File existence, section presence, side effects, content preservation | Free | Every run |
| **T2: LLM-as-judge** | Per-criterion rubric scoring against golden reference | 1 LLM call per command | Every run |
| **T3: Functional** | Build compiles, tests pass, coverage threshold | Requires Android SDK | implement_change and verify_story only |

**Why T1 + T2 instead of just T2:** T1 is free and deterministic. It catches obvious breakage
(missing files, broken structure) without spending an LLM call. T2 then focuses the (more expensive)
judge on quality dimensions that can't be checked with grep.

**Why not T3 for all commands:** `open_story` and `propose_change` produce documentation artifacts
only — no build environment needed. `implement_change` and `verify_story` produce code and run
builds, so T3 applies only to them.

### Decision 3: LLM-as-judge with configurable judge model

The judge model should be different from (ideally stronger than) the model being evaluated, to avoid
self-preference bias. This is configurable via `EVAL_JUDGE_MODEL`.

**Why not a fixed judge:** When testing a model change (axis 2), the model being evaluated varies.
Using the same model as judge would introduce bias. A configurable judge lets the user pick an
appropriate model for each scenario.

### Decision 4: Human interaction is part of the eval, not scripted away

Commands like `propose_change` surface questions to the user. Different models may ask different
questions, so scripted answers would constrain the eval to one model's question pattern.

**What this means:**
- The questions themselves are an evaluable artifact (the `question_quality` rubric criterion)
- Evals require a human in the loop — they can't run unattended in CI
- Wall-clock time includes human thinking/typing time (acceptable since only `propose_change`
  has interactive questions, and the user wants to measure total time for now)
- This can be revisited later if interaction-free measurement becomes important

### Decision 5: One run per configuration, not multiple

**Why:** T1 is deterministic (1 run is enough). T2 is anchored by the reference (reduces variance).
The user's rate limits make multiple Opus runs expensive. Start with 1, add runs only if scores are
too noisy to act on.

### Decision 6: Start with `open_story`

**Why:** Cheapest command (single Opus call, no build environment), reference material already exists
(`sourcematerial/unrefined_user_story.md` and `sourcematerial/refined_user_story.md`), and it covers
the two highest-priority uncovered CRITICALs from the analysis (#1: refinement output structure, #2:
12 required sections present). This scenario becomes the template for the other three.

---

## The Golden Reference: What Each Command Produces

Catalogued by diffing consecutive branches in the venice repo.

### open_story (branch 0→1, 4 files changed)

| Artifact | Path | Description |
|----------|------|-------------|
| Refined story | `docs/userstories/5.1.2-navigate-leg-segment-WIP.md` | 210 lines: refined content at top, original at bottom under `## Original user story` |
| Report | `docs/reports/5.1.2-navigate-leg-segment.html` | 190 lines: HTML report with opening section and Command Metrics |
| Index update | `docs/userstories/index.md` | Link updated from `.md` to `-WIP.md` |
| Original deleted | `docs/userstories/5.1.2-navigate-leg-segment.md` | Removed (git mv to WIP) |

The refined story contains these sections (mapped to the 12 refinement requirements):

| # | Requirement | Section heading in golden reference |
|---|-------------|-------------------------------------|
| 1 | Full description | `## Description` |
| 2 | Fields to update | `## Fields and MVI Artefacts` |
| 3 | Endpoint structure/URLs | `## Intent URI` |
| 4 | Files to modify | `## Files to Modify` |
| 5 | Unit tests | `## Unit Testing Strategy` |
| 6 | Documentation | `## Documentation Updates` |
| 7 | Security | `## Security Considerations` |
| 8 | Performance | `## Performance Considerations` |
| 9 | GDPR | `## GDPR and Sensitive Information` |
| 10 | Analytics | `## Analytics` |
| 11 | Non-functional | `## Other Non-Functional Requirements` |
| 12 | Completion steps | `## Definition of Done` |

### propose_change (branch 1→2, 6 files changed)

| Artifact | Path | Description |
|----------|------|-------------|
| Proposal | `openspec/changes/navigate-leg-segment/proposal.md` | Why, what changes, capabilities, impact |
| Design | `openspec/changes/navigate-leg-segment/design.md` | Context, goals/non-goals, decisions, risks |
| Spec | `openspec/changes/navigate-leg-segment/specs/leg-navigation/spec.md` | 71-line specification |
| Tasks | `openspec/changes/navigate-leg-segment/tasks.md` | 7 sections, 29 tasks, BDD structure |
| Config | `openspec/changes/navigate-leg-segment/.openspec.yaml` | OpenSpec metadata |
| Report | `docs/reports/5.1.2-navigate-leg-segment.html` | Appended proposal section |

The tasks.md structure:
- Section 1: Prerequisites (4 tasks, no BDD)
- Sections 2-6: BDD sections (test task + implementation task pairs)
- Section 7: Verification (4 tasks)

### implement_change (branch 2→3, 19 files changed)

| Category | Files | Description |
|----------|-------|-------------|
| Source code | 8 files | UiIntent, UiEffect, UiState, ViewModel, LegSummary, TripDetailScreen, MainScreen, NavigationUriBuilder |
| Test files | 5 files | Unit tests + compose UI tests for all new code |
| Strings | 3 files | EN, IT, ES-rES locale strings |
| Tasks | 1 file | All 29 checkboxes now `[x]` |
| Docs | 1 file | AGENTS.md current status updated |
| Report | 1 file | Appended implementation section |

### verify_story (branch 3→4, 9 files changed)

| Operation | Description |
|-----------|-------------|
| Story rename | `-WIP.md` → `-DONE.md` (git mv) |
| Index update | Link updated to DONE filename |
| Change archive | Entire change directory moved to `openspec/changes/archive/2026-10-05-navigate-leg-segment/` |
| Spec sync | `openspec/specs/leg-navigation/spec.md` created (77 lines, living specification) |
| Report | Appended with all gate results: OpenSpec verify, TODO scan, security, build, unit tests, coverage, test file coverage, preview coverage, on-device, Definition of Done — all PASS |

---

## Architecture

### Evaluation Tiers

**Tier 1: Structural assertions (free, deterministic)**

Same technology as existing evals: shell scripts with `grep`, `test -f`, `git diff`. These check:
- File existence and naming (did the right files get created/renamed/moved?)
- Section presence (do required headings exist in the output?)
- Side effects (git mv performed, checkboxes checked, index updated)
- Content preservation (original story text preserved with downgraded headings)

**Tier 2: LLM-as-judge with per-criterion rubric (moderate cost)**

A separate LLM call evaluates the candidate output against the golden reference. The judge receives:
1. The command's requirements (from the command `.md` file)
2. The golden reference artifacts (from the venice repo branches)
3. The candidate artifacts (from the eval run)
4. A rubric defining criteria, types (boolean / 1-5 scale / checklist), and descriptions

The judge returns a JSON object with per-criterion scores and rationales:
```json
{
  "criteria": {
    "section_completeness": { "score": 12, "max": 12, "rationale": "All 12 sections present..." },
    "what_not_how": { "score": 4, "max": 5, "rationale": "Mostly requirements-level..." },
    "analytics_section_quality": { "score": 5, "max": 5, "rationale": "Follows naming conventions..." }
  }
}
```

**Tier 3: Functional verification (requires build environment)**

Only for `implement_change` and `verify_story`. Runs the actual build toolchain:
- `./gradlew check` (compile + detekt + lint)
- `./gradlew test` (unit tests)
- Coverage verification (kover)

### Timing Capture

| Metric | Source | Availability |
|--------|--------|-------------|
| Wall-clock duration | `date` before and after the command run | Always |
| Token usage | Harness output (if exposed) | Depends on harness |
| Command Metrics | Report HTML (start/end time, duration, interaction count) | Always (embedded by the command) |

### Configuration

| Parameter | Purpose | Default |
|-----------|---------|---------|
| `EVAL_TOOL` | Harness under test | `claude` |
| `EVAL_JUDGE_MODEL` | Model for T2 judge (should differ from model being evaluated) | Configurable |

### How This Serves Each Regression Axis

| Axis | What changes | What stays fixed | Key eval layer |
|------|-------------|-----------------|----------------|
| Command change | Command `.md` file | Model, harness, reference repo | All tiers — T1 catches broken guardrails, T2 catches quality drift |
| Model change | Model (Opus→Sonnet, version upgrade) | Command, harness, reference repo | T2 is critical — structure may be fine but quality may drop |
| Harness change | Claude Code → Cursor/OpenCode | Command, model, reference repo | All tiers — different harnesses call tools differently |

---

## Per-Command Eval Design

### 1. `open_story` (branch 0→1)

**Setup:** Extract `goldenreference/open_story/repo-snapshot.tar.gz` and initialise isolated git repo.
Input: unrefined story at `docs/userstories/5.1.2-navigate-leg-segment.md`.

**T1 Structural assertions:**
- Original story file no longer exists (renamed via git mv)
- WIP story file exists
- `## Original user story` section present in WIP file
- All 12 required sections present (Description, Fields, Endpoints/URI, Files to Modify,
  Unit Testing, Documentation, Security, Performance, GDPR, Analytics, Non-Functional,
  Definition of Done/Completion steps)
- Original content preserved with downgraded headings (## → ###)
- Index.md updated with WIP filename
- Report file exists
- Report contains Command Metrics section

**T2 LLM-as-judge rubric:**

| Criterion | Type | Description |
|-----------|------|-------------|
| `section_completeness` | checklist (12) | Each of the 12 required refinement sections is present AND substantive (not just a heading) |
| `what_not_how` | 1-5 | Stays at requirements/acceptance-criteria level; does not prescribe architecture, design patterns, or specific libraries |
| `acceptance_criteria_quality` | 1-5 | Criteria are testable, specific, and cover the scope of the story (compare to golden reference for completeness) |
| `analytics_section_quality` | 1-5 | Events follow naming conventions (snake_case, object_action), parameters are bounded, product question stated, privacy floor respected |
| `content_preservation` | boolean | Original story text preserved verbatim under `## Original user story` with headings downgraded one level |
| `overall_coherence` | 1-5 | The refined story reads as a coherent, self-consistent document suitable for the propose_change phase |

**Golden reference:** `goldenreference/open_story/output/`

---

### 2. `propose_change` (branch 1→2)

**Setup:** Extract `goldenreference/propose_change/repo-snapshot.tar.gz` and initialise isolated git repo.

**T1 Structural assertions:**
- Change directory exists under `openspec/changes/`
- proposal.md, design.md, tasks.md, .openspec.yaml exist
- At least one spec file exists under `specs/`
- tasks.md has checkbox format `- [ ]`
- tasks.md has section structure (numbered sections)
- BDD sections contain test-task + implementation-task pairs
- Report file updated (new section appended)

**T2 LLM-as-judge rubric:**

| Criterion | Type | Description |
|-----------|------|-------------|
| `proposal_completeness` | 1-5 | Proposal covers why, what changes, impact — compare to golden reference for scope |
| `design_quality` | 1-5 | Design documents context, goals/non-goals, decisions with rationale, risks |
| `bdd_task_structure` | 1-5 | Tasks follow BDD: test task (with GIVEN/WHEN/THEN) + implementation task pairs; prerequisites first, verification last |
| `task_granularity` | 1-5 | Tasks are atomic, implementable by a sub-agent in one pass, with clear completion criteria |
| `question_quality` | 1-5 | If questions were surfaced, they are relevant and avoid assumptions; if no questions, the story was unambiguous enough to proceed |
| `story_alignment` | 1-5 | The proposed change faithfully implements the refined user story without scope creep or omissions |

**Golden reference:** `goldenreference/propose_change/output/`

---

### 3. `implement_change` (branch 2→3)

**Setup:** Extract `goldenreference/implement_change/repo-snapshot.tar.gz` and initialise isolated git repo.
Requires Android SDK.

**T1 Structural assertions:**
- All tasks in tasks.md are `[x]` (no unchecked `[ ]` remain)
- Report file updated
- Expected source files exist (each implementation task should have produced a file change)
- Expected test files exist (each BDD test task should have produced a test file)
- Strings added to all locale directories

**T2 LLM-as-judge rubric:**

| Criterion | Type | Description |
|-----------|------|-------------|
| `task_completion` | checklist | Each task in tasks.md is checked AND the corresponding file changes exist |
| `bdd_discipline` | 1-5 | Evidence of test-first: test files contain tests matching the GIVEN/WHEN/THEN from task descriptions |
| `code_quality` | 1-5 | Code follows project conventions (MVI, Clean Architecture, naming, no `!!`, etc.) — compare to golden reference |
| `test_quality` | 1-5 | Tests are meaningful (not trivially passing), cover edge cases, use project patterns (MockK, runTest) |

**T3 Functional verification:**
- `./gradlew check` passes (compiles, detekt, lint)
- `./gradlew test` passes (unit tests)
- Coverage meets 95% threshold

**Golden reference:** `goldenreference/implement_change/output/`

---

### 4. `verify_story` (branch 3→4)

**Setup:** Extract `goldenreference/verify_story/repo-snapshot.tar.gz` and initialise isolated git repo.
Requires Android SDK.

**T1 Structural assertions:**
- Story file renamed to `-DONE.md`
- No `-WIP.md` file remains
- Index.md references the DONE file
- Change directory moved to archive (under `openspec/changes/archive/`)
- Spec file exists in `openspec/specs/`
- Report contains gate result sections
- Report contains "PASSED" outcome

**T2 LLM-as-judge rubric:**

| Criterion | Type | Description |
|-----------|------|-------------|
| `gate_coverage` | checklist | All expected gates evaluated and reported (OpenSpec verify, TODO scan, security, build, unit tests, coverage, test file coverage, preview coverage, on-device, Definition of Done) |
| `report_completeness` | 1-5 | Report contains all expected sections with substantive content (not placeholder text) |
| `lifecycle_correctness` | boolean | Story file correctly renamed, index updated, change archived, spec synced |
| `outcome_justified` | 1-5 | The PASS/FAIL outcome is justified by the gate results (not blindly passing) |

---

## Golden Reference Storage

### Design

The golden reference lives in `docs/sdlc/evals/goldenreference/`, one subdirectory per command. The
existing `docs/sdlc/evals/sourcematerial/` directory is removed and its contents migrated here.

Each command subdirectory contains:

- **`repo-snapshot.tar.gz`** — a `git archive` tarball of the full repo at the "before" branch (~4 MB each).
  The command needs a real working directory with project structure, SDLC config, AGENTS.md, all source
  files — individual files can't reproduce this.
- **`output/`** — the individual files produced by the command, preserving their repo-relative paths.
  The T2 judge and T1 assertions read these directly without unpacking an archive.
- **`input.md`** — the primary input artifact extracted separately for convenience, so the judge prompt
  can reference "what the command was given" without unpacking the tarball.

**The tarballs contain no `.git/` directory, no remotes, and no connection to the source repo.**
`git archive` produces a plain file tree. The scenario script creates a fresh, isolated git repo at
runtime (see Fixture Initialisation below).

### Source

All artifacts are extracted once from the venice repo at `/home/guido/dev/personal/venice` using the
5 workshop branches. After extraction, the eval system is fully self-contained — no scenario script
accesses the venice repo.

### Layout

```
docs/sdlc/evals/goldenreference/
├── README.md
│
├── open_story/
│   ├── repo-snapshot.tar.gz                       # git archive of workshop/00_main
│   ├── input.md                           # unrefined story (for judge prompt)
│   └── output/
│       ├── docs/userstories/5.1.2-navigate-leg-segment-WIP.md
│       ├── docs/reports/5.1.2-navigate-leg-segment.html
│       └── docs/userstories/index.md
│
├── propose_change/
│   ├── repo-snapshot.tar.gz                       # git archive of workshop/01_sdlc_open_story
│   ├── input.md                           # refined story (for judge prompt)
│   └── output/
│       ├── openspec/changes/navigate-leg-segment/proposal.md
│       ├── openspec/changes/navigate-leg-segment/design.md
│       ├── openspec/changes/navigate-leg-segment/tasks.md
│       ├── openspec/changes/navigate-leg-segment/specs/leg-navigation/spec.md
│       ├── openspec/changes/navigate-leg-segment/.openspec.yaml
│       └── docs/reports/5.1.2-navigate-leg-segment.html
│
├── implement_change/
│   ├── repo-snapshot.tar.gz                       # git archive of workshop/02_sdlc_propose_change
│   ├── input.md                           # tasks.md (for judge prompt)
│   └── output/
│       ├── app/src/main/java/.../intent/TripDetailUiIntent.kt
│       ├── app/src/main/java/.../effect/TripDetailUiEffect.kt
│       ├── app/src/main/java/.../state/TripDetailUiState.kt
│       ├── app/src/main/java/.../viewmodel/TripDetailViewModel.kt
│       ├── app/src/main/java/.../screens/tripdetail/LegSummary.kt
│       ├── app/src/main/java/.../screens/tripdetail/TripDetailScreen.kt
│       ├── app/src/main/java/.../MainScreen.kt
│       ├── app/src/main/java/.../util/NavigationUriBuilder.kt
│       ├── app/src/test/java/.../NavigationUriBuilderTest.kt
│       ├── app/src/test/java/.../TripDetailViewModelTest.kt
│       ├── app/src/androidTest/java/.../MainScreenTest.kt
│       ├── app/src/androidTest/java/.../LegSummaryTest.kt
│       ├── app/src/androidTest/java/.../TripDetailScreenTest.kt
│       ├── app/src/main/res/values/strings.xml
│       ├── app/src/main/res/values-it/strings.xml
│       ├── app/src/main/res/values-es-rES/strings.xml
│       ├── openspec/changes/navigate-leg-segment/tasks.md
│       └── docs/reports/5.1.2-navigate-leg-segment.html
│
└── verify_story/
    ├── repo-snapshot.tar.gz                       # git archive of workshop/03_sdlc_implement_changes
    ├── input.md                           # story + tasks (for judge prompt)
    └── output/
        ├── docs/userstories/5.1.2-navigate-leg-segment-DONE.md
        ├── docs/userstories/index.md
        ├── docs/reports/5.1.2-navigate-leg-segment.html
        ├── openspec/specs/leg-navigation/spec.md
        ├── openspec/changes/archive/2026-10-05-navigate-leg-segment/.openspec.yaml
        ├── openspec/changes/archive/2026-10-05-navigate-leg-segment/design.md
        ├── openspec/changes/archive/2026-10-05-navigate-leg-segment/proposal.md
        ├── openspec/changes/archive/2026-10-05-navigate-leg-segment/specs/leg-navigation/spec.md
        └── openspec/changes/archive/2026-10-05-navigate-leg-segment/tasks.md
```

### Fixture initialisation

The tarballs contain no `.git/` directory, so the scenario script must create a fresh, isolated git
repo before running the command:

```bash
mkdir "$WORK_DIR"
tar xzf goldenreference/open_story/repo-snapshot.tar.gz -C "$WORK_DIR"
cd "$WORK_DIR"
git init
git add -A
git commit -m "golden reference baseline"
```

This gives the command a real git repo with one commit, a `main` branch, and **zero remotes**. There
is no way for any script to push, pull, or fetch from the source venice repo — the remote does not
exist. The `cleanup_fixture()` helper removes the entire `$WORK_DIR` after the scenario completes.

### Regeneration

A one-time extraction script (`extract_golden_reference.sh`) creates the tarballs and output files
from the venice repo. It is run manually when the golden reference needs updating (e.g., after a
new pipeline run produces better reference artifacts). The script is idempotent and documents which
venice branch maps to which command.

### Size estimate

4 tarballs at ~4 MB each = ~16 MB total. The output files add negligible size. This is large for a
git repo but acceptable — these are test fixtures that change rarely.

---

## Implementation Plan

### Phase 1: Infrastructure

1. **Create `goldenreference/` directory** and extract artifacts from the venice repo:
   - Run the extraction script to create `repo-snapshot.tar.gz` and `output/` for each command
   - Create `input.md` files (primary input artifact for judge prompts)
   - Remove the old `sourcematerial/` directory
   - Write `goldenreference/README.md` documenting source, structure, and regeneration

2. **Add LLM-as-judge helper** to `docs/sdlc/evals/lib/eval_helpers.sh`:
   - `run_judge()` function: takes a rubric file, golden reference file(s), candidate file(s),
     and invokes `$EVAL_JUDGE_TOOL` (configurable) with a structured prompt
   - Returns per-criterion scores as JSON
   - `assert_judge_score()`: asserts a criterion meets a minimum score threshold

3. **Add timing capture** to `run_eval_with_args()`:
   - Record wall-clock start/end with `date +%s`
   - Parse token usage from harness output if available
   - Include timing data in the JSON result file

4. **Add fixture helpers** to `docs/sdlc/evals/lib/eval_helpers.sh`:
   - `create_fixture()`: extracts `repo-snapshot.tar.gz` to a temp directory, runs `git init` + `git add -A`
     + `git commit` to create an isolated local-only repo with no remotes
   - `cleanup_fixture()`: removes the temp directory

### Phase 2: Rubric files

Create rubric definition files in `docs/sdlc/evals/rubrics/`:
- `open_story_rubric.md`
- `propose_change_rubric.md`
- `implement_change_rubric.md`
- `verify_story_rubric.md`

Each rubric file contains:
- The criteria table (name, type, description)
- The judge prompt template (instructions for the LLM judge)
- Pointers to the golden reference files

### Phase 3: Scenarios

Create one happy-path scenario per command:
- `open_story_golden_quality.sh`
- `propose_change_golden_quality.sh`
- `implement_change_golden_quality.sh` (requires Android SDK)
- `verify_story_golden_quality.sh` (requires Android SDK)

Each scenario:
1. Creates a fixture by extracting `repo-snapshot.tar.gz` and initialising an isolated git repo (no remotes)
2. Runs the command via the configured harness
3. Runs T1 structural assertions (deterministic)
4. Runs T2 LLM-as-judge evaluation against `output/` reference files (rubric-based)
5. Records timing and scores to the JSON result file
6. Cleans up the fixture directory

### Phase 4: Comparison tooling

Extend `compare_results.sh` to handle:
- Score-based comparison (not just binary pass/fail)
- Per-criterion score diffs between runs
- Timing comparison (wall-clock, tokens)

---

## Starting Point

**`open_story_golden_quality`** — cheapest command (single Opus call, no build environment),
reference material already exists, and it covers uncovered CRITICALs #1 and #2. This scenario
becomes the template for the other three.

---

## Verification

1. Run `open_story_golden_quality`: should pass all T1 assertions and produce T2 scores
2. Intentionally degrade the command (remove a refinement requirement) and verify T2 scores drop
3. Run with a different model (e.g. Sonnet instead of Opus) and compare scores
4. Run with `--tool opencode` and compare scores
5. Verify timing data appears in the JSON results
