# SDLC Command Evals

Testing infrastructure for the SDLC command files that drive the AI coding agent lifecycle.

We are testing the **commands** (the instruction files), not the LLM itself. The commands are the program; the AI coding agent (Claude Code, OpenCode, etc.) is the runtime. An eval runs a command through the runtime against a controlled scenario and checks that the correct behaviour happens — actual tool calls, file side effects, and git operations, not hypothetical answers.

---

## Eval Layers

Every eval belongs to one or more **independent layers**. Layers can run in any combination — they are not a pipeline.

| Layer | Name | What it does | Cost | Trigger |
|-------|------|-------------|------|---------|
| **L1** | Guardrail | `grep`-based assertions that required patterns exist in command MD files | Free | Always — before every commit |
| **L2** | Structural | Deterministic assertions on command output: file existence, section presence, side effects, content preservation | Free (but uses rate-limit budget to run the command) | When modifying a command |
| **L3** | Judge | LLM-as-judge scoring against golden reference on per-criterion rubrics | Moderate (1 API call per command) | When `ANTHROPIC_API_KEY` + `EVAL_JUDGE_MODEL` are set |
| **L4** | Functional | Build and test verification (`./gradlew check`, coverage) | High (requires Android SDK) | Opt-in, for implementation commands |
| **L5** | Behavioural | Scenario testing for abnormal conditions: edge cases, gate failures, precondition violations | Moderate (uses rate-limit budget) | When modifying guardrails or error handling |

---

## SDLC Commands

These are the commands being evaluated. Each is a markdown instruction file that an AI coding agent executes.

| Command | Purpose | L1 | L2 | L3 | L4 | L5 |
|---------|---------|:--:|:--:|:--:|:--:|:--:|
| `sdlc_open_story` | Refines a user story: renames to WIP, adds sections, preserves original content | ✓ | ✓ | ✓ | | ✓ |
| `sdlc_propose_change` | Creates an OpenSpec change proposal from a WIP story | ✓ | ✓ | ✓ | | ✓ |
| `sdlc_implement_change` | Implements code from an OpenSpec proposal: source, tests, strings | ✓ | ✓ | ✓ | | |
| `sdlc_verify_story` | Runs verification gates, archives change, renames story to DONE | ✓ | ✓ | ✓ | | ✓ |
| `sdlc_doctor` | Health-check: verifies tooling, config, and command files are present | ✓ | ✓ | | | |
| `sdlc_project_doctor` | Health-check: verifies project-level config (detekt, kover, fastlane) | ✓ | ✓ | | | |
| `sdlc_exp_four_in_one` | Experimental: runs the full open→propose→implement→verify pipeline | ✓ | | | | ✓ |
| `sdlc_exp_vibe_a_story` | Experimental: lightweight story-to-code pipeline | ✓ | | | | ✓ |

---

## Scenario Quick Reference

Every scenario is a self-contained script that sets up a fixture, runs a command, and asserts on the result.

| Command | Scenario | L2 | L3 | L5 | What it tests |
|---------|----------|:--:|:--:|:--:|---------------|
| `open_story` | `open_story_golden_quality` | ✓ | ✓ | | Story refinement quality: 12 sections, content preservation |
| | `open_story_dirty_state` | | | ✓ | Warns about uncommitted changes before proceeding |
| | `open_story_not_on_main` | | | ✓ | Detects non-main branch, asks about proceeding |
| `propose_change` | `propose_change_golden_quality` | ✓ | ✓ | | Proposal, design, BDD tasks, spec quality |
| | `propose_change_surfaces_questions` | | | ✓ | Surfaces questions on ambiguous requirements instead of assuming |
| `implement_change` | `implement_change_golden_quality` | ✓ | ✓ | | Task completion, code quality, test quality, locale strings |
| `verify_story` | `verify_story_golden_quality` | ✓ | ✓ | | Gate coverage, lifecycle operations, report quality |
| | `verify_story_precondition_fail` | | | ✓ | Stops before gates when story is not in WIP state |
| | `verify_story_blocks_on_gate_failure` | | | ✓ | Blocks at first gate failure, doesn't reach downstream gates |
| `doctor` | `doctor_all_pass` | ✓ | | | All checks pass when everything is correctly configured |
| | `doctor_missing_openspec_config` | ✓ | | | Detects missing `openspec/config.yaml` |
| | `doctor_missing_opsx_commands` | ✓ | | | Detects 2 missing command files |
| | `doctor_security_disabled` | ✓ | | | Detects security plugin set to `false` |
| | `doctor_everything_broken` | ✓ | | | All checks fail when everything is missing |
| `project_doctor` | `project_doctor_all_pass` | ✓ | | | All project config checks pass |
| | `project_doctor_missing_detekt` | ✓ | | | Detects missing detekt config |
| | `project_doctor_low_coverage` | ✓ | | | Detects kover minBound below threshold |
| `exp_four_in_one` | `exp_four_in_one_dirty_state` | | | ✓ | Detects dirty working tree |
| `exp_vibe_a_story` | `exp_vibe_a_story_dirty_state` | | | ✓ | Detects dirty working tree |

---

## Scripts

### `check_guardrails.sh` — L1 guardrail assertions (free, instant)

Parses the command markdown files and asserts that required guardrail phrases, orchestration patterns, and cross-command consistency rules are present. No API calls, no runtime — just `grep`.

```bash
./docs/sdlc/evals/check_guardrails.sh
```

**When to use:** Always, before committing any change to command files. It runs in under 1 second.

**What it tests:**
- Required guardrail phrases exist in each command (e.g., `sdlc_open_story.md` contains "DO NOT MAKE ASSUMPTIONS", "DO NOT DELETE DATA", "git mv")
- Orchestration patterns are intact (e.g., `sdlc_doctor.md` references "haiku" for sub-agents, `sdlc_verify_story.md` has all gate steps)
- Cross-command consistency (e.g., all commands that use sub-agents include failure handling, all commands end with "suggest a commit message")

---

### `run_evals.sh` — L2/L3/L5 execution evals (uses rate-limit budget)

Runs SDLC commands through Claude Code (or another tool) against controlled fixtures and asserts on actual behaviour: output content, file side effects, git operations.

```bash
# Run all evals
./docs/sdlc/evals/run_evals.sh

# Run a specific command group
./docs/sdlc/evals/run_evals.sh open_story
./docs/sdlc/evals/run_evals.sh propose_change
./docs/sdlc/evals/run_evals.sh verify_story
./docs/sdlc/evals/run_evals.sh doctor

# Run a single scenario
./docs/sdlc/evals/run_evals.sh doctor_all_pass

# Use a different AI coding tool
./docs/sdlc/evals/run_evals.sh --tool opencode

# Name the run directory (for comparison)
./docs/sdlc/evals/run_evals.sh --output my_baseline
```

**When to use:** Run evals for the specific command you modified:

| Command modified | What to run | Rate-limit cost |
|---|---|---|
| `sdlc_open_story` | `./run_evals.sh open_story` | Moderate (Opus sub-agent) |
| `sdlc_propose_change` | `./run_evals.sh propose_change` | Moderate (Sonnet sub-agents) |
| `sdlc_implement_change` | `./run_evals.sh implement_change` | High (Opus + Android SDK) |
| `sdlc_verify_story` | `./run_evals.sh verify_story` | Moderate (multiple sub-agents) |
| `sdlc_doctor` | `./run_evals.sh doctor` | Low (Haiku sub-agents only) |
| `sdlc_project_doctor` | `./run_evals.sh project_doctor` | Low (Haiku sub-agents only) |
| `sdlc_exp_four_in_one` | `./run_evals.sh exp_four_in_one` | Low (git safety only) |
| `sdlc_exp_vibe_a_story` | `./run_evals.sh exp_vibe_a_story` | Low–Moderate (git safety) |

Run all with no filter if you touched shared infrastructure (e.g. `eval_helpers.sh`, guidelines files referenced by multiple commands).

---

### `run_judge_only.sh` — L3 judge without re-running commands (1 API call per command)

Runs just the LLM-as-judge evaluation against the golden reference, without the expensive command execution. Useful for re-evaluating saved candidate artifacts, sanity-checking the judge, or testing with a different judge model.

```bash
# Self-check: score the golden reference against itself (expect near-perfect)
ANTHROPIC_API_KEY=sk-... EVAL_JUDGE_MODEL=claude-sonnet-5-5 \
  ./docs/sdlc/evals/run_judge_only.sh --self-check all

# Re-judge saved candidate artifacts from a previous run
./docs/sdlc/evals/run_judge_only.sh open_story results/open_story_golden_quality_candidate

# Judge from a fixture directory (collects changed files from baseline)
./docs/sdlc/evals/run_judge_only.sh --from-fixture /tmp/sdlc_eval_golden_open_story_XXXX open_story
```

**When to use:** After changing a rubric, or to compare judge scores across different judge models without re-running the pipeline.

---

### `compare_results.sh` — Regression comparison (no API calls)

Diffs two aggregate JSON result files and reports regressions (PASS to FAIL), improvements (FAIL to PASS), new/removed scenarios, per-criterion L3 score diffs, and timing changes.

Arguments can be a run directory name, `latest`, or a full path to an aggregate JSON file:

```bash
# Compare two named runs
./docs/sdlc/evals/compare_results.sh my_baseline latest

# Compare by timestamp
./docs/sdlc/evals/compare_results.sh 2026-10-23T191644_claude 2026-10-24T103012_opencode

# Full paths still work
./docs/sdlc/evals/compare_results.sh results/runs/my_baseline/aggregate.json results/runs/latest/aggregate.json

# Compare across tools (labels columns by tool name)
./docs/sdlc/evals/compare_results.sh --tool-diff claude_run opencode_run
```

**Exit codes:** `0` = no regressions, `1` = regressions detected, `2` = usage error.

**When to use:** After modifying commands, to verify no scenarios regressed. Also for cross-tool evaluation when testing a new AI coding tool.

---

### `statistical_baseline.sh` — Statistical baseline and comparison (no API calls)

Reads L3 scores from all saved runs and computes per-criterion statistics (mean, standard deviation, min, max). Optionally compares a single run against the baseline distribution using z-scores to detect regressions.

```bash
# Show L3 score statistics across named baseline runs
./docs/sdlc/evals/statistical_baseline.sh baseline_os_1 baseline_os_2 baseline_os_3 baseline_os_4 baseline_os_5

# Use a glob pattern for all baselines of one scenario
./docs/sdlc/evals/statistical_baseline.sh baseline_os_*

# Include pass rates and timing statistics
./docs/sdlc/evals/statistical_baseline.sh --all baseline_os_*

# Compare a new run against the baseline distribution
./docs/sdlc/evals/statistical_baseline.sh --compare latest -- baseline_os_*

# Machine-readable JSON output
./docs/sdlc/evals/statistical_baseline.sh --json baseline_impl_*

# Custom z-score threshold (default: 1.5)
./docs/sdlc/evals/statistical_baseline.sh --compare my_run --threshold 2.0 -- baseline_os_*
```

**Comparison verdicts:**
- `LIKELY REGRESSION` — score is more than `threshold` standard deviations below the mean
- `POSSIBLE DROP` — score is between 1.0 and `threshold` standard deviations below the mean
- `WITHIN RANGE` — score is within 1.0 standard deviation of the mean
- `ABOVE BASELINE` — score is above the mean
- When σ = 0 (all baseline runs scored identically), any deviation is flagged as a regression

**Exit codes:** `0` = no regressions, `1` = regressions detected, `2` = usage error.

**When to use:** After accumulating multiple baseline runs, to determine whether a new run's scores represent a real regression or normal variance. Most valuable when you have 5+ baseline runs per scenario.

---

### Baseline Data Management

Baseline run directories (`results/runs/baseline_*`) contain the `aggregate.json` files that `statistical_baseline.sh` reads. Without them, the `--compare` feature has nothing to compare against.

**Should baselines be committed?** Yes — the `aggregate.json` files are small (~2KB each) and represent hours of compute and API cost to regenerate. Commit at least the aggregate files so any clone can run `--compare` immediately.

**When to recreate baselines:**

| Change | Invalidates baselines? | Why |
|--------|:----------------------:|-----|
| Command `.md` file updated | Yes | The instructions being scored changed |
| Rubric/judge prompt updated | Yes | The scoring criteria shifted |
| Judge model changed | Yes | Different judge, different calibration |
| Golden reference repo updated | Yes | The reference the command operates on changed |
| New scenario added | Partial | Only the new scenario needs baselines |
| Unrelated changes (README, scripts) | No | Baselines are still valid |
| Model under test upgraded | **No** | That is exactly what `--compare` is for |

**Naming convention:** `baseline_<prefix>_<n>` — see the table below.

| Prefix | Scenario |
|--------|----------|
| `baseline_os_` | `open_story_golden_quality` |
| `baseline_pc_` | `propose_change_golden_quality` |
| `baseline_impl_` | `implement_change_golden_quality` |
| `baseline_vs_` | `verify_story_golden_quality` |

**Creating baselines:** Run 5 repetitions per scenario:

```bash
for i in 1 2 3 4 5; do
  ./docs/sdlc/evals/run_evals.sh --output baseline_os_$i open_story_golden_quality
done
```

---

## Recommended Workflow

1. **Always run `check_guardrails.sh`** before committing changes to command files — it's free, instant, and checks all 6 commands.
2. **Run execution evals for the command you modified** — see the table above for the correct filter and expected cost.
3. **Compare before/after** when modifying commands: name the baseline run with `--output`, run again after changes, then use `compare_results.sh` to identify regressions.
4. **Cross-tool comparison** when evaluating a new tool: run the same scenarios with `--tool claude` and `--tool opencode`, then compare with `--tool-diff`.
5. **Statistical baseline comparison** when you have 5+ saved runs: use `statistical_baseline.sh --compare <run> -- baseline_*` to check whether a new run's L3 scores fall within the established distribution. This is more reliable than a two-run diff because it accounts for normal variance.

Note: `sdlc_implement_change` has a golden quality scenario but requires an Android SDK environment. The L3 judge evaluation works without the SDK.

---

## Golden Reference

The golden quality scenarios (`*_golden_quality.sh`) compare command output against a **known-good reference** extracted from a successful pipeline run on the venice project.

Each golden reference lives under `goldenreference/<command>/` and contains:
- `repo-snapshot.tar.gz` — the project state before the command runs (used as the fixture)
- `input.md` — the exact input given to the command
- `output/` — the files produced by the command (the reference to compare against)

**Rubrics** are in `rubrics/` — one per command, each defining per-criterion scoring scales with explicit descriptions of what constitutes each score level.

**Candidate artifacts** are saved to `results/runs/<run>/<scenario>_candidate/` after each run, so you can re-run just the L3 judge without re-executing the command.

**Self-check** (sanity test for the judge and rubrics):

```bash
./docs/sdlc/evals/run_judge_only.sh --self-check all
```

This scores the golden reference against itself — expect near-perfect scores. Low scores indicate a rubric or judge prompt issue.

---

## Scenario Details

### Doctor command scenarios

Each scenario creates a temporary fixture with specific files present or absent, runs the doctor command, and checks the output for correct pass/fail lines.

| Scenario | Fixture state | Expected behaviour |
|----------|--------------|-------------------|
| `doctor_all_pass` | All files present, all config correct | All pass, summary says "All checks passed" |
| `doctor_missing_openspec_config` | Remove `openspec/config.yaml` | Fail for that check, others pass |
| `doctor_missing_opsx_commands` | Remove 2 of the 6 opsx command files | Fail for those 2, others pass |
| `doctor_security_disabled` | Set plugin to `false` in settings | Fail for security check |
| `doctor_everything_broken` | Remove all checked files | All fail, correct failure count |
| `project_doctor_all_pass` | Full project config present | All pass |
| `project_doctor_missing_detekt` | Remove detekt config | Fail for detekt checks only |
| `project_doctor_low_coverage` | Set minBound to 50 instead of 95 | Fail for kover threshold check |

### Story command scenarios

Evals for commands with more complex behaviour and critical guardrails. These use more rate-limit budget per run.

**Fixture design:** All story command fixtures use `create_story_command_base_fixture()` which creates a git repo with git user config, initial commit on `main`, minimal guidelines files, OpenSpec config, AGENTS.md, and gradlew stub. Scenarios extend the base with `create_sample_story_new()`, `create_sample_story_wip()`, or `create_sample_story_ambiguous()` and apply scenario-specific tweaks.

### Golden quality scenarios (L2 + L3)

| Scenario | What L2 (structural) checks | What L3 (judge) scores |
|----------|----------------------------|----------------------|
| `open_story_golden_quality` | WIP file created, original removed, 10+ sections, index updated, report exists | section_completeness, what_not_how, acceptance_criteria_quality, analytics_section_quality, content_preservation, overall_coherence |
| `propose_change_golden_quality` | Change directory created, proposal + design + tasks exist, BDD structure | proposal_quality, design_quality, task_quality, spec_alignment |
| `implement_change_golden_quality` | Tasks checked off, 4+ source files, test files, UI test files, locale strings, report | task_completion, bdd_discipline, code_quality, test_quality |
| `verify_story_golden_quality` | Story renamed DONE, WIP removed, index updated, change archived, spec synced, report with gates | gate_coverage, report_completeness, lifecycle_correctness, outcome_justified |

### Behavioural scenarios (L5)

| Scenario | Abnormal condition | Expected behaviour |
|----------|-------------------|-------------------|
| `open_story_dirty_state` | Uncommitted changes on main | Warns about dirty state, mentions the specific dirty file |
| `open_story_not_on_main` | On `feature/existing-work` branch | Detects non-main branch, asks about proceeding/switching |
| `propose_change_surfaces_questions` | Deliberately ambiguous requirements | Surfaces questions, does not make assumptions |
| `verify_story_precondition_fail` | Story in "New" state (not WIP) | Stops before gates, doesn't reach later verification steps |
| `verify_story_blocks_on_gate_failure` | WIP story, no openspec change artifacts | Blocks at first gate, doesn't reach downstream gates |
| `exp_four_in_one_dirty_state` | Dirty working tree | Detects uncommitted changes, warns user |
| `exp_vibe_a_story_dirty_state` | Dirty working tree | Detects uncommitted changes, warns user |

---

## Rate Limits

All execution evals run under the Claude Code subscription — no extra API costs. The only constraint is subscription rate limits.

- **L1 guardrails:** No rate-limit concern — no API calls at all.
- **Doctor evals:** ~8 scenarios, each spawning ~3 Haiku sub-agents. Lightweight; unlikely to hit limits even if run repeatedly.
- **Story command evals:** Heavier commands (`sdlc_open_story` uses Opus, `sdlc_verify_story` spawns many sub-agents). Run selectively — only when touching the specific command under test.
- **General rule:** Run L1 guardrails freely. Run doctor evals when touching any command. Run story command scenarios individually for the command you changed.

---

## Cross-Tool Testing

Same fixtures and assertions, different `--tool` flag:
- `--tool claude` (default): runs via `claude -p`
- `--tool opencode`: runs via OpenCode's equivalent CLI

```bash
./docs/sdlc/evals/run_evals.sh --tool claude --output claude_run
./docs/sdlc/evals/run_evals.sh --tool opencode --output opencode_run
./docs/sdlc/evals/compare_results.sh --tool-diff claude_run opencode_run
```

---

## File Structure

```
docs/sdlc/evals/
├── check_guardrails.sh                # L1: guardrail assertions
├── run_evals.sh                       # L2+L3+L5: execution eval runner
├── run_judge_only.sh                  # L3: judge-only runner (no command execution)
├── compare_results.sh                 # Regression comparison
├── diff_candidate.sh                  # Diff candidate output vs golden reference
├── extract_golden_reference.sh        # One-time: extract golden ref from venice repo
├── lib/
│   └── eval_helpers.sh                # Shared fixture creators, assertion helpers, judge
├── rubrics/
│   ├── open_story_rubric.md           # Per-criterion rubric for open_story judge
│   ├── propose_change_rubric.md
│   ├── implement_change_rubric.md
│   └── verify_story_rubric.md
├── goldenreference/
│   ├── README.md
│   ├── open_story/                    # repo-snapshot.tar.gz, input.md, output/
│   ├── propose_change/
│   ├── implement_change/
│   └── verify_story/
├── scenarios/
│   ├── open_story_golden_quality.sh   # L2+L3: golden quality eval
│   ├── open_story_dirty_state.sh      # L5: dirty working tree
│   ├── open_story_not_on_main.sh      # L5: wrong branch
│   ├── propose_change_golden_quality.sh
│   ├── propose_change_surfaces_questions.sh
│   ├── implement_change_golden_quality.sh
│   ├── verify_story_golden_quality.sh
│   ├── verify_story_precondition_fail.sh
│   ├── verify_story_blocks_on_gate_failure.sh
│   ├── doctor_*.sh                    # L2: doctor scenarios
│   ├── project_doctor_*.sh            # L2: project doctor scenarios
│   ├── exp_four_in_one_dirty_state.sh
│   └── exp_vibe_a_story_dirty_state.sh
├── statistical_baseline.sh             # Statistical baseline and z-score comparison
└── results/                           # Run outputs (mostly gitignored)
    ├── runs/
    │   ├── baseline_os_1/             # Committed baseline: open_story run 1 of 5
    │   │   └── aggregate.json         #   (only aggregate.json is committed)
    │   ├── baseline_os_2/ … _5/
    │   ├── baseline_pc_1/ … _5/       # Committed baseline: propose_change
    │   ├── baseline_vs_1/ … _5/       # Committed baseline: verify_story
    │   ├── baseline_impl_1/ … _5/     # Committed baseline: implement_change
    │   ├── 2026-10-23T191644_claude/  # Auto-named: <timestamp>_<tool> (gitignored)
    │   │   ├── aggregate.json
    │   │   ├── <scenario>.json
    │   │   ├── <scenario>_candidate/
    │   │   └── <scenario>_output.txt
    │   ├── my_baseline/               # Custom-named via --output (gitignored)
    │   └── latest -> my_baseline/     # Symlink to most recent run
    └── .gitkeep
```

---

## Prerequisites

- `claude` CLI installed and authenticated (or the tool specified via `--tool`)
- `openspec` CLI installed (for doctor openspec CLI check)
- `fastlane`, `bundle` installed (for project_doctor CLI checks)
- `jq` installed (for L3 judge result parsing and comparison)
- `ANTHROPIC_API_KEY` set (for L3 LLM-as-judge; L2 structural assertions run without it)
- `EVAL_JUDGE_MODEL` set (for L3; recommended: a model different from the one being evaluated)
- Android SDK (for `implement_change` and `verify_story` L4 functional verification)

---

## Verification

- **L1 guardrails:** Run `./docs/sdlc/evals/check_guardrails.sh` — all assertions pass. Intentionally remove a guardrail phrase, re-run, verify it catches the regression.
- **Doctor evals:** Run `./docs/sdlc/evals/run_evals.sh doctor` — all doctor scenarios pass. Intentionally break a fixture (remove a file that should exist) — verify the eval catches the changed behaviour.
- **Story command evals:** Run `./docs/sdlc/evals/run_evals.sh open_story` or a single scenario: `./docs/sdlc/evals/run_evals.sh open_story_dirty_state`. Run individual commands selectively.
- **Regression comparison:** Run with `--output before`, make a change, run again with `--output after`, then `./docs/sdlc/evals/compare_results.sh before after` — verify regressions are correctly identified.
