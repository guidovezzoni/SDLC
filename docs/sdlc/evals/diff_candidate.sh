#!/usr/bin/env bash
# Diff a candidate output directory against the golden reference.
#
# Produces a structured report: file presence (missing/extra/common),
# line counts, section headings diff, and a content summary.
#
# Usage:
#   ./docs/sdlc/evals/diff_candidate.sh <command> [candidate_dir]
#   ./docs/sdlc/evals/diff_candidate.sh <command> --run <run_name>
#
# Arguments:
#   <command>        One of: open_story, propose_change, implement_change, verify_story
#   [candidate_dir]  Path to candidate output directory (optional if --run is used)
#
# Options:
#   --run <name>     Resolve candidate from a results/runs/<name>/ directory
#   --content        Show full content diff for each common file (unified diff)
#   -h, --help       Show this help
#
# Examples:
#   ./docs/sdlc/evals/diff_candidate.sh open_story /tmp/sdlc_eval_candidate_abc123
#   ./docs/sdlc/evals/diff_candidate.sh open_story --run latest
#   ./docs/sdlc/evals/diff_candidate.sh implement_change --run 2026-10-24T082236_claude --content

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GOLDEN_DIR="$SCRIPT_DIR/goldenreference"
RUNS_DIR="$SCRIPT_DIR/results/runs"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

VALID_COMMANDS="open_story propose_change implement_change verify_story"

usage() {
    sed -n '2,/^[^#]/s/^# \?//p' "$0" | head -n -1
    exit 2
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

COMMAND=""
CANDIDATE_DIR=""
RUN_NAME=""
SHOW_CONTENT=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage ;;
        --run)
            [[ $# -lt 2 ]] && { echo "Error: --run requires a value"; usage; }
            RUN_NAME="$2"
            shift 2
            ;;
        --content)
            SHOW_CONTENT=true
            shift
            ;;
        *)
            if [[ -z "$COMMAND" ]]; then
                COMMAND="$1"
            elif [[ -z "$CANDIDATE_DIR" ]]; then
                CANDIDATE_DIR="$1"
            else
                echo "Error: unexpected argument '$1'"
                usage
            fi
            shift
            ;;
    esac
done

if [[ -z "$COMMAND" ]]; then
    echo "Error: <command> is required."
    usage
fi

if ! echo "$VALID_COMMANDS" | grep -qw "$COMMAND"; then
    echo "Error: unknown command '$COMMAND'. Must be one of: $VALID_COMMANDS"
    exit 2
fi

# Resolve candidate directory
if [[ -n "$RUN_NAME" && -n "$CANDIDATE_DIR" ]]; then
    echo "Error: specify --run or a candidate directory, not both."
    usage
fi

if [[ -n "$RUN_NAME" ]]; then
    CANDIDATE_DIR="$RUNS_DIR/$RUN_NAME/${COMMAND}_golden_quality_candidate"
    if [[ ! -d "$CANDIDATE_DIR" ]]; then
        echo -e "${RED}Error${RESET}: no candidate directory for '$COMMAND' in run '$RUN_NAME'"
        echo "  Expected: $CANDIDATE_DIR"
        exit 2
    fi
fi

if [[ -z "$CANDIDATE_DIR" ]]; then
    echo "Error: provide a candidate directory or use --run <name>."
    usage
fi

if [[ ! -d "$CANDIDATE_DIR" ]]; then
    echo -e "${RED}Error${RESET}: candidate directory does not exist: $CANDIDATE_DIR"
    exit 2
fi

GOLDEN_OUTPUT="$GOLDEN_DIR/$COMMAND/output"
if [[ ! -d "$GOLDEN_OUTPUT" ]]; then
    echo -e "${RED}Error${RESET}: golden reference output not found: $GOLDEN_OUTPUT"
    exit 1
fi

# ---------------------------------------------------------------------------
# Collect file lists (relative paths)
# ---------------------------------------------------------------------------

golden_files=$(cd "$GOLDEN_OUTPUT" && find . -type f | sed 's|^\./||' | LC_ALL=C sort)
candidate_files=$(cd "$CANDIDATE_DIR" && find . -type f | sed 's|^\./||' | LC_ALL=C sort)

only_golden=$(comm -23 <(echo "$golden_files") <(echo "$candidate_files"))
only_candidate=$(comm -13 <(echo "$golden_files") <(echo "$candidate_files"))
common_files=$(comm -12 <(echo "$golden_files") <(echo "$candidate_files"))

golden_count=$(echo "$golden_files" | grep -c . || true)
candidate_count=$(echo "$candidate_files" | grep -c . || true)
common_count=$(echo "$common_files" | grep -c . || true)
missing_count=$(echo "$only_golden" | grep -c . || true)
extra_count=$(echo "$only_candidate" | grep -c . || true)

# ---------------------------------------------------------------------------
# Report header
# ---------------------------------------------------------------------------

echo ""
echo -e "${BOLD}Candidate Diff Report: ${COMMAND}${RESET}"
echo -e "${DIM}Golden:    $GOLDEN_OUTPUT${RESET}"
echo -e "${DIM}Candidate: $CANDIDATE_DIR${RESET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ---------------------------------------------------------------------------
# File presence
# ---------------------------------------------------------------------------

echo ""
echo -e "${BOLD}File Presence${RESET}  (golden: $golden_count, candidate: $candidate_count, common: $common_count)"

if [[ "$missing_count" -gt 0 ]]; then
    echo ""
    echo -e "  ${RED}Missing from candidate ($missing_count):${RESET}"
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        echo -e "    ${RED}-${RESET} $f"
    done <<< "$only_golden"
fi

if [[ "$extra_count" -gt 0 ]]; then
    echo ""
    echo -e "  ${CYAN}Extra in candidate ($extra_count):${RESET}"
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        echo -e "    ${CYAN}+${RESET} $f"
    done <<< "$only_candidate"
fi

if [[ "$missing_count" -eq 0 && "$extra_count" -eq 0 ]]; then
    echo -e "  ${GREEN}All files match.${RESET}"
fi

# ---------------------------------------------------------------------------
# Line count comparison
# ---------------------------------------------------------------------------

if [[ -n "$common_files" ]]; then
    echo ""
    echo -e "${BOLD}Line Counts${RESET}"
    echo ""

    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        g_lines=$(wc -l < "$GOLDEN_OUTPUT/$f" 2>/dev/null || echo 0)
        c_lines=$(wc -l < "$CANDIDATE_DIR/$f" 2>/dev/null || echo 0)
        diff_lines=$((c_lines - g_lines))

        padded=$(printf '%-60s' "$f")

        if [[ "$diff_lines" -eq 0 ]]; then
            echo -e "  ${DIM}${padded}  ${g_lines}L = ${c_lines}L${RESET}"
        elif [[ "$diff_lines" -gt 0 ]]; then
            echo -e "  ${padded}  ${g_lines}L → ${c_lines}L  ${CYAN}+${diff_lines}${RESET}"
        else
            abs=$(( -diff_lines ))
            echo -e "  ${padded}  ${g_lines}L → ${c_lines}L  ${YELLOW}-${abs}${RESET}"
        fi
    done <<< "$common_files"
fi

# ---------------------------------------------------------------------------
# Section headings diff (markdown and HTML files)
# ---------------------------------------------------------------------------

extract_headings() {
    local file="$1"
    case "$file" in
        *.md)
            grep -E '^#{1,6} ' "$file" 2>/dev/null || true
            ;;
        *.html)
            grep -oE '<h[1-6][^>]*>.*?</h[1-6]>' "$file" 2>/dev/null \
                | sed 's/<[^>]*>//g' \
                | sed 's/^/# /' || true
            ;;
    esac
}

if [[ -n "$common_files" ]]; then
    headings_shown=false

    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        case "$f" in *.md|*.html) ;; *) continue ;; esac

        g_headings=$(extract_headings "$GOLDEN_OUTPUT/$f")
        c_headings=$(extract_headings "$CANDIDATE_DIR/$f")

        if [[ "$g_headings" != "$c_headings" ]]; then
            if ! $headings_shown; then
                echo ""
                echo -e "${BOLD}Section Headings Diff${RESET}"
                headings_shown=true
            fi

            echo ""
            echo -e "  ${BOLD}$f${RESET}"
            diff --color=never -u \
                <(echo "$g_headings") \
                <(echo "$c_headings") \
                | tail -n +3 \
                | while IFS= read -r line; do
                    case "$line" in
                        +*) echo -e "    ${GREEN}$line${RESET}" ;;
                        -*) echo -e "    ${RED}$line${RESET}" ;;
                        *)  echo -e "    ${DIM}$line${RESET}" ;;
                    esac
                done || true
        fi
    done <<< "$common_files"

    if ! $headings_shown; then
        echo ""
        echo -e "${BOLD}Section Headings${RESET}"
        echo -e "  ${GREEN}All section headings match.${RESET}"
    fi
fi

# ---------------------------------------------------------------------------
# Content diff (unified, opt-in via --content)
# ---------------------------------------------------------------------------

if $SHOW_CONTENT && [[ -n "$common_files" ]]; then
    echo ""
    echo -e "${BOLD}Content Diff${RESET}"

    while IFS= read -r f; do
        [[ -z "$f" ]] && continue

        file_diff=$(diff -u "$GOLDEN_OUTPUT/$f" "$CANDIDATE_DIR/$f" 2>/dev/null || true)
        if [[ -n "$file_diff" ]]; then
            echo ""
            echo -e "  ${BOLD}$f${RESET}"
            echo "$file_diff" | tail -n +3 | head -80 | while IFS= read -r line; do
                case "$line" in
                    +*) echo -e "    ${GREEN}$line${RESET}" ;;
                    -*) echo -e "    ${RED}$line${RESET}" ;;
                    *)  echo -e "    ${DIM}$line${RESET}" ;;
                esac
            done
            total_lines=$(echo "$file_diff" | tail -n +3 | wc -l)
            if [[ "$total_lines" -gt 80 ]]; then
                echo -e "    ${DIM}... ($((total_lines - 80)) more lines)${RESET}"
            fi
        else
            echo -e "  ${DIM}$f — identical${RESET}"
        fi
    done <<< "$common_files"
fi

# ---------------------------------------------------------------------------
# Content summary (for non --content mode, show a brief stats overview)
# ---------------------------------------------------------------------------

if ! $SHOW_CONTENT && [[ -n "$common_files" ]]; then
    identical=0
    different=0
    diff_files=()

    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        if diff -q "$GOLDEN_OUTPUT/$f" "$CANDIDATE_DIR/$f" > /dev/null 2>&1; then
            identical=$((identical + 1))
        else
            different=$((different + 1))
            diff_files+=("$f")
        fi
    done <<< "$common_files"

    echo ""
    echo -e "${BOLD}Content Summary${RESET}"
    echo -e "  Identical: $identical    Different: $different"

    if [[ ${#diff_files[@]} -gt 0 ]]; then
        echo ""
        echo -e "  ${YELLOW}Files with differences:${RESET}"
        for f in "${diff_files[@]}"; do
            stat_line=$(diff "$GOLDEN_OUTPUT/$f" "$CANDIDATE_DIR/$f" 2>/dev/null \
                | grep -c '^[<>]' || true)
            echo -e "    ${YELLOW}~${RESET} $f  ${DIM}(~${stat_line} changed lines)${RESET}"
        done
        echo ""
        echo -e "  ${DIM}Use --content for full unified diffs.${RESET}"
    fi
fi

# ---------------------------------------------------------------------------
# Footer
# ---------------------------------------------------------------------------

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

total_issues=$((missing_count + extra_count))
if [[ "$total_issues" -eq 0 ]]; then
    echo -e "${GREEN}All golden reference files present in candidate.${RESET}"
else
    echo -e "${YELLOW}${total_issues} file presence issue(s) (${missing_count} missing, ${extra_count} extra).${RESET}"
fi

echo ""
