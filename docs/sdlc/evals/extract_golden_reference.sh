#!/usr/bin/env bash
# Extract golden-reference artifacts from the venice repo.
#
# Run manually when the golden reference needs updating.
# Idempotent: removes and recreates goldenreference/ each time.
#
# Usage: ./extract_golden_reference.sh [/path/to/venice]
#
# The venice repo must have these local branches:
#   workshop/00_main
#   workshop/01_sdlc_open_story
#   workshop/02_sdlc_propose_change
#   workshop/03_sdlc_implement_changes
#   workshop/04_sdlc_verify

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GOLDEN_DIR="$SCRIPT_DIR/goldenreference"
VENICE="${1:-/home/guido/dev/personal/venice}"

if [[ ! -d "$VENICE/.git" ]]; then
    echo "Error: Venice repo not found at $VENICE"
    exit 1
fi

BRANCHES=(
    "workshop/00_main"
    "workshop/01_sdlc_open_story"
    "workshop/02_sdlc_propose_change"
    "workshop/03_sdlc_implement_changes"
    "workshop/04_sdlc_verify"
)
for branch in "${BRANCHES[@]}"; do
    if ! git -C "$VENICE" rev-parse --verify "$branch" &>/dev/null; then
        echo "Error: Branch '$branch' not found in $VENICE"
        exit 1
    fi
done

echo "Venice repo: $VENICE"
echo "Output dir:  $GOLDEN_DIR"
echo ""

rm -rf "$GOLDEN_DIR"
mkdir -p "$GOLDEN_DIR"

extract_outputs() {
    local before="$1" after="$2" output_dir="$3"

    mkdir -p "$output_dir"
    local count=0

    while IFS=$'\t' read -r status path; do
        case "$status" in
            A|M|C|T)
                mkdir -p "$output_dir/$(dirname "$path")"
                git -C "$VENICE" show "$after:$path" > "$output_dir/$path"
                count=$((count + 1))
                ;;
            D)
                ;;
        esac
    done < <(git -C "$VENICE" diff --no-renames --name-status "$before".."$after")

    echo "  Extracted $count output files"
}

extract_file() {
    local branch="$1" file_path="$2" dest="$3"
    git -C "$VENICE" show "$branch:$file_path" > "$dest"
}

# --- open_story ---
echo "=== open_story ==="
mkdir -p "$GOLDEN_DIR/open_story/output"

echo "  Creating repo-snapshot.tar.gz from workshop/00_main..."
git -C "$VENICE" archive workshop/00_main | gzip > "$GOLDEN_DIR/open_story/repo-snapshot.tar.gz"

echo "  Extracting input.md..."
extract_file "workshop/00_main" \
    "docs/userstories/5.1.2-navigate-leg-segment.md" \
    "$GOLDEN_DIR/open_story/input.md"

echo "  Extracting outputs..."
extract_outputs "workshop/00_main" "workshop/01_sdlc_open_story" \
    "$GOLDEN_DIR/open_story/output"
echo ""

# --- propose_change ---
echo "=== propose_change ==="
mkdir -p "$GOLDEN_DIR/propose_change/output"

echo "  Creating repo-snapshot.tar.gz from workshop/01_sdlc_open_story..."
git -C "$VENICE" archive workshop/01_sdlc_open_story | gzip > "$GOLDEN_DIR/propose_change/repo-snapshot.tar.gz"

echo "  Extracting input.md..."
extract_file "workshop/01_sdlc_open_story" \
    "docs/userstories/5.1.2-navigate-leg-segment-WIP.md" \
    "$GOLDEN_DIR/propose_change/input.md"

echo "  Extracting outputs..."
extract_outputs "workshop/01_sdlc_open_story" "workshop/02_sdlc_propose_change" \
    "$GOLDEN_DIR/propose_change/output"
echo ""

# --- implement_change ---
echo "=== implement_change ==="
mkdir -p "$GOLDEN_DIR/implement_change/output"

echo "  Creating repo-snapshot.tar.gz from workshop/02_sdlc_propose_change..."
git -C "$VENICE" archive workshop/02_sdlc_propose_change | gzip > "$GOLDEN_DIR/implement_change/repo-snapshot.tar.gz"

echo "  Extracting input.md..."
extract_file "workshop/02_sdlc_propose_change" \
    "openspec/changes/navigate-leg-segment/tasks.md" \
    "$GOLDEN_DIR/implement_change/input.md"

echo "  Extracting outputs..."
extract_outputs "workshop/02_sdlc_propose_change" "workshop/03_sdlc_implement_changes" \
    "$GOLDEN_DIR/implement_change/output"
echo ""

# --- verify_story ---
echo "=== verify_story ==="
mkdir -p "$GOLDEN_DIR/verify_story/output"

echo "  Creating repo-snapshot.tar.gz from workshop/03_sdlc_implement_changes..."
git -C "$VENICE" archive workshop/03_sdlc_implement_changes | gzip > "$GOLDEN_DIR/verify_story/repo-snapshot.tar.gz"

echo "  Extracting input.md (story + tasks)..."
{
    echo "# Story"
    echo ""
    git -C "$VENICE" show "workshop/03_sdlc_implement_changes:docs/userstories/5.1.2-navigate-leg-segment-WIP.md"
    echo ""
    echo "---"
    echo ""
    echo "# Tasks"
    echo ""
    git -C "$VENICE" show "workshop/03_sdlc_implement_changes:openspec/changes/navigate-leg-segment/tasks.md"
} > "$GOLDEN_DIR/verify_story/input.md"

echo "  Extracting outputs..."
extract_outputs "workshop/03_sdlc_implement_changes" "workshop/04_sdlc_verify" \
    "$GOLDEN_DIR/verify_story/output"
echo ""

# --- Summary ---
echo "=== Summary ==="
for cmd in open_story propose_change implement_change verify_story; do
    tarball_size=$(du -h "$GOLDEN_DIR/$cmd/repo-snapshot.tar.gz" | cut -f1)
    output_count=$(find "$GOLDEN_DIR/$cmd/output" -type f | wc -l)
    echo "  $cmd: tarball=$tarball_size, outputs=$output_count files"
done
echo ""
echo "Done. Golden reference extracted to $GOLDEN_DIR"
