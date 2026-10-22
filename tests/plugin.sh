#!/bin/sh
# Tests of the crew plugin's scripts: plugins/crew/scripts/tracker.sh against stubbed gh and glab, on
# both platforms. It covers kind, check, body get and the three guards of body put, state, comments,
# create, close, list, and the mr commands (create, list, state, checks, merge); then the Stop hook
# goal-stop.sh, run as Claude Code runs it, on top of the same stubs.
# Run it from anywhere: sh tests/plugin.sh
# Every assertion prints "ok <what>" or "FAIL <what>" and the run goes on; the exit status is 1 when
# any FAIL was printed. Nothing outside the temp dir changes: HOME and PATH are replaced, stubs stand
# in for gh and glab, and a throwaway repo stands in for the one tracker.sh runs inside.
src=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd) || exit 1
tracker="$src/plugins/crew/scripts/tracker.sh"
realgit=$(command -v git) || { echo "FAIL setup: git not found"; exit 1; }
realjq=$(command -v jq) || { echo "FAIL setup: jq not found"; exit 1; }
t=$(mktemp -d) || exit 1
trap 'rm -rf "$t"' EXIT
trap 'exit 1' HUP INT TERM
t=$(CDPATH='' cd -- "$t" && pwd -P) || exit 1

export HOME="$t/home"
export PATH="$t/bin:/usr/bin:/bin"
export GIT_TERMINAL_PROMPT=0 GIT_CONFIG_NOSYSTEM=1 STUB_T="$t"
unset GH_TOKEN GITHUB_TOKEN GITLAB_TOKEN GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
mkdir -p "$HOME" "$t/bin" "$t/fx/gh" "$t/fx/glab" || exit 1
cd "$t" || exit 1

npass=0 nfail=0
SHA=0123456789abcdef0123456789abcdef01234567
cr=$(printf '\r')
B0=$(printf '# T\r\n\r\n- [ ] one\r\n- [ ] two\r\n- [ ] three') # a body as the server keeps it: CRLF, no final newline
B1=$(printf '# T\r\n\r\n- [x] one\r\n- [ ] two\r\n- [ ] three') # the same, with a box ticked from the page

# --- helpers -------------------------------------------------------------------------------

check() { # <what> <exit status of the test>
  if [ "$2" -eq 0 ]; then
    npass=$((npass + 1))
    echo "ok $1"
  else
    nfail=$((nfail + 1))
    echo "FAIL $1"
    echo "#   last call: rc=$rc out=[$out] err=[$err]"
  fi
}
die() {
  echo "FAIL $*"
  echo "plugin: aborted"
  exit 1
}
g() { "$realgit" -c user.name=crew-test -c user.email=crew-test@example.invalid -c commit.gpgsign=false "$@"; }
is() { [ "$@" ]; } # a test whose status check() reads (shellcheck reads $? after a bare [ ] as a condition)
has_text() { case $1 in *"$2"*) return 0 ;; esac; return 1; } # <haystack> <needle>
run() { # <tracker.sh args>: rc, out and err of one call from inside the repo; both CLI logs start empty
  : >"$t/gh.log"
  : >"$t/glab.log"
  out=$(cd "$t/repo" && "$tracker" "$@" 2>"$t/err")
  rc=$?
  err=$(cat "$t/err")
}
logged() { grep -Fxq -- "$1" "$t/$K.log"; } # <line>: the CLI got exactly this call
json() { printf '%s\n' "$out" | jq -c "$1"; } # <jq filter>: applied to the last answer
issue() { # <cli> <n> <state> <body> <updated>: issue-<n>.json in the cli's raw shape; an empty body is "" on gh, null on glab
  if [ "$1" = gh ]; then
    jq -n --argjson n "$2" --arg s "$3" --arg b "$4" --arg u "$5" \
      '{number: $n, title: "T", state: $s, body: $b, updatedAt: $u, comments: []}'
  else
    jq -n --argjson n "$2" --arg s "$3" --arg b "$4" --arg u "$5" \
      '{iid: $n, title: "T", state: $s, description: (if $b == "" then null else $b end), updated_at: $u}'
  fi >"$t/fx/$1/issue-$2.json"
}
mrfx() { # <n> <state> <base> <pipeline status, "" for none>: pr-<n>.json or mr-<n>.json in the raw shape
  if [ "$K" = gh ]; then
    jq -n --argjson n "$1" --arg s "$2" --arg b "$3" \
      '{number: $n, state: $s, headRefName: "issue-12", baseRefName: $b, url: "https://github.com/o/r/pull/\($n)"}' >"$t/fx/gh/pr-$1.json"
  else
    jq -n --argjson n "$1" --arg s "$2" --arg b "$3" --arg p "$4" \
      '{iid: $n, state: $s, source_branch: "issue-12", target_branch: $b, web_url: "https://gitlab.com/o/r/-/merge_requests/\($n)", head_pipeline: (if $p == "" then null else {status: $p} end)}' >"$t/fx/glab/mr-$1.json"
  fi
}
fxbody() { jq -j '.body // .description' "$t/fx/$K/issue-7.json"; }
fxstamp() { jq -r '.updatedAt // .updated_at' "$t/fx/$K/issue-7.json"; }
fx_is() { fxbody >"$t/fx.body" && cmp -s "$t/fx.body" "$1"; } # <file>: the issue's body is this file, byte for byte
refused() { # <what> <text stderr must have>: the last body put was refused, wrote nothing, left the body as $before
  is "$rc" -ne 0
  check "$K body put: $1 exits non-zero" $?
  has_text "$err" "$2"
  check "$K body put: $1 says why ('$2')" $?
  ! grep -Eq '^issue (edit|update) ' "$t/$K.log"
  check "$K body put: $1 sends no write" $?
  is "$(fxbody)" = "$before"
  check "$K body put: $1 leaves the issue's body" $?
}
platform() { # <gh|glab>: the origin and the raw words of that platform
  K=$1
  if [ "$K" = gh ]; then
    url=https://github.com/o/r.git OPEN=OPEN CLOSED=CLOSED MERGED=MERGED MR=pr
    T0=2026-10-06T23:17:13Z T1=2026-10-06T23:20:00Z C1=2026-10-01T00:00:00Z C2=2026-10-02T00:00:00Z
    upd="issue edit" flag=--body-file
    merge_line="pr merge 9 --merge --match-head-commit $SHA --delete-branch"
    echo '{"defaultBranchRef": {"name": "main"}}' >"$t/fx/gh/repo.json"
  else
    url=git@gitlab.com:g/r.git OPEN=opened CLOSED=closed MERGED=merged MR=mr
    T0=2024-07-24T21:14:34.463Z T1=2024-07-24T21:20:00.000Z C1=2024-10-01T00:00:00.000Z C2=2024-10-02T00:00:00.000Z
    upd="issue update" flag=--description-file
    merge_line="mr merge 9 --sha $SHA --auto-merge=false --remove-source-branch --yes"
    echo '{"default_branch": "main"}' >"$t/fx/glab/repo.json"
  fi
  g -C "$t/repo" remote set-url origin "$url" || die "setup: origin of the repo"
}

# --- stubs ---------------------------------------------------------------------------------

# gh and glab in one file: appends its arguments to $STUB_T/<cli>.log, one call per line, and serves the
# fixtures of $STUB_T/fx/<cli>/ in the cli's raw shape. A write (issue edit or update) changes the
# fixture and its timestamp; a fixture that is missing is an exit 1 with a message.
cat >"$t/bin/gh" <<'EOF'
#!/bin/sh
c=${0##*/}
fx=$STUB_T/fx/$c
printf '%s\n' "$*" >>"$STUB_T/$c.log"
die() { echo "stub $c: $*" >&2; exit 1; }
need() { [ -f "$1" ] || die "no fixture ${1#"$STUB_T"/}"; }
now() { # a new timestamp at every call, to the second on gh and to the millisecond on glab
  n=$(($(cat "$STUB_T/clock") + 1))
  echo "$n" >"$STUB_T/clock"
  if [ "$c" = gh ]; then printf '2030-01-01T00:00:%02dZ' "$n"; else printf '2030-01-01T00:00:00.%03dZ' "$n"; fi
}
if [ "$c" = gh ]; then
  bk=body tk=updatedAt web=https://github.com/o/r pr=pull
else
  bk=description tk=updated_at web=https://gitlab.com/o/r/- pr=merge_requests
fi
# the file given with --body-file or --description-file is kept: tracker.sh may delete it afterwards
f= p=
for a in "$@"; do
  case $p in --body-file|--description-file) f=$a; cp "$f" "$STUB_T/$c.sent" ;; esac
  p=$a
done
case "$1 $2" in
  "auth status")
    if [ -e "$fx/unauth" ]; then echo "not logged in" >&2; exit 1; fi
    echo "logged in" ;;
  "issue view") need "$fx/issue-$3.json"; cat "$fx/issue-$3.json" ;;
  "issue list") cat "$fx"/issue-*.json 2>/dev/null | jq -s . ;;
  "issue edit"|"issue update")
    need "$fx/issue-$3.json"
    jq --rawfile b "$f" --arg s "$(now)" ".$bk = \$b | .$tk = \$s" "$fx/issue-$3.json" >"$fx/new" &&
      mv "$fx/new" "$fx/issue-$3.json" ;;
  "issue create") echo "$web/issues/42" ;;
  "issue close"|"issue comment"|"issue note"|"pr edit"|"mr update"|"pr merge"|"mr merge") ;;
  "pr create"|"mr create") echo "$web/$pr/17" ;;
  "pr view"|"mr view") need "$fx/$1-$3.json"; cat "$fx/$1-$3.json" ;;
  "pr list"|"mr list") cat "$fx/$1"-*.json 2>/dev/null | jq -s . ;;
  "pr checks")
    if [ -f "$fx/checks.fail" ]; then cat "$fx/checks.fail" >&2; exit 1; fi ;;
  "repo view") need "$fx/repo.json"; cat "$fx/repo.json" ;;
  "api --paginate")
    case $5 in
      */notes*) n=${5#*issues/}; n=${n%%/*}; need "$fx/notes-$n.json"; jq -c '.[]' "$fx/notes-$n.json" ;;
      *) cat "$fx"/issue-*.json 2>/dev/null | jq -c . ;;
    esac ;;
  *) die "unexpected call: $*" ;;
esac
EOF
cp "$t/bin/gh" "$t/bin/glab"
# git and jq: tracker.sh finds them through the replaced PATH
printf '#!/bin/sh\nexec "%s" "$@"\n' "$realgit" >"$t/bin/git"
printf '#!/bin/sh\nexec "%s" "$@"\n' "$realjq" >"$t/bin/jq"
chmod +x "$t"/bin/*
echo 0 >"$t/clock"

# --- the repo tracker.sh runs in -----------------------------------------------------------

mkdir "$t/repo" || die "setup: repo dir"
g -C "$t/repo" init -q || die "setup: git init"
g -C "$t/repo" commit -q --allow-empty -m "test: the one commit" || die "setup: commit"
g -C "$t/repo" remote add origin https://github.com/o/r.git || die "setup: origin"

# =============================================================================================
echo "== kind"
for u in https://github.com/o/r.git git@github.com-work:o/r.git git@gitlab.com:g/r.git; do
  g -C "$t/repo" remote set-url origin "$u" || die "setup: origin $u"
  run kind
  case $u in *github*) want=gh ;; *) want=glab ;; esac
  is "$rc,$out" = "0,$want"
  check "kind: $u is $want" $?
done
g -C "$t/repo" remote set-url origin https://example.com/o/r.git || die "setup: origin example.com"
run kind
is "$rc" -ne 0
check "kind: a remote that is neither exits non-zero" $?
is "$out" = ""
check "kind: a remote that is neither prints nothing" $?
g -C "$t/repo" remote remove origin || die "setup: remove origin"
run kind
is "$rc" -ne 0
check "kind: a repo without origin exits non-zero" $?
is "$out" = ""
check "kind: a repo without origin prints nothing" $?
g -C "$t/repo" remote add origin https://github.com/o/r.git || die "setup: origin"

# =============================================================================================
for K in gh glab; do
  platform "$K"
  echo "== $K"

  # --- check ---
  touch "$t/fx/$K/unauth"
  run check
  is "$rc" -ne 0
  check "$K check: unauthenticated exits non-zero" $?
  has_text "$err" "$K auth login"
  check "$K check: unauthenticated names '$K auth login'" $?
  rm "$t/fx/$K/unauth"
  run check
  is "$rc,$out" = "0,$K ok"
  check "$K check: authenticated prints '$K ok'" $?

  # --- body get ---
  issue "$K" 7 "$OPEN" "$B0" "$T0"
  run body get 7 "$t/b.md"
  is "$rc" -eq 0
  check "$K body get: exits 0" $?
  is "$(grep -c "$cr" "$t/b.md")" = 0
  check "$K body get: no CR in the file" $?
  printf '# T\n\n- [ ] one\n- [ ] two\n- [ ] three' | cmp -s - "$t/b.md"
  check "$K body get: the body, byte for byte" $?
  is "$(cat "$t/b.md.stamp")" = "$T0"
  check "$K body get: the stamp is the fixture's timestamp" $?
  issue "$K" 7 "$OPEN" "" "$T0"
  run body get 7 "$t/e.md"
  is "$rc" -ne 0
  check "$K body get: an empty body exits non-zero" $?

  # --- body put refuses ---
  issue "$K" 7 "$OPEN" "$B0" "$T0"
  run body get 7 "$t/p.md"
  before=$(fxbody)
  : >"$t/empty.md"
  cp "$t/p.md.stamp" "$t/empty.md.stamp"
  run body put 7 "$t/empty.md"
  refused "an empty file" "is empty"
  cp "$t/p.md" "$t/nostamp.md"
  run body put 7 "$t/nostamp.md"
  refused "a missing .stamp" ".stamp: run"
  issue "$K" 7 "$OPEN" "$B1" "$T1" # the user ticked a box from the page after body get
  before=$(fxbody)
  run body put 7 "$t/p.md"
  refused "a stamp older than the issue" "changed since body get"
  issue "$K" 7 "$OPEN" "$B0" "$T0"
  run body get 7 "$t/p.md"
  before=$(fxbody)
  printf 'x\n' >"$t/short.md"
  cp "$t/p.md.stamp" "$t/short.md.stamp"
  run body put 7 "$t/short.md"
  refused "a file under half the body" "under half"

  # --- body put passes ---
  issue "$K" 7 "$OPEN" "$B0" "$T0"
  run body get 7 "$t/ok.md"
  printf '\n- [x] four' >>"$t/ok.md"
  run body put 7 "$t/ok.md"
  is "$rc" -eq 0
  check "$K body put: a good file exits 0" $?
  logged "$upd 7 $flag $t/ok.md"
  check "$K body put: the call is '$upd 7 $flag <file>'" $?
  fx_is "$t/ok.md"
  check "$K body put: the issue's body is the file" $?
  is "$(cat "$t/ok.md.stamp")" = "$(fxstamp)"
  check "$K body put: the stamp is the issue's new timestamp" $?
  is "$(fxstamp)" != "$T0"
  check "$K body put: the timestamp did move" $?
  issue "$K" 7 "$OPEN" "$B0" "$T0"
  run body get 7 "$t/s.md"
  printf 'x\n' >"$t/s.md"
  run body put 7 "$t/s.md" --shrink
  is "$rc" -eq 0
  check "$K body put --shrink: the short file exits 0" $?
  logged "$upd 7 $flag $t/s.md"
  check "$K body put --shrink: the call is made" $?
  fx_is "$t/s.md"
  check "$K body put --shrink: the issue's body is the file" $?

  # --- state ---
  issue "$K" 7 "$OPEN" "$B0" "$T0"
  run state 7
  is "$out" = open
  check "$K state: $OPEN prints open" $?
  issue "$K" 7 "$CLOSED" "$B0" "$T0"
  run state 7
  is "$out" = closed
  check "$K state: $CLOSED prints closed" $?
  for pair in "$OPEN:open" "$MERGED:merged" "$CLOSED:closed"; do
    mrfx 9 "${pair%%:*}" main ""
    run mr state 9
    is "$out" = "${pair##*:}"
    check "$K mr state: ${pair%%:*} prints ${pair##*:}" $?
  done

  # --- comments ---
  issue "$K" 7 "$OPEN" "$B0" "$T0"
  if [ "$K" = gh ]; then
    jq --arg c1 "$C1" --arg c2 "$C2" \
      '.comments = [{body: "second\r\nline", createdAt: $c2}, {body: "first", createdAt: $c1}]' \
      "$t/fx/gh/issue-7.json" >"$t/new" && mv "$t/new" "$t/fx/gh/issue-7.json"
  else
    jq -n --arg c1 "$C1" --arg c2 "$C2" \
      '[{body: "second\r\nline", created_at: $c2, system: false}, {body: "closed", created_at: "2024-10-01T12:00:00.000Z", system: true}, {body: "first", created_at: $c1, system: false}]' \
      >"$t/fx/glab/notes-7.json"
  fi
  run comment list 7
  want=$(jq -nc --arg c1 "$C1" --arg c2 "$C2" '[{body: "first", createdAt: $c1}, {body: "second\nline", createdAt: $c2}]')
  is "$(json .)" = "$want"
  check "$K comment list: newest-first fixtures come out oldest first, CR stripped, createdAt kept" $?
  is "$(json length)" = 2
  check "$K comment list: no system note" $?
  printf 'hello\n' >"$t/c.md"
  run comment add 7 "$t/c.md"
  is "$rc" -eq 0
  check "$K comment add: exits 0" $?
  if [ "$K" = gh ]; then want="issue comment 7 --body-file $t/c.md"; else want="issue note 7 --message hello"; fi
  logged "$want"
  check "$K comment add: the call is made" $?

  # --- create and close ---
  printf 'body\n' >"$t/n.md"
  run create "New issue" "$t/n.md"
  is "$out" = 42
  check "$K create: prints the stub's number" $?
  grep -q -e --yes "$t/$K.log"
  yes=$?
  if [ "$K" = glab ]; then want=0; else want=1; fi
  is "$yes" -eq "$want"
  check "$K create: --yes is in the log only on glab" $?
  issue "$K" 7 "$OPEN" "$B0" "$T0"
  run close 7
  is "$out" = closed
  check "$K close: an open issue prints closed" $?
  logged "issue close 7"
  check "$K close: an open issue is closed" $?
  issue "$K" 7 "$CLOSED" "$B0" "$T0"
  run close 7
  is "$out" = "already closed"
  check "$K close: a closed issue prints 'already closed'" $?
  ! grep -q '^issue close ' "$t/$K.log"
  check "$K close: a closed issue is not closed again" $?

  # --- list ---
  issue "$K" 7 "$OPEN" "$B0" "$T0"
  issue "$K" 8 "$OPEN" "" "$T0"
  run list
  is "$(json 'map(.number)')" = "[7,8]"
  check "$K list: every open issue" $?
  if [ "$K" = gh ]; then
    is "$(sed -n 's/.* --limit \([0-9][0-9]*\).*/\1/p' "$t/gh.log")" -gt 30
    check "$K list: --limit is above 30" $?
  else
    has_text "$(cat "$t/glab.log")" "--paginate"
    check "$K list: pages through glab api" $?
  fi
  rm "$t/fx/$K/issue-8.json"
  mrfx 9 "$OPEN" mother ""
  run mr list
  is "$(json 'map(.number)')" = "[9]"
  check "$K mr list: the open MR/PR" $?
  if [ "$K" = gh ]; then
    is "$(sed -n 's/.* --limit \([0-9][0-9]*\).*/\1/p' "$t/gh.log")" -gt 30
    check "$K mr list: --limit is above 30" $?
  fi

  # --- mr create ---
  printf 'Body of the MR.\n' >"$t/m.md"
  run mr create 12 issue-12 mother "Title" "$t/m.md"
  is "$out" = 17
  check "$K mr create: prints the stub's number" $?
  if [ "$K" = glab ]; then
    line=$(grep '^mr create ' "$t/glab.log")
    for f in "--related-issue 12" --remove-source-branch --yes; do
      has_text "$line" "$f"
      check "$K mr create: the call has $f" $?
    done
    cmp -s "$t/m.md" "$t/glab.sent"
    check "$K mr create: the description is the file as it is" $?
  else
    line=$(grep '^pr create ' "$t/gh.log")
    for f in --related-issue --remove-source-branch --yes; do
      ! has_text "$line" "$f"
      check "$K mr create: the call has no $f" $?
    done
    is "$(head -n 1 "$t/gh.sent")" = "Closes #12"
    check "$K mr create: the body starts with 'Closes #12' though the file did not" $?
    printf 'Closes #12\n\nBody of the MR.\n' >"$t/m2.md"
    run mr create 12 issue-12 mother "Title" "$t/m2.md"
    is "$(grep -c 'Closes #12' "$t/gh.sent")" = 1
    check "$K mr create: 'Closes #12' is not added twice" $?
    is "$(head -n 1 "$t/gh.sent")" = "Closes #12"
    check "$K mr create: the body starts with 'Closes #12' as the file did" $?
  fi

  # --- mr checks ---
  if [ "$K" = gh ]; then
    run mr checks 9
    is "$rc,$out" = "0,success"
    check "$K mr checks: passing checks print success" $?
    echo "no checks reported on the 'issue-12' branch" >"$t/fx/gh/checks.fail"
    run mr checks 9
    is "$rc,$out" = "0,none"
    check "$K mr checks: 'no checks reported' prints none and exits 0" $?
    printf 'build\tfail\t1m\n' >"$t/fx/gh/checks.fail"
    run mr checks 9
    is "$rc" -eq 1
    check "$K mr checks: any other failure exits 1" $?
    rm "$t/fx/gh/checks.fail"
  else
    mrfx 9 "$OPEN" mother ""
    run mr checks 9
    is "$rc,$out" = "0,none"
    check "$K mr checks: a null head_pipeline prints none and exits 0" $?
    mrfx 9 "$OPEN" mother success
    run mr checks 9
    is "$rc,$out" = "0,success"
    check "$K mr checks: a success pipeline prints success" $?
    mrfx 9 "$OPEN" mother failed
    run mr checks 9
    is "$rc" -eq 1
    check "$K mr checks: a failed pipeline exits 1" $?
  fi

  # --- mr merge ---
  mrfx 9 "$OPEN" main ""
  run mr merge 9 "$SHA"
  is "$rc" -ne 0
  check "$K mr merge: a base equal to the default branch exits non-zero" $?
  ! grep -Eq '^(pr|mr) merge ' "$t/$K.log"
  check "$K mr merge: a base equal to the default branch merges nothing" $?
  mrfx 9 "$MERGED" mother ""
  run mr merge 9 "$SHA"
  is "$rc" -eq 0
  check "$K mr merge: a mother branch exits 0" $?
  logged "$merge_line"
  check "$K mr merge: the call is '$MR merge 9 ... $SHA ...'" $?
done

# =============================================================================================
echo "== goal-stop.sh"
hook="$src/plugins/crew/scripts/goal-stop.sh"
gd=$(g -C "$t/repo" rev-parse --path-format=absolute --git-path crew) || die "setup: git path of crew"
# issue 7 as the hook sees it, with the CRs the server keeps: Phase 2 has boxes left, or none does
BP=$(printf '# T\r\n\r\n## Plan\r\n\r\n### Phase 1 — first\r\n\r\n- [x] one\r\n\r\n### Phase 2 — second\r\n\r\n- [ ] two\r\n\r\n- [ ] three')
BD=$(printf '# T\r\n\r\n## Plan\r\n\r\n### Phase 1 — first\r\n\r\n- [x] one\r\n\r\n### Phase 2 — second\r\n\r\n- [x] two')
stop() { # [hook [dir]]: rc, out and err of one run of the hook, as Claude Code starts it: the cwd as JSON on stdin
  out=$(cd "${2:-$t}" && printf '{"cwd":"%s"}' "$t/repo" | "${1:-$hook}" 2>"$t/err")
  rc=$?
  err=$(cat "$t/err")
}
goal() { rm -rf "$gd" && mkdir -p "$gd" && echo "$1" >"$gd/goal"; } # <n>: a goal on that issue, and nothing else in the state dir
reason() { printf '%s\n' "$out" | jq -r '.reason // empty'; }
silent() { # <what>: the hook let the turn stop without a word on stdout
  is "$rc,$out" = "0,"
  check "$1: exits 0 with nothing on stdout" $?
}
blocked() { # <what> [text the reason must have]...: the hook blocked
  w=$1
  shift
  is "$(printf '%s\n' "$out" | jq -r .decision)" = block
  check "$w: blocks" $?
  for needle; do
    has_text "$(reason)" "$needle"
    check "$w: the reason says '$needle'" $?
  done
}

rm -rf "$gd"
stop
silent "no goal file"

for K in gh glab; do
  platform "$K"
  issue "$K" 7 "$OPEN" "$BP" "$T0"
  goal 7
  stop
  blocked "$K goal 7, Phase 2 unticked" "#7" "Phase 2 — second"
done

platform gh
issue gh 7 OPEN "$BD" "$T0"
goal 7
printf 'x\n3\n' >"$gd/blocks"
stop
silent "every box ticked, clean tree"
is ! -e "$gd/goal"
check "every box ticked, clean tree: goal is removed" $?
is ! -e "$gd/blocks"
check "every box ticked, clean tree: blocks is removed" $?

: >"$t/repo/dirty.txt"
goal 7
stop
blocked "every box ticked, dirty tree" "uncommitted changes"
rm "$t/repo/dirty.txt"

issue gh 7 OPEN "$BP" "$T0"
goal 7
: >"$gd/in-flight"
stop
silent "in-flight with boxes unticked"

goal 7
i=1
while [ "$i" -le 5 ]; do
  stop
  blocked "same state, run $i of 6"
  i=$((i + 1))
done
stop
silent "same state, run 6 of 6"
has_text "$err" "stalled"
check "same state, run 6 of 6: warns 'stalled'" $?
is ! -e "$gd/blocks"
check "same state, run 6 of 6: blocks is removed" $?

rm -f "$t/fx/gh/issue-8.json"
goal 8
stop
silent "goal 8, no such issue"
has_text "$err" "cannot read issue #8"
check "goal 8, no such issue: warns 'cannot read issue #8'" $?

# the same warning for every other way the tracker cannot be read
goal 7
mkdir "$t/lone"
cp "$hook" "$t/lone/"
stop "$t/lone/goal-stop.sh"
silent "tracker.sh missing"
has_text "$err" "cannot read issue #7"
check "tracker.sh missing: warns 'cannot read issue #7'" $?
cp "$src/plugins/crew/scripts/tracker.sh" "$t/lone/"
chmod -x "$t/lone/tracker.sh"
stop "$t/lone/goal-stop.sh"
silent "tracker.sh not executable"
has_text "$err" "cannot read issue #7"
check "tracker.sh not executable: warns 'cannot read issue #7'" $?
stop plugins/crew/scripts/goal-stop.sh "$src"
blocked "started by a relative path" "#7"
g -C "$t/repo" remote set-url origin https://example.com/o/r.git || die "setup: origin example.com"
stop
silent "origin is neither GitHub nor GitLab"
has_text "$err" "cannot read issue #7"
check "origin is neither GitHub nor GitLab: warns 'cannot read issue #7'" $?

# =============================================================================================
echo "plugin: $npass ok, $nfail FAIL"
[ "$nfail" -eq 0 ] || exit 1
exit 0
