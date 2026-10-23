#!/usr/bin/env bash
# Scenario: propose_change golden-reference quality evaluation.
# Fixture: full venice project repo after open_story (workshop/01_sdlc_open_story).
# T1: structural assertions on change artifacts and task structure.
# T2: LLM-as-judge scoring against the golden reference.
#
# Interactive: yes — the command surfaces questions about the story to the user.
# Prerequisites: claude CLI (or $EVAL_TOOL), ANTHROPIC_API_KEY + EVAL_JUDGE_MODEL for T2.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/eval_helpers.sh"

SCENARIO_NAME="propose_change_golden_quality"
GOLDEN_OUTPUT=$(get_golden_output_dir "propose_change")
RUBRIC="$EVAL_ROOT/rubrics/propose_change_rubric.md"

# --- Setup ---
FIXTURE_DIR=$(create_golden_fixture "propose_change")
git -C "$FIXTURE_DIR" branch -M main
git -C "$FIXTURE_DIR" checkout -b feature/5.1.2-navigate-leg-segment --quiet
git -C "$FIXTURE_DIR" tag eval-baseline

# --- Run ---
OUTPUT_FILE="$FIXTURE_DIR/eval_output.txt"
echo -e "  ${DIM}Running $EVAL_TOOL for $SCENARIO_NAME...${RESET}"
echo -e "  ${YELLOW}This scenario is interactive — answer questions when prompted.${RESET}"
run_eval_with_args "$FIXTURE_DIR" "$COMMANDS_DIR/sdlc_propose_change.md" "$OUTPUT_FILE" "5.1.2" || true

# --- T1: Structural Assertions ---
echo -e "\n  ${BOLD}T1: Structural Assertions${RESET}"
begin_assertions

# Find the change directory (name may vary)
CHANGE_DIR=$(find "$FIXTURE_DIR/openspec/changes" -mindepth 1 -maxdepth 1 -type d ! -name archive 2>/dev/null | head -1)

if [[ -n "$CHANGE_DIR" && -d "$CHANGE_DIR" ]]; then
    assertion_pass "Change directory created: $(basename "$CHANGE_DIR")"
else
    assertion_fail "Change directory created" "no directory found under openspec/changes/"
fi

if [[ -n "$CHANGE_DIR" ]]; then
    assert_file_exists "$CHANGE_DIR/proposal.md" "proposal.md exists"
    assert_file_exists "$CHANGE_DIR/design.md" "design.md exists"
    assert_file_exists "$CHANGE_DIR/tasks.md" "tasks.md exists"
    assert_file_exists "$CHANGE_DIR/.openspec.yaml" ".openspec.yaml exists"

    # At least one spec file under specs/
    SPEC_COUNT=$(find "$CHANGE_DIR/specs" -name "spec.md" 2>/dev/null | wc -l)
    if [[ "$SPEC_COUNT" -ge 1 ]]; then
        assertion_pass "At least one spec file exists ($SPEC_COUNT found)"
    else
        assertion_fail "At least one spec file exists" "none found under specs/"
    fi

    TASKS_FILE="$CHANGE_DIR/tasks.md"

    # Checkbox format
    if grep -qE '\- \[[ x]\]' "$TASKS_FILE" 2>/dev/null; then
        assertion_pass "tasks.md has checkbox format"
    else
        assertion_fail "tasks.md has checkbox format"
    fi

    # Section structure (numbered sections)
    TASK_SECTIONS=$(grep -cE '^#{1,3} [0-9]+' "$TASKS_FILE" 2>/dev/null || true)
    if [[ "$TASK_SECTIONS" -ge 3 ]]; then
        assertion_pass "tasks.md has section structure ($TASK_SECTIONS sections)"
    else
        assertion_fail "tasks.md has section structure" "found $TASK_SECTIONS sections, expected >= 3"
    fi

    # BDD: look for test+implementation task patterns (GIVEN/WHEN/THEN keywords)
    if grep -qiE "GIVEN.*WHEN.*THEN|Given.*When.*Then" "$TASKS_FILE" 2>/dev/null; then
        assertion_pass "tasks.md contains BDD test descriptions"
    else
        assertion_fail "tasks.md contains BDD test descriptions"
    fi
else
    # Skip file-level assertions if change directory wasn't created
    for skip in "proposal.md" "design.md" "tasks.md" ".openspec.yaml" "spec files" \
                "checkbox format" "section structure" "BDD descriptions"; do
        assertion_fail "$skip" "change directory not found"
    done
fi

# Report updated
REPORT="$FIXTURE_DIR/docs/reports/5.1.2-navigate-leg-segment.html"
if [[ -f "$REPORT" ]] && grep -qi "propos" "$REPORT"; then
    assertion_pass "Report updated with proposal section"
else
    assertion_fail "Report updated with proposal section"
fi

# --- T2: LLM-as-judge ---
echo -e "\n  ${BOLD}T2: LLM-as-judge${RESET}"

CANDIDATE_DIR=$(collect_candidate_from_baseline "$FIXTURE_DIR")
JUDGE_RESULT="$FIXTURE_DIR/judge_result.json"

run_judge "$RUBRIC" "$GOLDEN_OUTPUT" "$CANDIDATE_DIR" "$JUDGE_RESULT" || true

assert_judge_score "$JUDGE_RESULT" "proposal_completeness" 3 "proposal_completeness >= 3/5"
assert_judge_score "$JUDGE_RESULT" "design_quality" 3 "design_quality >= 3/5"
assert_judge_score "$JUDGE_RESULT" "bdd_task_structure" 3 "bdd_task_structure >= 3/5"
assert_judge_score "$JUDGE_RESULT" "task_granularity" 3 "task_granularity >= 3/5"
assert_judge_score "$JUDGE_RESULT" "question_quality" 3 "question_quality >= 3/5"
assert_judge_score "$JUDGE_RESULT" "story_alignment" 3 "story_alignment >= 3/5"

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
