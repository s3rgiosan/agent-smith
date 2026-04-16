# Claude Code Spinner Verbs

A collection of custom spinner verb themes for [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

Spinner verbs are the action phrases shown while Claude is working (e.g., "Using the Force for 12s").

## Available Themes

| Theme | File | Verbs |
|-------|------|-------|
| Movie Quotes | [movie-quotes.json](movie-quotes.json) | 36 |
| Monty Python | [monty-python.json](monty-python.json) | 30 |
| Pirate | [pirate.json](pirate.json) | 30 |
| Portuguese | [portuguese.json](portuguese.json) | 39 |
| Hugo (TV Game) | [hugo.json](hugo.json) | 8 |

## Usage

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
