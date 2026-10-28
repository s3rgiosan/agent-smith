# Claude Skills

Skills teach Claude a way of working and switch on by themselves when the task fits. Each subdirectory here is one skill: a folder with a `SKILL.md` (with `name`/`description` frontmatter) that Claude loads when the description matches the task.

Install them with `install_claude_skills.sh` from `claude/scripts/`. It symlinks by default, so edits here take effect immediately.

## `grill-me`

A relentless interview that stress-tests a plan, decision, or design until you and Claude reach a shared understanding — every branch of the decision walked, nothing silently assumed.

Maps the plan as a **design tree** and works it in **rounds**: each round asks the whole *frontier* (every decision whose prerequisites are already settled), numbered, each with a recommended answer. Your answers reshape the tree; the frontier is recomputed and the next round asked. Facts about the environment are Claude's job to gather (read-only checks or a dispatched sub-agent), never yours to supply; a running decision log keeps status, recommendation, and blocking dependencies between rounds. Triggers on any "grill" phrase — e.g. "grill me on this".

## `mac-app-ui`

A UI standard for Mac apps, built on Apple's Human Interface Guidelines for macOS.

It first settles the app's platforms and shape (windowed, menu-bar-only, or windowed with a status item) from the repo or by asking, and records them in the project's CLAUDE.md. It then applies Apple's macOS type scale, semantic system colours and the user's accent, and a wiring contract for every menu item and permission. References cover Tauri and Electron webview apps, SwiftUI/AppKit apps, the shared menu, menu-bar extra, Settings, About and alert contract, and sourced macOS HIG facts. Before the app goes to the user for testing, verification renders every surface in WKWebView in light and dark, checks the type sizes and hard-coded colours, and compares controls and window chrome against real AppKit renders and a captured native window. The results go in a conformance table, and the app is handed over only when no row is Doesn't or Not checked. Triggers when building, restyling or reviewing one of these apps, or when a Mac app feels non-native, looks like a web page or a terminal, or has text that is too small.
