#!/usr/bin/env bash
# Scenario: open_story golden-reference quality evaluation.
# Fixture: full venice project repo at the pre-open_story state (workshop/00_main).
# T1: structural assertions on file operations and section presence.
# T2: LLM-as-judge scoring against the golden reference.
#
# Interactive: yes — the command may ask about uncommitted changes and branch handling.
# Prerequisites: claude CLI (or $EVAL_TOOL), ANTHROPIC_API_KEY + EVAL_JUDGE_MODEL for T2.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/eval_helpers.sh"

SCENARIO_NAME="open_story_golden_quality"
GOLDEN_OUTPUT=$(get_golden_output_dir "open_story")
GOLDEN_INPUT=$(get_golden_input "open_story")
RUBRIC="$EVAL_ROOT/rubrics/open_story_rubric.md"

# --- Setup ---
echo -e "\n  ${BOLD}Setup${RESET}"
FIXTURE_DIR=$(create_golden_fixture "open_story")
git -C "$FIXTURE_DIR" tag eval-baseline

# --- Run ---
OUTPUT_FILE=$(mktemp "/tmp/sdlc_eval_output_${SCENARIO_NAME}_XXXXXX")
echo -e "\n  ${BOLD}Command Execution${RESET}"
echo -e "  ${DIM}Running $EVAL_TOOL for $SCENARIO_NAME (this may take several minutes)...${RESET}"
run_eval_with_args "$FIXTURE_DIR" "$COMMANDS_DIR/sdlc_open_story.md" "$OUTPUT_FILE" "5.1.2" || true
echo -e "  ${DIM}Command completed in ${EVAL_DURATION}s${RESET}"

# --- T1: Structural Assertions ---
echo -e "\n  ${BOLD}T1: Structural Assertions${RESET}"
begin_assertions

STORY_DIR="$FIXTURE_DIR/docs/userstories"
REPORT_DIR="$FIXTURE_DIR/docs/reports"
WIP_FILE="$STORY_DIR/5.1.2-navigate-leg-segment-WIP.md"

echo -e "  ${DIM}Checking file operations...${RESET}"
assert_file_not_exists "$STORY_DIR/5.1.2-navigate-leg-segment.md" \
    "Original story file removed (git mv)"

assert_file_exists "$WIP_FILE" \
    "WIP story file created"

if [[ -f "$WIP_FILE" ]] && grep -qi "## Original user story" "$WIP_FILE"; then
    assertion_pass "Original user story section present"
else
    assertion_fail "Original user story section present"
fi

echo -e "  ${DIM}Checking required sections...${RESET}"
SECTION_COUNT=0
for pattern in \
    "## Description" \
    "## Fields|## MVI|## Artefact" \
    "## Intent URI|## Endpoint|## URL" \
    "## Files to Modify" \
    "## Unit Test" \
    "## Documentation" \
    "## Security" \
    "## Performance" \
    "## GDPR|## Sensitive" \
    "## Analytics" \
    "## Non.Functional|## Other Non" \
    "## Definition of Done|## Completion"; do
    if [[ -f "$WIP_FILE" ]] && grep -qiE "$pattern" "$WIP_FILE"; then
        SECTION_COUNT=$((SECTION_COUNT + 1))
    fi
done

if [[ "$SECTION_COUNT" -ge 10 ]]; then
    assertion_pass "Required sections present ($SECTION_COUNT/12)"
else
    assertion_fail "Required sections present" "found $SECTION_COUNT/12, expected >= 10"
fi

echo -e "  ${DIM}Checking index and report...${RESET}"
if [[ -f "$STORY_DIR/index.md" ]] && grep -q "WIP" "$STORY_DIR/index.md"; then
    assertion_pass "Index updated with WIP filename"
else
    assertion_fail "Index updated with WIP filename"
fi

assert_file_exists "$REPORT_DIR/5.1.2-navigate-leg-segment.html" \
    "Report file exists"

if [[ -f "$REPORT_DIR/5.1.2-navigate-leg-segment.html" ]] && \
   grep -qi "Command Metrics" "$REPORT_DIR/5.1.2-navigate-leg-segment.html"; then
    assertion_pass "Report contains Command Metrics"
else
    assertion_fail "Report contains Command Metrics"
fi

# --- T2: LLM-as-judge ---
echo -e "\n  ${BOLD}T2: LLM-as-judge${RESET}"

CANDIDATE_DIR=$(collect_candidate_from_baseline "$FIXTURE_DIR")
JUDGE_RESULT="$FIXTURE_DIR/judge_result.json"

run_judge "$RUBRIC" "$GOLDEN_OUTPUT" "$CANDIDATE_DIR" "$JUDGE_RESULT" "$GOLDEN_INPUT" || true

assert_judge_score "$JUDGE_RESULT" "section_completeness" 10 "section_completeness >= 10/12"
assert_judge_score "$JUDGE_RESULT" "what_not_how" 3 "what_not_how >= 3/5"
assert_judge_score "$JUDGE_RESULT" "acceptance_criteria_quality" 3 "acceptance_criteria_quality >= 3/5"
assert_judge_score "$JUDGE_RESULT" "analytics_section_quality" 3 "analytics_section_quality >= 3/5"
assert_judge_score "$JUDGE_RESULT" "content_preservation" 1 "content_preservation = 1 (boolean)"
assert_judge_score "$JUDGE_RESULT" "overall_coherence" 3 "overall_coherence >= 3/5"

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
    rm -rf "${RESULTS_DIR}/${SCENARIO_NAME}_candidate"
    cp -r "$CANDIDATE_DIR" "${RESULTS_DIR}/${SCENARIO_NAME}_candidate"
fi

cp "$OUTPUT_FILE" "${RESULTS_DIR}/${SCENARIO_NAME}_output.txt" 2>/dev/null || true
rm -rf "$CANDIDATE_DIR"
rm -f "$OUTPUT_FILE"
cleanup_fixture "$FIXTURE_DIR"
exit $RESULT
