#!/usr/bin/env bash
# Run ONLY the T2 LLM-as-judge evaluation for one or more golden quality scenarios.
#
# This skips the expensive command execution (T1 + command run) and evaluates
# candidate artifacts directly against the golden reference. Useful for:
#   - Re-running the judge after changing a rubric
#   - Evaluating saved candidate artifacts from a previous run
#   - Sanity-checking the judge by scoring the golden reference against itself
#   - Testing with a different judge model without re-running the pipeline
#
# Usage:
#   ./run_judge_only.sh open_story /path/to/candidate_dir
#   ./run_judge_only.sh propose_change /path/to/candidate_dir
#   ./run_judge_only.sh --self-check open_story          # score golden against itself
#   ./run_judge_only.sh --self-check all                 # self-check all 4 commands
#   ./run_judge_only.sh --from-fixture /path/to/fixture open_story  # collect from fixture
#
# Environment variables:
#   ANTHROPIC_API_KEY     Required. Your Anthropic API key.
#   EVAL_JUDGE_MODEL      Required. Model ID for the judge (e.g. claude-sonnet-5-5).
#   EVAL_JUDGE_MAX_TOKENS Optional. Max output tokens for judge response (default: 4096).
#
# The judge result JSON is written to results/<command>_judge_only.json and printed
# as a score summary table.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/eval_helpers.sh"

RESULTS_DIR="${RESULTS_DIR:-$EVAL_ROOT/results}"
export RESULTS_DIR
mkdir -p "$RESULTS_DIR"

COMMANDS=(open_story propose_change implement_change verify_story)

usage() {
    echo "Usage: $(basename "$0") [options] <command> <candidate_dir>"
    echo "       $(basename "$0") --self-check <command|all>"
    echo "       $(basename "$0") --from-fixture <fixture_dir> <command>"
    echo ""
    echo "Commands: ${COMMANDS[*]}"
    echo ""
    echo "Options:"
    echo "  --self-check       Score the golden reference against itself (sanity check)"
    echo "  --from-fixture DIR Collect candidate artifacts from a fixture working directory"
    echo "  --output FILE      Write judge result to a custom path"
    echo ""
    echo "Environment:"
    echo "  ANTHROPIC_API_KEY      Required"
    echo "  EVAL_JUDGE_MODEL       Required (e.g. claude-sonnet-5-5)"
    echo "  EVAL_JUDGE_MAX_TOKENS  Optional (default: 4096)"
    exit 1
}

validate_command() {
    local cmd="$1"
    for valid in "${COMMANDS[@]}"; do
        [[ "$cmd" == "$valid" ]] && return 0
    done
    echo -e "${RED}ERROR${RESET}: Unknown command '$cmd'."
    echo "Valid commands: ${COMMANDS[*]}"
    exit 1
}

print_scores() {
    local result_file="$1"
    local command_name="$2"

    if [[ ! -f "$result_file" ]]; then
        echo -e "  ${RED}No result file${RESET}"
        return
    fi

    local skipped error
    skipped=$(jq -r '.skipped // false' "$result_file" 2>/dev/null)
    error=$(jq -r '.error // false' "$result_file" 2>/dev/null)

    if [[ "$skipped" == "true" ]]; then
        local reason
        reason=$(jq -r '.reason // "unknown"' "$result_file" 2>/dev/null)
        echo -e "  ${YELLOW}SKIPPED${RESET}: $reason"
        return
    fi
    if [[ "$error" == "true" ]]; then
        local reason
        reason=$(jq -r '.reason // .http_code // "unknown"' "$result_file" 2>/dev/null)
        echo -e "  ${RED}ERROR${RESET}: $reason"
        return
    fi

    echo ""
    echo -e "  ${BOLD}Scores: $command_name${RESET}"
    echo "  ──────────────────────────────────────────────────"
    printf "  %-30s %6s %6s  %s\n" "Criterion" "Score" "Max" "Rationale"
    echo "  ──────────────────────────────────────────────────"

    jq -r '.criteria | to_entries[] | "  \(.key)|\(.value.score)|\(.value.max)|\(.value.rationale // "-")"' \
        "$result_file" 2>/dev/null | while IFS='|' read -r name score max rationale; do
        local color="$GREEN"
        if [[ -n "$max" && "$max" != "null" ]]; then
            local pct
            pct=$(echo "scale=0; $score * 100 / $max" | bc 2>/dev/null || echo 0)
            if [[ "$pct" -lt 60 ]]; then
                color="$RED"
            elif [[ "$pct" -lt 80 ]]; then
                color="$YELLOW"
            fi
        fi
        local short_rationale="${rationale:0:60}"
        [[ ${#rationale} -gt 60 ]] && short_rationale="${short_rationale}..."
        printf "  %-30s ${color}%5s${RESET} %5s  ${DIM}%s${RESET}\n" "$name" "$score" "$max" "$short_rationale"
    done

    echo "  ──────────────────────────────────────────────────"

    local summary
    summary=$(jq -r '.summary // empty' "$result_file" 2>/dev/null)
    [[ -n "$summary" ]] && echo -e "  ${DIM}Summary: $summary${RESET}"

    local input_tokens output_tokens
    input_tokens=$(jq -r '.judge_usage.input_tokens // "?"' "$result_file" 2>/dev/null)
    output_tokens=$(jq -r '.judge_usage.output_tokens // "?"' "$result_file" 2>/dev/null)
    echo -e "  ${DIM}Judge tokens: ${input_tokens} in / ${output_tokens} out${RESET}"
}

run_judge_for_command() {
    local command_name="$1"
    local candidate_dir="$2"
    local result_file="$3"

    local golden_output golden_input rubric
    golden_output=$(get_golden_output_dir "$command_name")
    golden_input=$(get_golden_input "$command_name")
    rubric="$EVAL_ROOT/rubrics/${command_name}_rubric.md"

    if [[ ! -d "$golden_output" ]]; then
        echo -e "  ${RED}ERROR${RESET}: Golden output not found: $golden_output"
        return 1
    fi
    if [[ ! -f "$rubric" ]]; then
        echo -e "  ${RED}ERROR${RESET}: Rubric not found: $rubric"
        return 1
    fi
    if [[ ! -d "$candidate_dir" ]]; then
        echo -e "  ${RED}ERROR${RESET}: Candidate directory not found: $candidate_dir"
        return 1
    fi

    local candidate_count
    candidate_count=$(find "$candidate_dir" -type f | wc -l)
    echo -e "  ${DIM}Candidate: $candidate_dir ($candidate_count files)${RESET}"
    echo -e "  ${DIM}Golden: $golden_output ($(find "$golden_output" -type f | wc -l) files)${RESET}"
    echo -e "  ${DIM}Rubric: $rubric${RESET}"
    [[ -f "$golden_input" ]] && echo -e "  ${DIM}Input: $golden_input${RESET}"

    run_judge "$rubric" "$golden_output" "$candidate_dir" "$result_file" "$golden_input"
}

# --- Parse arguments ---
SELF_CHECK=false
FROM_FIXTURE=""
CUSTOM_OUTPUT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --self-check)
            SELF_CHECK=true
            shift
            ;;
        --from-fixture)
            FROM_FIXTURE="$2"
            shift 2
            ;;
        --output)
            CUSTOM_OUTPUT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            break
            ;;
    esac
done

if [[ $# -lt 1 ]]; then
    usage
fi

COMMAND="$1"
CANDIDATE_DIR="${2:-}"

echo ""
echo -e "${BOLD}SDLC T2 Judge-Only Evaluation${RESET}"
echo -e "${DIM}Model: ${EVAL_JUDGE_MODEL:-not set}${RESET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# --- Self-check mode ---
if $SELF_CHECK; then
    if [[ "$COMMAND" == "all" ]]; then
        CMDS=("${COMMANDS[@]}")
    else
        validate_command "$COMMAND"
        CMDS=("$COMMAND")
    fi

    TOTAL=0
    PASSED=0
    for cmd in "${CMDS[@]}"; do
        TOTAL=$((TOTAL + 1))
        echo ""
        echo -e "${BOLD}Self-check: $cmd${RESET}"
        echo -e "${DIM}Scoring golden reference against itself (expect near-perfect scores)${RESET}"

        golden_output=$(get_golden_output_dir "$cmd")
        result_file="${CUSTOM_OUTPUT:-$RESULTS_DIR/${cmd}_judge_self_check.json}"

        if run_judge_for_command "$cmd" "$golden_output" "$result_file"; then
            PASSED=$((PASSED + 1))
            print_scores "$result_file" "$cmd"
        else
            print_scores "$result_file" "$cmd"
        fi
    done

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BOLD}Self-check complete: ${PASSED}/${TOTAL} commands judged successfully.${RESET}"
    exit 0
fi

# --- From-fixture mode ---
if [[ -n "$FROM_FIXTURE" ]]; then
    validate_command "$COMMAND"

    if [[ ! -d "$FROM_FIXTURE" ]]; then
        echo -e "${RED}ERROR${RESET}: Fixture directory not found: $FROM_FIXTURE"
        exit 1
    fi

    echo -e "${DIM}Collecting candidate artifacts from fixture baseline diff...${RESET}"

    BASELINE_REF="eval-baseline"
    if ! git -C "$FROM_FIXTURE" rev-parse "$BASELINE_REF" >/dev/null 2>&1; then
        BASELINE_REF=$(git -C "$FROM_FIXTURE" rev-list --max-parents=0 HEAD 2>/dev/null)
    fi

    CANDIDATE_DIR=$(mktemp -d "/tmp/sdlc_eval_candidate_XXXXXX")
    changed_files=$(cd "$FROM_FIXTURE" && {
        git diff --name-only "$BASELINE_REF" HEAD 2>/dev/null
        git diff --name-only HEAD 2>/dev/null
        git ls-files --others --exclude-standard 2>/dev/null
    } | sort -u)

    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        if [[ -f "$FROM_FIXTURE/$file" ]]; then
            mkdir -p "$(dirname "$CANDIDATE_DIR/$file")"
            cp "$FROM_FIXTURE/$file" "$CANDIDATE_DIR/$file"
        fi
    done <<< "$changed_files"

    result_file="${CUSTOM_OUTPUT:-$RESULTS_DIR/${COMMAND}_judge_only.json}"

    echo ""
    echo -e "${BOLD}Judge: $COMMAND${RESET}"
    if run_judge_for_command "$COMMAND" "$CANDIDATE_DIR" "$result_file"; then
        print_scores "$result_file" "$COMMAND"
    else
        print_scores "$result_file" "$COMMAND"
    fi

    rm -rf "$CANDIDATE_DIR"
    exit 0
fi

# --- Standard mode: command + candidate directory ---
validate_command "$COMMAND"

if [[ -z "$CANDIDATE_DIR" ]]; then
    echo -e "${RED}ERROR${RESET}: Candidate directory required."
    echo "Usage: $(basename "$0") $COMMAND /path/to/candidate_dir"
    echo "   or: $(basename "$0") --self-check $COMMAND"
    exit 1
fi

result_file="${CUSTOM_OUTPUT:-$RESULTS_DIR/${COMMAND}_judge_only.json}"

echo ""
echo -e "${BOLD}Judge: $COMMAND${RESET}"
if run_judge_for_command "$COMMAND" "$CANDIDATE_DIR" "$result_file"; then
    print_scores "$result_file" "$COMMAND"
else
    print_scores "$result_file" "$COMMAND"
fi

echo ""
echo -e "${DIM}Result: $result_file${RESET}"
