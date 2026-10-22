#!/usr/bin/env bash
# PreToolUse hook (hooks/hooks.json) on Bash and Monitor: keeps crew:issue-phase and crew:issue-writer
# from committing and from writing to the tracker. The orchestrator does both, and the agents say what is
# left in their report.
#
# The list is not the agents' `disallowedTools`: an entry with a specifier, `Bash(git push *)`, removes the
# whole Bash tool from the subagent, not only the matching commands. A plugin cannot ship the
# `permissions.deny` rule that would do it, but its hooks run inside the plugin's subagents, and their
# input carries `agent_type`. Only the two agents are guarded: the main session and crew:issue-runner,
# which commit, never see this hook, and a missing jq or an unreadable input lets the call through.
#
# Exit 2 stops the call, and the agent reads stderr as the tool result. Anything else: exit 0, silent.
# tracker.sh is matched too: its `body put` runs `gh issue edit` as a subprocess, which no hook sees.
#
# ponytail: this reads the command as written, so `git -C dir commit`, `env X=1 git commit`,
# `gh -R o/r issue edit` or `bash -c '…'` go through, and a heredoc line that starts with `git commit`
# is refused. It is a guardrail for agents that follow their instructions, not a sandbox; a parser of
# shell is the upgrade if an agent ever works around it.

set -u

command -v jq >/dev/null 2>&1 || exit 0
input=$(cat)
agent=$(jq -r '.agent_type // empty' <<<"$input" 2>/dev/null) || exit 0

# grep -E, POSIX only, one line at a time: a command starts at the start of a line or after ; & | ( or `,
# and after any of the reserved words and braces that may stand before it there (`if x; then git push`)
start='(^|[;&|(`])[[:space:]]*((if|then|do|else|elif|while|until|time|!|\{)[[:space:]]+)*'
end='([[:space:]]|$|[;&|)])'
w='[[:space:]]+'
tracker="[^\"']*tracker\\.sh[\"']?"
both="git${w}(commit|push|reset|checkout|switch)"
both="$both|gh${w}issue${w}(edit|close|comment)|gh${w}pr${w}(create|merge)"
both="$both|glab${w}issue${w}(update|close|note)|glab${w}mr${w}(create|merge)"
both="$both|[\"']?${tracker}${w}(body${w}put|create|close|comment${w}add|mr${w}(create|merge|retarget))"
writer="git${w}stash|gh${w}issue${w}create|gh${w}pr|glab${w}issue${w}create|glab${w}mr"
case $agent in
  *issue-phase) pattern=$both ;;
  *issue-writer) pattern="$both|$writer" ;;
  *) exit 0 ;;
esac

# a Monitor started with `ws` has no command
cmd=$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null) || exit 0
[ -n "$cmd" ] || exit 0
hit=$(printf '%s\n' "$cmd" | grep -oE -e "$start($pattern)$end" | head -n 1)
[ -n "$hit" ] || exit 0
hit=$(sed -E "s/^$start//; s/[^[:alnum:]]+\$//" <<<"$hit")
echo "crew: $agent does not run '$hit': the orchestrator commits and writes to the tracker, say what is left in your report" >&2
exit 2
