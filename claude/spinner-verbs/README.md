# Claude Code Spinner Verbs

Part of [Agent Smith](../../README.md): tools, scripts and skills for agent-driven development.

Make the wait fun. Spinner verbs are the action phrases Claude Code shows while it works ("Using the Force for 12s"), and these themes swap the defaults for something with more character.

---

## Available Themes

| Theme | File | Verbs |
|-------|------|-------|
| Movie Quotes | `movie-quotes.json` | 36 |
| Monty Python | `monty-python.json` | 30 |
| Pirate | `pirate.json` | 30 |
| Portuguese | `portuguese.json` | 38 |
| Hugo (TV Game) | `hugo.json` | 8 |
| Portuguese Football | `portuguese-football.json` | 33 |

---

## Usage

### With the script

[`manage_claude_spinner_verbs.sh`](../scripts/README.md#manage_claude_spinner_verbssh) writes a theme into a settings file for you. It can also stack themes, add your own phrases, switch the mode, remove the verbs, and rotate the theme once a day.

```bash
cd agent-smith/claude/scripts

# Open the menu
./manage_claude_spinner_verbs.sh

# Or use flags
./manage_claude_spinner_verbs.sh --use portuguese --add portuguese-football

# A different theme each day
./manage_claude_spinner_verbs.sh --install-rotation
```

### By hand

1. Pick a theme file from this repo
2. Copy the JSON contents into your Claude Code settings file:
   - **Global** (all projects): `~/.claude/settings.json`
   - **Project** (shared with team): `.claude/settings.json`
   - **Local** (personal override): `.claude/settings.local.json`
3. Merge the `spinnerVerbs` object into your existing settings

### Modes

- `"replace"` — use only the custom verbs
- `"append"` — add custom verbs to the default set

To switch modes, change the `"mode"` value in the JSON before pasting.

### Example

```json
{
  "spinnerVerbs": {
    "mode": "replace",
    "verbs": [
      "Using the Force",
      "Charging the flux capacitor"
    ]
  }
}
```

---

## License

[MIT](../../LICENSE)
