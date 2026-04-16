# Scripts

Standalone shell scripts for day-to-day maintenance tasks.

## `update_wiki_paths.sh`

Rewrites path references inside an Obsidian vault after you move a project folder. Sweeps markdown bodies, YAML frontmatter, and any other text files. Skips `.git/`, `.obsidian/`, `.trash/`, `wiki-export/`, and `node_modules/`.

Designed for vaults built with [obsidian-wiki](https://github.com/Ar9av/obsidian-wiki).

```bash
./update_wiki_paths.sh \
  --old "/Users/alice/Local Sites" \
  --new /Users/alice/www \
  --vault ~/Obsidian/my-vault
```

Flags:

| Flag | Description |
|------|-------------|
| `--old` | Original directory path (required) |
| `--new` | New directory path (required) |
| `--vault` | Path to the Obsidian vault root (default: `$OBSIDIAN_VAULT`) |
| `--backup` | Keep `.bak` copy of each modified file |
| `--dry-run` | Preview changes, no writes |
| `--no-tilde` | Skip the extra `~/foo` pass (on by default when `--old` is under `$HOME`) |
| `--help` | Show usage |
