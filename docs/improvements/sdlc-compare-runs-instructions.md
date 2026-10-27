# Compare Runs: Model Regression Testing Instructions

Practical workflow for evaluating how the 4 SDLC commands perform on a new model version and
detecting regressions against a baseline.

## Evaluation tiers

| Tier | What | Cost |
|------|------|------|
| **T1: Structural** | Deterministic assertions — file existence, section presence, side effects (grep, `test -f`, `git diff`) | Free |
| **T2: LLM-as-judge** | Per-criterion rubric scoring against a golden reference | 1 LLM call per command |
| **T3: Functional** | Build and test verification — `./gradlew check`, `./gradlew test`, coverage | Requires Android SDK |

---

## Prerequisites

- **Golden reference repo** at `$REFERENCE_REPO` (default `/home/guido/dev/personal/venice`) with
  the 5 workshop branches:
  ```
  workshop/00_main → workshop/01_sdlc_open_story → workshop/02_sdlc_propose_change
                                                    → workshop/03_sdlc_implement_changes
                                                    → workshop/04_sdlc_verify
  ```
- **Baseline run results** on the current model. If none exist, run the same steps below on the
  current model first to establish one.
- **Judge model chosen** — must be the same for both baseline and candidate runs (see Decision 1
  below).

---

## Per-command setup

Each command starts from a fresh worktree of the appropriate branch, so the 4 commands are
independent — a bad `open_story` result doesn't block testing `implement_change`.

| Command | Worktree from | Human needed? | Android SDK? | Estimated time |
|---------|--------------|---------------|-------------|----------------|
| `open_story` | `workshop/00_main` | No | No | ~5–10 min |
| `propose_change` | `workshop/01_sdlc_open_story` | Yes (questions) | No | ~15–30 min |
| `implement_change` | `workshop/02_sdlc_propose_change` | No | Yes | ~30–60 min |
| `verify_story` | `workshop/03_sdlc_implement_changes` | No | Yes + device | ~20–40 min |

**Total: ~1.5–2.5 hours** of wall-clock time per model, plus T2 judge calls afterwards.

---

## Steps for each command

1. **Create worktree** from the golden-reference branch
2. **Configure the new model** (env var or harness config)
3. **Record start time**
4. **Run the command** via the harness (`$EVAL_TOOL`)
5. **Record end time**
6. **Run T1 structural assertions** (scripted, instant)
7. **Run T2 LLM-as-judge** against the golden reference (1 LLM call)
8. **Run T3 functional checks** (`implement_change` and `verify_story` only — `./gradlew check test`)
9. **Extract Command Metrics** from the report HTML
10. **Write results JSON** (T1 pass/fail, T2 scores + rationales, timing)
11. **Clean up worktree**

Then once all 4 are done:

12. **Run `compare_results.sh`** — baseline vs. candidate, producing a comparison report with score
    deltas and timing ratios

---

## Decisions to make before each comparison

### Decision 1: Judge model for T2

When testing a new model, the judge should be a different model to avoid self-preference bias.

| Testing | Judge with | Rationale |
|---------|-----------|-----------|
| Opus 5 (new) | Opus 4 (current) | Known baseline; but may have its own biases |
| Opus 5 (new) | Different family (e.g. Sonnet latest) | Independent; but different capability level |
| Opus 5 (new) | Same judge for both baseline and candidate runs | Best — keeps judge constant so score deltas reflect the candidate, not the judge |

The last option is the most reliable: pick one judge model and use it for both baseline and candidate.
That way score deltas are pure signal.

### Decision 2: Handling `propose_change` questions

The new model may ask different questions. You need to:
- Answer them honestly (not script them)
- Accept that your answers are a confounding variable (different questions → different answers →
  different proposal)
- Note the questions in the run metadata for comparison

### Decision 3: Independent vs. sequential runs

The default workflow runs each command independently from a golden-reference branch. This isolates
each command's quality but misses pipeline interactions — a new model's `open_story` output might
interact differently with its own `propose_change`.

| Approach | Pro | Con |
|----------|-----|-----|
| **Independent** (default) | Isolates each command; a failure doesn't cascade; attributable results | Doesn't test pipeline integration; each command works with a different model's upstream output |
| **Sequential** (full pipeline) | Tests real end-to-end flow; each command works with its own model's output | Failure cascades; ~double the time and cost; harder to attribute which command regressed |

Start with independent runs. Add a sequential pipeline run only if the independent results look clean
and you want end-to-end confidence.

---

## Interpreting results

### Regression signals by tier

| Tier | Regression signal | Severity | Action |
|------|------------------|----------|--------|
| T1 | Any assertion that passed on baseline now fails | High — structural breakage | Investigate immediately |
| T2 | Any criterion drops ≥ 2 points | High — likely regression | Review rationale; likely a real problem |
| T2 | Any criterion drops 1 point | Medium — potential regression | Review rationale; could be judge noise |
| T2 | Any criterion drops ≤ 0.5 points | Low — possible noise | Note but don't flag |
| T2 | Aggregate score drops | Medium — overall quality concern | Review all criteria |
| T2 | Boolean criterion flips `true → false` | High — regression | Investigate |
| T2 | Checklist count decreases | Medium — partial regression | Identify which items were lost |
| T3 | Build/tests fail when baseline passed | Blocking — broken code | The new model produced non-functional output |
| Timing | Wall-clock > 1.5× baseline | Cost concern | May be acceptable if quality improved |
| Timing | Token usage > 1.3× baseline | Cost concern | 30% more tokens = 30% more cost |
| Timing | Interaction count increased | Notable | More questions = more human time |

### Reading the comparison report

The comparison report contains three sections:

**T1 structural diff:** Four categories — `regressions` (passed → failed), `improvements`
(failed → passed), `unchanged_pass`, `unchanged_fail`. Any entry in `regressions` needs
investigation.

**T2 quality score diff:** Per-criterion `delta` (candidate − baseline), with both rationales
side-by-side. Look at the rationales, not just the numbers — they explain WHY the score changed.

**Timing diff:** Ratios (candidate / baseline) for wall-clock and tokens. Ratios normalise across
commands — a 60-second increase means different things for a 5-minute command vs. a 40-minute command.

---

## Run labelling

Each run needs enough metadata to identify the configuration under test:

```json
{
  "run_id": "2026-10-21_open_story_opus5_claude",
  "command": "open_story",
  "model": "claude-opus-5-5",
  "judge_model": "claude-opus-4-6",
  "harness": "claude",
  "command_md_hash": "a3f9c821...",
  "reference_repo_commit": "e7b2d4f1...",
  "timestamp": "2026-10-21T10:00:00Z"
}
```

The `command_md_hash` is a content hash of the command `.md` file — it identifies the command version
without requiring a git commit. The `reference_repo_commit` pins the golden reference. Together with
model, judge model, and harness, these fields fully identify the configuration under test.

---

## Known limitations

### No blocking-gate testing

This workflow confirms the new model can produce good output on the happy path, but does not test
whether it still stops when something is wrong. A model upgrade that makes gates more lenient (passes
when it should fail) would not be caught. Testing that requires dedicated failure-injection scenarios
— separate from this workflow.

### No automation yet

Every step above is manual. The scenario scripts (`open_story_golden_quality.sh` etc.) would automate
steps 1–11, but they are not yet implemented. Until then, this is a ~2-hour manual process per model.

### `propose_change` human confound

The interactive questions in `propose_change` mean a human is part of the test. Different questions
produce different answers, which produce different proposals. Wall-clock time also includes human
thinking time. The comparison should note this and treat `propose_change` timing as less reliable
than the other three commands.

### Token data not yet available

Claude Code CLI does not currently expose token usage. Wall-clock time and Command Metrics (extracted
from the report HTML) are the only timing data available. Token-based cost comparison requires either
harness support or an API-level proxy.
