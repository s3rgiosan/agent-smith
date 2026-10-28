# Claude Skills

Skills teach Claude a way of working and switch on by themselves when the task fits. Each subdirectory here is one skill: a folder with a `SKILL.md` (with `name`/`description` frontmatter) that Claude loads when the description matches the task.

Install them with `install_claude_skills.sh` from `claude/scripts/`. It symlinks by default, so edits here take effect immediately.

## `grill-me`

A relentless interview that stress-tests a plan, decision, or design until you and Claude reach a shared understanding — every branch of the decision walked, nothing silently assumed.

## `mac-app-ui`

A UI standard for Mac apps, built on Apple's Human Interface Guidelines for macOS.

It starts by asking which platforms the app targets, whether it needs a menu-bar extra, and its shape. It then applies house conventions for type, system colours and the user's accent, selection, the app menu bar, the Settings window, the About panel, errors, empty states, icons and accessibility. References cover Tauri and Electron webview apps, SwiftUI/AppKit apps, and sourced macOS HIG facts. Two scripts check a webview UI: one renders it in WKWebView in light or dark, the other renders real AppKit controls to compare against. Triggers when building, restyling or reviewing one of these apps, or when a Mac app UI looks like a web page or a terminal or its text is too small.

Maps the plan as a **design tree** and works it in **rounds**: each round asks the whole *frontier* (every decision whose prerequisites are already settled), numbered, each with a recommended answer. Your answers reshape the tree; the frontier is recomputed and the next round asked. Facts about the environment are Claude's job to gather (read-only checks or a dispatched sub-agent), never yours to supply; a running decision log keeps status, recommendation, and blocking dependencies between rounds. Triggers on any "grill" phrase — e.g. "grill me on this".
