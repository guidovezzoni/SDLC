#!/usr/bin/env bash
# SDLC Eval Results Comparison
#
# Compares two aggregate JSON result files and highlights regressions,
# improvements, new/removed scenarios, L3 score diffs, and timing changes.
#
# Usage:
#   ./docs/sdlc/evals/compare_results.sh results/baseline.json results/candidate.json
#   ./docs/sdlc/evals/compare_results.sh --tool-diff results/claude.json results/opencode.json
#
# Exit codes:
#   0 — no regressions
#   1 — regressions detected
#   2 — usage error

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNS_DIR="$SCRIPT_DIR/results/runs"

usage() {
    echo "Usage: $(basename "$0") [--tool-diff] <baseline> <candidate>"
    echo ""
    echo "Compares two aggregate eval result files."
    echo ""
    echo "Arguments can be:"
    echo "  - A full path to an aggregate JSON file"
    echo "  - A run directory name (resolved under results/runs/<name>/aggregate.json)"
    echo "  - 'latest' (resolved via the latest symlink)"
    echo ""
    echo "Options:"
    echo "  --tool-diff    Label columns as tools instead of baseline/candidate"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0") my_baseline latest"
    echo "  $(basename "$0") 2026-10-23T191644_claude 2026-10-24T103012_opencode"
    echo "  $(basename "$0") results/runs/my_baseline/aggregate.json results/runs/latest/aggregate.json"
    echo "  $(basename "$0") --tool-diff results/runs/claude_run/aggregate.json results/runs/opencode_run/aggregate.json"
    exit 2
}

resolve_aggregate() {
    local arg="$1"
    if [[ -f "$arg" ]]; then
        echo "$arg"
    elif [[ -f "$RUNS_DIR/$arg/aggregate.json" ]]; then
        echo "$RUNS_DIR/$arg/aggregate.json"
    else
        echo -e "${RED}ERROR${RESET}: cannot resolve '$arg' — not a file and no $RUNS_DIR/$arg/aggregate.json found" >&2
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

TOOL_DIFF=false
BASELINE=""
CANDIDATE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --tool-diff)
            TOOL_DIFF=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            if [[ -z "$BASELINE" ]]; then
                BASELINE="$1"
            elif [[ -z "$CANDIDATE" ]]; then
                CANDIDATE="$1"
            else
                echo "Error: unexpected argument '$1'"
                usage
            fi
            shift
            ;;
    esac
done

if [[ -z "$BASELINE" || -z "$CANDIDATE" ]]; then
    echo "Error: two result references required."
    usage
fi

BASELINE=$(resolve_aggregate "$BASELINE") || exit 2
CANDIDATE=$(resolve_aggregate "$CANDIDATE") || exit 2

# ---------------------------------------------------------------------------
# jq check (needed for score and timing comparison)
# ---------------------------------------------------------------------------

HAS_JQ=false
if command -v jq > /dev/null 2>&1; then
    HAS_JQ=true
fi

SCORE_REGRESSIONS_COUNT=0
SCORE_IMPROVEMENTS_COUNT=0

# ---------------------------------------------------------------------------
# Parse JSON results into associative arrays
# ---------------------------------------------------------------------------

declare -A BASELINE_RESULTS
declare -A BASELINE_PASSED
declare -A BASELINE_FAILED
declare -A BASELINE_TOTAL
declare -A CANDIDATE_RESULTS
declare -A CANDIDATE_PASSED
declare -A CANDIDATE_FAILED
declare -A CANDIDATE_TOTAL

parse_results() {
    local file="$1"
    local prefix="$2"

    local scenarios
    scenarios=$(grep -o '"scenario": *"[^"]*"' "$file" | sed 's/"scenario": *"//;s/"//')

    local results
    results=$(grep -o '"result": *"[^"]*"' "$file" | sed 's/"result": *"//;s/"//')

    local passed_values
    passed_values=$(grep -o '"passed": *[0-9]*' "$file" | sed 's/"passed": *//')

    local failed_values
    failed_values=$(grep -o '"failed": *[0-9]*' "$file" | sed 's/"failed": *//')

    local total_values
    total_values=$(grep -o '"total": *[0-9]*' "$file" | sed 's/"total": *//')

    local -a scenario_arr
    mapfile -t scenario_arr <<< "$scenarios"

    local -a result_arr
    mapfile -t result_arr <<< "$results"

    local -a passed_arr
    mapfile -t passed_arr <<< "$passed_values"

    local -a failed_arr
    mapfile -t failed_arr <<< "$failed_values"

    local -a total_arr
    mapfile -t total_arr <<< "$total_values"

    for i in "${!scenario_arr[@]}"; do
        local scenario="${scenario_arr[$i]}"
        [[ -z "$scenario" ]] && continue

        if [[ "$prefix" == "BASELINE" ]]; then
            BASELINE_RESULTS["$scenario"]="${result_arr[$i]}"
            BASELINE_PASSED["$scenario"]="${passed_arr[$i]}"
            BASELINE_FAILED["$scenario"]="${failed_arr[$i]}"
            BASELINE_TOTAL["$scenario"]="${total_arr[$i]}"
        else
            CANDIDATE_RESULTS["$scenario"]="${result_arr[$i]}"
            CANDIDATE_PASSED["$scenario"]="${passed_arr[$i]}"
            CANDIDATE_FAILED["$scenario"]="${failed_arr[$i]}"
            CANDIDATE_TOTAL["$scenario"]="${total_arr[$i]}"
        fi
    done
}

parse_results "$BASELINE" "BASELINE"
parse_results "$CANDIDATE" "CANDIDATE"

# ---------------------------------------------------------------------------
# Compute all unique scenarios
# ---------------------------------------------------------------------------

declare -A ALL_SCENARIOS
for scenario in "${!BASELINE_RESULTS[@]}"; do
    ALL_SCENARIOS["$scenario"]=1
done
for scenario in "${!CANDIDATE_RESULTS[@]}"; do
    ALL_SCENARIOS["$scenario"]=1
done

SORTED_SCENARIOS=$(printf '%s\n' "${!ALL_SCENARIOS[@]}" | sort)

# ---------------------------------------------------------------------------
# Classify changes
# ---------------------------------------------------------------------------

REGRESSIONS=()
IMPROVEMENTS=()
UNCHANGED=()
NEW_SCENARIOS=()
REMOVED_SCENARIOS=()

while IFS= read -r scenario; do
    [[ -z "$scenario" ]] && continue

    local_baseline="${BASELINE_RESULTS[$scenario]:-}"
    local_candidate="${CANDIDATE_RESULTS[$scenario]:-}"

    if [[ -z "$local_baseline" && -n "$local_candidate" ]]; then
        NEW_SCENARIOS+=("$scenario")
    elif [[ -n "$local_baseline" && -z "$local_candidate" ]]; then
        REMOVED_SCENARIOS+=("$scenario")
    elif [[ "$local_baseline" == "PASS" && "$local_candidate" == "FAIL" ]]; then
        REGRESSIONS+=("$scenario")
    elif [[ "$local_baseline" == "FAIL" && "$local_candidate" == "PASS" ]]; then
        IMPROVEMENTS+=("$scenario")
    else
        UNCHANGED+=("$scenario")
    fi
done <<< "$SORTED_SCENARIOS"

# ---------------------------------------------------------------------------
# Labels
# ---------------------------------------------------------------------------

if $TOOL_DIFF; then
    LABEL_BASELINE="$(basename "$BASELINE" .json)"
    LABEL_CANDIDATE="$(basename "$CANDIDATE" .json)"
else
    LABEL_BASELINE="baseline"
    LABEL_CANDIDATE="candidate"
fi

# ---------------------------------------------------------------------------
# Output report
# ---------------------------------------------------------------------------

BASELINE_META=""
CANDIDATE_META=""
if $HAS_JQ; then
    b_tool=$(jq -r '.[0].tool // empty' "$BASELINE" 2>/dev/null)
    b_model=$(jq -r '.[0].model // empty' "$BASELINE" 2>/dev/null)
    c_tool=$(jq -r '.[0].tool // empty' "$CANDIDATE" 2>/dev/null)
    c_model=$(jq -r '.[0].model // empty' "$CANDIDATE" 2>/dev/null)
    [[ -n "$b_tool" || -n "$b_model" ]] && BASELINE_META=" (tool: ${b_tool:-?}, model: ${b_model:-default})"
    [[ -n "$c_tool" || -n "$c_model" ]] && CANDIDATE_META=" (tool: ${c_tool:-?}, model: ${c_model:-default})"
fi

echo ""
echo -e "${BOLD}SDLC Eval Comparison Report${RESET}"
echo -e "${DIM}$LABEL_BASELINE: $BASELINE${BASELINE_META}${RESET}"
echo -e "${DIM}$LABEL_CANDIDATE: $CANDIDATE${CANDIDATE_META}${RESET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Summary counts
TOTAL_SCENARIOS=${#ALL_SCENARIOS[@]}
echo ""
echo -e "${BOLD}Summary:${RESET} $TOTAL_SCENARIOS scenario(s) compared"
echo -e "  Regressions:  ${#REGRESSIONS[@]}"
echo -e "  Improvements: ${#IMPROVEMENTS[@]}"
echo -e "  Unchanged:    ${#UNCHANGED[@]}"
echo -e "  New:          ${#NEW_SCENARIOS[@]}"
echo -e "  Removed:      ${#REMOVED_SCENARIOS[@]}"

# Regressions (most important)
if [[ ${#REGRESSIONS[@]} -gt 0 ]]; then
    echo ""
    echo -e "${RED}${BOLD}REGRESSIONS (PASS → FAIL):${RESET}"
    for scenario in "${REGRESSIONS[@]}"; do
        local_b_passed="${BASELINE_PASSED[$scenario]:-0}"
        local_b_total="${BASELINE_TOTAL[$scenario]:-0}"
        local_c_passed="${CANDIDATE_PASSED[$scenario]:-0}"
        local_c_total="${CANDIDATE_TOTAL[$scenario]:-0}"
        local_c_failed="${CANDIDATE_FAILED[$scenario]:-0}"
        echo -e "  ${RED}▼${RESET} $scenario"
        echo -e "    ${DIM}$LABEL_BASELINE: PASS ($local_b_passed/$local_b_total assertions)${RESET}"
        echo -e "    ${RED}$LABEL_CANDIDATE: FAIL ($local_c_passed/$local_c_total assertions, $local_c_failed failed)${RESET}"
    done
fi

# Improvements
if [[ ${#IMPROVEMENTS[@]} -gt 0 ]]; then
    echo ""
    echo -e "${GREEN}${BOLD}IMPROVEMENTS (FAIL → PASS):${RESET}"
    for scenario in "${IMPROVEMENTS[@]}"; do
        local_b_passed="${BASELINE_PASSED[$scenario]:-0}"
        local_b_total="${BASELINE_TOTAL[$scenario]:-0}"
        local_b_failed="${BASELINE_FAILED[$scenario]:-0}"
        local_c_passed="${CANDIDATE_PASSED[$scenario]:-0}"
        local_c_total="${CANDIDATE_TOTAL[$scenario]:-0}"
        echo -e "  ${GREEN}▲${RESET} $scenario"
        echo -e "    ${DIM}$LABEL_BASELINE: FAIL ($local_b_passed/$local_b_total assertions, $local_b_failed failed)${RESET}"
        echo -e "    ${GREEN}$LABEL_CANDIDATE: PASS ($local_c_passed/$local_c_total assertions)${RESET}"
    done
fi

# New scenarios
if [[ ${#NEW_SCENARIOS[@]} -gt 0 ]]; then
    echo ""
    echo -e "${CYAN}${BOLD}NEW SCENARIOS (only in $LABEL_CANDIDATE):${RESET}"
    for scenario in "${NEW_SCENARIOS[@]}"; do
        local_c_result="${CANDIDATE_RESULTS[$scenario]}"
        local_c_passed="${CANDIDATE_PASSED[$scenario]:-0}"
        local_c_total="${CANDIDATE_TOTAL[$scenario]:-0}"
        if [[ "$local_c_result" == "PASS" ]]; then
            echo -e "  ${CYAN}+${RESET} $scenario — ${GREEN}PASS${RESET} ($local_c_passed/$local_c_total)"
        else
            echo -e "  ${CYAN}+${RESET} $scenario — ${RED}FAIL${RESET} ($local_c_passed/$local_c_total)"
        fi
    done
fi

# Removed scenarios
if [[ ${#REMOVED_SCENARIOS[@]} -gt 0 ]]; then
    echo ""
    echo -e "${YELLOW}${BOLD}REMOVED SCENARIOS (only in $LABEL_BASELINE):${RESET}"
    for scenario in "${REMOVED_SCENARIOS[@]}"; do
        local_b_result="${BASELINE_RESULTS[$scenario]}"
        echo -e "  ${YELLOW}-${RESET} $scenario — was ${DIM}$local_b_result${RESET}"
    done
fi

# Unchanged (brief)
if [[ ${#UNCHANGED[@]} -gt 0 ]]; then
    echo ""
    echo -e "${DIM}${BOLD}UNCHANGED:${RESET}"
    for scenario in "${UNCHANGED[@]}"; do
        local_result="${CANDIDATE_RESULTS[$scenario]}"
        local_c_passed="${CANDIDATE_PASSED[$scenario]:-0}"
        local_c_total="${CANDIDATE_TOTAL[$scenario]:-0}"
        if [[ "$local_result" == "PASS" ]]; then
            echo -e "  ${DIM}  $scenario — PASS ($local_c_passed/$local_c_total)${RESET}"
        else
            echo -e "  ${DIM}  $scenario — FAIL ($local_c_passed/$local_c_total)${RESET}"
        fi
    done
fi

# ---------------------------------------------------------------------------
# L3 Score comparison (requires jq)
# ---------------------------------------------------------------------------

if $HAS_JQ; then
    mapfile -t B_SCORED < <(jq -r \
        '.[] | select(.judge != null and .judge.criteria != null and (.judge.skipped // false | not) and (.judge.error // false | not)) | .scenario' \
        "$BASELINE" 2>/dev/null || true)
    mapfile -t C_SCORED < <(jq -r \
        '.[] | select(.judge != null and .judge.criteria != null and (.judge.skipped // false | not) and (.judge.error // false | not)) | .scenario' \
        "$CANDIDATE" 2>/dev/null || true)

    SCORE_SCENARIOS=()
    for b_s in ${B_SCORED[@]+"${B_SCORED[@]}"}; do
        [[ -z "$b_s" ]] && continue
        for c_s in ${C_SCORED[@]+"${C_SCORED[@]}"}; do
            [[ "$b_s" == "$c_s" ]] && SCORE_SCENARIOS+=("$b_s") && break
        done
    done

    if [[ ${#SCORE_SCENARIOS[@]} -gt 0 ]]; then
        echo ""
        echo -e "${BOLD}L3 SCORE COMPARISON:${RESET}"

        for scenario in "${SCORE_SCENARIOS[@]}"; do
            echo -e "\n  ${BOLD}$scenario${RESET}"

            unset B_SC B_MX C_SC C_MX 2>/dev/null || true
            declare -A B_SC B_MX C_SC C_MX

            while IFS=$'\t' read -r name score max; do
                [[ -z "$name" ]] && continue
                B_SC["$name"]="$score"
                B_MX["$name"]="$max"
            done < <(jq -r --arg s "$scenario" \
                '.[] | select(.scenario == $s) | .judge.criteria | to_entries[] | "\(.key)\t\(.value.score)\t\(.value.max)"' \
                "$BASELINE" 2>/dev/null || true)

            while IFS=$'\t' read -r name score max; do
                [[ -z "$name" ]] && continue
                C_SC["$name"]="$score"
                C_MX["$name"]="$max"
            done < <(jq -r --arg s "$scenario" \
                '.[] | select(.scenario == $s) | .judge.criteria | to_entries[] | "\(.key)\t\(.value.score)\t\(.value.max)"' \
                "$CANDIDATE" 2>/dev/null || true)

            ALL_CRIT=$(printf '%s\n' "${!B_SC[@]}" "${!C_SC[@]}" | sort -u)

            while IFS= read -r crit; do
                [[ -z "$crit" ]] && continue
                b_score="${B_SC[$crit]:-}"
                b_max="${B_MX[$crit]:-}"
                c_score="${C_SC[$crit]:-}"
                c_max="${C_MX[$crit]:-}"
                padded_crit=$(printf '%-35s' "$crit")

                if [[ -z "$b_score" ]]; then
                    echo -e "    ${CYAN}+${RESET} ${padded_crit}  — → ${c_score}/${c_max}  ${CYAN}(new)${RESET}"
                elif [[ -z "$c_score" ]]; then
                    echo -e "    ${YELLOW}-${RESET} ${padded_crit}  ${b_score}/${b_max} → —  ${YELLOW}(removed)${RESET}"
                else
                    b_int=${b_score%%.*}
                    c_int=${c_score%%.*}
                    diff=$((c_int - b_int))

                    if [[ "$diff" -gt 0 ]]; then
                        echo -e "    ${GREEN}▲${RESET} ${padded_crit}  ${b_score}/${b_max} → ${c_score}/${c_max}  ${GREEN}+${diff}${RESET}"
                        SCORE_IMPROVEMENTS_COUNT=$((SCORE_IMPROVEMENTS_COUNT + 1))
                    elif [[ "$diff" -lt 0 ]]; then
                        echo -e "    ${RED}▼${RESET} ${padded_crit}  ${b_score}/${b_max} → ${c_score}/${c_max}  ${RED}${diff}${RESET}"
                        SCORE_REGRESSIONS_COUNT=$((SCORE_REGRESSIONS_COUNT + 1))
                    else
                        echo -e "    ${DIM}═ ${padded_crit}  ${b_score}/${b_max} → ${c_score}/${c_max}${RESET}"
                    fi
                fi
            done <<< "$ALL_CRIT"

            unset B_SC B_MX C_SC C_MX 2>/dev/null || true
        done
    fi
else
    if grep -q '"judge"' "$BASELINE" 2>/dev/null || grep -q '"judge"' "$CANDIDATE" 2>/dev/null; then
        echo ""
        echo -e "  ${YELLOW}NOTE${RESET}: Install jq for L3 score comparison and timing analysis"
    fi
fi

# ---------------------------------------------------------------------------
# Timing comparison (requires jq)
# ---------------------------------------------------------------------------

if $HAS_JQ; then
    mapfile -t B_TIMED < <(jq -r \
        '.[] | select(.timing != null and .timing.duration_seconds != null) | .scenario' \
        "$BASELINE" 2>/dev/null || true)
    mapfile -t C_TIMED < <(jq -r \
        '.[] | select(.timing != null and .timing.duration_seconds != null) | .scenario' \
        "$CANDIDATE" 2>/dev/null || true)

    TIMED_SCENARIOS=()
    for b_t in ${B_TIMED[@]+"${B_TIMED[@]}"}; do
        [[ -z "$b_t" ]] && continue
        for c_t in ${C_TIMED[@]+"${C_TIMED[@]}"}; do
            [[ "$b_t" == "$c_t" ]] && TIMED_SCENARIOS+=("$b_t") && break
        done
    done

    if [[ ${#TIMED_SCENARIOS[@]} -gt 0 ]]; then
        echo ""
        echo -e "${BOLD}TIMING COMPARISON:${RESET}"

        for scenario in "${TIMED_SCENARIOS[@]}"; do
            b_dur=$(jq -r --arg s "$scenario" \
                '.[] | select(.scenario == $s) | .timing.duration_seconds' \
                "$BASELINE" 2>/dev/null || echo "0")
            c_dur=$(jq -r --arg s "$scenario" \
                '.[] | select(.scenario == $s) | .timing.duration_seconds' \
                "$CANDIDATE" 2>/dev/null || echo "0")

            b_int=${b_dur%%.*}
            c_int=${c_dur%%.*}
            diff=$((c_int - b_int))
            padded=$(printf '%-40s' "$scenario")

            if [[ "$diff" -gt 0 && "$b_int" -gt 0 ]]; then
                pct=$(awk "BEGIN {printf \"%.0f\", ($diff / $b_int) * 100}" 2>/dev/null || echo "?")
                echo -e "  ${padded}  ${b_int}s → ${c_int}s  ${RED}+${diff}s (${pct}% slower)${RESET}"
            elif [[ "$diff" -lt 0 && "$b_int" -gt 0 ]]; then
                abs_diff=$(( -diff ))
                pct=$(awk "BEGIN {printf \"%.0f\", ($abs_diff / $b_int) * 100}" 2>/dev/null || echo "?")
                echo -e "  ${padded}  ${b_int}s → ${c_int}s  ${GREEN}-${abs_diff}s (${pct}% faster)${RESET}"
            elif [[ "$diff" -gt 0 ]]; then
                echo -e "  ${padded}  ${b_int}s → ${c_int}s  ${RED}+${diff}s${RESET}"
            elif [[ "$diff" -lt 0 ]]; then
                abs_diff=$(( -diff ))
                echo -e "  ${padded}  ${b_int}s → ${c_int}s  ${GREEN}-${abs_diff}s${RESET}"
            else
                echo -e "  ${DIM}${padded}  ${b_int}s → ${c_int}s  (unchanged)${RESET}"
            fi
        done
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ ${#REGRESSIONS[@]} -gt 0 ]]; then
    echo -e "${RED}${BOLD}${#REGRESSIONS[@]} regression(s) detected.${RESET}"
fi

if [[ "$SCORE_REGRESSIONS_COUNT" -gt 0 ]]; then
    echo -e "${YELLOW}${BOLD}${SCORE_REGRESSIONS_COUNT} score regression(s) across L3 criteria.${RESET}"
fi

if [[ ${#REGRESSIONS[@]} -eq 0 && "$SCORE_REGRESSIONS_COUNT" -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}No regressions detected.${RESET}"
fi

# Exit 1 on binary regressions (pass→fail); score regressions are warnings
if [[ ${#REGRESSIONS[@]} -gt 0 ]]; then
    exit 1
else
    exit 0
fi
