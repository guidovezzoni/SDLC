# verify_story Evaluation Rubric

## Golden Reference

- **Input:** `goldenreference/verify_story/input.md` — the user story and tasks
- **Output:** `goldenreference/verify_story/output/` — renamed story, updated index, report,
  archived change, synced spec

## Criteria

### gate_coverage

- **Type:** checklist (10)
- **Score:** count of gates that were evaluated and reported
- **Max:** 10

The 10 expected verification gates, each corresponding to a step in the
`sdlc_verify_story` command:

| # | Gate | Command step |
|---|------|-------------|
| 1 | OpenSpec verify | Step 2 |
| 2 | TODO scan | Step 3 |
| 3 | Security review | Step 4 |
| 4 | Clean build / static analysis | Step 5 |
| 5 | Unit tests | Step 6 |
| 6 | Coverage report | Step 7 |
| 7 | Test file coverage | Step 8 |
| 8 | Compose preview coverage | Step 9 |
| 9 | On-device tests | Step 10 |
| 10 | Definition of Done | Step 11 |

Score 1 per gate that appears in the report with a PASS/FAIL result (or NOT_FEASIBLE
for on-device, with explanation). A gate mentioned without a clear result scores 0.

### report_completeness

- **Type:** 1–5 scale
- **Description:** The report contains all expected sections with substantive content.

| Score | Meaning |
|-------|---------|
| 5 | Report contains: all gate results with detail, coverage table, archive location, spec sync status, README/AGENTS sync check, final PASSED outcome, Command Metrics |
| 4 | All sections present; one section is thin (e.g. coverage table missing a column) |
| 3 | Most sections present but one or two are missing entirely |
| 2 | Report exists but is incomplete — several sections missing |
| 1 | Report is a stub or placeholder |

Compare against the golden reference report which contains all gate results in a
structured HTML format with the coverage table and Command Metrics subsection.

### lifecycle_correctness

- **Type:** boolean (0 or 1)
- **Score:** 1 if all lifecycle operations were performed correctly; 0 otherwise.

All four must be true:
1. Story file renamed from `-WIP.md` to `-DONE.md` (no `-WIP.md` remains)
2. `docs/userstories/index.md` updated to reference the `-DONE.md` filename
3. Change directory moved from `openspec/changes/` to `openspec/changes/archive/` with
   a date prefix
4. Spec synced: living spec file exists in `openspec/specs/`

### outcome_justified

- **Type:** 1–5 scale
- **Description:** The PASS/FAIL outcome is justified by the gate results — the command
  does not blindly pass.

| Score | Meaning |
|-------|---------|
| 5 | Outcome is clearly justified: all gates passed with evidence, and the final outcome reflects the aggregate result. If any gate had failed, the command would have stopped. |
| 4 | Outcome justified; minor gap (e.g. one gate result is vague but overall assessment is correct) |
| 3 | Outcome is correct but justification is weak — gate results are summarised too briefly to verify |
| 2 | Outcome may not match gate results — some gates lack clear PASS/FAIL or the outcome ignores a failing gate |
| 1 | Outcome appears arbitrary — no relationship between gate results and final verdict |

Key checks:
- Each gate has an explicit PASS or FAIL (not just a description of what was checked)
- The blocking gate protocol was followed (FAIL on any gate → stop)
- The final PASSED outcome is supported by all gates being PASS
- If any gate was NOT_FEASIBLE (e.g. on-device), the handling is documented
