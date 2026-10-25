# Performance Analysis: Quality Scoring, Timing, and Cross-Run Comparison

Companion to `sdlc-eval-analysis.md` (case coverage). That document catalogues discrete pass/fail
eval cases for each SDLC command. This document details the evaluation dimensions that fall outside
that case inventory: graduated quality scoring, timing and cost capture, and cross-run comparison.

These dimensions are orthogonal to the pass/fail cases in the analysis — they don't fill rows in that
table because the table has no rows for them. They answer different questions:

| Dimension | Question it answers |
|-----------|-------------------|
| Case coverage (analysis) | "Did the command do the right things?" |
| Quality scoring (this doc) | "How well did it do them?" |
| Timing & cost capture (this doc) | "How long did it take and what did it cost?" |
| Cross-run comparison (this doc) | "Did any of the above regress between runs?" |

### Evaluation layers

The eval system uses independent layers, ordered by cost:

| Layer | What | Cost | Catches |
|-------|------|------|---------|
| **L1: Guardrail** | Grep-based static checks on command files — no execution needed | Free | Broken guardrails, missing safeguards |
| **L2: Structural** | Deterministic assertions — file existence, section presence, side effects, content preservation (grep, `test -f`, `git diff`) | Free | Broken structure, missing artifacts, wrong side effects |
| **L3: Judge** | Per-criterion rubric scoring — an LLM judge compares candidate output against a golden reference on specific quality dimensions | Moderate (1 LLM call per command) | Semantic regressions — section exists but content is garbage, quality drift |
| **L4: Functional** | Build and test verification — `./gradlew check`, `./gradlew test`, coverage threshold | Requires build environment | Compilation failures, test failures, coverage drops |
| **L5: Behavioural** | Edge-case, gate-failure, and failure-handling scenarios | Moderate | Blocking-gate failures, error recovery, edge-case handling |

L2 is what the existing structural assertions already do. L3 and L4 are additions.
L4 applies only to `implement_change` and `verify_story` (the commands that produce code).

### Regression axes

The eval system must detect regressions across three independent axes, each changing one variable
while the others stay fixed:

| Axis | What changes | What stays fixed |
|------|-------------|-----------------|
| **Command change** | The command `.md` file (prompt instructions) | Model, harness, reference repo |
| **Model change** | The LLM model (e.g. Opus 4 → Opus 5) | Command, harness, reference repo |
| **Harness change** | The tool-calling harness (Claude Code → Cursor/OpenCode) | Command, model, reference repo |

---

## 1. Quality Scoring

### Problem

The eval analysis tracks output quality as binary assertions (L2 structural): a section exists or it
doesn't, a structure is present or it isn't. This catches breakage but not degradation. A refinement
that contains all 12 required sections passes the binary check whether the sections are insightful or
vacuous.

L3 (judge) scoring addresses this with per-criterion rubrics that produce a 1–5 score (or
boolean/checklist) with a rationale. This section catalogues every quality criterion, maps it to what
it measures, and identifies where the analysis has no equivalent.

### Criterion inventory

#### `open_story`

| Criterion | Type | What it measures | Analysis equivalent |
|-----------|------|------------------|-------------------|
| `section_completeness` | checklist (12) | Each of 12 sections present AND substantive | Partial — L2 checks presence only |
| `what_not_how` | 1–5 | Requirements-level language; no architecture/patterns/libraries prescribed | Partial — L2 is binary |
| `acceptance_criteria_quality` | 1–5 | Criteria are testable, specific, and cover the story scope | None |
| `analytics_section_quality` | 1–5 | Events follow naming conventions (snake_case, object_action), parameters bounded, product question stated, privacy floor respected | None |
| `content_preservation` | boolean | Original story text preserved verbatim under `## Original user story` with headings downgraded | Partial — L2 checks structure, not verbatim content |
| `overall_coherence` | 1–5 | Refined story reads as a coherent, self-consistent document suitable for propose_change | None |

**Gap analysis:** 3 criteria have no analysis equivalent at all (`acceptance_criteria_quality`,
`analytics_section_quality`, `overall_coherence`). The remaining 3 upgrade L2 binary checks to graduated
or deeper L3 assertions. The analytics criterion is particularly valuable because the analytics section
is the most format-sensitive output — naming conventions, parameter bounding, and privacy rules are
all checkable against `guidelines-analytics.md` but invisible to a structural grep.

#### `propose_change`

| Criterion | Type | What it measures | Analysis equivalent |
|-----------|------|------------------|-------------------|
| `proposal_completeness` | 1–5 | Proposal covers why, what changes, impact — compared to golden reference scope | Partial — analysis #4 row 1 checks file existence |
| `design_quality` | 1–5 | Design documents context, goals/non-goals, decisions with rationale, risks | None |
| `bdd_task_structure` | 1–5 | Tasks follow BDD: test task (GIVEN/WHEN/THEN) + implementation task pairs; prerequisites first, verification last | Partial — analysis #4 rows 2–5 check structure binarily |
| `task_granularity` | 1–5 | Tasks are atomic, implementable by a sub-agent in one pass, with clear completion criteria | None |
| `question_quality` | 1–5 | If questions surfaced, they are relevant and avoid assumptions; if none, story was unambiguous | None |
| `story_alignment` | 1–5 | Proposed change faithfully implements the refined story without scope creep or omissions | None |

**Gap analysis:** 3 criteria have no equivalent (`design_quality`, `task_granularity`,
`story_alignment`). `question_quality` is related to the existing `propose_change_surfaces_questions`
eval but measures quality rather than presence. `task_granularity` is high-value because a task that
is too coarse for a sub-agent to complete in one pass is the #1 cause of `implement_change` failures
— it's a propose_change quality problem that surfaces as an implement_change execution problem.

#### `implement_change`

| Criterion | Type | What it measures | Analysis equivalent |
|-----------|------|------------------|-------------------|
| `task_completion` | checklist | Each task checked AND corresponding file changes exist | Partial — analysis #1d row 1 and #1e check checkboxes only |
| `bdd_discipline` | 1–5 | Evidence of test-first: test files contain tests matching GIVEN/WHEN/THEN from task descriptions | Partial — analysis #1d row 2 is binary (RED/GREEN cycle observed or not) |
| `code_quality` | 1–5 | Code follows project conventions (MVI, Clean Architecture, naming, no `!!`) — compared to golden reference | None |
| `test_quality` | 1–5 | Tests are meaningful (not trivially passing), cover edge cases, use project patterns (MockK, runTest) | None |

**Gap analysis:** `code_quality` and `test_quality` have no equivalent in the analysis. These are
the highest-consequence quality dimensions for `implement_change` — a command that produces compiling,
test-passing code can still produce code that violates every project convention. L4 (functional
verification) catches correctness; L3 (judge) catches quality. Neither `code_quality` nor
`test_quality` is detectable by grep or build tooling.

#### `verify_story`

| Criterion | Type | What it measures | Analysis equivalent |
|-----------|------|------------------|-------------------|
| `gate_coverage` | checklist | All expected gates evaluated and reported (OpenSpec verify, TODO scan, security, build, unit tests, coverage, test file coverage, preview coverage, on-device, Definition of Done) | Partial — analysis has individual gate rows but no "all gates present" check |
| `report_completeness` | 1–5 | Report contains all expected sections with substantive content (not placeholder text) | Partial — analysis #16 row 2 checks data point count |
| `lifecycle_correctness` | boolean | Story renamed, index updated, change archived, spec synced | Covered — analysis #12, #13, #14 cover these as individual L2 assertions |
| `outcome_justified` | 1–5 | PASS/FAIL outcome justified by the gate results, not blindly passing | None |

**Gap analysis:** `outcome_justified` has no analysis equivalent and is arguably the most important
quality criterion for verify_story. A verification command that rubber-stamps PASS regardless of gate
outcomes defeats the entire pipeline. The analysis checks that individual gates block on failure
(L5 behavioural), but never checks that the final outcome is logically derived from the gate results.

### Scoring dimensions not tied to a specific command

The per-criterion rubrics above are command-specific, but several quality dimensions cut across all
four commands:

| Dimension | Description | Where it applies |
|-----------|-------------|-----------------|
| **Golden-reference fidelity** | How closely does the candidate match the known-good output in structure and substance? | All L3 criteria use comparison against golden reference |
| **Rubric calibration** | Does the judge model score consistently across runs on the same input? | All L3 scores — variance in judge scoring is noise, not signal |
| **Score-to-pass threshold** | At what score does a criterion represent acceptable quality? | All L3 criteria need a minimum threshold to be actionable |

These are meta-concerns about the scoring system itself, not about the commands. They matter for
cross-run comparison (section 3) because score drift could be judge noise rather than real regression.

### Summary: quality scoring gap

| Command | Total L3 criteria | Criteria with no analysis equivalent | Criteria upgrading binary to graded |
|---------|-------------------|--------------------------------------|-------------------------------------|
| `open_story` | 6 | 3 | 3 |
| `propose_change` | 6 | 3 | 3 |
| `implement_change` | 4 | 2 | 2 |
| `verify_story` | 4 | 1 | 2 |
| **Total** | **20** | **9** | **10** |

9 criteria measure things the analysis has no row for. 10 criteria upgrade existing binary checks to
graduated quality scores. 1 criterion (`lifecycle_correctness`) is fully covered by existing analysis
cases. The total of 20 quality criteria represents an evaluation surface that is invisible to the
current case inventory.

---

## 2. Timing and Cost Capture

### Problem

The eval analysis and the existing eval infrastructure measure correctness only. There is no record
of how long a command took, how many tokens it consumed, or how many LLM interactions occurred. This
means:

- A command change that doubles execution time is invisible to the eval system
- A model change that triples token usage (and cost) is undetectable
- A harness change that adds unnecessary round-trips has no measurement

These are not hypothetical — model upgrades routinely change output length and interaction patterns,
and command prompt edits can cause the LLM to over-elaborate or under-specify, changing both quality
and cost.

### What to capture

Three timing sources are available. This section expands each into concrete metrics.

#### 2.1 Wall-clock duration

| Metric | Source | Granularity | Notes |
|--------|--------|-------------|-------|
| `total_wall_seconds` | `date +%s` before and after | Per command run | Includes human interaction time (currently only `propose_change` has interactive questions) |
| `human_interaction_seconds` | Not currently separable | Per command run | Would require harness support to isolate "time waiting for user input" from "time executing" |

**Limitation:** Wall-clock time conflates LLM execution, tool execution, and human response time.
For `propose_change` (which surfaces questions), the human component can dominate. For the other three
commands, human time is negligible (no interactive questions), making wall-clock a reasonable proxy
for execution time.

**Future separation:** If harness-level timing becomes available (e.g., Claude Code exposing
per-tool-call timestamps), the human component could be isolated by summing the gaps between
"tool result returned" and "next tool call made" when those gaps exceed a threshold (e.g., >5s
suggests human interaction rather than LLM processing).

#### 2.2 Token usage

| Metric | Source | Availability |
|--------|--------|-------------|
| `input_tokens` | Harness output | Claude Code: not currently exposed in CLI output |
| `output_tokens` | Harness output | Claude Code: not currently exposed in CLI output |
| `total_tokens` | Computed | Sum of input + output |
| `cache_read_tokens` | Harness output | Claude Code: not currently exposed |
| `estimated_cost_usd` | Computed from tokens × model pricing | Requires knowing which model was used |

**Availability gap:** Claude Code does not currently expose token usage in its CLI output. This makes
token capture harness-dependent:

| Harness | Token data available? | How |
|---------|----------------------|-----|
| Claude Code (CLI) | No | Not exposed; would need API-level logging or a wrapper |
| Claude Code (API via SDK) | Yes | Response object includes `usage.input_tokens`, `usage.output_tokens` |
| OpenCode | Unknown | Depends on OpenCode's output format |
| Cursor | Unknown | Depends on Cursor's output format |

**Practical approach:** Start with wall-clock only. Add token capture when either (a) the harness
exposes it, or (b) we wrap the harness call in an API-level proxy that intercepts usage data. Token
capture is valuable for the model-change axis (comparing Opus vs. Sonnet cost) but not essential for
the command-change axis (same model, same rough token count).

#### 2.3 Command Metrics (self-reported)

Each SDLC command's report HTML already embeds a Command Metrics section with data captured by the
LLM during execution:

| Metric | Description | Reliability |
|--------|-------------|-------------|
| `start_time` | Timestamp when the command began | Reliable — captured at start |
| `end_time` | Timestamp when the command completed | Reliable — captured at end |
| `duration` | Computed from start/end | Reliable if start/end are correct |
| `interaction_count` | Number of user interactions during the command | Reliable — the LLM counts its own questions |

**Extraction:** These are embedded in the report HTML, so extraction requires parsing the HTML report
after the command completes. The eval scenario can:
1. Locate the report file (path is deterministic per command)
2. Extract the Command Metrics section (grep/sed or a simple HTML parser)
3. Parse the values into the JSON result file

**Cross-validation:** Command Metrics duration can be cross-validated against wall-clock duration.
A large discrepancy would indicate either (a) the LLM misreported its times, or (b) significant
overhead outside the command's self-measurement window.

### Metrics per command

Not all metrics are equally relevant to every command:

| Metric | open_story | propose_change | implement_change | verify_story |
|--------|-----------|----------------|------------------|-------------|
| Wall-clock duration | High value | High value (includes human time) | High value (longest command) | High value |
| Token usage | Medium | Medium | High (most sub-agent calls) | High (many gates) |
| Interaction count | Low (0 expected) | High (questions are an artifact) | Low (0 expected) | Low (0 expected) |
| Command Metrics | Medium | Medium | High (tracks section-by-section progress) | High (tracks gate-by-gate progress) |

**`implement_change` is the cost outlier.** It orchestrates multiple sub-agents (one per task section),
each making multiple tool calls. A model change that increases verbosity or a command change that adds
task sections has a multiplicative effect on cost. This command benefits most from token tracking.

### Result schema

Each eval run should produce a timing block in its JSON result:

```json
{
  "timing": {
    "wall_clock": {
      "start_epoch": 1729500000,
      "end_epoch": 1729500300,
      "duration_seconds": 300
    },
    "tokens": {
      "input_tokens": null,
      "output_tokens": null,
      "total_tokens": null,
      "estimated_cost_usd": null,
      "source": "not_available"
    },
    "command_metrics": {
      "start_time": "2026-10-21T10:00:00Z",
      "end_time": "2026-10-21T10:05:00Z",
      "duration_seconds": 300,
      "interaction_count": 0
    }
  }
}
```

Fields are nullable — capture what's available, leave the rest as `null` with a `source` field
explaining why (e.g., `"not_available"`, `"harness_does_not_expose"`, `"parse_error"`).

---

## 3. Cross-Run Comparison

### Problem

A single eval run produces a snapshot: L2 pass/fail results, L3 quality scores, and timing data. This
answers "is the current output acceptable?" but not "did it get worse?" Regression detection requires
comparing two snapshots — a baseline and a candidate — and surfacing meaningful differences.

The three regression axes (defined above) each compare runs where one variable changed:

| Axis | Baseline | Candidate | What changed |
|------|----------|-----------|-------------|
| Command change | Run with original command `.md` | Run with edited command `.md` | The prompt instructions |
| Model change | Run with Model A (e.g. Opus 4) | Run with Model B (e.g. Opus 5) | The LLM model |
| Harness change | Run with Claude Code | Run with OpenCode/Cursor | The tool-calling harness |

### What to compare

#### 3.1 L2 structural comparison (binary)

L2 assertions are pass/fail. Comparison is straightforward:

| Scenario | Meaning |
|----------|---------|
| Both pass | No structural regression |
| Baseline passes, candidate fails | **Regression** — something broke |
| Baseline fails, candidate passes | **Improvement** — something was fixed |
| Both fail | Persistent issue — unchanged |

This is the existing `compare_results.sh` model. No change needed for L2.

#### 3.2 L3 quality score comparison (graduated)

L3 scores are 1–5 (or boolean/checklist). Comparison is more nuanced:

| Metric | What it shows |
|--------|--------------|
| Per-criterion score delta | `candidate.score - baseline.score` — positive is improvement, negative is regression |
| Per-criterion rationale diff | Side-by-side rationale text — explains WHY the score changed |
| Aggregate score delta | Sum or mean of all criterion deltas — overall quality direction |
| Regression flag | Any criterion where delta ≤ -1 (one full point drop) |

**Threshold for concern:** A 1-point drop on a 5-point scale is a meaningful regression (20% of the
range). A 0.5-point drop could be judge noise. With one run per configuration (the practical starting
point given rate-limit constraints), we cannot distinguish small regressions from noise without
multiple runs. Practical approach:

- **Delta ≥ -1:** Flag as potential regression, include rationale for review
- **Delta = -2 or worse:** Flag as likely regression
- **Delta ≤ -0.5:** Note but don't flag — could be noise

For boolean criteria, any `true → false` is a regression.

For checklist criteria (e.g., `section_completeness` 12/12), any decrease in count is a regression,
and the comparison should identify which specific items were lost.

#### 3.3 Timing comparison

| Metric | Comparison | Concern threshold |
|--------|-----------|-------------------|
| Wall-clock duration | Ratio: `candidate / baseline` | >1.5× is a flag (50% slower) |
| Token usage | Ratio: `candidate / baseline` | >1.3× is a flag (30% more tokens = 30% more cost) |
| Interaction count | Delta: `candidate - baseline` | Any increase is notable (more questions = more human time) |

**Why ratios, not deltas:** A 60-second increase means different things for a 2-minute command vs.
a 20-minute command. Ratios normalise across commands.

**Wall-clock caveat:** For `propose_change`, wall-clock includes human response time, which varies
between runs regardless of any code/model/harness change. The comparison should note this and prefer
Command Metrics duration (which also includes human time but is at least self-consistently measured
by the same LLM).

#### 3.4 Command-specific comparison points

Beyond the generic comparison above, each command has artifacts where specific diffs are informative:

| Command | Artifact comparison | What it catches |
|---------|-------------------|-----------------|
| `open_story` | Diff of refined story section headings | Sections added/removed/reordered |
| `open_story` | Diff of analytics section event names | Naming convention drift |
| `propose_change` | Diff of tasks.md section structure | Task count changes, BDD pair changes |
| `propose_change` | Diff of tasks.md checkbox count | Scope creep/reduction |
| `implement_change` | Diff of created file list | Different files produced for same tasks |
| `implement_change` | Diff of test file list | Test coverage difference |
| `verify_story` | Diff of gate result list | Gates added/removed/reordered |
| `verify_story` | Diff of final outcome | PASS→FAIL or FAIL→PASS |

These are structural diffs (diffable with standard tools), not quality judgements. They complement the
L3 quality comparison by showing WHAT changed, while L3 scores show WHETHER the change was better or
worse.

### Comparison report schema

```json
{
  "comparison": {
    "axis": "command_change",
    "baseline": {
      "run_id": "2026-10-20_open_story_opus4_claude",
      "timestamp": "2026-10-20T14:00:00Z"
    },
    "candidate": {
      "run_id": "2026-10-21_open_story_opus4_claude",
      "timestamp": "2026-10-21T10:00:00Z"
    },
    "l2_structural": {
      "regressions": [],
      "improvements": [],
      "unchanged_pass": ["story_file_renamed", "index_updated", "..."],
      "unchanged_fail": []
    },
    "l3_quality": {
      "criteria": {
        "section_completeness": {
          "baseline": 12,
          "candidate": 11,
          "delta": -1,
          "flag": "regression",
          "baseline_rationale": "All 12 sections present and substantive...",
          "candidate_rationale": "11 sections present; GDPR section is a heading with no content..."
        },
        "what_not_how": {
          "baseline": 4,
          "candidate": 4,
          "delta": 0,
          "flag": null
        }
      },
      "aggregate_delta": -0.17,
      "regression_count": 1,
      "improvement_count": 0
    },
    "timing": {
      "wall_clock": {
        "baseline_seconds": 120,
        "candidate_seconds": 180,
        "ratio": 1.5,
        "flag": "slower"
      },
      "tokens": {
        "baseline_total": null,
        "candidate_total": null,
        "ratio": null,
        "flag": null
      },
      "interaction_count": {
        "baseline": 0,
        "candidate": 0,
        "delta": 0,
        "flag": null
      }
    }
  }
}
```

### Comparison workflow

```
Run A (baseline)          Run B (candidate)
    │                          │
    ▼                          ▼
┌──────────┐             ┌──────────┐
│ L2 results│             │ L2 results│
│ L3 scores │             │ L3 scores │
│ Timing    │             │ Timing    │
└────┬──────┘             └────┬──────┘
     │                         │
     └──────────┬──────────────┘
                ▼
        ┌──────────────┐
        │ compare_results│
        │   .sh          │
        └───────┬────────┘
                ▼
        ┌──────────────┐
        │ Comparison    │
        │ report (JSON) │
        └───────┬────────┘
                ▼
        ┌──────────────┐
        │ Flags:        │
        │ - Regressions │
        │ - Improvements│
        │ - Cost changes│
        └──────────────┘
```

### Comparison edge cases

| Edge case | How to handle |
|-----------|--------------|
| Baseline has no L3 scores (ran before L3 was added) | Compare L2 only; note L3 comparison not possible |
| Different judge model between runs | Flag in report — scores may not be comparable |
| Different command set between runs (new criteria added) | Compare only shared criteria; list new/removed criteria separately |
| Token data available in one run but not the other | Report available data; mark token comparison as incomplete |
| Wall-clock times differ wildly due to human interaction | If `interaction_count` differs, note that wall-clock comparison is unreliable |

### Labelling runs

Each run needs enough metadata to identify what was being tested:

```json
{
  "run_id": "2026-10-21_open_story_opus4_claude",
  "command": "open_story",
  "model": "claude-opus-4-6",
  "harness": "claude",
  "command_md_hash": "a3f9c821...",
  "reference_repo_commit": "e7b2d4f1...",
  "timestamp": "2026-10-21T10:00:00Z"
}
```

The `command_md_hash` is a content hash of the command `.md` file — it identifies the command version
without requiring a git commit. The `reference_repo_commit` pins the golden reference. Together with
model and harness, these four fields fully identify the configuration under test.

---

## Relationship to the Analysis Case Inventory

This document and `sdlc-eval-analysis.md` are complementary but non-overlapping:

| Dimension | Analysis (case inventory) | This document |
|-----------|--------------------------|---------------|
| **Unit of measurement** | Discrete pass/fail cases | Graduated scores, durations, deltas |
| **Question** | "Does it work?" | "How well? How fast? Did it regress?" |
| **Coverage metric** | Cases covered / cases possible | Criteria defined / criteria scored |
| **Regression detection** | A previously-passing case now fails | A quality score drops, execution slows, cost increases |
| **Failure signal** | Binary: broken or not | Graduated: degraded, unchanged, improved |

Implementing both gives two independent regression signals:
1. **Case failures** catch breakage — something that worked now doesn't
2. **Score drops** catch degradation — everything works but the output is worse

A command change could pass all L2 structural assertions (no case regressions) while dropping L3
quality scores across the board. Conversely, a model change could improve quality scores while
breaking a structural assertion. Neither signal subsumes the other.

### Coverage accounting

To avoid confusion, quality scoring, timing, and comparison metrics should NOT be added as rows
to the analysis case table. They are different in kind:

- A case is a **scenario + assertion**: "run the command in this state, assert this outcome"
- A quality criterion is a **rubric + score**: "judge this output on this dimension, score 1–5"
- A timing metric is a **measurement**: "how long, how many tokens"
- A comparison is a **delta**: "how did this change from last time"

Adding them to the case table would conflate "does the command work?" with "how well does it work?"
and make the coverage percentage meaningless. They belong in their own tracking — this document.
