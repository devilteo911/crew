#!/usr/bin/env bash
# Stop hook of /issue-flow:implement and /issue-flow:big-implement: the roadmap "goal".
#
# It does not let the turn end while one of the issues in progress has unchecked boxes in its Plan.
# The state lives in <git-dir>/issue-flow/, never committed:
#   goal       the numbers of the issues in progress, one per line — just one for implement, all
#              the children of the project and the mother for big-implement (the mother has no Plan:
#              what counts are the boxes of its Issues section, ticked when a child is merged into
#              its branch); without it, the hook does nothing
#   in-flight  a subagent is at work — a phase one for implement, the child's runner for
#              big-implement — and its notification will wake the orchestrator
#   blocks     how many times in a row the hook has blocked with the same state
#
# When in doubt, let it stop (exit 0): a goal that cannot be verified must not turn into
# an infinite loop.

MAX_BLOCKS=5

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
cwd=$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null)
[ -n "$cwd" ] || cwd=$PWD
cd "$cwd" 2>/dev/null || exit 0

dir=$(git rev-parse --path-format=absolute --git-path issue-flow 2>/dev/null) || exit 0
[ -f "$dir/goal" ] || exit 0
[ -f "$dir/in-flight" ] && exit 0

warn() { echo "issue-flow: $*" >&2; exit 0; }

numbers=$(grep -o '[0-9]\+' "$dir/goal")
[ -n "$numbers" ] || warn "$dir/goal holds no issue number: goal ignored"

# same choice as TRACKER.md §1: the remote tells which tracker it is
remote=$(git remote get-url origin 2>/dev/null)

# sum the unchecked boxes of all the issues in the goal; remember the first one that has any
unchecked=0
first=""
for number in $numbers; do
  if [[ $remote == *github.com* ]]; then
    body=$(gh issue view "$number" --json body --jq '.body' 2>/dev/null | sed 's/\r$//')
  else
    body=$(glab issue view "$number" --output json 2>/dev/null | jq -r '.description // empty')
  fi
  [ -n "$body" ] || warn "cannot read issue #$number from the tracker: goal not verified"

  # only the boxes of the Plan (the legacy "## Piano" is still read); without a Plan section, the whole body
  plan=$(awk '/^## /{inside = ($0 ~ /^## (Plan|Piano)/)} inside' <<<"$body")
  [ -n "$plan" ] || plan=$body
  n=$(grep -c '^[[:space:]]*- \[ \]' <<<"$plan")
  if [ "$n" -gt 0 ] && [ -z "$first" ]; then
    first=$number
    phase=$(awk '/^### /{phase = substr($0, 5)} /^[[:space:]]*- \[ \]/{print phase; exit}' <<<"$plan")
  fi
  unchecked=$((unchecked + n))
done

if [ "$unchecked" -eq 0 ] && [ -z "$(git status --porcelain 2>/dev/null)" ]; then
  rm -f "$dir/goal" "$dir/blocks"
  exit 0
fi

# safety counter: if nothing changes between one block and the next, the turn is spinning
# idle and blocking it again is pointless
state="$(git rev-parse HEAD 2>/dev/null) $unchecked"
times=0
if [ -f "$dir/blocks" ] && [ "$(head -1 "$dir/blocks")" = "$state" ]; then
  times=$(sed -n 2p "$dir/blocks")
fi
times=$((times + 1))
printf '%s\n%s\n' "$state" "$times" >"$dir/blocks"
if [ "$times" -gt "$MAX_BLOCKS" ]; then
  rm -f "$dir/blocks"
  warn "#${first:-$numbers} stalled for $MAX_BLOCKS turns without progress: letting it stop"
fi

if [ "$unchecked" -eq 0 ]; then
  reason="Roadmap fully ticked, but there are uncommitted changes: commit the last phase as /issue-flow:implement says."
else
  reason="Roadmap of #$first is not complete: $unchecked unchecked boxes${phase:+, the first one in \"$phase\"}. Carry on as /issue-flow:implement says (or /issue-flow:big-implement, if you are running a project: check the child that the runner reported, then start a fresh issue-runner for the next one)."
fi
reason+=" If you are in one of the cases of \"When to really stop\", or you leave a box unchecked for a reason, remove $dir/goal and tell the user why you stop."

jq -n --arg r "$reason" '{decision: "block", reason: $r}'
