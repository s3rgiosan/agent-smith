# Claude Scripts

Shell scripts for maintaining Claude Code installations.

## `update_claude_paths.sh`

Fixes up a `.claude` directory after you move a project folder. Does two things:

1. **Renames Claude's encoded project dirs** under `projects/`, `file-history/`, `todos/`, `shell-snapshots/`, `debug/`. Prefix-match cascades to every subproject — one run handles a whole parent-dir move. Merges into existing entries if the target already exists.
2. **Rewrites path references in file contents** across every text file in `.claude`. Skips binaries and symlinks, ignores `.git/` and `node_modules/`.

Works with BSD and GNU `sed`, and any `.claude` location (not just `~/.claude`).

```bash
./update_claude_paths.sh \
  --old /Users/alice/projects \
  --new /Users/alice/work/projects \
  --claude /Users/alice/.claude
```

Flags:

| Flag | Description |
|------|-------------|
| `--old` | Original directory path (required) |
| `--new` | New directory path (required) |
| `--claude` | Path to `.claude` folder (default: `~/.claude`) |
| `--backup` | Keep `.bak` copy of each modified file |
| `--dry-run` | Preview changes, no writes |
| `--no-tilde` | Skip the extra `~/foo` pass (on by default when `--old` is under `$HOME`) |
| `--help` | Show usage |
