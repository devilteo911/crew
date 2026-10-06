#!/bin/sh
# End-to-end test of crew, in a throwaway HOME: the curl installer on a stale managed clone,
# self-update at launch, an offline and a diverged clone, a development clone, `crew run`.
# Run it from anywhere: sh tests/e2e.sh
# Every assertion prints "ok <what>" or "FAIL <what>" and the run goes on; the exit status is
# 1 when any FAIL was printed. Nothing outside the temp dir changes: HOME and PATH are
# replaced, and stubs stand in for claude, the terminal and (on macOS) osascript.
src=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd) || exit 1
realgit=$(command -v git) || { echo "FAIL setup: git not found"; exit 1; }
t=$(mktemp -d) || exit 1
trap 'rm -rf "$t"' EXIT
trap 'exit 1' HUP INT TERM
t=$(CDPATH='' cd -- "$t" && pwd -P) || exit 1

export HOME="$t/home"
export PATH="$t/bin:$HOME/.local/bin:/usr/bin:/bin"
export TERMINAL="$t/bin/term" SHELL=/bin/true GIT_TERMINAL_PROMPT=0 GIT_CONFIG_NOSYSTEM=1 XDG_CONFIG_HOME="$HOME/.config"
unset SSH_AUTH_SOCK GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE CREW_DIR CREW_NO_UPDATE CREW_REPO
mkdir -p "$HOME" "$t/bin" "$t/bin-noclaude" || exit 1
cd "$t" || exit 1

npass=0 nfail=0
clone="$HOME/.local/share/crew"

# --- stubs ---------------------------------------------------------------------------------

# claude: one log line "<cwd> <args>"; the plugin list says issue-flow@crew is installed
cat >"$t/bin/claude" <<EOF
#!/bin/sh
printf '%s\n' "\$PWD \$*" >>"$t/claude.log"
if [ "\$*" = "plugin list --json" ]; then echo '[{"id":"issue-flow@crew"}]'; fi
exit 0
EOF
# term: used through TERMINAL, drops its -e and runs the rest (SHELL=/bin/true ends it at once)
cat >"$t/bin/term" <<'EOF'
#!/bin/sh
shift
exec "$@"
EOF
# git: logs its arguments, then runs the real git
cat >"$t/bin/git" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$t/git.log"
exec "$realgit" "\$@"
EOF
# osascript: only macOS reaches it; runs the command bin/crew hands to Terminal.app, here
cat >"$t/bin/osascript" <<'EOF'
#!/bin/sh
s=${2#*do script \"}
s=${s%\"}
sh -c "$s" </dev/null >/dev/null 2>&1 &
exit 0
EOF
cp "$t/bin/git" "$t/bin/term" "$t/bin-noclaude/"
chmod +x "$t"/bin/* "$t"/bin-noclaude/*
: >"$t/claude.log"
: >"$t/git.log"

# --- helpers -------------------------------------------------------------------------------

check() { # <what> <exit status of the test>
  if [ "$2" -eq 0 ]; then
    npass=$((npass + 1))
    echo "ok $1"
  else
    nfail=$((nfail + 1))
    echo "FAIL $1"
  fi
}
die() {
  echo "FAIL $*"
  echo "e2e: aborted"
  exit 1
}
g() { "$realgit" -c user.name=crew-test -c user.email=crew-test@example.invalid -c commit.gpgsign=false "$@"; }
is() { [ "$@" ]; } # a test whose status check() reads (shellcheck reads $? after a bare [ ] as a condition)
has_text() { case $1 in *"$2"*) return 0 ;; esac; return 1; } # <haystack> <needle>
model_of() { tr -d '[:space:]' <"$HOME/.claude/crew/$1.model"; }
loglines() { grep -c '' "$t/claude.log"; }
sessions_after() { tail -n +"$(($1 + 1))" "$t/claude.log" | grep -c ' -n '; } # <lines already in the log>
new_has() { tail -n +"$(($1 + 1))" "$t/claude.log" | grep -Fxq -- "$2"; }    # <lines already in the log> <exact line>
wait_sessions() { # <lines already in the log> <how many new sessions>: up to 15 s
  i=0
  while [ "$(sessions_after "$1")" -lt "$2" ] && [ "$i" -lt 15 ]; do
    sleep 1
    i=$((i + 1))
  done
}
plugin_refresh_first() { # both plugin commands are in the log, before the first session
  awk '/plugin marketplace update crew/ && !m { m = NR }
       /plugin update issue-flow@crew/ && !u { u = NR }
       / -n / && !s { s = NR }
       END { exit !(m && u && s && m < s && u < s) }' "$t/claude.log"
}
origin_commit() { # <message>: commit the work clone's tree on top of origin's main and push it
  g -C "$t/work" add -A || die "setup: git add in the work clone"
  g -C "$t/work" commit -q --allow-empty -m "$1" || die "setup: commit '$1'"
  g -C "$t/work" push -q origin main || die "setup: push '$1' to origin"
}
dump() { # the logs and outputs, for whoever reads a FAIL (lines start with #, never with ok/FAIL)
  echo "# claude.log:"
  sed 's/^/#   /' "$t/claude.log"
  for f in "$t"/*.out "$t"/*.err; do
    [ -s "$f" ] || continue
    echo "# ${f#"$t"/}:"
    sed 's/^/#   /' "$f"
  done
}
# The installer prompts on /dev/tty, which opens even for a stdin that is not a tty whenever the
# caller has a controlling terminal. Detach from it when setsid can (not on macOS).
if command -v setsid >/dev/null 2>&1 && setsid -w true >/dev/null 2>&1; then
  detach() { setsid -w "$@"; }
else
  detach() { "$@"; }
fi

# --- origin: a bare clone of the code under test, main = its working tree on top ---------------

g clone -q --bare "$src" "$t/origin.git" || die "setup: bare clone of $src"
g -C "$t/origin.git" rev-parse -q --verify refs/heads/main >/dev/null ||
  g -C "$t/origin.git" update-ref refs/heads/main "$(g -C "$src" rev-parse HEAD)" ||
  die "setup: origin has no main"
g -C "$t/origin.git" symbolic-ref HEAD refs/heads/main || die "setup: origin HEAD"
g -C "$t/origin.git" merge-base --is-ancestor 4341dd2 refs/heads/main ||
  die "setup: 4341dd2 is not in main's history (a shallow checkout? use fetch-depth: 0)"
g clone -q "$t/origin.git" "$t/work" || die "setup: work clone"
# the tree of the commit is the tracked files of the working tree, committed or not
g -C "$t/work" rm -rq . || die "setup: empty the work clone"
g -C "$src" -c core.quotePath=false ls-files | while IFS= read -r f; do
  [ -e "$src/$f" ] || [ -L "$src/$f" ] || continue
  mkdir -p "$t/work/$(dirname -- "$f")"
  cp -pP "$src/$f" "$t/work/$f"
done
origin_commit "test: the working tree of the code under test"

# =============================================================================================
echo "== A: reported machine (clone at 4341dd2, stale keybinding, curl installer)"
mkdir -p "$HOME/.local/share" "$HOME/.local/bin" "$HOME/.claude" || die "setup: HOME"
g clone -q "$t/origin.git" "$clone" || die "setup: managed clone"
g -C "$clone" reset -q --hard 4341dd2 || die "setup: reset the managed clone to 4341dd2"
ln -s "$clone/bin/crew" "$HOME/.local/bin/crew"
ln -s "$clone/prompts" "$HOME/.claude/crew"

case "$(uname -s)" in
  Darwin) kb="$HOME/Library/Application Support/Code/User/keybindings.json"; key="cmd+shift+c" ;;
  *)      kb="$HOME/.config/Code/User/keybindings.json"; key="meta+shift+c" ;;
esac
mkdir -p "$(dirname "$kb")" || die "setup: VS Code User directory"
# the entry the installer of 4341dd2 wrote: no --model, no stagger
line1='  { "key": "'"$key"'", "command": "runCommands", "args": { "commands": [{"command":"workbench.action.terminal.new"},{"command":"workbench.action.terminal.sendSequence","args":{"text":"claude -n ciurma --append-system-prompt-file ~/.claude/crew/ciurma.md\u000D"}},{"command":"workbench.action.terminal.split"},{"command":"workbench.action.terminal.sendSequence","args":{"text":"claude -n sottoposto --append-system-prompt-file ~/.claude/crew/sottoposto.md\u000D"}}] } },'
line2='  { "key": "ctrl+alt+t", "command": "workbench.action.terminal.new" }'
printf '%s\n' '[' "$line1" "$line2" ']' >"$kb"
cp "$kb" "$t/kb.before"

# the way curl runs it: from a directory that is not a clone, stdin not a tty, no claude on PATH
( cd "$t" && PATH="$t/bin-noclaude:$HOME/.local/bin:/usr/bin:/bin" && detach sh <"$src/install.sh" ) >"$t/a.out" 2>"$t/a.err"
check "A: the installer exits 0" $?

want=$(g -C "$t/origin.git" rev-parse refs/heads/main)
is "$(g -C "$clone" rev-parse HEAD)" = "$want"
check "A: the managed clone is at origin/main" $?
is "$(cat "$clone/VERSION" 2>/dev/null)" = "$(cat "$src/VERSION")"
check "A: the clone's VERSION is the working tree's" $?

l1=$(sed -n 2p "$kb")
has_text "$l1" '"text":"crew run ciurma\u000D"'
check "A: ciurma runs 'crew run ciurma', no sleep before it" $?
has_text "$l1" '"text":"sleep 5; crew run sottoposto\u000D"'
check "A: sottoposto runs 'sleep 5; crew run sottoposto'" $?
has_text "$l1" '"key": "'"$key"'"'
check "A: the crew entry keeps its key $key" $?
case $l1 in '  {'*'},') s=0 ;; *) s=1 ;; esac
check "A: the crew entry keeps its indentation and trailing comma" "$s"
is "$(sed -n 3p "$kb")" = "$line2"
check "A: the unrelated binding is byte-identical" $?
del=$(diff "$t/kb.before" "$kb" | grep -c '^<')
add=$(diff "$t/kb.before" "$kb" | grep -c '^>')
is "$del,$add" = 1,1
check "A: exactly one line of keybindings.json changed" $?
if command -v python3 >/dev/null 2>&1; then
  python3 -m json.tool "$kb" >/dev/null 2>&1
  check "A: keybindings.json still parses" $?
else
  echo "ok A: keybindings.json still parses (skipped: python3 is not installed)"
fi

# =============================================================================================
echo "== B: self-update (origin gets ciurma on haiku and a new plugin version)"
printf 'haiku\n' >"$t/work/prompts/ciurma.model"
pj="$t/work/plugins/issue-flow/.claude-plugin/plugin.json"
sed 's/"version": *"[^"]*"/"version": "99.0.0"/' "$pj" >"$t/pj.new" || die "setup: bump the plugin version"
cat "$t/pj.new" >"$pj"
if g -C "$t/work" diff --quiet -- plugins/issue-flow/.claude-plugin/plugin.json; then
  die "setup: plugin.json has no version to bump"
fi
origin_commit "test: ciurma on haiku, new issue-flow version"
want=$(g -C "$t/origin.git" rev-parse refs/heads/main)

mkdir "$t/proj" || die "setup: project directory"
n0=$(loglines)
crew "$t/proj" >"$t/b1.out" 2>"$t/b1.err"
wait_sessions "$n0" 2

is "$(g -C "$clone" rev-parse HEAD)" = "$want"
check "B: the managed clone is at the new origin/main" $?
is "$(grep -cF 'plugin marketplace update crew' "$t/claude.log")" -eq 1
check "B: 'claude plugin marketplace update crew' runs once" $?
is "$(grep -cF 'plugin update issue-flow@crew' "$t/claude.log")" -eq 1
check "B: 'claude plugin update issue-flow@crew' runs once" $?
plugin_refresh_first
check "B: both plugin commands run before the first session" $?
new_has "$n0" "$t/proj -n sottoposto --model opus --append-system-prompt-file $HOME/.claude/crew/sottoposto.md"
check "B: sottoposto starts on opus in the project directory" $?
new_has "$n0" "$t/proj -n ciurma --model haiku --append-system-prompt-file $HOME/.claude/crew/ciurma.md"
check "B: ciurma starts on haiku in the project directory" $?

n1=$(loglines)
p1=$(grep -c ' plugin ' "$t/claude.log")
crew "$t/proj" >"$t/b2.out" 2>"$t/b2.err"
wait_sessions "$n1" 2
is "$(sessions_after "$n1")" -eq 2
check "B: the second launch starts both sessions" $?
is "$(grep -c ' plugin ' "$t/claude.log")" -eq "$p1"
check "B: the second launch adds no plugin command" $?
is ! -s "$t/b2.err"
check "B: the second launch prints nothing on stderr" $?

# =============================================================================================
echo "== C: offline (the fetch hangs) and diverged"
printf 'upstream moved on\n' >"$t/work/upstream-note"
origin_commit "test: origin moves on"
g -C "$clone" remote set-url origin ssh://crew.invalid/crew.git || die "setup: point the remote at a dead host"
cm=$(model_of ciurma)
sm=$(model_of sottoposto)
n0=$(loglines)
s0=$(date +%s)
# 'sleep 60 #': git appends the host and the command to GIT_SSH_COMMAND, and sleep rejects them;
# the comment swallows them, so the fetch really hangs until crew's own watchdog stops it.
# git's ssh probe and its sleep are orphaned by that kill and end by themselves within 60 s;
# they hold no pipe of this script (its outputs go to files), and nothing here kills by name.
GIT_SSH_COMMAND='sleep 60 #' crew "$t/proj" >"$t/c1.out" 2>"$t/c1.err"
rc=$?
s1=$(date +%s)
wait_sessions "$n0" 2

is "$((s1 - s0))" -lt 10
check "C: the offline launch returns within 10 s" $?
is "$rc" -eq 0
check "C: the offline launch exits 0" $?
is "$(grep -c '' "$t/c1.err")" -eq 1
check "C: the offline launch prints exactly one line on stderr" $?
head -n 1 "$t/c1.err" | grep -q '^crew:'
check "C: that line is a crew: warning" $?
new_has "$n0" "$t/proj -n ciurma --model $cm --append-system-prompt-file $HOME/.claude/crew/ciurma.md"
check "C: ciurma still starts, on $cm" $?
new_has "$n0" "$t/proj -n sottoposto --model $sm --append-system-prompt-file $HOME/.claude/crew/sottoposto.md"
check "C: sottoposto still starts, on $sm" $?

# origin already has a commit the clone lacks; a local commit makes the two diverge
g -C "$clone" remote set-url origin "$t/origin.git" || die "setup: restore the remote"
g -C "$clone" commit -q --allow-empty -m "local change in the managed clone" || die "setup: local commit in the managed clone"
n0=$(loglines)
crew "$t/proj" >"$t/c2.out" 2>"$t/c2.err"
rc=$?
wait_sessions "$n0" 2

is "$rc" -eq 0
check "C: the diverged launch exits 0" $?
is "$(grep -c '' "$t/c2.err")" -eq 1
check "C: the diverged launch prints exactly one line on stderr" $?
head -n 1 "$t/c2.err" | grep -q '^crew:'
check "C: that line is a crew: warning" $?
new_has "$n0" "$t/proj -n ciurma --model $cm --append-system-prompt-file $HOME/.claude/crew/ciurma.md"
check "C: ciurma still starts, on $cm" $?
new_has "$n0" "$t/proj -n sottoposto --model $sm --append-system-prompt-file $HOME/.claude/crew/sottoposto.md"
check "C: sottoposto still starts, on $sm" $?

# =============================================================================================
echo "== D: the development clone and 'crew run'"
n0=$(loglines)
g0=$(grep -c '' "$t/git.log")
# CREW_NO_UPDATE stays unset: this run must not fetch because it is not the managed clone
( cd "$t" && sh "$src/bin/crew" "$t/proj" ) >"$t/d1.out" 2>"$t/d1.err"
wait_sessions "$n0" 2
is "$(tail -n +"$((g0 + 1))" "$t/git.log" | grep -c fetch)" -eq 0
check "D: the development clone runs no git fetch" $?
is "$(sessions_after "$n0")" -eq 2
check "D: the development clone still starts both sessions" $?

cm=$(model_of ciurma)
n0=$(loglines)
( cd "$t/proj" && CREW_NO_UPDATE=1 crew run ciurma ) >"$t/d2.out" 2>"$t/d2.err"
new_has "$n0" "$t/proj -n ciurma --model $cm --append-system-prompt-file $HOME/.claude/crew/ciurma.md"
check "D: 'crew run ciurma' starts ciurma on $cm in the current directory" $?

( cd "$t/proj" && CREW_NO_UPDATE=1 crew run nope ) >"$t/d3.out" 2>"$t/d3.err"
rc=$?
is "$rc" -ne 0
check "D: 'crew run nope' exits non-zero" $?
grep -qF "crew: no profile 'nope'" "$t/d3.err"
check "D: 'crew run nope' says crew: no profile 'nope' on stderr" $?

# =============================================================================================
if [ "$nfail" -ne 0 ]; then dump; fi
echo "e2e: $npass ok, $nfail FAIL"
[ "$nfail" -eq 0 ] || exit 1
exit 0
