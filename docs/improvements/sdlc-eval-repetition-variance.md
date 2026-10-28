# Eval Repetition & Variance Analysis Plan

**Branch:** `feature/004-repetitons`
**Started:** 2026-10-27
**Status:** Phase 4-7 COMPLETE — all 20/20 baseline runs done. Phase 8 (analysis) complete.

---

## Goal

Establish statistical baselines for eval L3 (LLM-as-judge) scores by running each golden-quality
scenario multiple times, measuring variance, and building a distribution that future runs can be
compared against. This leverages a higher-tier subscription while available, so the baselines persist
for later use on a lower tier.

---

## Background

A single eval run produces a snapshot — but LLM output is non-deterministic. A 1-point score drop
could be a real regression or just run-to-run noise. Without knowing the variance, there is no way
to distinguish the two. Multiple repetitions per scenario establish the distribution (mean, stdev,
min, max) so that future z-score comparisons can flag real regressions.

The eval infrastructure already supports this:
- `run_evals.sh --output <name>` saves runs with custom names
- `statistical_baseline.sh` computes per-criterion statistics across multiple runs
- `statistical_baseline.sh --compare <run>` flags scores outside the baseline distribution

---

## Phases

### Phase 1+2: Judge Calibration (COMPLETE)

**Purpose:** Before running expensive command executions, verify that the L3 judge itself is stable.

**Method:** Run `run_judge_only.sh --self-check all` multiple times (7 runs) and check score
consistency when the judge evaluates the golden reference against itself.

**Results:**

| Verdict | Count | Criteria |
|---------|-------|----------|
| LOCKED (σ=0, golden gets max) | 14/20 | 70% of criteria are perfectly stable |
| RELIABLE (low variance) | 3/20 | overall_coherence, question_quality, story_alignment, gate_coverage |
| RUBRIC GAP (golden < max) | 3/20 | what_not_how, code_quality, test_quality |

**RUBRIC GAP detail:**
- `what_not_how` — golden self-scores μ=4.0 (max 5), σ=0.53. The golden reference intentionally
  includes some implementation-level detail (file names, test framework mentions) that the rubric
  penalises. This is a known design choice.
- `code_quality` — golden self-scores μ=4.71 (max 5), σ=0.45. Minor code style nits occasionally
  cost a point.
- `test_quality` — golden self-scores μ=4.71 (max 5), σ=0.45. Same pattern.

**Conclusion:** The judge is reliable. 70% of criteria are deterministic; the remaining 30% have
low, well-understood variance. Phase 3 (rubric tuning) is optional — the gaps are minor.

### Phase 3: Rubric Tuning (OPTIONAL, DEFERRED)

**Purpose:** Adjust rubrics so the golden reference scores perfectly against itself.

**Decision:** Deferred. The rubric gaps are understood and minor. The `what_not_how` gap is a design
choice (the golden reference intentionally includes some implementation guidance), not a rubric bug.
Tuning can be done later if the gaps cause false positives in comparisons.

### Phase 4-7: Command Execution Baselines (COMPLETE — 20/20 runs)

**Purpose:** Run each golden-quality scenario 5 times to build per-scenario statistical distributions.

**Plan:** 5 runs each × 4 scenarios = 20 total runs.

| Phase | Scenario | Est. time/run | Priority | Status |
|-------|----------|---------------|----------|--------|
| 4 | `implement_change_golden_quality` | ~16 min | Highest (most variance observed) | **5/5 COMPLETE** |
| 5 | `verify_story_golden_quality` | ~13 min | High | **5/5 COMPLETE** |
| 6 | `open_story_golden_quality` | ~4 min | Medium | **5/5 COMPLETE** |
| 7 | `propose_change_golden_quality` | ~5 min | Medium | **5/5 COMPLETE** |

**Total actual time:** ~3.8 hours of command execution plus judge calls.

**Completed baseline statistics:**

`open_story_golden_quality` (5 runs, 100% pass rate, timing μ=262s σ=10s):

| Criterion | Mean | σ | Range | Verdict |
|-----------|------|---|-------|---------|
| section_completeness | 12.00 | 0.00 | 12–12 | Locked |
| content_preservation | 1.00 | 0.00 | 1–1 | Locked |
| overall_coherence | 4.20 | 0.45 | 4–5 | Low variance |
| what_not_how | 3.20 | 0.45 | 3–4 | Low variance |
| acceptance_criteria_quality | 4.60 | 0.55 | 4–5 | Medium variance |
| analytics_section_quality | 4.60 | 0.55 | 4–5 | Medium variance |

`propose_change_golden_quality` (5 runs, 100% pass rate, timing μ=284s σ=15s):

| Criterion | Mean | σ | Range | Verdict |
|-----------|------|---|-------|---------|
| proposal_completeness | 5.00 | 0.00 | 5–5 | Locked |
| design_quality | 5.00 | 0.00 | 5–5 | Locked |
| task_granularity | 4.00 | 0.00 | 4–4 | Locked |
| bdd_task_structure | 4.80 | 0.45 | 4–5 | Low variance |
| question_quality | 3.20 | 0.45 | 3–4 | Low variance |
| story_alignment | 3.80 | 0.45 | 3–4 | Low variance |

`verify_story_golden_quality` (5 runs, 100% pass rate, timing μ=788s σ=55s):

| Criterion | Mean | σ | Range | Verdict |
|-----------|------|---|-------|---------|
| report_completeness | 5.00 | 0.00 | 5–5 | Locked |
| lifecycle_correctness | 1.00 | 0.00 | 1–1 | Locked |
| gate_coverage | 9.80 | 0.45 | 9–10 | Low variance |
| outcome_justified | 4.00 | 1.00 | 3–5 | **High variance** |

`implement_change_golden_quality` (5 runs, 100% pass rate, timing μ=933s σ=211s):

| Criterion | Mean | σ | Range | Verdict |
|-----------|------|---|-------|---------|
| bdd_discipline | 5.00 | 0.00 | 5–5 | Locked |
| code_quality | 4.00 | 0.00 | 4–4 | Locked |
| test_quality | 4.00 | 0.00 | 4–4 | Locked |
| task_completion | 27.60 | 0.89 | 27–29 | Medium variance |

### Phase 8: Analysis and Documentation (COMPLETE)

**Purpose:** Analyse the distributions and document findings.

**Overall results across 20 criteria, 20 runs (5 per scenario), 100% pass rate:**

| Variance band | Count | Criteria |
|---------------|-------|----------|
| Locked (σ=0) | 10/20 (50%) | section_completeness, content_preservation, proposal_completeness, design_quality, task_granularity, report_completeness, lifecycle_correctness, bdd_discipline, code_quality, test_quality |
| Low (σ < 0.5) | 6/20 (30%) | overall_coherence, what_not_how, bdd_task_structure, question_quality, story_alignment, gate_coverage |
| Medium (0.5 ≤ σ < 1.0) | 3/20 (15%) | acceptance_criteria_quality, analytics_section_quality, task_completion |
| **High (σ ≥ 1.0)** | **1/20 (5%)** | **outcome_justified** (verify_story) |

**Key findings:**

1. **The baselines are reliable.** 80% of criteria (16/20) have σ < 0.5, meaning a 1-point drop
   is almost certainly a real regression, not noise.

2. **One criterion needs investigation:** `outcome_justified` (verify_story) has σ=1.0, range 3–5.
   This makes it nearly useless for regression detection — a score of 3 could be normal. The rubric
   or the command output may need tightening.

3. **`task_completion` is a checklist, not a 1–5 scale.** Its σ=0.89 on a 29-point scale is actually
   low proportionally (3% relative variance). The absolute number fluctuates because different runs
   produce slightly different task counts.

4. **Timing variance is highest for `implement_change`** (σ=211s on μ=933s, CV=23%). This is expected
   — it orchestrates the most sub-agents and has the most variable execution path. The other three
   commands have CV < 7%.

5. **Recommended z-score threshold: 1.5** (the default). With these distributions, a z=1.5 flag
   means "this score is outside the range seen in all 5 baseline runs" for most criteria, which is
   the right sensitivity level.

6. **5 runs per scenario is sufficient.** The distributions are tight enough that adding more runs
   would not meaningfully change the mean or stdev for 19/20 criteria. `outcome_justified` might
   benefit from more runs to confirm whether σ=1.0 is real or an outlier, but the rubric itself
   should be investigated first.

### Phase 9: Statistical Comparison Script (COMPLETE)

**Purpose:** Build `statistical_baseline.sh` to compute and compare against distributions.

**Status:** Script written, tested, and committed.

**Capabilities:**
- Computes per-criterion statistics (mean, stdev, min, max) across any set of runs
- Compares a single run against baseline distribution using z-scores
- Configurable z-score threshold (default 1.5)
- `--all` flag for pass rates and timing statistics
- `--json` flag for programmatic use
- Colour-coded output: green (σ < 0.5), yellow (0.5–1.0), red (σ ≥ 1.0)

---

## Usage: Comparing a Future Run Against Baselines

```bash
# Set env vars for L3 judge
export ANTHROPIC_API_KEY=sk-...
export EVAL_JUDGE_MODEL=claude-sonnet-5-5

# Run a new eval
./docs/sdlc/evals/run_evals.sh --output my_new_run open_story_golden_quality

# Compare against baseline distribution
./docs/sdlc/evals/statistical_baseline.sh --compare my_new_run -- baseline_os_*
```

---

## Naming Convention

Baseline runs follow this pattern: `baseline_<scenario>_<n>`

| Prefix | Scenario |
|--------|----------|
| `baseline_os_` | open_story_golden_quality |
| `baseline_pc_` | propose_change_golden_quality |
| `baseline_impl_` | implement_change_golden_quality |
| `baseline_vs_` | verify_story_golden_quality |

---

## Files Changed/Created

| File | Status | Description |
|------|--------|-------------|
| `docs/sdlc/evals/statistical_baseline.sh` | Committed | Statistical baseline computation script |
| `docs/sdlc/evals/README.md` | Committed | Added documentation for statistical_baseline.sh |
| `docs/improvements/sdlc-eval-repetition-variance.md` | Committed | This plan and results document |

---

## Baseline Run Inventory

All runs stored under `docs/sdlc/evals/results/runs/`:

| Run | Scenario | Result | Scores | Time |
|-----|----------|--------|--------|------|
| baseline_os_1 | open_story | PASS | 12/4/4/5/1/4 | 247s |
| baseline_os_2 | open_story | PASS | 12/3/5/5/1/4 | 271s |
| baseline_os_3 | open_story | PASS | 12/3/4/4/1/4 | 265s |
| baseline_os_4 | open_story | PASS | 12/3/5/5/1/4 | 257s |
| baseline_os_5 | open_story | PASS | 12/3/5/4/1/5 | 270s |
| baseline_pc_1 | propose_change | PASS | 5/5/4/4/3/4 | 299s |
| baseline_pc_2 | propose_change | PASS | 5/5/5/4/3/4 | 279s |
| baseline_pc_3 | propose_change | PASS | 5/5/5/4/3/3 | 273s |
| baseline_pc_4 | propose_change | PASS | 5/5/5/4/4/4 | 267s |
| baseline_pc_5 | propose_change | PASS | 5/5/5/4/3/4 | 300s |
| baseline_vs_1 | verify_story | PASS | 10/5/1/3 | 697s |
| baseline_vs_2 | verify_story | PASS | 10/5/1/5 | 833s |
| baseline_vs_3 | verify_story | PASS | 10/5/1/5 | 781s |
| baseline_vs_4 | verify_story | PASS | 10/5/1/4 | 814s |
| baseline_vs_5 | verify_story | PASS | 9/5/1/3 | 817s |
| baseline_impl_1 | implement_change | PASS | 28/5/4/4 | 1152s |
| baseline_impl_2 | implement_change | PASS | 29/5/4/4 | 1173s |
| baseline_impl_3 | implement_change | PASS | 27/5/4/4 | 780s |
| baseline_impl_4 | implement_change | PASS | 27/5/4/4 | 823s |
| baseline_impl_5 | implement_change | PASS | 27/5/4/4 | 739s |

---

## Follow-Up Actions

| Action | Priority | Description |
|--------|----------|-------------|
| Investigate `outcome_justified` rubric | High | σ=1.0 makes this criterion unreliable for regression detection. Review rubric wording and judge prompt for ambiguity. |
| Test `--compare` workflow | Low | Run a future eval and use `statistical_baseline.sh --compare latest -- baseline_os_*` to confirm the z-score comparison works end-to-end. |

---

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-10-27 | Skip Phase 3 (rubric tuning) | Rubric gaps are minor and well-understood; golden reference intentionally includes implementation detail |
| 2026-10-27 | Use claude-sonnet-5-5 as judge model | Different family from the models being evaluated; consistent across all runs |
| 2026-10-27 | 5 runs per scenario | Minimum for meaningful stdev; balances cost vs. statistical power |
| 2026-10-27 | Start with open_story (lightest) | Fast feedback on the process before committing to expensive implement_change runs |
