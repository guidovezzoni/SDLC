# implement_change Evaluation Rubric

## Golden Reference

- **Input:** `goldenreference/implement_change/input.md` — the tasks.md with all tasks unchecked
- **Output:** `goldenreference/implement_change/output/` — source files, test files, strings,
  checked tasks, report

## Criteria

### task_completion

- **Type:** checklist (count of completed tasks)
- **Score:** number of tasks checked `[x]` in the candidate's tasks.md
- **Max:** total number of tasks in the input tasks.md (29 in the golden reference)

For each checked task, verify that the corresponding file change exists. A task checked
without evidence of the work (no file created or modified) scores 0 for that task.

### bdd_discipline

- **Type:** 1–5 scale
- **Description:** Evidence of test-first development: test files contain tests matching
  the GIVEN/WHEN/THEN descriptions from the task list.

| Score | Meaning |
|-------|---------|
| 5 | Every BDD test task has a corresponding test method with a name matching the GIVEN/WHEN/THEN pattern; tests are meaningful (not trivially passing) |
| 4 | Most test tasks have matching tests; one or two test names diverge from the task description but still test the right behaviour |
| 3 | Tests exist but ordering evidence is ambiguous — tests may have been written after implementation |
| 2 | Some test files exist but don't clearly map to BDD task descriptions |
| 1 | No evidence of test-first development; tests are missing or trivial |

Compare the candidate's test methods against the golden reference's test structure.
The golden reference has tests in:
- `NavigationUriBuilderTest.kt` (URL builder tests)
- `TripDetailViewModelTest.kt` (ViewModel intent/effect tests)
- `LegSummaryTest.kt` (Compose UI tests)
- `TripDetailScreenTest.kt` (Compose UI tests)
- `MainScreenTest.kt` (effect handler tests)

### code_quality

- **Type:** 1–5 scale
- **Description:** Code follows the project's Android guidelines (MVI, Clean Architecture,
  naming, Kotlin best practices).

| Score | Meaning |
|-------|---------|
| 5 | Follows all conventions from guidelines-android.md: MVI pattern (UiState/UiIntent/UiEffect), no `!!`, proper naming, one class per file, literals extracted, composables are presentational |
| 4 | Follows conventions with minor deviations (e.g. one minor naming inconsistency) |
| 3 | Generally follows conventions but has notable issues (e.g. logic in composables, `!!` usage) |
| 2 | Multiple convention violations; code works but doesn't follow project patterns |
| 1 | Code ignores project conventions entirely |

Key checks from the Android guidelines:
- UiIntent/UiEffect/UiState follow the sealed class pattern
- ViewModel exposes `StateFlow<UiState>` and `SharedFlow<UiEffect>`
- Composables are purely presentational (no logic, no locale detection)
- No `!!` operator — use `?.let`, `?: return`, or `?: throw`
- One class per file
- Literals extracted to private constants
- Modifier as first optional parameter in composables
- Strings extracted to `strings.xml` for all locales

### test_quality

- **Type:** 1–5 scale
- **Description:** Tests are meaningful, cover edge cases, and use project testing patterns.

| Score | Meaning |
|-------|---------|
| 5 | Tests are meaningful (not trivially passing), cover edge cases, use MockK and runTest where needed, follow GIVEN/WHEN/THEN naming, have a setup method where appropriate |
| 4 | Tests are meaningful with good coverage; minor pattern deviations |
| 3 | Tests exist and cover the main path but miss edge cases or have pattern issues |
| 2 | Tests are superficial — mostly happy path, trivially passing, or poorly structured |
| 1 | Tests are absent, broken, or test nothing meaningful |

Key checks from the testing guidelines:
- Unit tests in `app/src/test/` using JUnit 4
- GIVEN/WHEN/THEN naming pattern
- MockK for dependency mocking
- `runTest` and `UnconfinedTestDispatcher` for coroutine tests
- Expected values extracted to variables before assertions
- Compose UI tests in `app/src/androidTest/` using `createComposeRule()`
- UI tests pass UiState directly, capture intents via `onIntent` lambda
- 95%+ coverage target
