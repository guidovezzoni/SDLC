# propose_change Evaluation Rubric

## Golden Reference

- **Input:** `goldenreference/propose_change/input.md` — the refined user story (WIP)
- **Output:** `goldenreference/propose_change/output/` — proposal, design, spec, tasks, config, report

## Criteria

### proposal_completeness

- **Type:** 1–5 scale
- **Description:** The proposal covers why the change is needed, what changes, which
  capabilities are affected, and the impact.

| Score | Meaning |
|-------|---------|
| 5 | All four sections present and substantive: Why, What Changes, Capabilities, Impact — comparable in scope to the golden reference |
| 4 | All sections present; minor gaps in one area (e.g. impact list misses a file) |
| 3 | Most sections present but one is superficial or missing |
| 2 | Proposal exists but is incomplete — missing multiple sections or very thin |
| 1 | Proposal is a stub or placeholder |

Compare the candidate's scope against the golden reference — it should cover at least the
same files, intents, effects, and integration points.

### design_quality

- **Type:** 1–5 scale
- **Description:** The design document provides context, goals/non-goals, decisions with
  rationale, and identified risks.

| Score | Meaning |
|-------|---------|
| 5 | Context, goals, non-goals, design decisions with rationale, risks — all present and well-reasoned |
| 4 | All sections present; decisions are sound but rationale could be deeper |
| 3 | Design exists but missing goals/non-goals or risk assessment |
| 2 | Design is superficial — lists decisions without rationale |
| 1 | Design is a stub or absent |

Key checks:
- Does the design explain WHY each decision was made, not just WHAT?
- Are non-goals explicitly stated (what this change does NOT do)?
- Are risks identified with their likelihood and mitigation?

### bdd_task_structure

- **Type:** 1–5 scale
- **Description:** Tasks follow BDD ordering: test task (with GIVEN/WHEN/THEN) paired
  with implementation task. Prerequisites first, verification last.

| Score | Meaning |
|-------|---------|
| 5 | Clear BDD structure: prerequisites → BDD pairs (test then implement) → verification. Every test task has GIVEN/WHEN/THEN and names the test class. |
| 4 | BDD structure correct; minor issues (e.g. one test task missing GIVEN/WHEN/THEN format) |
| 3 | Some BDD pairing but inconsistent — some sections have tests after implementation or missing test tasks |
| 2 | Tasks listed but no clear BDD ordering or test-first discipline |
| 1 | Flat task list with no structure or BDD awareness |

Expected structure from the golden reference:
- Section 1: Prerequisites (setup tasks, no BDD)
- Sections 2–6: BDD sections with test + implementation pairs
- Section 7: Verification (build, tests, on-device)

### task_granularity

- **Type:** 1–5 scale
- **Description:** Tasks are atomic — each is implementable by a sub-agent in one pass
  with clear completion criteria.

| Score | Meaning |
|-------|---------|
| 5 | Every task is atomic with clear completion criteria; a sub-agent could implement each without further clarification |
| 4 | Most tasks are atomic; one or two are slightly broad but still actionable |
| 3 | Mixed — some tasks are well-scoped, others bundle multiple concerns |
| 2 | Many tasks are too broad ("implement the feature") or too vague |
| 1 | Tasks are high-level objectives, not actionable work items |

Check against the golden reference: it has 29 tasks across 7 sections, with each task
naming specific files, classes, or operations.

### question_quality

- **Type:** 1–5 scale
- **Description:** If the command surfaced questions to the user, they are relevant and
  avoid assumptions. If no questions were asked, the story was unambiguous enough to proceed.

| Score | Meaning |
|-------|---------|
| 5 | Questions (if any) are relevant, specific, and would genuinely affect the design; or no questions were needed and the story was indeed unambiguous |
| 4 | Questions are relevant; one is minor or could have been resolved from the story |
| 3 | Some questions are relevant but others are unnecessary or already answered in the story |
| 2 | Questions are mostly irrelevant or reveal the command didn't read the story carefully |
| 1 | Questions are entirely off-topic or the command failed to ask about genuine ambiguities |

This criterion evaluates judgement: asking too many questions is as much a failure as
asking too few when ambiguities exist.

### story_alignment

- **Type:** 1–5 scale
- **Description:** The proposed change faithfully implements the refined user story without
  scope creep or omissions.

| Score | Meaning |
|-------|---------|
| 5 | Every acceptance criterion from the story is addressed; no scope creep beyond the story |
| 4 | All criteria addressed; minor additions that are reasonable (e.g. edge case handling) |
| 3 | Most criteria addressed but one is missed or significant scope creep |
| 2 | Several criteria missed or substantial scope creep |
| 1 | Proposal does not align with the user story |

Compare the proposal's "What Changes" and the tasks against the user story's acceptance
criteria and Definition of Done — they should map one-to-one.
