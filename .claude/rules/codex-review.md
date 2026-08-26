# Codex Review Fold-In

Claude Code only — this file lives under `~/.claude/rules/`, which only Claude
Code loads. It governs the `codex@openai-codex` plugin ("Use Codex from Claude
Code"); the Codex CLI itself never sees `/codex:review`, so this rule does not
belong in the shared `~/.config/agents/AGENTS.md`. Dormant while the plugin is
not in `settings.json` `enabledPlugins`.

Any Codex review invocation (`/codex:review`, `/codex:adversarial-review`, or
`codex-rescue` output containing review-style findings) → automatically review
and verify Codex's findings, then fold in. This supersedes the plugin's own
`codex-result-handling` skill rule to stop after presenting findings and ask
before touching a file — overridden for these invocations.

**The sequence:**

1. **Present** — show Codex's findings verbatim first (per plugin contract):
   file/line, severity, evidence boundaries (inference vs confirmed) intact.
2. **Verify** — independently check each finding against source before acting on
   it. Reject false positives explicitly, with the reason. Never rubber-stamp a
   finding because Codex reported it.
3. **Fold in** — apply verified fixes to the code directly. No confirmation
   prompt for this step.
4. **Flag** — don't auto-apply, ask the user instead, for: a finding Codex
   marked as inference/uncertain rather than confirmed, a fix with more than one
   reasonable implementation, or anything touching prod data/DDL/ destructive
   ops (still gated per OPS.md Destructive ops & data safety).
5. **Commit** — per the repo's own commit rule, if one applies.

Same discipline as Plan Review: a finding earns its fix by clearing independent
verification, not by being reported.
