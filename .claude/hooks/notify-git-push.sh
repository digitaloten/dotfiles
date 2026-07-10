#!/usr/bin/env bash
# PostToolUse(Bash): detect a REAL `git push` and tell Claude to monitor CI.
#
# The old inline regex was \bgit\b[^&|;]*\bpush\b, which fired on:
#   git stash push          (subcommand, not a push)
#   git push --dry-run      (pushes nothing)
#   git log --grep=push     (the word, in an argument)
#   echo "git push"         (the word, in a string)
#
# Here `push` must be the git SUBCOMMAND: git, optional global options
# (-c k=v, -C dir, --no-pager, ...), then `push`.

set -uo pipefail

cmd=$(jq -r '.tool_input.command // empty')
[ -n "$cmd" ] || exit 0

# Did the tool actually succeed? A failed push needs no CI watch.
# tool_response shape varies; treat an explicit error/interrupt as failure.
if printf '%s' "${CLAUDE_TOOL_RESPONSE:-}" | grep -qi 'error'; then exit 0; fi

is_push() {
  printf '%s' "$1" | grep -qiP '(^|[;&|(]|&&|\|\||\bthen\b|\bdo\b|\belse\b)[[:space:]]*git[[:space:]]+(-[cC][[:space:]]+\S+[[:space:]]+|--no-pager[[:space:]]+|--git-dir=\S+[[:space:]]+|--work-tree=\S+[[:space:]]+)*push(?=[[:space:];&|)]|$)'
}

# --dry-run / -n push nothing.
is_dry_run() {
  printf '%s' "$1" | grep -qP 'push\b[^;&|]*(--dry-run|[[:space:]]-n\b)'
}

if is_push "$cmd" && ! is_dry_run "$cmd"; then
  printf '%s' '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"A git push just ran. Standing user instruction: after every push, monitor CI. Identify the pushed commit(s), then poll the repo CI until the pipeline reaches a terminal state (GitLab: glab ci status; GitHub: gh run watch). If a job failed, read its log and report the cause; retry transient/infra failures. Report the final pipeline status. Skip only if the push itself failed."}}'
fi
exit 0
