#!/usr/bin/env bash
# Scenario: implement_change golden-reference quality evaluation.
# Fixture: full venice project repo after propose_change (workshop/02_sdlc_propose_change).
# T1: structural assertions on task completion, file creation, and locale strings.
# T2: LLM-as-judge scoring against the golden reference.
#
# Interactive: yes — the command may prompt about device connectivity and task issues.
# Prerequisites: claude CLI (or $EVAL_TOOL), Android SDK, openspec CLI,
#   ANTHROPIC_API_KEY + EVAL_JUDGE_MODEL for T2.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/eval_helpers.sh"

SCENARIO_NAME="implement_change_golden_quality"
GOLDEN_OUTPUT=$(get_golden_output_dir "implement_change")
RUBRIC="$EVAL_ROOT/rubrics/implement_change_rubric.md"

# --- Setup ---
FIXTURE_DIR=$(create_golden_fixture "implement_change")
git -C "$FIXTURE_DIR" branch -M main
git -C "$FIXTURE_DIR" checkout -b feature/5.1.2-navigate-leg-segment --quiet
git -C "$FIXTURE_DIR" tag eval-baseline

# --- Run ---
OUTPUT_FILE="$FIXTURE_DIR/eval_output.txt"
echo -e "  ${DIM}Running $EVAL_TOOL for $SCENARIO_NAME...${RESET}"
echo -e "  ${YELLOW}This scenario requires Android SDK and is interactive.${RESET}"
run_eval_with_args "$FIXTURE_DIR" "$COMMANDS_DIR/sdlc_implement_change.md" "$OUTPUT_FILE" "" || true

# --- T1: Structural Assertions ---
echo -e "\n  ${BOLD}T1: Structural Assertions${RESET}"
begin_assertions

# Find the tasks file
TASKS_FILE=$(find "$FIXTURE_DIR/openspec/changes" -name "tasks.md" ! -path "*/archive/*" 2>/dev/null | head -1)

if [[ -n "$TASKS_FILE" && -f "$TASKS_FILE" ]]; then
    # All tasks checked (no unchecked boxes remain)
    UNCHECKED=$(grep -c '\- \[ \]' "$TASKS_FILE" 2>/dev/null || true)
    CHECKED=$(grep -c '\- \[x\]' "$TASKS_FILE" 2>/dev/null || true)
    if [[ "$UNCHECKED" -eq 0 && "$CHECKED" -gt 0 ]]; then
        assertion_pass "All tasks checked ($CHECKED tasks, 0 unchecked)"
    else
        assertion_fail "All tasks checked" "$CHECKED checked, $UNCHECKED unchecked"
    fi
else
    assertion_fail "tasks.md found" "not found under openspec/changes/"
fi

# Source files created under app/src/main/java/
SRC_COUNT=$(find "$FIXTURE_DIR/app/src/main/java" -name "*.kt" -newer "$FIXTURE_DIR/.git/refs/tags/eval-baseline" 2>/dev/null | wc -l)
if [[ "$SRC_COUNT" -ge 4 ]]; then
    assertion_pass "Source files created ($SRC_COUNT .kt files)"
else
    # Fallback: count all .kt files that match expected patterns
    SRC_COUNT=$(find "$FIXTURE_DIR/app/src/main/java" -name "*.kt" 2>/dev/null | \
        grep -ciE "UiIntent|UiEffect|UiState|ViewModel|LegSummary|TripDetail|NavigationUri|MainScreen" || true)
    if [[ "$SRC_COUNT" -ge 4 ]]; then
        assertion_pass "Source files created ($SRC_COUNT matching .kt files)"
    else
        assertion_fail "Source files created" "found $SRC_COUNT, expected >= 4"
    fi
fi

# Unit test files under app/src/test/java/
TEST_COUNT=$(find "$FIXTURE_DIR/app/src/test/java" -name "*Test.kt" 2>/dev/null | wc -l)
if [[ "$TEST_COUNT" -ge 1 ]]; then
    assertion_pass "Unit test files created ($TEST_COUNT files)"
else
    assertion_fail "Unit test files created" "found $TEST_COUNT, expected >= 1"
fi

# Compose UI test files under app/src/androidTest/java/
UI_TEST_COUNT=$(find "$FIXTURE_DIR/app/src/androidTest/java" -name "*Test.kt" 2>/dev/null | wc -l)
if [[ "$UI_TEST_COUNT" -ge 1 ]]; then
    assertion_pass "UI test files created ($UI_TEST_COUNT files)"
else
    assertion_fail "UI test files created" "found $UI_TEST_COUNT, expected >= 1"
fi

# Locale strings updated (EN, IT, ES-rES)
for locale_dir in "values" "values-it" "values-es-rES"; do
    STRINGS="$FIXTURE_DIR/app/src/main/res/$locale_dir/strings.xml"
    if [[ -f "$STRINGS" ]]; then
        assertion_pass "Strings file exists: $locale_dir"
    else
        assertion_fail "Strings file exists: $locale_dir"
    fi
done

# Report updated
REPORT="$FIXTURE_DIR/docs/reports/5.1.2-navigate-leg-segment.html"
if [[ -f "$REPORT" ]] && grep -qi "implement" "$REPORT"; then
    assertion_pass "Report updated with implementation section"
else
    assertion_fail "Report updated with implementation section"
fi

# --- T2: LLM-as-judge ---
echo -e "\n  ${BOLD}T2: LLM-as-judge${RESET}"

CANDIDATE_DIR=$(collect_candidate_from_baseline "$FIXTURE_DIR")
JUDGE_RESULT="$FIXTURE_DIR/judge_result.json"

run_judge "$RUBRIC" "$GOLDEN_OUTPUT" "$CANDIDATE_DIR" "$JUDGE_RESULT" || true

assert_judge_score "$JUDGE_RESULT" "task_completion" 20 "task_completion >= 20/29"
assert_judge_score "$JUDGE_RESULT" "bdd_discipline" 3 "bdd_discipline >= 3/5"
assert_judge_score "$JUDGE_RESULT" "code_quality" 3 "code_quality >= 3/5"
assert_judge_score "$JUDGE_RESULT" "test_quality" 3 "test_quality >= 3/5"

# --- Report & Cleanup ---
rm -rf "$CANDIDATE_DIR"
report_scenario_result "$SCENARIO_NAME"
RESULT=$?

if [[ -n "${RESULTS_DIR:-}" && -f "$JUDGE_RESULT" ]] && command -v jq > /dev/null 2>&1; then
    RESULT_JSON="$RESULTS_DIR/${SCENARIO_NAME}.json"
    if [[ -f "$RESULT_JSON" ]]; then
        jq --argjson judge "$(cat "$JUDGE_RESULT")" '. + {judge: $judge}' \
            "$RESULT_JSON" > "${RESULT_JSON}.tmp" && \
            mv "${RESULT_JSON}.tmp" "$RESULT_JSON" || true
    fi
fi

cleanup_fixture "$FIXTURE_DIR"
exit $RESULT
