#!/usr/bin/env bash
# tracker.sh <command> [args] — the only caller of gh and glab; which one comes from the origin remote
#   kind                               gh | glab; exit 1 when origin is neither
#   check                              the CLI is installed, authenticated and resolves the repo; else the remedy
#   view <n>                           {number,title,state,body,updatedAt}, state open|closed, body without CR
#   state <n>                          open | closed
#   list                               the open issues, as view objects, every page
#   body get <n> <file>                the body to <file> (no CR), its updated timestamp to <file>.stamp
#   body put <n> <file> [--shrink]     refuses an empty file, one under half the body, or an issue changed since body get
#   create <title> <file>              prints the new number
#   close <n>                          prints closed | already closed
#   comment add <n> <file>
#   comment list <n>                   [{body,createdAt}], oldest first, without GitLab's system notes
#   mr create <issue> <head> <base> <title> <file>   prints the MR/PR number
#   mr list [--head B] [--base B] [--merged]         [{number,state,head,base,url}], open unless --merged
#   mr state <n|branch>                open | merged | closed
#   mr retarget <n> <base>
#   mr checks <n>                      waits; success or none → exit 0, failed → exit 1
#   mr merge <n> <sha>                 never into the default branch; exit 1 unless merged now

# The CLIs are asked for JSON, never for --jq, and the JSON is filtered here with jq 1.6 features only.
# Every CLI call is captured and checked, never piped into jq: a failed call must not look like data.

set -u

die() { echo "tracker.sh: $*" >&2; exit 1; }
usage() { sed -n '2,/^$/s/^# \{0,1\}//p' "$0" >&2; exit 2; }
num() { [[ $1 =~ ^[0-9]+$ ]] || die "'$1' is not an issue number"; }

kind() {
  local url
  url=$(git remote get-url origin 2>/dev/null) || die "no origin remote: cannot tell GitHub from GitLab"
  case $url in
    *github*) echo gh ;;
    *gitlab*) echo glab ;;
    *) die "origin is $url: neither GitHub nor GitLab, ask the user which tracker this is" ;;
  esac
}

# stdin: one raw issue or an array of them (gh or glab shape) → the {number,title,state,body,updatedAt} shape
# -n with `input` fails on empty input, -e on a null result: an empty answer is never data
norm() {
  local p='{number, title, state, body, updatedAt}'
  [ "$K" = glab ] && p='{number: .iid, title, state, body: .description, updatedAt: .updated_at}'
  jq -en "def n: $p"'
    | if .number == null then error("not an issue") else . end
    | .state |= ((. // "") | ascii_downcase | sub("^opened$"; "open"))
    | .body |= ((. // "") | gsub("\r"; ""));
    input | if type == "array" then map(n) else n end'
}

# issue <n>: the normalised issue
issue() {
  local j
  if [ "$K" = gh ]; then
    j=$(gh issue view "$1" --json number,title,state,body,updatedAt) || die "gh issue view $1 failed"
  else
    j=$(glab issue view "$1" --output json) || die "glab issue view $1 failed"
  fi
  norm <<<"$j" || die "unreadable answer of $K for issue #$1"
}

# stamp <issue json>: the updated timestamp; a missing one would switch the body put guard off
stamp() { jq -er .updatedAt <<<"$1" || die "the issue carries no updated timestamp"; }

check() {
  local out
  if [ "$K" = gh ]; then
    out=$(gh auth status 2>&1) || die "gh is not authenticated: ask the user to run 'gh auth login --hostname github.com'. $out"
    out=$(gh issue list --state all --limit 1 --json number 2>&1) ||
      die "gh does not resolve the repo, usually the remote is an SSH alias: inside the repo run 'gh repo set-default OWNER/REPO' (or prefix a command with GH_REPO=OWNER/REPO). $out"
  else
    out=$(glab auth status 2>&1) || die "glab is not authenticated: ask the user to run 'glab auth login --hostname gitlab.com'. $out"
    out=$(glab issue list --all --per-page 1 --output json 2>&1) ||
      die "glab does not resolve the repo, usually the remote is an SSH alias: inside the repo run 'glab config set host gitlab.com'. $out"
  fi
  echo "$K ok"
}

list() {
  local j
  if [ "$K" = gh ]; then
    j=$(gh issue list --state open --limit 1000 --json number,title,state,body,updatedAt) || die "gh issue list failed"
  else
    j=$(glab api --paginate --output ndjson "projects/:fullpath/issues?state=opened&per_page=100") || die "glab api issues failed"
    j=$(jq -s . <<<"$j") || die "unreadable answer of glab api issues"
  fi
  norm <<<"$j" || die "unreadable answer of $K issue list"
}

body_get() { # n file
  local cur ts
  cur=$(issue "$1") || exit 1
  ts=$(stamp "$cur") || exit 1
  [ -n "$(jq -r .body <<<"$cur")" ] || die "issue #$1 has an empty body: nothing to read"
  jq -j .body <<<"$cur" >"$2" || die "cannot write $2"
  echo "$ts" >"$2.stamp"
}

body_put() { # n file [--shrink]
  local n=$1 f=$2 cur old ts
  [ -s "$f" ] || die "$f is empty: refusing to empty issue #$n"
  [ -f "$f.stamp" ] || die "no $f.stamp: run 'tracker.sh body get $n $f' first"
  # re-read the issue into $cur: while the stamp still matches, its body is the one body get read
  cur=$(issue "$n") || exit 1
  ts=$(stamp "$cur") || exit 1
  [ "$ts" = "$(cat "$f.stamp")" ] ||
    die "issue #$n changed since body get: run body get again and redo the change"
  old=$(jq -j .body <<<"$cur" | wc -c)
  [ "${3:-}" = --shrink ] || [ $(($(wc -c <"$f") * 2)) -ge "$old" ] ||
    die "$f is under half of the $old bytes of issue #$n: pass --shrink if that is the intent"
  # ponytail: a change made between the check and the write, or in the same second on GitHub, goes unseen; neither CLI can write conditionally
  if [ "$K" = gh ]; then
    gh issue edit "$n" --body-file "$f" >/dev/null || die "gh issue edit $n failed"
  else
    glab issue update "$n" --description-file "$f" >/dev/null || die "glab issue update $n failed"
  fi
  cur=$(issue "$n") || exit 1
  ts=$(stamp "$cur") || exit 1
  echo "$ts" >"$f.stamp"
}

create() { # title file
  local out n
  [ -s "$2" ] || die "$2 is empty: refusing to create an issue without a body"
  if [ "$K" = gh ]; then
    out=$(gh issue create --title "$1" --body-file "$2") || die "gh issue create failed"
  else
    out=$(glab issue create --title "$1" --description-file "$2" --yes) || die "glab issue create failed"
  fi
  n=$(sed -n 's|.*/issues/\([0-9][0-9]*\).*|\1|p' <<<"$out" | tail -n 1)
  [ -n "$n" ] || die "no issue number in the answer of $K: $out"
  echo "$n"
}

close() { # n
  local cur
  cur=$(issue "$1") || exit 1
  if [ "$(jq -r .state <<<"$cur")" = closed ]; then echo "already closed"; return; fi
  "$K" issue close "$1" >/dev/null || die "$K issue close $1 failed"
  echo closed
}

comment_add() { # n file
  [ -s "$2" ] || die "$2 is empty: refusing to post an empty comment"
  if [ "$K" = gh ]; then
    gh issue comment "$1" --body-file "$2" >/dev/null || die "gh issue comment $1 failed"
  else
    glab issue note "$1" --message "$(cat "$2")" >/dev/null || die "glab issue note $1 failed"
  fi
}

comment_list() { # n
  local j sel
  if [ "$K" = gh ]; then
    j=$(gh issue view "$1" --json comments) || die "gh issue view $1 failed"
    sel='[.comments[] | {body, createdAt}]'
  else
    j=$(glab api --paginate --output ndjson "projects/:fullpath/issues/$1/notes?sort=asc&order_by=created_at&per_page=100") ||
      die "glab api notes of issue $1 failed"
    j=$(jq -s . <<<"$j") || die "unreadable answer of glab api notes"
    sel='map(select(.system | not) | {body, createdAt: .created_at})'
  fi
  jq -en 'input | '"$sel"'
    | sort_by(.createdAt)
    | map(.body |= ((. // "") | gsub("\r"; "")))' <<<"$j" || die "unreadable answer of $K for the comments of issue #$1"
}

# mr_create <issue> <head> <base> <title> <file>: the new MR/PR's number
mr_create() {
  local f=$5 body out n
  [ -s "$f" ] || die "$f is empty: refusing to open an MR/PR with an empty body"
  if [ "$K" = gh ]; then
    # gh has no --related-issue: the link to the issue is `Closes #<issue>` on the first line of the body
    body=$f
    if [ "$(head -n 1 "$f" | tr -d '\r')" != "Closes #$1" ]; then
      tmp=$(mktemp) || die "cannot make a temporary file"
      trap 'rm -f "$tmp"' EXIT
      { printf 'Closes #%s\n\n' "$1"; cat "$f"; } >"$tmp" || die "cannot write $tmp"
      body=$tmp
    fi
    out=$(gh pr create --head "$2" --base "$3" --title "$4" --body-file "$body") || die "gh pr create failed"
  else
    out=$(glab mr create --related-issue "$1" --source-branch "$2" --target-branch "$3" --title "$4" \
      --description-file "$f" --remove-source-branch --yes) || die "glab mr create failed"
  fi
  n=$(sed -nE 's#.*/(pull|merge_requests)/([0-9]+).*#\2#p' <<<"$out" | tail -n 1)
  [ -n "$n" ] || die "no MR/PR number in the answer of $K: $out"
  echo "$n"
}

# mr_list [--head B] [--base B] [--merged]: [{number,state,head,base,url}], state lowercase, open unless --merged
mr_list() {
  local head='' base='' st=open j sel a
  while [ $# -gt 0 ]; do
    case $1 in
      --head) [ -n "${2:-}" ] || usage; head=$2; shift ;;
      --base) [ -n "${2:-}" ] || usage; base=$2; shift ;;
      --merged) st=merged ;;
      *) usage ;;
    esac
    shift
  done
  if [ "$K" = gh ]; then
    a=(--state "$st" --limit 1000 --json "number,state,headRefName,baseRefName,url")
    [ -n "$head" ] && a+=(--head "$head")
    [ -n "$base" ] && a+=(--base "$base")
    j=$(gh pr list "${a[@]}") || die "gh pr list failed"
    sel='{number, state, head: .headRefName, base: .baseRefName, url}'
  else
    # ponytail: one page of 100 is enough for the MRs of one branch; paginate with glab api if a branch ever has more
    a=(--per-page 100 --output json)
    [ -n "$head" ] && a+=(--source-branch "$head")
    [ -n "$base" ] && a+=(--target-branch "$base")
    [ "$st" = merged ] && a+=(--merged)
    j=$(glab mr list "${a[@]}") || die "glab mr list failed"
    sel='{number: .iid, state, head: .source_branch, base: .target_branch, url: .web_url}'
  fi
  jq -en 'input | (. // []) | map('"$sel"' | .state |= (ascii_downcase | sub("^opened$"; "open")))' <<<"$j" ||
    die "unreadable answer of $K for the MR/PR list"
}

# mr_state <n|branch>: open | merged | closed
mr_state() {
  local j
  if [ "$K" = gh ]; then
    j=$(gh pr view "$1" --json state) || die "gh pr view $1 failed"
  else
    j=$(glab mr view "$1" --output json) || die "glab mr view $1 failed"
  fi
  jq -enr 'input | .state | ascii_downcase | sub("^opened$"; "open")' <<<"$j" || die "unreadable answer of $K for the state of MR/PR $1"
}

mr_retarget() { # n base
  [ -n "$2" ] || die "no base branch given"
  if [ "$K" = gh ]; then
    gh pr edit "$1" --base "$2" >/dev/null || die "gh pr edit $1 failed"
  else
    glab mr update "$1" --target-branch "$2" --yes >/dev/null || die "glab mr update $1 failed"
  fi
}

# mr_checks <n>: waits for the pipelines; prints success | none, or the failure and exit 1
mr_checks() {
  local j s out
  if [ "$K" = gh ]; then
    out=$(gh pr checks "$1" --watch --fail-fast 2>&1) && { echo success; return; }
    case $out in *"no checks reported"*) echo none; return ;; esac
    echo "$out" >&2
    echo failed
    exit 1
  fi
  while :; do
    j=$(glab mr view "$1" --output json) || die "glab mr view $1 failed"
    # a missing head_pipeline is `none`, but an answer that is no MR at all must not read as green
    s=$(jq -enr 'input | if .iid == null then error("not an MR") else .head_pipeline.status // "none" end' <<<"$j") ||
      die "unreadable answer of glab for MR $1"
    case $s in created|waiting_for_resource|preparing|pending|running|scheduled) sleep 10 ;; *) break ;; esac
  done
  echo "$s"
  [ "$s" = success ] || [ "$s" = none ] || exit 1
}

# mr_merge <n> <sha>: merges only when the MR/PR does not target the default branch, and only that commit
mr_merge() {
  local b d base def s
  [[ $2 =~ ^[0-9a-fA-F]{7,64}$ ]] || die "'$2' is not a commit sha: the merge must be tied to the commit that was verified"
  if [ "$K" = gh ]; then
    b=$(gh pr view "$1" --json baseRefName) || die "gh pr view $1 failed"
    d=$(gh repo view --json defaultBranchRef) || die "gh repo view failed"
    base=$(jq -enr 'input | .baseRefName | select(length > 0)' <<<"$b") || die "unreadable base branch of PR $1"
    def=$(jq -enr 'input | .defaultBranchRef.name | select(length > 0)' <<<"$d") || die "unreadable default branch of the repo"
  else
    b=$(glab mr view "$1" --output json) || die "glab mr view $1 failed"
    d=$(glab repo view --output json) || die "glab repo view failed"
    base=$(jq -enr 'input | .target_branch | select(length > 0)' <<<"$b") || die "unreadable target branch of MR $1"
    def=$(jq -enr 'input | .default_branch | select(length > 0)' <<<"$d") || die "unreadable default branch of the repo"
  fi
  [ "$base" != "$def" ] || die "MR/PR $1 targets $def, the default branch: that merge belongs to the user"
  if [ "$K" = gh ]; then
    # --merge keeps the phases' commits, with their (#<number>), in the history of the mother branch;
    # --match-head-commit merges only the commit that was verified
    gh pr merge "$1" --merge --match-head-commit "$2" --delete-branch >/dev/null || die "gh pr merge $1 failed"
  else
    # --auto-merge=false: without it glab defers the merge to the end of the pipeline, and the next child
    # would be born from a mother branch that still lacks this one; --sha merges only the verified commit
    glab mr merge "$1" --sha "$2" --auto-merge=false --remove-source-branch --yes >/dev/null || die "glab mr merge $1 failed"
  fi
  s=$(mr_state "$1") || exit 1
  [ "$s" = merged ] || die "MR/PR $1 is $s after the merge, not merged: the server queued it, set auto-merge or refused it"
}

# command and arity
case "${1:-} ${2:-}:$#" in
  "kind :1"|"check :1"|"list :1"|"view "*:2|"state "*:2|"close "*:2|"create "*:3) ;;
  "body get:4"|"body put:4"|"body put:5"|"comment add:4"|"comment list:3") ;;
  "mr create:7"|"mr list:"*|"mr state:3"|"mr retarget:4"|"mr checks:3"|"mr merge:4") ;;
  *) usage ;;
esac

[ "$1" = kind ] && { kind; exit; }
K=$(kind) || exit 1
command -v "$K" >/dev/null 2>&1 || {
  [ "$K" = gh ] && url=https://cli.github.com || url=https://gitlab.com/gitlab-org/cli
  die "$K is not installed and cannot be installed silently: install it from $url, then run '$K auth login'"
}

case $1 in view|state|close) num "$2" ;; body|comment) num "$3" ;; esac
case "$1 ${2:-}" in "mr create"|"mr retarget"|"mr checks"|"mr merge") num "$3" ;; esac
[ "$1 ${2:-}:$#" = "body put:5" ] && [ "$5" != --shrink ] && usage

case "$1 ${2:-}" in
  "check ") check ;;
  "list ") list ;;
  "view "*) issue "$2" ;;
  "state "*) cur=$(issue "$2") || exit 1; jq -r .state <<<"$cur" ;;
  "body get") body_get "$3" "$4" ;;
  "body put") body_put "$3" "$4" "${5:-}" ;;
  "create "*) create "$2" "$3" ;;
  "close "*) close "$2" ;;
  "comment add") comment_add "$3" "$4" ;;
  "comment list") comment_list "$3" ;;
  "mr create") mr_create "$3" "$4" "$5" "$6" "$7" ;;
  "mr list") shift 2; mr_list "$@" ;;
  "mr state") mr_state "$3" ;;
  "mr retarget") mr_retarget "$3" "$4" ;;
  "mr checks") mr_checks "$3" ;;
  "mr merge") mr_merge "$3" "$4" ;;
esac
