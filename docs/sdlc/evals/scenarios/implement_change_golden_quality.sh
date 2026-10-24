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
GOLDEN_INPUT=$(get_golden_input "implement_change")
RUBRIC="$EVAL_ROOT/rubrics/implement_change_rubric.md"

# --- Setup ---
echo -e "\n  ${BOLD}Setup${RESET}"
FIXTURE_DIR=$(create_golden_fixture "implement_change")
progress "Adding google-services stub..."
add_google_services_stub "$FIXTURE_DIR"
git -C "$FIXTURE_DIR" add -f app/google-services.json 2>/dev/null || true
git -C "$FIXTURE_DIR" -c user.name="eval" -c user.email="eval@test" \
    commit -m "add google-services stub" --quiet --allow-empty
progress "Creating feature branch..."
git -C "$FIXTURE_DIR" checkout -b feature/5.1.2-navigate-leg-segment --quiet
git -C "$FIXTURE_DIR" push --quiet --all origin
git -C "$FIXTURE_DIR" branch --set-upstream-to=origin/feature/5.1.2-navigate-leg-segment >/dev/null 2>&1 || true
git -C "$FIXTURE_DIR" tag eval-baseline

# --- Run ---
OUTPUT_FILE=$(mktemp "/tmp/sdlc_eval_output_${SCENARIO_NAME}_XXXXXX")
EVAL_CMD=$(mktemp "/tmp/sdlc_eval_cmd_${SCENARIO_NAME}_XXXXXX.md")
{
    echo "IMPORTANT: This is an automated evaluation run. If no Android device is connected,"
    echo "skip on-device tests and proceed with all remaining tasks. Do not wait for a device."
    echo "Complete as many tasks as possible."
    echo ""
    cat "$COMMANDS_DIR/sdlc_implement_change.md"
} > "$EVAL_CMD"

echo -e "\n  ${BOLD}Command Execution${RESET}"
echo -e "  ${DIM}Running $EVAL_TOOL for $SCENARIO_NAME (this may take several minutes)...${RESET}"
run_eval_with_args "$FIXTURE_DIR" "$EVAL_CMD" "$OUTPUT_FILE" "" || true
echo -e "  ${DIM}Command completed in ${EVAL_DURATION}s${RESET}"
rm -f "$EVAL_CMD"

# --- T1: Structural Assertions ---
echo -e "\n  ${BOLD}T1: Structural Assertions${RESET}"
begin_assertions

echo -e "  ${DIM}Checking task completion...${RESET}"
# Find the tasks file
TASKS_FILE=$(find "$FIXTURE_DIR/openspec/changes" -name "tasks.md" ! -path "*/archive/*" 2>/dev/null | head -1)

if [[ -n "$TASKS_FILE" && -f "$TASKS_FILE" ]]; then
    # All tasks checked (no unchecked boxes remain)
    UNCHECKED=$(grep -c '\- \[ \]' "$TASKS_FILE" 2>/dev/null || true)
    CHECKED=$(grep -c '\- \[x\]' "$TASKS_FILE" 2>/dev/null || true)
    if [[ "$UNCHECKED" -eq 0 && "$CHECKED" -gt 0 ]]; then
        assertion_pass "All tasks checked ($CHECKED tasks, 0 unchecked)"
    else
        assertion_fail "All tasks checked" "$CHECKED checked, $UNCHECKED unchecked — likely no Android device connected"
    fi
else
    assertion_fail "tasks.md found" "not found under openspec/changes/"
fi

echo -e "  ${DIM}Checking source and test files...${RESET}"
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

echo -e "  ${DIM}Checking locale strings and report...${RESET}"
# Locale strings updated (EN, IT, ES-rES)
for locale_dir in "values" "values-it" "values-es-rES"; do
    STRINGS="$FIXTURE_DIR/app/src/main/res/$locale_dir/strings.xml"
    if [[ -f "$STRINGS" ]]; then
        assertion_pass "Strings file exists: $locale_dir"
    else
        assertion_fail "Strings file exists: $locale_dir"
    fi
done

# Report updated (may not exist if command focuses on implementation over reporting)
REPORT="$FIXTURE_DIR/docs/reports/5.1.2-navigate-leg-segment.html"
if [[ -f "$REPORT" ]]; then
    if grep -qiE "implement|task|section|phase" "$REPORT"; then
        assertion_pass "Report updated with implementation content"
    else
        assertion_pass "Report file exists (content varies)"
    fi
else
    assertion_fail "Report file exists"
fi

# --- T2: LLM-as-judge ---
echo -e "\n  ${BOLD}T2: LLM-as-judge${RESET}"

CANDIDATE_DIR=$(collect_candidate_from_baseline "$FIXTURE_DIR")
JUDGE_RESULT="$FIXTURE_DIR/judge_result.json"

run_judge "$RUBRIC" "$GOLDEN_OUTPUT" "$CANDIDATE_DIR" "$JUDGE_RESULT" "$GOLDEN_INPUT" || true

assert_judge_score "$JUDGE_RESULT" "task_completion" 20 "task_completion >= 20/29"
assert_judge_score "$JUDGE_RESULT" "bdd_discipline" 3 "bdd_discipline >= 3/5"
assert_judge_score "$JUDGE_RESULT" "code_quality" 3 "code_quality >= 3/5"
assert_judge_score "$JUDGE_RESULT" "test_quality" 3 "test_quality >= 3/5"

# --- Report & Cleanup ---
report_scenario_result "$SCENARIO_NAME" || true
RESULT=$ASSERTIONS_FAILED

if [[ -n "${RESULTS_DIR:-}" && -f "$JUDGE_RESULT" ]] && command -v jq > /dev/null 2>&1; then
    RESULT_JSON="$RESULTS_DIR/${SCENARIO_NAME}.json"
    if [[ -f "$RESULT_JSON" ]]; then
        jq --argjson judge "$(cat "$JUDGE_RESULT")" '. + {judge: $judge}' \
            "$RESULT_JSON" > "${RESULT_JSON}.tmp" && \
            mv "${RESULT_JSON}.tmp" "$RESULT_JSON" || true
    fi
fi

if [[ -n "${RESULTS_DIR:-}" && -d "$CANDIDATE_DIR" ]]; then
    cp -r "$CANDIDATE_DIR" "${RESULTS_DIR}/${SCENARIO_NAME}_candidate"
fi

cp "$OUTPUT_FILE" "${RESULTS_DIR}/${SCENARIO_NAME}_output.txt" 2>/dev/null || true
rm -rf "$CANDIDATE_DIR"
rm -f "$OUTPUT_FILE"
cleanup_fixture "$FIXTURE_DIR"
exit $RESULT
