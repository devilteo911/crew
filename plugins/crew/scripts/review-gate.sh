#!/usr/bin/env bash
# review-gate.sh <issue> <sha> — no pull request towards the target branch without a passed review of its exact commit.
#
# Run by /crew:close, right before the push, with the SHA about to be pushed (git rev-parse HEAD), and by
# /crew:big-implement before the mother's pull request. It reads the issue's comments through tracker.sh, next to
# this script, and takes the latest comment whose first line (CR removed) is the marker /crew:review writes:
#   <!-- crew:review verdict=<passed|changes-requested> sha=<full SHA> -->
# A comment that quotes the marker further down does not count.
#
# Exit 0, and "review-gate: #<n> passed review at <sha7>" on stdout, only when that verdict is passed and its sha is
# <sha> character for character: the full SHA, never a prefix. Every other outcome exits 1 with one line on stderr that
# says what to do (no review, changes requested, another commit was reviewed). It fails closed, unlike the hooks:
# a missing jq, a failing tracker.sh or JSON that does not parse also exits 1, and tracker.sh's own message
# reaches stderr as it is.
#
# The marker is trusted, not its author: the gate catches a forgotten or a stale review, not a forged one.

set -u

refuse() { echo "review-gate: $*" >&2; exit 1; }

[[ $# -eq 2 && ${1:-} =~ ^[0-9]+$ && -n ${2:-} ]] || { echo "usage: review-gate.sh <issue> <sha>" >&2; exit 2; }
n=$1 sha=$2

command -v jq >/dev/null 2>&1 || refuse "jq is not installed: cannot read the reviews of #$n"

comments=$("$(dirname -- "$0")/tracker.sh" comment list "$n") || exit 1
marker=$(jq -r '[.[].body | gsub("\r"; "") | select(startswith("<!-- crew:review ")) | split("\n")[0]] | last // empty' <<<"$comments") || exit 1
verdict=$(sed -n 's/.* verdict=\([a-z-]*\).*/\1/p' <<<"$marker")
reviewed=$(sed -n 's/.* sha=\([0-9a-f]*\).*/\1/p' <<<"$marker")

[ -n "$marker" ] || refuse "#$n has no review. A pull request towards the target branch needs a passed review of its exact commit: run /crew:review $n, then close again."
case $verdict:$reviewed in
  passed:?*) ;;
  changes-requested:*) refuse "the latest review of #$n requested changes at ${reviewed:0:7}: fix them, then run /crew:review $n." ;;
  *) refuse "the latest review of #$n has a marker the gate cannot read ($marker): run /crew:review $n." ;;
esac
[ "$reviewed" = "$sha" ] || refuse "the latest review of #$n passed ${reviewed:0:7}, but the branch is at ${sha:0:7}: a commit after the review needs a new one, run /crew:review $n."

echo "review-gate: #$n passed review at ${sha:0:7}"
