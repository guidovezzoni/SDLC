# open_story Evaluation Rubric

## Golden Reference

- **Input:** `goldenreference/open_story/input.md` — the unrefined user story
- **Output:** `goldenreference/open_story/output/` — refined story, report, updated index

## Criteria

### section_completeness

- **Type:** checklist (12)
- **Score:** count of sections present AND substantive (not just a heading with no content)
- **Max:** 12

The 12 required refinement sections, each mapping to a refinement requirement in the
`sdlc_open_story` command:

| # | Requirement | Expected section heading (or close variant) |
|---|-------------|---------------------------------------------|
| 1 | Full description of the functionality | Description |
| 2 | Comprehensive list of fields to update | Fields, MVI Artefacts, or similar |
| 3 | Structure and URLs of endpoints | Intent URI, Endpoint, or URL structure |
| 4 | Files to modify | Files to Modify |
| 5 | How to create unit tests | Unit Testing Strategy |
| 6 | How to update documentation | Documentation Updates |
| 7 | Security issues and mitigations | Security Considerations |
| 8 | Performance issues and mitigations | Performance Considerations |
| 9 | GDPR and sensitive information | GDPR and Sensitive Information |
| 10 | Analytics events for the feature | Analytics |
| 11 | Other non-functional requirements | Non-Functional Requirements |
| 12 | Steps for task completion | Definition of Done or Completion Steps |

Score 1 per section that is both present and contains substantive content (at least one
paragraph, table, or list of items — not just a heading or a one-line placeholder).

### what_not_how

- **Type:** 1–5 scale
- **Description:** The refinement stays at the requirements/acceptance-criteria level and does
  not prescribe architecture, design patterns, or specific libraries.

| Score | Meaning |
|-------|---------|
| 5 | Entirely requirements-level; no architecture or library prescriptions |
| 4 | Mostly requirements-level; one or two minor implementation hints |
| 3 | Mixed — some sections describe requirements, others prescribe solutions |
| 2 | Mostly implementation-level; requirements are interleaved with design decisions |
| 1 | Reads like a design document rather than a user story refinement |

The golden reference includes technical notes (e.g. URL format, intent structure) because
those are part of the external-facing behaviour, not internal architecture. Score those as
requirements, not implementation prescriptions.

### acceptance_criteria_quality

- **Type:** 1–5 scale
- **Description:** Acceptance criteria are testable, specific, and cover the scope of the story.

| Score | Meaning |
|-------|---------|
| 5 | Every criterion is testable with a clear pass/fail condition; full scope coverage |
| 4 | Criteria are testable; minor gaps in scope coverage |
| 3 | Most criteria are testable; some are vague or scope gaps exist |
| 2 | Several criteria are untestable or vaguely worded |
| 1 | Criteria are mostly platitudes ("it should work well") |

Compare against the golden reference for scope completeness — the candidate should cover
at least the same acceptance criteria topics.

### analytics_section_quality

- **Type:** 1–5 scale
- **Description:** The Analytics section follows the project's analytics guidelines.

| Score | Meaning |
|-------|---------|
| 5 | Events use snake_case object_action naming, parameters are bounded primitives, product question stated, privacy floor respected, tracking plan alignment noted |
| 4 | Naming and parameters correct; minor omission (e.g. product question not explicitly stated) |
| 3 | Event defined but naming or parameter design has issues |
| 2 | Analytics section exists but is superficial or violates guidelines |
| 1 | Analytics section is a placeholder or missing entirely |

Key checks from the analytics guidelines:
- Event names: `snake_case`, `object_action` format, past tense
- Parameters: bounded primitives only, no identifiers, no free text
- Product question each event answers is stated
- Privacy floor: no PII, no coordinates, no place names in event parameters
- If no new event is needed, an explicit rationale is given

### content_preservation

- **Type:** boolean (0 or 1)
- **Score:** 1 if the original story text is preserved verbatim under an
  `## Original user story` heading; 0 otherwise.

Check that:
- An `## Original user story` section exists near the bottom of the file
- The original story content appears beneath it (compare against the input file)

### overall_coherence

- **Type:** 1–5 scale
- **Description:** The refined story reads as a coherent, self-consistent document suitable
  for the propose_change phase.

| Score | Meaning |
|-------|---------|
| 5 | Reads as a single coherent document; sections reference each other consistently; no contradictions; ready for design phase |
| 4 | Coherent with minor inconsistencies between sections |
| 3 | Mostly coherent but some sections feel disconnected or contradict each other |
| 2 | Significant inconsistencies or sections that don't align |
| 1 | Disjointed; sections appear independently generated with no cross-referencing |

Things to check:
- Do the acceptance criteria align with the description?
- Do the files-to-modify match the MVI artefacts listed?
- Do the unit test strategies cover the acceptance criteria?
- Does the Definition of Done reflect the acceptance criteria?
- Are terms and names used consistently throughout?
