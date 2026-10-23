# Golden Reference

Artifacts from a successful SDLC pipeline run against the venice Android project (story 5.1.2),
used as the reference baseline for regression testing.

## Source

Extracted from 5 branches in `/home/guido/dev/personal/venice`:

| Command | Before branch | After branch |
|---------|---------------|--------------|
| `open_story` | `workshop/00_main` | `workshop/01_sdlc_open_story` |
| `propose_change` | `workshop/01_sdlc_open_story` | `workshop/02_sdlc_propose_change` |
| `implement_change` | `workshop/02_sdlc_propose_change` | `workshop/03_sdlc_implement_changes` |
| `verify_story` | `workshop/03_sdlc_implement_changes` | `workshop/04_sdlc_verify` |

## Structure

Each command subdirectory contains:

- **`repo-snapshot.tar.gz`** — `git archive` of the full repo at the "before" branch. No `.git/`
  directory, no remotes. The scenario script creates a fresh isolated git repo from this at runtime.
- **`output/`** — files produced by the command, preserving their repo-relative paths. Only
  non-deleted files (the "after" state). T1 assertions and T2 judges read these directly.
- **`input.md`** — the primary input artifact for convenience (judge prompts reference it without
  unpacking the tarball).

## Regeneration

Run the extraction script when the golden reference needs updating:

```bash
./extract_golden_reference.sh [/path/to/venice]
```

The script is idempotent — it removes and recreates `goldenreference/` each time. Defaults to
`/home/guido/dev/personal/venice` if no path argument is provided.

## Known deviations

- The source branch names (`workshop/0N_...`) don't match the default SDLC naming convention
  (`feature/5.1.2-...`). Branch naming is not asserted on.
- `open_story/output/` has 3 files (not 4) because the deleted original story file is correctly
  excluded — deletion is verified by T1 structural assertions instead.
