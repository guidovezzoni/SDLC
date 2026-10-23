#!/usr/bin/env bash
# Scenario: verify_story golden-reference quality evaluation.
# Fixture: full venice project repo after implement_change (workshop/03_sdlc_implement_changes).
#   Uses a two-tarball setup: main branch has the clean project state (open_story tarball)
#   and the feature branch has the post-implementation state (verify_story tarball), so
#   git diff main...HEAD returns a meaningful file list for the verify command.
# T1: structural assertions on lifecycle operations and gate results.
# T2: LLM-as-judge scoring against the golden reference.
#
# Interactive: yes — the command may prompt about device connectivity and gate failures.
# Prerequisites: claude CLI (or $EVAL_TOOL), Android SDK, openspec CLI,
#   ANTHROPIC_API_KEY + EVAL_JUDGE_MODEL for T2.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/eval_helpers.sh"

SCENARIO_NAME="verify_story_golden_quality"
GOLDEN_OUTPUT=$(get_golden_output_dir "verify_story")
RUBRIC="$EVAL_ROOT/rubrics/verify_story_rubric.md"

# --- Setup (two-tarball approach for meaningful git diff) ---
echo -e "\n  ${BOLD}Setup${RESET}"
FIXTURE_DIR=$(mktemp -d "/tmp/sdlc_eval_golden_verify_story_XXXXXX")

progress "Extracting main branch (pre-SDLC state)..."
# Main branch: clean project state before any SDLC commands
tar xzf "$EVAL_ROOT/goldenreference/open_story/repo-snapshot.tar.gz" -C "$FIXTURE_DIR"
git -C "$FIXTURE_DIR" init --quiet
git -C "$FIXTURE_DIR" add -A
git -C "$FIXTURE_DIR" -c user.name="eval" -c user.email="eval@test" \
    commit -m "golden reference baseline" --quiet
git -C "$FIXTURE_DIR" branch -M main

progress "Creating feature branch (post-implementation state)..."
# Feature branch: state after implement_change (ready for verification)
git -C "$FIXTURE_DIR" checkout -b feature/5.1.2-navigate-leg-segment --quiet
git -C "$FIXTURE_DIR" rm -rf --quiet .
git -C "$FIXTURE_DIR" -c user.name="eval" -c user.email="eval@test" \
    commit -m "clear tree" --quiet --allow-empty
tar xzf "$EVAL_ROOT/goldenreference/verify_story/repo-snapshot.tar.gz" -C "$FIXTURE_DIR"
add_google_services_stub "$FIXTURE_DIR"
git -C "$FIXTURE_DIR" add -A
git -C "$FIXTURE_DIR" -c user.name="eval" -c user.email="eval@test" \
    commit -m "implement story 5.1.2" --quiet
add_local_remote "$FIXTURE_DIR"
git -C "$FIXTURE_DIR" push --quiet -u origin main feature/5.1.2-navigate-leg-segment
git -C "$FIXTURE_DIR" tag eval-baseline
progress "Fixture ready: $FIXTURE_DIR"

# --- Run ---
OUTPUT_FILE=$(mktemp "/tmp/sdlc_eval_output_${SCENARIO_NAME}_XXXXXX")
EVAL_CMD=$(mktemp "/tmp/sdlc_eval_cmd_${SCENARIO_NAME}_XXXXXX.md")
{
    echo "IMPORTANT: This is an automated evaluation run. If no Android device is connected,"
    echo "skip on-device tests and proceed with all remaining gates. If a build or test step"
    echo "fails, record the failure and continue with the remaining gates. Complete the full"
    echo "lifecycle: rename story, update index, archive change, sync spec, write report."
    echo ""
    cat "$COMMANDS_DIR/sdlc_verify_story.md"
} > "$EVAL_CMD"

echo -e "\n  ${BOLD}Command Execution${RESET}"
echo -e "  ${DIM}Running $EVAL_TOOL for $SCENARIO_NAME (this may take several minutes)...${RESET}"
run_eval_with_args "$FIXTURE_DIR" "$EVAL_CMD" "$OUTPUT_FILE" "5.1.2" || true
echo -e "  ${DIM}Command completed in ${EVAL_DURATION}s${RESET}"
rm -f "$EVAL_CMD"

# --- T1: Structural Assertions ---
echo -e "\n  ${BOLD}T1: Structural Assertions${RESET}"
begin_assertions

STORY_DIR="$FIXTURE_DIR/docs/userstories"
REPORT="$FIXTURE_DIR/docs/reports/5.1.2-navigate-leg-segment.html"

echo -e "  ${DIM}Checking story lifecycle...${RESET}"
# Story renamed to DONE
assert_file_exists "$STORY_DIR/5.1.2-navigate-leg-segment-DONE.md" \
    "Story file renamed to -DONE.md"

# No 5.1.2 WIP file remains
if [[ ! -f "$STORY_DIR/5.1.2-navigate-leg-segment-WIP.md" ]]; then
    assertion_pass "5.1.2 WIP file removed"
else
    assertion_fail "5.1.2 WIP file removed" "still exists"
fi

# Index references 5.1.2 DONE
if [[ -f "$STORY_DIR/index.md" ]] && grep -q "5.1.2.*DONE" "$STORY_DIR/index.md"; then
    assertion_pass "Index updated with 5.1.2 DONE filename"
else
    assertion_fail "Index updated with 5.1.2 DONE filename"
fi

echo -e "  ${DIM}Checking archive and spec sync...${RESET}"
# navigate-leg-segment change archived
ARCHIVE_DIR=$(find "$FIXTURE_DIR/openspec/changes/archive" -mindepth 1 -maxdepth 1 -type d \
    -name "*navigate-leg-segment*" 2>/dev/null | head -1)
if [[ -n "$ARCHIVE_DIR" && -d "$ARCHIVE_DIR" ]]; then
    assertion_pass "Change archived: $(basename "$ARCHIVE_DIR")"
else
    assertion_fail "navigate-leg-segment change archived"
fi

# Active navigate-leg-segment directory removed
if [[ ! -d "$FIXTURE_DIR/openspec/changes/navigate-leg-segment" ]]; then
    assertion_pass "Active change directory removed"
else
    assertion_fail "Active change directory removed" "navigate-leg-segment still exists"
fi

# leg-navigation spec synced
if find "$FIXTURE_DIR/openspec/specs" -path "*/leg-navigation/spec.md" 2>/dev/null | grep -q .; then
    assertion_pass "Living spec synced (leg-navigation)"
else
    assertion_fail "Living spec synced" "leg-navigation/spec.md not found under openspec/specs/"
fi

echo -e "  ${DIM}Checking report and gates...${RESET}"
# Report was updated by verify_story (not just pre-existing from implementation)
REPORT_REL="docs/reports/5.1.2-navigate-leg-segment.html"
REPORT_CHANGED=$(git -C "$FIXTURE_DIR" diff eval-baseline -- "$REPORT_REL" 2>/dev/null | wc -l)
if [[ "$REPORT_CHANGED" -gt 0 ]]; then
    assertion_pass "Report modified from baseline ($REPORT_CHANGED diff lines)"

    GATE_KEYWORDS=0
    for gate in "TODO" "security" "build\|static analysis\|detekt\|lint" "unit test" \
                "coverage" "Definition of Done\|DoD"; do
        if grep -qiE "$gate" "$REPORT"; then
            GATE_KEYWORDS=$((GATE_KEYWORDS + 1))
        fi
    done
    if [[ "$GATE_KEYWORDS" -ge 4 ]]; then
        assertion_pass "Report contains gate results ($GATE_KEYWORDS gate keywords found)"
    else
        assertion_fail "Report contains gate results" "found $GATE_KEYWORDS gate keywords, expected >= 4"
    fi

    if grep -qi "PASS" "$REPORT"; then
        assertion_pass "Report contains PASS outcome"
    else
        assertion_fail "Report contains PASS outcome"
    fi
else
    assertion_fail "Report modified from baseline" "report unchanged — verify_story did not update it"
    assertion_fail "Report contains gate results" "report not updated"
    assertion_fail "Report contains PASS outcome" "report not updated"
fi

# --- T2: LLM-as-judge ---
echo -e "\n  ${BOLD}T2: LLM-as-judge${RESET}"

CANDIDATE_DIR=$(collect_candidate_from_baseline "$FIXTURE_DIR")
JUDGE_RESULT="$FIXTURE_DIR/judge_result.json"

run_judge "$RUBRIC" "$GOLDEN_OUTPUT" "$CANDIDATE_DIR" "$JUDGE_RESULT" || true

assert_judge_score "$JUDGE_RESULT" "gate_coverage" 7 "gate_coverage >= 7/10"
assert_judge_score "$JUDGE_RESULT" "report_completeness" 3 "report_completeness >= 3/5"
assert_judge_score "$JUDGE_RESULT" "lifecycle_correctness" 1 "lifecycle_correctness = 1 (boolean)"
assert_judge_score "$JUDGE_RESULT" "outcome_justified" 3 "outcome_justified >= 3/5"

# --- Report & Cleanup ---
rm -rf "$CANDIDATE_DIR"
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

cp "$OUTPUT_FILE" "${RESULTS_DIR}/${SCENARIO_NAME}_output.txt" 2>/dev/null || true
rm -f "$OUTPUT_FILE"

# cleanup_fixture expects /tmp/sdlc_eval_* prefix
if [[ -d "$FIXTURE_DIR" && "$FIXTURE_DIR" == /tmp/sdlc_eval_* ]]; then
    rm -rf "$FIXTURE_DIR" "${FIXTURE_DIR}_remote.git"
fi
exit $RESULT
