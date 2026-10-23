#!/usr/bin/env bash
# Shared helper library for SDLC execution evals (Phase 2 & 3).
# Sourced by scenario scripts — not executed directly.

set -euo pipefail

EVAL_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EVAL_ROOT="$(cd "$EVAL_LIB_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$EVAL_ROOT/../../.." && pwd)"
COMMANDS_DIR="$PROJECT_ROOT/docs/sdlc/commands"

EVAL_TOOL="${EVAL_TOOL:-claude}"

ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"
EVAL_JUDGE_MODEL="${EVAL_JUDGE_MODEL:-}"
EVAL_JUDGE_MAX_TOKENS="${EVAL_JUDGE_MAX_TOKENS:-4096}"

EVAL_START_TIME=""
EVAL_END_TIME=""
EVAL_DURATION=""
EVAL_MODEL_USAGE=""
EVAL_SUBAGENT_STATS=""
EVAL_TOTAL_COST=""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

progress() {
    echo -e "  ${DIM}▸ $1${RESET}" >&2
}

ASSERTIONS_PASSED=0
ASSERTIONS_FAILED=0
ASSERTIONS_TOTAL=0
OUTPUT_FILE=""
FIXTURE_SNAPSHOT=""

# ---------------------------------------------------------------------------
# Fixture lifecycle
# ---------------------------------------------------------------------------

create_fixture_dir() {
    local scenario_name="$1"
    local fixture_dir
    fixture_dir=$(mktemp -d "/tmp/sdlc_eval_${scenario_name}_XXXXXX")
    git -C "$fixture_dir" init --quiet
    echo "$fixture_dir"
}

cleanup_fixture() {
    local fixture_dir="$1"
    if [[ -d "$fixture_dir" && "$fixture_dir" == /tmp/sdlc_eval_* ]]; then
        rm -rf "$fixture_dir" "${fixture_dir}_remote.git"
    fi
}

add_google_services_stub() {
    local fixture_dir="$1"
    local app_dir="$fixture_dir/app"
    [[ -d "$app_dir" ]] || return 0
    [[ -f "$app_dir/google-services.json" ]] && return 0
    cat > "$app_dir/google-services.json" << 'GSJSON'
{
  "project_info": {"project_number":"0","project_id":"eval-stub","storage_bucket":""},
  "client": [{"client_info":{"mobilesdk_app_id":"1:0:android:eval","android_client_info":{"package_name":"com.guidovezzoni.venice"}},"api_key":[{"current_key":"stub"}]}],
  "configuration_version": "1"
}
GSJSON
}

add_local_remote() {
    local fixture_dir="$1"
    local remote_dir="${fixture_dir}_remote.git"
    git clone --bare --quiet "$fixture_dir" "$remote_dir"
    git -C "$fixture_dir" remote add origin "$remote_dir"
    git -C "$fixture_dir" fetch --quiet origin
    git -C "$fixture_dir" branch --set-upstream-to=origin/main main >/dev/null 2>&1 || true
}

snapshot_fixture() {
    local fixture_dir="$1"
    FIXTURE_SNAPSHOT=$(mktemp "/tmp/sdlc_eval_snapshot_XXXXXX")
    find "$fixture_dir" -not -path '*/.git/*' -not -path '*/.git' -not -name 'eval_output.txt' -type f | sort > "$FIXTURE_SNAPSHOT"
}

create_golden_fixture() {
    local command_name="$1"
    local tarball="$EVAL_ROOT/goldenreference/${command_name}/repo-snapshot.tar.gz"

    if [[ ! -f "$tarball" ]]; then
        echo "Error: Golden reference tarball not found: $tarball" >&2
        return 1
    fi

    progress "Extracting golden reference for ${command_name}..."
    local fixture_dir
    fixture_dir=$(mktemp -d "/tmp/sdlc_eval_golden_${command_name}_XXXXXX")

    tar xzf "$tarball" -C "$fixture_dir"
    progress "Initialising isolated git repo..."
    git -C "$fixture_dir" init --quiet
    git -C "$fixture_dir" add -A
    git -C "$fixture_dir" -c user.name="eval" -c user.email="eval@test" \
        commit -m "golden reference baseline" --quiet
    git -C "$fixture_dir" branch -M main

    add_local_remote "$fixture_dir"
    progress "Fixture ready: $fixture_dir"

    echo "$fixture_dir"
}

get_golden_output_dir() {
    local command_name="$1"
    echo "$EVAL_ROOT/goldenreference/${command_name}/output"
}

get_golden_input() {
    local command_name="$1"
    echo "$EVAL_ROOT/goldenreference/${command_name}/input.md"
}

# ---------------------------------------------------------------------------
# Shared fixture: guidelines, AGENTS.md, tracking plan, and the SDLC command
# files that reference them.
#
# Both doctors need these: sdlc_doctor has a Guidelines category (files exist,
# AGENTS.md references them, the artefact guidelines are referenced by an SDLC
# command), and sdlc_project_doctor has an Analytics category (tracking plan
# exists with the expected headings, AGENTS.md references it, and
# sdlc_open_story.md carries the analytics refinement hook).
# ---------------------------------------------------------------------------

create_guidelines_fixture() {
    local dir="$1"

    mkdir -p "$dir/docs/guidelines"
    for guideline in android git process analytics userstories reports; do
        echo "# guidelines-${guideline} placeholder" > "$dir/docs/guidelines/guidelines-${guideline}.md"
    done

    cat > "$dir/AGENTS.md" << 'EOF'
# AGENTS.md

## External File Loading

### Android Guidelines

For Native Android code style and best practices: @docs/guidelines/guidelines-android.md

### Analytics Guidelines

For analytics event design, naming, and delivery: @docs/guidelines/guidelines-analytics.md
The event dictionary is the tracking plan: @docs/analytics/tracking-plan.md

### Git Guidelines

For git operations and commit conventions: @docs/guidelines/guidelines-git.md

### General Guidelines

Read the following file immediately as it's relevant to all workflows: @docs/guidelines/guidelines-process.md

## Project Overview

Eval fixture project.
EOF

    mkdir -p "$dir/docs/analytics"
    cat > "$dir/docs/analytics/tracking-plan.md" << 'EOF'
# Tracking Plan

## Event Dictionary

| Event | Parameters | Trigger |
|-------|-----------|---------|
| `item_added` | `item_count` | An item is persisted |

## Parameter Reference

| Parameter | Type | Allowed values |
|-----------|------|----------------|
| `item_count` | Int | 0–n |

## User Properties

| Property | Type | Allowed values |
|----------|------|----------------|
| `item_count_band` | String | `0`, `1`, `2_5`, `6_plus` |
EOF

    mkdir -p "$dir/docs/sdlc/commands"
    cat > "$dir/docs/sdlc/commands/sdlc_open_story.md" << 'EOF'
# sdlc_open_story placeholder

   ## Context Files
   - User story guidelines: docs/guidelines/guidelines-userstories.md
   - Analytics guidelines: docs/guidelines/guidelines-analytics.md
   - Tracking plan (event dictionary): docs/analytics/tracking-plan.md

   ## Refinement Requirements

   1. Acceptance criteria
   2. An `## Analytics` section defining the events this feature must emit —
      their names, parameters, and the product question each answers.
   3. The steps required for the task to be considered complete
EOF

    cat > "$dir/docs/sdlc/commands/sdlc_verify_story.md" << 'EOF'
# sdlc_verify_story placeholder

   ## Context Files
   - Report guidelines: docs/guidelines/guidelines-reports.md
   - User story guidelines: docs/guidelines/guidelines-userstories.md
EOF
}

# ---------------------------------------------------------------------------
# Base fixture: sdlc_doctor (all checks passing)
# ---------------------------------------------------------------------------

create_doctor_base_fixture() {
    local dir="$1"

    create_guidelines_fixture "$dir"

    mkdir -p "$dir/openspec"
    cat > "$dir/openspec/config.yaml" << 'EOF'
schema: spec-driven
EOF

    mkdir -p "$dir/.claude"
    cat > "$dir/.claude/settings.json" << 'EOF'
{
  "enabledPlugins": {
    "security-guidance@claude-plugins-official": true
  }
}
EOF

    local opsx_dir="$dir/.claude/commands/opsx"
    mkdir -p "$opsx_dir"
    for cmd in explore propose apply verify sync archive; do
        echo "# $cmd command placeholder" > "$opsx_dir/$cmd.md"
    done

    local sdlc_dir="$dir/.claude/commands/sdlc"
    mkdir -p "$sdlc_dir"
    for cmd in sdlc_open_story sdlc_propose_change sdlc_implement_change sdlc_verify_story sdlc_exp_four_in_one sdlc_exp_vibe_a_story sdlc_doctor sdlc_project_doctor; do
        echo "# $cmd command placeholder" > "$sdlc_dir/$cmd.md"
    done
}

# ---------------------------------------------------------------------------
# Base fixture: sdlc_project_doctor (all checks passing)
# ---------------------------------------------------------------------------

create_project_doctor_base_fixture() {
    local dir="$1"

    create_guidelines_fixture "$dir"

    # detekt must be 2.x: 1.x registers no variant tasks on a current AGP and
    # loads no custom ruleset, both silently. composeRules 0.6.x is the line
    # published against detekt 2.x, so the pair has to move together.
    mkdir -p "$dir/gradle"
    cat > "$dir/gradle/libs.versions.toml" << 'EOF'
[versions]
detekt = "2.0.0-alpha.5"
composeRules = "0.6.2"
kover = "0.9.8"
junit = "4.13.2"
mockk = "1.14.9"
coroutinesTest = "1.10.2"

[libraries]
junit = { group = "junit", name = "junit", version.ref = "junit" }
mockk = { group = "io.mockk", name = "mockk", version.ref = "mockk" }
kotlinx-coroutines-test = { group = "org.jetbrains.kotlinx", name = "kotlinx-coroutines-test", version.ref = "coroutinesTest" }
detekt-compose-rules = { group = "io.nlopez.compose.rules", name = "detekt", version.ref = "composeRules" }

[plugins]
detekt = { id = "dev.detekt", version.ref = "detekt" }
kover = { id = "org.jetbrains.kotlinx.kover", version.ref = "kover" }
EOF

    mkdir -p "$dir/app"
    cat > "$dir/app/build.gradle.kts" << 'EOF'
plugins {
    alias(libs.plugins.detekt)
    alias(libs.plugins.kover)
}

dependencies {
    detektPlugins(libs.detekt.compose.rules)
}

detekt {
    config.setFrom(files("$rootDir/config/detekt/detekt.yml"))
}

kover {
    reports {
        verify {
            rule {
                bound {
                    minBound(95)
                }
            }
        }
    }
}
EOF

    # No `build: maxIssues` — the key was removed in detekt 2.x, where the gate
    # is `failOnSeverity` (default Error) plus warningsAsErrors promoting
    # warnings to it. validation makes an unknown key fail the build.
    mkdir -p "$dir/config/detekt"
    cat > "$dir/config/detekt/detekt.yml" << 'EOF'
config:
  validation: true
  warningsAsErrors: true

naming:
  FunctionNaming:
    ignoreAnnotated:
      - 'Composable'

style:
  UnusedImport:
    active: true
  WildcardImport:
    active: true

Compose:
  active: true
EOF

    mkdir -p "$dir/app/src/test/java"
    cat > "$dir/app/src/test/java/SampleTest.kt" << 'EOF'
import org.junit.Test
class SampleTest {
    @Test fun placeholder() = Unit
}
EOF

    mkdir -p "$dir/fastlane"
    echo '# Fastfile placeholder' > "$dir/fastlane/Fastfile"

    echo 'source "https://rubygems.org"' > "$dir/Gemfile"

    mkdir -p "$dir/.github/workflows"
    cat > "$dir/.github/workflows/ci.yml" << 'EOF'
name: CI
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run checks
        run: ./gradlew check
      - name: Verify coverage
        run: ./gradlew koverVerify
EOF

    cat > "$dir/gradlew" << 'GRADLEW'
#!/bin/bash
exit 0
GRADLEW
    chmod +x "$dir/gradlew"
}

# ---------------------------------------------------------------------------
# Phase 3: Base fixture for story-level commands (open, propose, verify)
# ---------------------------------------------------------------------------

create_story_command_base_fixture() {
    local dir="$1"

    git -C "$dir" config user.name "Eval Fixture"
    git -C "$dir" config user.email "eval@fixture.test"

    mkdir -p "$dir/docs/guidelines"

    cat > "$dir/docs/guidelines/guidelines-userstories.md" << 'GUIDELINE_EOF'
# User Story Management Guidelines

This file is the single source of truth for how user stories are managed.

## Storage

User stories are stored as Markdown files in `docs/userstories/`.

## Index

The file `docs/userstories/index.md` is the master index of all user stories.

## File Naming

```
{id}-{slug}[-STATE].md
```

- **id**: hierarchical identifier (e.g. `1.2.4`)
- **slug**: kebab-case short description
- **STATE**: optional lifecycle suffix (`WIP` or `DONE`)

## Lifecycle

| State       | Filename pattern        | Example                        |
|-------------|-------------------------|--------------------------------|
| New         | `{id}-{slug}.md`        | `1.2.5-edit-stop.md`          |
| In Progress | `{id}-{slug}-WIP.md`    | `1.2.5-edit-stop-WIP.md`      |
| Done        | `{id}-{slug}-DONE.md`   | `1.2.5-edit-stop-DONE.md`     |

### Next User Story

When no specific story is specified, the next story to open is the first one in the index that is in the **New** state (i.e. not `-WIP` or `-DONE`).

### Opening a User Story

Rename the file by appending `-WIP` before the `.md` extension.

**Precondition:** The file must be in the **New** state.

### Closing a User Story

Rename the file by replacing the `-WIP` suffix with `-DONE` before the `.md` extension.

**Precondition:** The file must be in the **In Progress** state (`-WIP`).

### Renaming

File renames must use `git mv` so the change is tracked in version control.

### Index Update

After any state transition, update the link in `docs/userstories/index.md`.
GUIDELINE_EOF

    cat > "$dir/docs/guidelines/guidelines-git.md" << 'GUIDELINE_EOF'
# Git Guidelines

## Commit Message Format
1. First line: simple and concise summary of the change
2. Body (optional): extra detail if required

## File Operations
- Always use `git mv` instead of plain `mv` when renaming or moving tracked files

## Branch Verification
- Always verify the current branch by running `git branch --show-current`
GUIDELINE_EOF

    cat > "$dir/docs/guidelines/guidelines-reports.md" << 'GUIDELINE_EOF'
# Report Guidelines

Reports are HTML files in `docs/reports/`.
File naming: `{id}-{slug}.html`
One report per user story.
GUIDELINE_EOF

    cat > "$dir/docs/guidelines/guidelines-android.md" << 'GUIDELINE_EOF'
# Android Guidelines

- MVI Architecture with Clean Architecture (data/domain/UI)
- Jetpack Compose with Material 3
- Dependency Injection with Hilt
GUIDELINE_EOF

    cat > "$dir/docs/guidelines/guidelines-process.md" << 'GUIDELINE_EOF'
# Process and Workflow Guidelines

- Run `./gradlew clean` before coding
- Run `./gradlew check` after changes
- Run `./gradlew test` for unit tests
GUIDELINE_EOF

    mkdir -p "$dir/docs/userstories"
    mkdir -p "$dir/docs/reports"

    mkdir -p "$dir/openspec"
    cat > "$dir/openspec/config.yaml" << 'EOF'
schema: spec-driven
EOF

    cat > "$dir/AGENTS.md" << 'EOF'
# AGENTS.md
## Project Overview
Test project for SDLC evals.
EOF

    cat > "$dir/gradlew" << 'GRADLEW'
#!/bin/bash
exit 0
GRADLEW
    chmod +x "$dir/gradlew"

    git -C "$dir" add -A
    git -C "$dir" commit -m "Initial fixture setup" --quiet
    git -C "$dir" branch -M main
}

create_sample_story_new() {
    local dir="$1"
    local story_id="${2:-99.1.1}"
    local story_slug="${3:-test-feature}"

    cat > "$dir/docs/userstories/${story_id}-${story_slug}.md" << STORY_EOF
# ${story_id} — Test Feature

**Epic:** Test Epic
**Feature:** Test Feature

## User Story

As a user, I want to test a feature so that I can verify it works.

## Acceptance Criteria

- The feature should work correctly.
- The UI should update appropriately.
- Error states should be handled gracefully.
STORY_EOF

    cat > "$dir/docs/userstories/index.md" << INDEX_EOF
# User Stories Index

## Epic 99: Test

### Feature 99.1: Test Feature

- [${story_id} — Test Feature](${story_id}-${story_slug}.md)
INDEX_EOF
}

create_sample_story_wip() {
    local dir="$1"
    local story_id="${2:-99.1.1}"
    local story_slug="${3:-test-feature}"

    cat > "$dir/docs/userstories/${story_id}-${story_slug}-WIP.md" << STORY_EOF
# ${story_id} — Test Feature

**Epic:** Test Epic
**Feature:** Test Feature

## User Story

As a user, I want to test a feature so that I can verify it works.

## Acceptance Criteria

- The feature should work correctly.
- The UI should update appropriately.
- Error states should be handled gracefully.

## Definition of Done

- All acceptance criteria are met.
- Unit tests pass with >95% coverage.
- UI tests pass on a connected device.
STORY_EOF

    cat > "$dir/docs/userstories/index.md" << INDEX_EOF
# User Stories Index

## Epic 99: Test

### Feature 99.1: Test Feature

- [${story_id} — Test Feature](${story_id}-${story_slug}-WIP.md)
INDEX_EOF
}

create_sample_story_ambiguous() {
    local dir="$1"
    local story_id="${2:-99.1.1}"
    local story_slug="${3:-ambiguous-feature}"

    cat > "$dir/docs/userstories/${story_id}-${story_slug}-WIP.md" << STORY_EOF
# ${story_id} — Ambiguous Feature

**Epic:** Test Epic
**Feature:** Ambiguous Feature

## User Story

As a user, I want to manage items so that they are organised.

## Description

The feature should allow managing items. Details about the specific item types,
storage mechanism, and UI layout are intentionally unspecified.

## Acceptance Criteria

- Items can be managed.
- The feature integrates with existing functionality.
STORY_EOF

    cat > "$dir/docs/userstories/index.md" << INDEX_EOF
# User Stories Index

## Epic 99: Test

### Feature 99.1: Ambiguous Feature

- [${story_id} — Ambiguous Feature](${story_id}-${story_slug}-WIP.md)
INDEX_EOF
}

# ---------------------------------------------------------------------------
# Eval execution
# ---------------------------------------------------------------------------

extract_model_usage() {
    local json_file="$1"
    local text_file="$2"

    if ! command -v jq > /dev/null 2>&1; then
        EVAL_MODEL_USAGE=""
        EVAL_SUBAGENT_STATS=""
        EVAL_TOTAL_COST=""
        cp "$json_file" "$text_file"
        return
    fi

    local result
    result=$(jq -r '.result // empty' "$json_file" 2>/dev/null)
    if [[ -n "$result" ]]; then
        echo "$result" > "$text_file"
    else
        cp "$json_file" "$text_file"
    fi

    EVAL_MODEL_USAGE=$(jq -c '.modelUsage // empty' "$json_file" 2>/dev/null)
    EVAL_SUBAGENT_STATS=$(jq -c '.subagent_stats // empty' "$json_file" 2>/dev/null)
    EVAL_TOTAL_COST=$(jq -r '.total_cost_usd // empty' "$json_file" 2>/dev/null)

    if [[ -n "$EVAL_MODEL_USAGE" ]]; then
        local models
        models=$(echo "$EVAL_MODEL_USAGE" | jq -r 'keys | join(", ")' 2>/dev/null)
        local subagents_spawned
        subagents_spawned=$(echo "$EVAL_SUBAGENT_STATS" | jq -r '.spawned // 0' 2>/dev/null)
        echo -e "  ${DIM}Models: ${models}${RESET}"
        echo -e "  ${DIM}Subagents spawned: ${subagents_spawned} | Cost: \$${EVAL_TOTAL_COST:-unknown}${RESET}"
    fi
}

run_eval() {
    local fixture_dir="$1"
    local command_file="$2"
    local output_file="$3"

    OUTPUT_FILE="$output_file"

    local prompt
    prompt="$(cat "$command_file")"

    EVAL_START_TIME=$(date -Iseconds)
    local start_epoch
    start_epoch=$(date +%s)

    local exit_code=0
    if [[ "$EVAL_TOOL" == "claude" ]]; then
        local json_output
        json_output=$(mktemp "/tmp/sdlc_eval_json_XXXXXX")
        (cd "$fixture_dir" && "$EVAL_TOOL" \
            -p "$prompt" \
            --dangerously-skip-permissions \
            --no-session-persistence \
            --output-format json \
        ) > "$json_output" 2>&1 || exit_code=$?
        extract_model_usage "$json_output" "$output_file"
        rm -f "$json_output"
    else
        (cd "$fixture_dir" && "$EVAL_TOOL" \
            -p "$prompt" \
            --dangerously-skip-permissions \
            --no-session-persistence \
            --output-format text \
        ) > "$output_file" 2>&1 || exit_code=$?
    fi

    EVAL_END_TIME=$(date -Iseconds)
    local end_epoch
    end_epoch=$(date +%s)
    EVAL_DURATION=$((end_epoch - start_epoch))

    return $exit_code
}

run_eval_with_args() {
    local fixture_dir="$1"
    local command_file="$2"
    local output_file="$3"
    local args="${4:-}"
    local max_turns="${5:-}"

    OUTPUT_FILE="$output_file"

    local prompt
    prompt="$(cat "$command_file")"
    prompt="${prompt//\$ARGUMENTS/$args}"

    local output_format="text"
    if [[ "$EVAL_TOOL" == "claude" ]]; then
        output_format="json"
    fi

    local tool_args=(
        -p "$prompt"
        --dangerously-skip-permissions
        --no-session-persistence
        --output-format "$output_format"
    )

    if [[ -n "$max_turns" ]]; then
        tool_args+=(--max-turns "$max_turns")
    fi

    EVAL_START_TIME=$(date -Iseconds)
    local start_epoch
    start_epoch=$(date +%s)

    local exit_code=0
    if [[ "$output_format" == "json" ]]; then
        local json_output
        json_output=$(mktemp "/tmp/sdlc_eval_json_XXXXXX")
        (cd "$fixture_dir" && "$EVAL_TOOL" "${tool_args[@]}") > "$json_output" 2>&1 || exit_code=$?
        extract_model_usage "$json_output" "$output_file"
        rm -f "$json_output"
    else
        (cd "$fixture_dir" && "$EVAL_TOOL" "${tool_args[@]}") > "$output_file" 2>&1 || exit_code=$?
    fi

    EVAL_END_TIME=$(date -Iseconds)
    local end_epoch
    end_epoch=$(date +%s)
    EVAL_DURATION=$((end_epoch - start_epoch))

    return $exit_code
}

# ---------------------------------------------------------------------------
# Candidate artifact collection for T2 judge
# ---------------------------------------------------------------------------

collect_candidate_from_baseline() {
    local fixture_dir="$1"
    progress "Collecting candidate artifacts from baseline diff..."
    local candidate_dir
    candidate_dir=$(mktemp -d "/tmp/sdlc_eval_candidate_XXXXXX")

    local baseline_ref="eval-baseline"
    if ! git -C "$fixture_dir" rev-parse "$baseline_ref" >/dev/null 2>&1; then
        baseline_ref=$(git -C "$fixture_dir" rev-list --max-parents=0 HEAD 2>/dev/null)
    fi

    local changed_files
    changed_files=$(cd "$fixture_dir" && {
        git diff --name-only "$baseline_ref" HEAD 2>/dev/null
        git diff --name-only HEAD 2>/dev/null
        git ls-files --others --exclude-standard 2>/dev/null
    } | sort -u)

    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        if [[ -f "$fixture_dir/$file" ]]; then
            mkdir -p "$(dirname "$candidate_dir/$file")"
            cp "$fixture_dir/$file" "$candidate_dir/$file"
        fi
    done <<< "$changed_files"

    echo "$candidate_dir"
}

# ---------------------------------------------------------------------------
# LLM-as-judge (T2 evaluation)
# ---------------------------------------------------------------------------

run_judge() {
    local rubric_file="$1"
    local golden_dir="$2"
    local candidate_dir="$3"
    local result_file="$4"
    local input_file="${5:-}"

    if [[ -z "$ANTHROPIC_API_KEY" ]]; then
        echo -e "  ${YELLOW}SKIP${RESET} T2 judge: ANTHROPIC_API_KEY not set"
        echo '{"skipped": true, "reason": "ANTHROPIC_API_KEY not set"}' > "$result_file"
        return 2
    fi

    if [[ -z "$EVAL_JUDGE_MODEL" ]]; then
        echo -e "  ${YELLOW}SKIP${RESET} T2 judge: EVAL_JUDGE_MODEL not set"
        echo '{"skipped": true, "reason": "EVAL_JUDGE_MODEL not set"}' > "$result_file"
        return 2
    fi

    local rubric golden_files candidate_files input_content
    rubric="$(cat "$rubric_file")"

    input_content=""
    if [[ -n "$input_file" && -f "$input_file" ]]; then
        input_content="$(cat "$input_file")"
    fi

    golden_files=""
    while IFS= read -r -d '' file; do
        local rel_path="${file#"$golden_dir"/}"
        golden_files="${golden_files}--- ${rel_path} ---
$(cat "$file")

"
    done < <(find "$golden_dir" -type f -print0 | sort -z)

    candidate_files=""
    while IFS= read -r -d '' file; do
        local rel_path="${file#"$candidate_dir"/}"
        candidate_files="${candidate_files}--- ${rel_path} ---
$(cat "$file")

"
    done < <(find "$candidate_dir" -type f -print0 | sort -z)

    local system_prompt
    system_prompt="You are an evaluation judge for an AI coding assistant pipeline. You compare a candidate output against a golden reference using a per-criterion rubric.

Your task:
1. Read the rubric — it defines each criterion, its type (boolean, 1-5 scale, or checklist), and what constitutes each score level.
2. Read the command input — this is what the command was given to work with.
3. Read the golden reference artifacts — these are the high-quality expected outputs.
4. Read the candidate artifacts — these are what the command actually produced.
5. Score each criterion independently, comparing the candidate against the golden reference.

Return ONLY a JSON object with this exact structure:
{
  \"criteria\": {
    \"<criterion_name>\": {
      \"score\": <number>,
      \"max\": <number>,
      \"rationale\": \"<one to two sentence explanation referencing specific evidence>\"
    }
  },
  \"summary\": \"<one sentence overall assessment>\"
}

Scoring rules:
- Be strict: the golden reference represents high-quality output produced by a successful pipeline run.
- For boolean criteria: score 1 (true) or 0 (false).
- For 1-5 scale criteria: use the rubric's score descriptions to calibrate.
- For checklist criteria: count items that meet the criterion.
- Every rationale must cite specific artifacts or content, not just restate the criterion.
- If the candidate directory is empty or has no meaningful artifacts, score all criteria at their minimum."

    local input_section=""
    if [[ -n "$input_content" ]]; then
        input_section="## Command Input (what the command was given)

${input_content}

"
    fi

    local user_prompt
    user_prompt="## Rubric

${rubric}

${input_section}## Golden Reference Artifacts

${golden_files}

## Candidate Artifacts

${candidate_files}

Score the candidate against the golden reference using the rubric above. Return JSON only."

    local escaped_system escaped_user
    escaped_system=$(printf '%s' "$system_prompt" | jq -Rs .)
    escaped_user=$(printf '%s' "$user_prompt" | jq -Rs .)

    progress "Calling judge API (model: $EVAL_JUDGE_MODEL)..."

    local payload_file
    payload_file=$(mktemp "${TMPDIR:-/tmp}/eval_judge_payload.XXXXXX")
    printf '{"model":"%s","max_tokens":%s,"system":%s,"messages":[{"role":"user","content":%s}]}' \
        "$EVAL_JUDGE_MODEL" "$EVAL_JUDGE_MAX_TOKENS" "$escaped_system" "$escaped_user" > "$payload_file"

    local api_response
    api_response=$(curl -s -w "\n%{http_code}" \
        https://api.anthropic.com/v1/messages \
        -H "x-api-key: $ANTHROPIC_API_KEY" \
        -H "content-type: application/json" \
        -H "anthropic-version: 2023-06-01" \
        -d "@${payload_file}")
    rm -f "$payload_file"

    local http_code body
    http_code=$(echo "$api_response" | tail -1)
    body=$(echo "$api_response" | sed '$d')

    if [[ "$http_code" != "200" ]]; then
        echo -e "  ${RED}ERROR${RESET} T2 judge API call failed (HTTP $http_code)"
        local error_msg
        error_msg=$(echo "$body" | jq -r '.error.message // empty' 2>/dev/null)
        [[ -n "$error_msg" ]] && echo -e "  ${DIM}$error_msg${RESET}"
        echo "{\"error\": true, \"http_code\": $http_code, \"body\": $(echo "$body" | jq -Rs .)}" > "$result_file"
        return 1
    fi

    local text_content
    text_content=$(echo "$body" | jq -r '.content[0].text // empty')

    if [[ -z "$text_content" ]]; then
        echo -e "  ${RED}ERROR${RESET} T2 judge returned empty response"
        echo "{\"error\": true, \"reason\": \"empty response\", \"raw\": $(echo "$body" | jq -Rs .)}" > "$result_file"
        return 1
    fi

    local json_content=""

    if echo "$text_content" | jq . > /dev/null 2>&1; then
        json_content="$text_content"
    elif json_content=$(echo "$text_content" | sed -n '/^```/,/^```/{/^```/d;p}') && \
         [[ -n "$json_content" ]] && echo "$json_content" | jq . > /dev/null 2>&1; then
        :
    else
        echo -e "  ${RED}ERROR${RESET} T2 judge returned invalid JSON"
        echo "{\"error\": true, \"reason\": \"invalid JSON\", \"raw\": $(echo "$text_content" | jq -Rs .)}" > "$result_file"
        return 1
    fi

    local usage_info
    usage_info=$(echo "$body" | jq -c '{input_tokens: .usage.input_tokens, output_tokens: .usage.output_tokens}' 2>/dev/null)

    echo "$json_content" | jq --argjson usage "$usage_info" '. + {judge_usage: $usage}' > "$result_file" 2>/dev/null \
        || echo "$json_content" > "$result_file"

    echo -e "  ${GREEN}OK${RESET} T2 judge scores written to $result_file"
    local input_tokens output_tokens
    input_tokens=$(echo "$usage_info" | jq -r '.input_tokens // "?"' 2>/dev/null)
    output_tokens=$(echo "$usage_info" | jq -r '.output_tokens // "?"' 2>/dev/null)
    echo -e "  ${DIM}Judge tokens: ${input_tokens} in / ${output_tokens} out${RESET}"
    return 0
}

assert_judge_score() {
    local json_file="$1"
    local criterion="$2"
    local min_score="$3"
    local description="${4:-$criterion >= $min_score}"

    if [[ ! -f "$json_file" ]]; then
        assertion_fail "$description" "judge result file not found: $json_file"
        return
    fi

    local skipped
    skipped=$(jq -r '.skipped // false' "$json_file" 2>/dev/null)
    if [[ "$skipped" == "true" ]]; then
        echo -e "    ${YELLOW}SKIP${RESET} $description (judge was skipped)"
        return
    fi

    local error
    error=$(jq -r '.error // false' "$json_file" 2>/dev/null)
    if [[ "$error" == "true" ]]; then
        assertion_fail "$description" "judge returned an error"
        return
    fi

    local score
    score=$(jq -r ".criteria.\"$criterion\".score // empty" "$json_file" 2>/dev/null)

    if [[ -z "$score" ]]; then
        assertion_fail "$description" "criterion '$criterion' not found in judge output"
        return
    fi

    if (( $(echo "$score >= $min_score" | bc -l) )); then
        assertion_pass "$description (score: $score)"
    else
        local rationale
        rationale=$(jq -r ".criteria.\"$criterion\".rationale // \"no rationale\"" "$json_file" 2>/dev/null)
        assertion_fail "$description" "score $score < $min_score — $rationale"
    fi
}

# ---------------------------------------------------------------------------
# Assertion helpers
# ---------------------------------------------------------------------------

begin_assertions() {
    ASSERTIONS_PASSED=0
    ASSERTIONS_FAILED=0
    ASSERTIONS_TOTAL=0
}

assertion_pass() {
    local description="$1"
    ASSERTIONS_TOTAL=$((ASSERTIONS_TOTAL + 1))
    ASSERTIONS_PASSED=$((ASSERTIONS_PASSED + 1))
    echo -e "    ${GREEN}✅${RESET} $description"
}

assertion_fail() {
    local description="$1"
    local detail="${2:-}"
    ASSERTIONS_TOTAL=$((ASSERTIONS_TOTAL + 1))
    ASSERTIONS_FAILED=$((ASSERTIONS_FAILED + 1))
    if [[ -n "$detail" ]]; then
        echo -e "    ${RED}❌${RESET} $description — $detail"
    else
        echo -e "    ${RED}❌${RESET} $description"
    fi
}

assert_check_passes() {
    local pattern="$1"
    local description="$2"

    if grep -q "✅" "$OUTPUT_FILE" && grep "✅" "$OUTPUT_FILE" | grep -qiE "$pattern"; then
        assertion_pass "$description"
    else
        assertion_fail "$description" "expected ✅ line containing '$pattern'"
    fi
}

assert_check_fails() {
    local pattern="$1"
    local description="$2"

    if grep -q "❌" "$OUTPUT_FILE" && grep "❌" "$OUTPUT_FILE" | grep -qiE "$pattern"; then
        assertion_pass "$description"
    else
        assertion_fail "$description" "expected ❌ line containing '$pattern'"
    fi
}

assert_output_contains() {
    local pattern="$1"
    local description="$2"

    if grep -qiE "$pattern" "$OUTPUT_FILE"; then
        assertion_pass "$description"
    else
        assertion_fail "$description" "expected output containing '$pattern'"
    fi
}

assert_output_not_contains() {
    local pattern="$1"
    local description="$2"

    if grep -qiE "$pattern" "$OUTPUT_FILE"; then
        assertion_fail "$description" "output should NOT contain '$pattern'"
    else
        assertion_pass "$description"
    fi
}

assert_pass_count() {
    local expected="$1"
    local actual
    actual=$(grep -c "✅" "$OUTPUT_FILE" 2>/dev/null || true)

    if [[ "$actual" -eq "$expected" ]]; then
        assertion_pass "pass count is $expected"
    else
        assertion_fail "pass count should be $expected" "got $actual"
    fi
}

assert_fail_count() {
    local expected="$1"
    local actual
    actual=$(grep -c "❌" "$OUTPUT_FILE" 2>/dev/null || true)

    if [[ "$actual" -eq "$expected" ]]; then
        assertion_pass "fail count is $expected"
    else
        assertion_fail "fail count should be $expected" "got $actual"
    fi
}

assert_min_pass_count() {
    local minimum="$1"
    local actual
    actual=$(grep -c "✅" "$OUTPUT_FILE" 2>/dev/null || true)

    if [[ "$actual" -ge "$minimum" ]]; then
        assertion_pass "pass count >= $minimum (got $actual)"
    else
        assertion_fail "pass count should be >= $minimum" "got $actual"
    fi
}

assert_min_fail_count() {
    local minimum="$1"
    local actual
    actual=$(grep -c "❌" "$OUTPUT_FILE" 2>/dev/null || true)

    if [[ "$actual" -ge "$minimum" ]]; then
        assertion_pass "fail count >= $minimum (got $actual)"
    else
        assertion_fail "fail count should be >= $minimum" "got $actual"
    fi
}

assert_file_exists() {
    local file_path="$1"
    local description="$2"

    if [[ -f "$file_path" ]]; then
        assertion_pass "$description"
    else
        assertion_fail "$description" "file not found: $file_path"
    fi
}

assert_file_not_exists() {
    local file_path="$1"
    local description="$2"

    if [[ ! -f "$file_path" ]]; then
        assertion_pass "$description"
    else
        assertion_fail "$description" "file should not exist: $file_path"
    fi
}

assert_branch_exists() {
    local fixture_dir="$1"
    local branch_pattern="$2"
    local description="$3"

    if git -C "$fixture_dir" branch 2>/dev/null | grep -qE "$branch_pattern"; then
        assertion_pass "$description"
    else
        assertion_fail "$description" "no branch matching '$branch_pattern'"
    fi
}

assert_on_branch() {
    local fixture_dir="$1"
    local expected_branch="$2"
    local description="$3"

    local current_branch
    current_branch=$(git -C "$fixture_dir" branch --show-current 2>/dev/null)

    if [[ "$current_branch" == "$expected_branch" ]]; then
        assertion_pass "$description"
    else
        assertion_fail "$description" "expected branch '$expected_branch', got '$current_branch'"
    fi
}

assert_fixture_unchanged() {
    local fixture_dir="$1"

    if [[ -z "$FIXTURE_SNAPSHOT" || ! -f "$FIXTURE_SNAPSHOT" ]]; then
        assertion_fail "fixture unchanged" "no snapshot taken"
        return
    fi

    local current
    current=$(mktemp "/tmp/sdlc_eval_current_XXXXXX")
    find "$fixture_dir" -not -path '*/.git/*' -not -path '*/.git' -not -name 'eval_output.txt' -type f | sort > "$current"

    if diff -q "$FIXTURE_SNAPSHOT" "$current" > /dev/null 2>&1; then
        assertion_pass "no files created or removed in fixture"
    else
        local diff_output
        diff_output=$(diff "$FIXTURE_SNAPSHOT" "$current" || true)
        assertion_fail "fixture was modified" "diff: $diff_output"
    fi
    rm -f "$current"
}

# ---------------------------------------------------------------------------
# Scenario result
# ---------------------------------------------------------------------------

report_scenario_result() {
    local scenario_name="$1"

    echo ""
    if [[ "$ASSERTIONS_FAILED" -eq 0 ]]; then
        echo -e "  ${GREEN}${BOLD}PASS${RESET} $scenario_name — $ASSERTIONS_PASSED/$ASSERTIONS_TOTAL assertions passed"
    else
        echo -e "  ${RED}${BOLD}FAIL${RESET} $scenario_name — $ASSERTIONS_PASSED/$ASSERTIONS_TOTAL passed, $ASSERTIONS_FAILED failed"
    fi

    # Output JSON result to results dir if RESULTS_DIR is set
    if [[ -n "${RESULTS_DIR:-}" ]]; then
        local timing_json=""
        if [[ -n "${EVAL_DURATION:-}" && "$EVAL_DURATION" -gt 0 ]] 2>/dev/null; then
            timing_json=$(cat << TIMING_EOF
,
  "timing": {
    "start": "$EVAL_START_TIME",
    "end": "$EVAL_END_TIME",
    "duration_seconds": $EVAL_DURATION
  }
TIMING_EOF
)
        fi

        local model_json=""
        if [[ -n "${EVAL_MODEL_USAGE:-}" ]] && command -v jq > /dev/null 2>&1; then
            local stats="${EVAL_SUBAGENT_STATS}"
            [[ -z "$stats" ]] && stats="{}"
            model_json=",
  \"model_usage\": ${EVAL_MODEL_USAGE},
  \"subagent_stats\": ${stats},
  \"total_cost_usd\": ${EVAL_TOTAL_COST:-null}"
        fi

        cat > "$RESULTS_DIR/${scenario_name}.json" << RESULT_EOF
{
  "scenario": "$scenario_name",
  "passed": $ASSERTIONS_PASSED,
  "failed": $ASSERTIONS_FAILED,
  "total": $ASSERTIONS_TOTAL,
  "result": "$([ "$ASSERTIONS_FAILED" -eq 0 ] && echo "PASS" || echo "FAIL")",
  "tool": "$EVAL_TOOL",
  "timestamp": "$(date -Iseconds)"${timing_json}${model_json}
}
RESULT_EOF
    fi

    if [[ -n "$FIXTURE_SNAPSHOT" && -f "$FIXTURE_SNAPSHOT" ]]; then
        rm -f "$FIXTURE_SNAPSHOT"
    fi

    return "$ASSERTIONS_FAILED"
}
