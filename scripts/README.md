# Scripts

Standalone shell scripts for the chores that pile up around agent-driven work.

## `update_wiki_paths.sh`

Rewrites path references inside an Obsidian vault after you move a project folder. Sweeps markdown bodies, YAML frontmatter, and any other text files. Skips `.git/`, `.obsidian/`, `.trash/`, `wiki-export/`, and `node_modules/`.

Only whole paths are rewritten: the old path must be followed by a character that cannot continue a folder name (anything but letters, digits, `.`, `_` and `-`) or by the end of the line, so `/Users/MrAnderson/www` leaves `/Users/MrAnderson/www-notes` alone. The `~/…` pass runs when `--old` is inside `$HOME`. Without `--backup`, the script lists how many files will change and asks before editing them in place.

Designed for vaults built with [obsidian-wiki](https://github.com/Ar9av/obsidian-wiki).

```bash
./update_wiki_paths.sh \
  --old "/Users/MrAnderson/Local Sites" \
  --new /Users/MrAnderson/www \
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
| `--yes` | Skip the confirmation prompt; needed when there is no terminal and `--backup` is off |
| `--no-tilde` | Skip the extra `~/foo` pass (on by default when `--old` is inside `$HOME`) |
| `--help` | Show usage |
