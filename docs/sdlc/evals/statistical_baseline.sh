#!/usr/bin/env bash
# SDLC Eval Statistical Baseline
#
# Computes per-criterion statistics (mean, stdev, min, max, count) across
# multiple eval runs and optionally compares a new single run against the
# computed distribution.
#
# Usage:
#   # Compute statistics from multiple runs
#   ./statistical_baseline.sh run1 run2 run3 ...
#
#   # Compare a new run against the baseline distribution
#   ./statistical_baseline.sh --compare new_run -- run1 run2 run3 ...
#
#   # Use a glob pattern for baseline runs
#   ./statistical_baseline.sh --compare latest -- baseline_*
#
#   # Include pass/fail rate and timing stats
#   ./statistical_baseline.sh --all run1 run2 run3
#
# Arguments can be:
#   - A run directory name (resolved under results/runs/<name>/aggregate.json)
#   - 'latest' (resolved via the latest symlink)
#   - A full path to an aggregate JSON file
#
# Exit codes:
#   0 — no regressions (or no comparison requested)
#   1 — likely regressions detected (score > 2σ below mean)
#   2 — usage error

set -euo pipefail

export LC_NUMERIC=C

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNS_DIR="$SCRIPT_DIR/results/runs"

usage() {
    echo "Usage: $(basename "$0") [options] [--] <run1> <run2> [run3] ..."
    echo ""
    echo "Computes per-criterion statistics across multiple eval runs."
    echo ""
    echo "Options:"
    echo "  --compare <run>   Compare this run against the baseline distribution"
    echo "  --all             Include pass/fail rate and timing statistics"
    echo "  --json            Output raw statistics as JSON (for programmatic use)"
    echo "  --threshold <n>   Z-score threshold for flagging (default: 1.5)"
    echo ""
    echo "Arguments:"
    echo "  Run directory names, 'latest', or full paths to aggregate JSON files."
    echo "  At least 3 baseline runs are required for meaningful statistics."
    echo ""
    echo "Examples:"
    echo "  $(basename "$0") baseline_1 baseline_2 baseline_3 baseline_4 baseline_5"
    echo "  $(basename "$0") --compare latest -- baseline_*"
    echo "  $(basename "$0") --json baseline_*"
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

COMPARE_RUN=""
SHOW_ALL=false
JSON_OUTPUT=false
THRESHOLD="1.5"
BASELINE_RUNS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --compare)
            [[ $# -lt 2 ]] && { echo "Error: --compare requires a run argument"; usage; }
            COMPARE_RUN="$2"
            shift 2
            ;;
        --all)
            SHOW_ALL=true
            shift
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --threshold)
            [[ $# -lt 2 ]] && { echo "Error: --threshold requires a number"; usage; }
            THRESHOLD="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        --)
            shift
            break
            ;;
        *)
            break
            ;;
    esac
done

while [[ $# -gt 0 ]]; do
    BASELINE_RUNS+=("$1")
    shift
done

if [[ ${#BASELINE_RUNS[@]} -lt 2 ]]; then
    echo "Error: at least 2 baseline runs required (3+ recommended for meaningful statistics)."
    usage
fi

# ---------------------------------------------------------------------------
# Resolve all paths
# ---------------------------------------------------------------------------

BASELINE_FILES=()
for run in "${BASELINE_RUNS[@]}"; do
    resolved=$(resolve_aggregate "$run") || exit 2
    BASELINE_FILES+=("$resolved")
done

COMPARE_FILE=""
if [[ -n "$COMPARE_RUN" ]]; then
    COMPARE_FILE=$(resolve_aggregate "$COMPARE_RUN") || exit 2
fi

# ---------------------------------------------------------------------------
# jq check
# ---------------------------------------------------------------------------

if ! command -v jq > /dev/null 2>&1; then
    echo -e "${RED}ERROR${RESET}: jq is required for statistical analysis."
    exit 2
fi

# ---------------------------------------------------------------------------
# Collect all L3 scores into a flat structure for analysis
# ---------------------------------------------------------------------------

collect_scores() {
    local file="$1"
    jq -r '
        .[] |
        select(.judge != null and .judge.criteria != null and
               (.judge.skipped // false | not) and
               (.judge.error // false | not)) |
        .scenario as $s |
        .judge.criteria | to_entries[] |
        "\($s)\t\(.key)\t\(.value.score)\t\(.value.max // "null")"
    ' "$file" 2>/dev/null || true
}

collect_pass_fail() {
    local file="$1"
    jq -r '.[] | "\(.scenario)\t\(.result)\t\(.passed)\t\(.failed)\t\(.total)"' \
        "$file" 2>/dev/null || true
}

collect_timing() {
    local file="$1"
    jq -r '
        .[] |
        select(.timing != null and .timing.duration_seconds != null) |
        "\(.scenario)\t\(.timing.duration_seconds)"
    ' "$file" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Build combined TSV of all baseline scores
# ---------------------------------------------------------------------------

SCORES_TSV=$(mktemp "${TMPDIR:-/tmp}/eval_stats_scores.XXXXXX")
PASSFAIL_TSV=$(mktemp "${TMPDIR:-/tmp}/eval_stats_pf.XXXXXX")
TIMING_TSV=$(mktemp "${TMPDIR:-/tmp}/eval_stats_timing.XXXXXX")
trap 'rm -f "$SCORES_TSV" "$PASSFAIL_TSV" "$TIMING_TSV"' EXIT

for file in "${BASELINE_FILES[@]}"; do
    collect_scores "$file" >> "$SCORES_TSV"
    collect_pass_fail "$file" >> "$PASSFAIL_TSV"
    collect_timing "$file" >> "$TIMING_TSV"
done

# ---------------------------------------------------------------------------
# Compute statistics per scenario × criterion
# ---------------------------------------------------------------------------

compute_stats() {
    # Input: TSV of scenario\tcriterion\tscore\tmax
    # Output: JSON array of stat objects
    sort "$1" | awk -F'\t' '
    {
        key = $1 "\t" $2
        score = $3 + 0
        max = $4
        scores[key] = scores[key] (scores[key] ? "," : "") score
        maxes[key] = max
        count[key]++
        if (!(key in order)) { order[key] = ++nkeys; keys[nkeys] = key }
    }
    END {
        printf "[\n"
        first = 1
        for (i = 1; i <= nkeys; i++) {
            key = keys[i]
            split(key, parts, "\t")
            scenario = parts[1]
            criterion = parts[2]

            split(scores[key], vals, ",")
            c = count[key]
            sum = 0
            mn = vals[1] + 0
            mx = vals[1] + 0
            for (j = 1; j <= c; j++) {
                v = vals[j] + 0
                sum += v
                if (v < mn) mn = v
                if (v > mx) mx = v
            }
            mean = sum / c

            variance = 0
            for (j = 1; j <= c; j++) {
                d = (vals[j] + 0) - mean
                variance += d * d
            }
            if (c > 1) {
                stdev = sqrt(variance / (c - 1))
            } else {
                stdev = 0
            }

            if (!first) printf ",\n"
            first = 0
            printf "  {\"scenario\":\"%s\",\"criterion\":\"%s\",\"mean\":%.2f,\"stdev\":%.2f,\"min\":%s,\"max_score\":%s,\"max_possible\":\"%s\",\"count\":%d,\"values\":[%s]}", \
                scenario, criterion, mean, stdev, mn, mx, maxes[key], c, scores[key]
        }
        printf "\n]\n"
    }
    '
}

compute_pass_rate() {
    # Input: TSV of scenario\tresult\tpassed\tfailed\ttotal
    sort "$1" | awk -F'\t' '
    {
        scenario = $1
        result = $2
        count[scenario]++
        if (result == "PASS") pass_count[scenario]++
        if (!(scenario in order)) { order[scenario] = ++n; keys[n] = scenario }
    }
    END {
        printf "[\n"
        first = 1
        for (i = 1; i <= n; i++) {
            s = keys[i]
            pc = pass_count[s] + 0
            total = count[s]
            rate = (total > 0) ? pc / total * 100 : 0
            if (!first) printf ",\n"
            first = 0
            printf "  {\"scenario\":\"%s\",\"pass_count\":%d,\"total\":%d,\"pass_rate\":%.1f}", \
                s, pc, total, rate
        }
        printf "\n]\n"
    }
    '
}

compute_timing_stats() {
    # Input: TSV of scenario\tduration
    sort "$1" | awk -F'\t' '
    {
        scenario = $1
        dur = $2 + 0
        durations[scenario] = durations[scenario] (durations[scenario] ? "," : "") dur
        count[scenario]++
        if (!(scenario in order)) { order[scenario] = ++n; keys[n] = scenario }
    }
    END {
        printf "[\n"
        first = 1
        for (i = 1; i <= n; i++) {
            s = keys[i]
            split(durations[s], vals, ",")
            c = count[s]
            sum = 0; mn = vals[1] + 0; mx = vals[1] + 0
            for (j = 1; j <= c; j++) {
                v = vals[j] + 0
                sum += v
                if (v < mn) mn = v
                if (v > mx) mx = v
            }
            mean = sum / c
            variance = 0
            for (j = 1; j <= c; j++) {
                d = (vals[j] + 0) - mean
                variance += d * d
            }
            stdev = (c > 1) ? sqrt(variance / (c - 1)) : 0
            if (!first) printf ",\n"
            first = 0
            printf "  {\"scenario\":\"%s\",\"mean\":%.1f,\"stdev\":%.1f,\"min\":%d,\"max\":%d,\"count\":%d}", \
                s, mean, stdev, mn, mx, c
        }
        printf "\n]\n"
    }
    '
}

STATS_JSON=$(compute_stats "$SCORES_TSV")
PASSRATE_JSON=$(compute_pass_rate "$PASSFAIL_TSV")
TIMING_JSON=$(compute_timing_stats "$TIMING_TSV")

# ---------------------------------------------------------------------------
# JSON output mode
# ---------------------------------------------------------------------------

if $JSON_OUTPUT; then
    echo "{"
    echo "  \"baseline_runs\": ${#BASELINE_FILES[@]},"
    echo "  \"score_statistics\": $STATS_JSON,"
    echo "  \"pass_rates\": $PASSRATE_JSON,"
    echo "  \"timing_statistics\": $TIMING_JSON"
    echo "}"
    exit 0
fi

# ---------------------------------------------------------------------------
# Display statistics
# ---------------------------------------------------------------------------

echo ""
echo -e "${BOLD}SDLC Eval Statistical Baseline${RESET}"
echo -e "${DIM}Baseline runs: ${#BASELINE_FILES[@]}${RESET}"
for f in "${BASELINE_FILES[@]}"; do
    echo -e "${DIM}  $(basename "$(dirname "$f")")${RESET}"
done
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Print L3 score statistics
CURRENT_SCENARIO=""
echo "$STATS_JSON" | jq -r '.[] | "\(.scenario)\t\(.criterion)\t\(.mean)\t\(.stdev)\t\(.min)\t\(.max_score)\t\(.max_possible)\t\(.count)\t\(.values)"' | \
while IFS=$'\t' read -r scenario criterion mean stdev min_score max_score max_possible count values; do
    if [[ "$scenario" != "$CURRENT_SCENARIO" ]]; then
        CURRENT_SCENARIO="$scenario"
        echo ""
        echo -e "  ${BOLD}$scenario${RESET} ${DIM}(n=$count)${RESET}"
        printf "  %-32s %6s %6s %6s %6s %8s  %s\n" "Criterion" "Mean" "σ" "Min" "Max" "Ceiling" "Values"
        echo "  ────────────────────────────────────────────────────────────────────────────────────"
    fi

    padded=$(printf '%-32s' "$criterion")

    local_stdev_color="$GREEN"
    stdev_int=${stdev%%.*}
    if [[ "${stdev_int:-0}" -ge 1 ]]; then
        local_stdev_color="$RED"
    elif awk "BEGIN {exit !($stdev >= 0.5)}" 2>/dev/null; then
        local_stdev_color="$YELLOW"
    fi

    printf "  %s %6s ${local_stdev_color}%5s${RESET}σ %6s %6s %8s  ${DIM}[%s]${RESET}\n" \
        "$padded" "$mean" "$stdev" "$min_score" "$max_score" "$max_possible" "$values"
done

# Pass/fail rates
if $SHOW_ALL; then
    echo ""
    echo -e "${BOLD}PASS/FAIL RATES:${RESET}"
    echo "$PASSRATE_JSON" | jq -r '.[] | "\(.scenario)\t\(.pass_count)\t\(.total)\t\(.pass_rate)"' | \
    while IFS=$'\t' read -r scenario pass_count total pass_rate; do
        padded=$(printf '%-42s' "$scenario")
        rate_int=${pass_rate%%.*}
        color="$GREEN"
        [[ "$rate_int" -lt 100 ]] && color="$YELLOW"
        [[ "$rate_int" -lt 80 ]] && color="$RED"
        printf "  %s ${color}%5s%%${RESET} (%s/%s)\n" "$padded" "$pass_rate" "$pass_count" "$total"
    done

    echo ""
    echo -e "${BOLD}TIMING (seconds):${RESET}"
    printf "  %-42s %8s %8s %8s %8s %6s\n" "Scenario" "Mean" "σ" "Min" "Max" "n"
    echo "  ──────────────────────────────────────────────────────────────────────────────"
    echo "$TIMING_JSON" | jq -r '.[] | "\(.scenario)\t\(.mean)\t\(.stdev)\t\(.min)\t\(.max)\t\(.count)"' | \
    while IFS=$'\t' read -r scenario mean stdev min_val max_val count; do
        padded=$(printf '%-42s' "$scenario")
        printf "  %s %7ss %7ss %7ss %7ss %5s\n" "$padded" "$mean" "$stdev" "$min_val" "$max_val" "$count"
    done
fi

# ---------------------------------------------------------------------------
# Comparison mode
# ---------------------------------------------------------------------------

REGRESSION_COUNT=0

if [[ -n "$COMPARE_FILE" ]]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BOLD}COMPARISON: $(basename "$(dirname "$COMPARE_FILE")")${RESET}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    COMPARE_SCORES_TSV=$(mktemp "${TMPDIR:-/tmp}/eval_stats_compare.XXXXXX")
    trap 'rm -f "$SCORES_TSV" "$PASSFAIL_TSV" "$TIMING_TSV" "$COMPARE_SCORES_TSV"' EXIT
    collect_scores "$COMPARE_FILE" > "$COMPARE_SCORES_TSV"

    CURRENT_SCENARIO=""
    while IFS=$'\t' read -r scenario criterion new_score max_possible; do
        [[ -z "$scenario" ]] && continue

        baseline_stats=$(echo "$STATS_JSON" | jq -r --arg s "$scenario" --arg c "$criterion" \
            '.[] | select(.scenario == $s and .criterion == $c) | "\(.mean)\t\(.stdev)\t\(.min)\t\(.max_score)\t\(.count)"' 2>/dev/null)

        if [[ -z "$baseline_stats" ]]; then
            if [[ "$scenario" != "$CURRENT_SCENARIO" ]]; then
                CURRENT_SCENARIO="$scenario"
                echo ""
                echo -e "  ${BOLD}$scenario${RESET}"
            fi
            echo -e "    ${CYAN}+${RESET} $(printf '%-30s' "$criterion")  ${new_score}  ${CYAN}(new — no baseline data)${RESET}"
            continue
        fi

        IFS=$'\t' read -r b_mean b_stdev b_min b_max b_count <<< "$baseline_stats"

        if [[ "$scenario" != "$CURRENT_SCENARIO" ]]; then
            CURRENT_SCENARIO="$scenario"
            echo ""
            echo -e "  ${BOLD}$scenario${RESET} ${DIM}(baseline n=$b_count)${RESET}"
            printf "    %-30s %6s %10s %8s  %s\n" "Criterion" "Score" "Baseline" "Z-score" "Verdict"
            echo "    ──────────────────────────────────────────────────────────────────────"
        fi

        padded=$(printf '%-30s' "$criterion")
        baseline_range="${b_mean}±${b_stdev}"

        if awk "BEGIN {exit !($b_stdev > 0)}" 2>/dev/null; then
            z_score=$(awk "BEGIN {printf \"%.2f\", ($new_score - $b_mean) / $b_stdev}")
            z_abs=$(awk "BEGIN {v = $z_score; if (v < 0) v = -v; printf \"%.2f\", v}")

            if awk "BEGIN {exit !($z_score < -$THRESHOLD)}" 2>/dev/null; then
                verdict="${RED}LIKELY REGRESSION${RESET}"
                REGRESSION_COUNT=$((REGRESSION_COUNT + 1))
            elif awk "BEGIN {exit !($z_score < -1.0)}" 2>/dev/null; then
                verdict="${YELLOW}POSSIBLE DROP${RESET}"
            elif awk "BEGIN {exit !($z_score > $THRESHOLD)}" 2>/dev/null; then
                verdict="${GREEN}ABOVE BASELINE${RESET}"
            else
                verdict="${DIM}WITHIN RANGE${RESET}"
            fi

            printf "    %s %6s %10s %8s  %b\n" "$padded" "$new_score" "$baseline_range" "$z_score" "$verdict"
        else
            if [[ "$new_score" == "$b_mean" || "$new_score" == "${b_mean%.*}" ]]; then
                verdict="${DIM}MATCHES (σ=0)${RESET}"
            else
                diff=$(awk "BEGIN {printf \"%.0f\", $new_score - $b_mean}")
                if [[ "$diff" -lt 0 ]]; then
                    verdict="${YELLOW}DIFFERS (σ=0)${RESET}"
                else
                    verdict="${GREEN}ABOVE (σ=0)${RESET}"
                fi
            fi
            printf "    %s %6s %10s %8s  %b\n" "$padded" "$new_score" "${b_mean}±0" "—" "$verdict"
        fi
    done < "$COMPARE_SCORES_TSV"

    # Compare pass/fail
    COMPARE_PF_TSV=$(mktemp "${TMPDIR:-/tmp}/eval_stats_compare_pf.XXXXXX")
    trap 'rm -f "$SCORES_TSV" "$PASSFAIL_TSV" "$TIMING_TSV" "$COMPARE_SCORES_TSV" "$COMPARE_PF_TSV"' EXIT
    collect_pass_fail "$COMPARE_FILE" > "$COMPARE_PF_TSV"

    echo ""
    echo -e "  ${BOLD}Pass/Fail vs Baseline Rate${RESET}"
    while IFS=$'\t' read -r scenario result passed failed total; do
        [[ -z "$scenario" ]] && continue
        baseline_rate=$(echo "$PASSRATE_JSON" | jq -r --arg s "$scenario" \
            '.[] | select(.scenario == $s) | .pass_rate' 2>/dev/null)

        padded=$(printf '%-42s' "$scenario")
        if [[ -z "$baseline_rate" ]]; then
            echo -e "    $padded $result  ${CYAN}(new scenario)${RESET}"
        elif [[ "$result" == "FAIL" ]] && awk "BEGIN {exit !($baseline_rate == 100)}" 2>/dev/null; then
            echo -e "    $padded ${RED}FAIL${RESET}  (baseline: ${baseline_rate}% pass) ${RED}REGRESSION${RESET}"
            REGRESSION_COUNT=$((REGRESSION_COUNT + 1))
        elif [[ "$result" == "PASS" ]] && awk "BEGIN {exit !($baseline_rate < 100)}" 2>/dev/null; then
            echo -e "    $padded ${GREEN}PASS${RESET}  (baseline: ${baseline_rate}% pass) ${GREEN}IMPROVEMENT${RESET}"
        else
            echo -e "    $padded ${DIM}$result${RESET}  (baseline: ${baseline_rate}% pass)"
        fi
    done < "$COMPARE_PF_TSV"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

TOTAL_CRITERIA=$(echo "$STATS_JSON" | jq 'length')
HIGH_VARIANCE=$(echo "$STATS_JSON" | jq "[.[] | select(.stdev >= 1.0)] | length")
MEDIUM_VARIANCE=$(echo "$STATS_JSON" | jq "[.[] | select(.stdev >= 0.5 and .stdev < 1.0)] | length")
LOW_VARIANCE=$(echo "$STATS_JSON" | jq "[.[] | select(.stdev < 0.5)] | length")

echo -e "${BOLD}Variance summary:${RESET} $TOTAL_CRITERIA criteria across ${#BASELINE_FILES[@]} runs"
echo -e "  ${GREEN}Low variance (σ < 0.5):${RESET}    $LOW_VARIANCE"
echo -e "  ${YELLOW}Medium variance (0.5–1.0):${RESET} $MEDIUM_VARIANCE"
echo -e "  ${RED}High variance (σ ≥ 1.0):${RESET}   $HIGH_VARIANCE"

if [[ "$HIGH_VARIANCE" -gt 0 ]]; then
    echo ""
    echo -e "${YELLOW}High-variance criteria (investigate rubric or command):${RESET}"
    echo "$STATS_JSON" | jq -r '.[] | select(.stdev >= 1.0) | "  \(.scenario) → \(.criterion): σ=\(.stdev), range \(.min)–\(.max_score)"'
fi

if [[ -n "$COMPARE_FILE" ]]; then
    echo ""
    if [[ "$REGRESSION_COUNT" -gt 0 ]]; then
        echo -e "${RED}${BOLD}${REGRESSION_COUNT} likely regression(s) detected.${RESET}"
    else
        echo -e "${GREEN}${BOLD}No regressions detected — all scores within baseline range.${RESET}"
    fi
fi

if [[ "$REGRESSION_COUNT" -gt 0 ]]; then
    exit 1
else
    exit 0
fi
