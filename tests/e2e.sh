#!/bin/sh
# End-to-end test of crew, in a throwaway HOME: the curl installer on a stale managed clone,
# self-update at launch, an offline and a diverged clone, a development clone, `crew run`, the
# replacement of issue-flow@crew by crew@crew in the launcher and in the installer, and a
# profile's worktree.
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
# GIT_CEILING_DIRECTORIES: $t/proj is not a repo wherever mktemp put $t, so A-D hold whether or not crew's prompts ship a .worktree
export TERMINAL="$t/bin/term" SHELL=/bin/true GIT_TERMINAL_PROMPT=0 GIT_CONFIG_NOSYSTEM=1 XDG_CONFIG_HOME="$HOME/.config" GIT_CEILING_DIRECTORIES="$t"
unset SSH_AUTH_SOCK GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE CREW_DIR CREW_NO_UPDATE CREW_REPO
mkdir -p "$HOME" "$t/bin" "$t/bin-noclaude" || exit 1
cd "$t" || exit 1

npass=0 nfail=0
clone="$HOME/.local/share/crew"

# --- stubs ---------------------------------------------------------------------------------

# claude: one log line "<cwd> <args>"; the installed plugins are the ids in $t/plugins, one per
# line: plugin list --json prints them, install, uninstall and marketplace remove change them.
# While $t/list-fails exists, the next plugin list --json removes it and fails.
cat >"$t/bin/claude" <<EOF
#!/bin/sh
printf '%s\n' "\$PWD \$*" >>"$t/claude.log"
p="$t/plugins"
case "\$*" in
  'plugin list --json') ! rm "$t/list-fails" 2>/dev/null || exit 1; printf '[%s]\n' "\$(sed 's/.*/{"id":"&"}/' "\$p" | paste -s -d, -)" ;;
  'plugin install '*) printf '%s\n' "\$3" >>"\$p" ;;
  'plugin uninstall '*) grep -vxF -- "\$3" "\$p" >"\$p.new"; cat "\$p.new" >"\$p" ;;
  'plugin marketplace remove '*) grep -v -- "@\$4\\\$" "\$p" >"\$p.new"; cat "\$p.new" >"\$p" ;;
esac
exit 0
EOF
# term: used through TERMINAL, drops its -e and runs the rest (SHELL=/bin/true ends it at once). It and
# osascript drop CREW_DIR, as Terminal.app does: the command bin/crew hands over must carry it
cat >"$t/bin/term" <<'EOF'
#!/bin/sh
unset CREW_DIR
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
unset CREW_DIR
s=${2#*do script \"}
s=${s%\"}
sh -c "$s" </dev/null >/dev/null 2>&1 &
exit 0
EOF
cp "$t/bin/git" "$t/bin/term" "$t/bin-noclaude/"
chmod +x "$t"/bin/* "$t"/bin-noclaude/*
: >"$t/claude.log"
: >"$t/git.log"
printf '%s\n' crew@crew >"$t/plugins"

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
new_count() { tail -n +"$(($1 + 1))" "$t/claude.log" | grep -c -e "$2"; }  # <lines already in the log> <regexp>: how many new lines match
in_order() { # <lines already in the log> <regexp>...: the first new line matching each comes after the one before it
  n=$1
  shift
  prev=0
  for x in "$@"; do
    k=$(tail -n +"$((n + 1))" "$t/claude.log" | awk -v p="$x" '$0 ~ p { print NR; exit }')
    [ -n "$k" ] && [ "$k" -gt "$prev" ] || return 1
    prev=$k
  done
}
wait_sessions() { # <lines already in the log> <how many new sessions>: up to 15 s
  i=0
  while [ "$(sessions_after "$1")" -lt "$2" ] && [ "$i" -lt 15 ]; do
    sleep 1
    i=$((i + 1))
  done
}
plugin_refresh_first() { # both plugin commands are in the log, before the first session
  awk '/plugin marketplace update crew/ && !m { m = NR }
       /plugin update crew@crew/ && !u { u = NR }
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
  echo "# plugins:"
  sed 's/^/#   /' "$t/plugins"
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
g -C "$t/origin.git" merge-base --is-ancestor 64f4e37 refs/heads/main ||
  die "setup: 64f4e37 is not in main's history (a shallow checkout? use fetch-depth: 0)"
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

# the entry is current now: a second run is a no-op, it neither writes the file nor says it did
cp -p "$kb" "$t/kb.after"
( cd "$t" && PATH="$t/bin-noclaude:$HOME/.local/bin:/usr/bin:/bin" && detach sh <"$src/install.sh" ) >"$t/a2.out" 2>"$t/a2.err"
cmp -s "$kb" "$t/kb.after"
check "A: a second installer run leaves keybindings.json byte-identical" $?
if [ -n "$(find "$kb" -newer "$t/kb.after")" ]; then s=1; else s=0; fi
check "A: a second installer run does not write keybindings.json at all" "$s"
if grep -q 'now runs' "$t/a2.out"; then s=1; else s=0; fi
check "A: a second installer run does not say it rewrote the entry" "$s"

# =============================================================================================
echo "== B: self-update (origin gets ciurma on haiku and a new plugin version)"
printf 'haiku\n' >"$t/work/prompts/ciurma.model"
pj="$t/work/plugins/crew/.claude-plugin/plugin.json"
sed 's/"version": *"[^"]*"/"version": "99.0.0"/' "$pj" >"$t/pj.new" || die "setup: bump the plugin version"
cat "$t/pj.new" >"$pj"
if g -C "$t/work" diff --quiet -- plugins/crew/.claude-plugin/plugin.json; then
  die "setup: plugin.json has no version to bump"
fi
origin_commit "test: ciurma on haiku, new crew plugin version"
want=$(g -C "$t/origin.git" rev-parse refs/heads/main)

mkdir "$t/proj" || die "setup: project directory"
n0=$(loglines)
crew "$t/proj" >"$t/b1.out" 2>"$t/b1.err"
wait_sessions "$n0" 2

is "$(g -C "$clone" rev-parse HEAD)" = "$want"
check "B: the managed clone is at the new origin/main" $?
is "$(grep -cF 'plugin marketplace update crew' "$t/claude.log")" -eq 1
check "B: 'claude plugin marketplace update crew' runs once" $?
is "$(grep -cF 'plugin update crew@crew' "$t/claude.log")" -eq 1
check "B: 'claude plugin update crew@crew' runs once" $?
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
echo "== E: the rename reaches a 0.4.0 machine (clone at 64f4e37, issue-flow@crew installed)"
# 64f4e37 is the last main commit before the rename: its bin/crew is the launcher every 0.4.0
# machine runs. It pulls the rename, then execs the new launcher with CREW_NO_UPDATE=1, whose
# migrate() does the replacement. The old launcher's own 'marketplace update' and 'plugin update
# issue-flow@crew' are accepted by the stub and not counted.
g -C "$clone" reset -q --hard 64f4e37 || die "setup: reset the managed clone to 64f4e37"
g -C "$clone" config --unset crew.migrated || : # scenario B set it, and a launcher that never ran has not
printf '%s\n' issue-flow@crew >"$t/plugins"
want=$(g -C "$t/origin.git" rev-parse refs/heads/main)
n0=$(loglines)
crew "$t/proj" >"$t/e1.out" 2>"$t/e1.err"
wait_sessions "$n0" 2

is "$(g -C "$clone" rev-parse HEAD)" = "$want"
check "E: the managed clone is at origin/main" $?
is "$(new_count "$n0" ' plugin install crew@crew$')" -eq 1
check "E: 'claude plugin install crew@crew' runs once" $?
is "$(new_count "$n0" ' plugin uninstall issue-flow@crew$')" -eq 1
check "E: 'claude plugin uninstall issue-flow@crew' runs once" $?
in_order "$n0" ' plugin install crew@crew$' ' plugin uninstall issue-flow@crew$' ' -n '
check "E: the install comes before the uninstall, both before the first session" $?
is "$(cat "$t/plugins")" = crew@crew
check "E: crew@crew is the only plugin left" $?
grep -qF 'issue-flow@crew replaced by crew@crew' "$t/e1.out"
check "E: the launcher says issue-flow@crew was replaced by crew@crew" $?
is "$(sessions_after "$n0")" -eq 2
check "E: both sessions start" $?

n1=$(loglines)
p1=$(grep -c ' plugin ' "$t/claude.log")
crew "$t/proj" >"$t/e2.out" 2>"$t/e2.err"
wait_sessions "$n1" 2
is "$(grep -c ' plugin ' "$t/claude.log")" -eq "$p1"
check "E: the second launch adds no plugin command" $?
is ! -s "$t/e2.err"
check "E: the second launch prints nothing on stderr" $?

# a plugin list that fails once leaves nothing done and nothing remembered: the next launch migrates.
# 'crew run' alone, since every session a plain 'crew' opens runs migrate() again.
g -C "$clone" config --unset crew.migrated || die "setup: unset crew.migrated"
printf '%s\n' issue-flow@crew >"$t/plugins"
: >"$t/list-fails"
n0=$(loglines)
( cd "$t/proj" && CREW_NO_UPDATE=1 crew run ciurma ) >"$t/e3.out" 2>"$t/e3.err"
is ! -e "$t/list-fails" && is "$(new_count "$n0" ' plugin install ')" -eq 0 && is "$(sessions_after "$n0")" -eq 1
check "E: a failed plugin list installs nothing and the session starts" $?
is -z "$(g -C "$clone" config --get crew.migrated)"
check "E: a failed plugin list leaves crew.migrated unset" $?
( cd "$t/proj" && CREW_NO_UPDATE=1 crew run ciurma ) >"$t/e4.out" 2>"$t/e4.err"
is "$(cat "$t/plugins")" = crew@crew && is "$(g -C "$clone" config --get crew.migrated)" = 3.0.0
check "E: the next launch replaces issue-flow@crew and sets crew.migrated" $?

# =============================================================================================
echo "== F: the curl installer on issue-flow@crew and upstream's issue-flow@issue-flow"
# claude is on the PATH here. ponytail and caveman are installed, so on macOS (where detach does
# nothing and /dev/tty opens) the menu takes its 'already installed' path and reads nothing.
printf '%s\n' issue-flow@crew issue-flow@issue-flow ponytail@ponytail caveman@caveman >"$t/plugins"
n0=$(loglines)
( cd "$t" && detach sh <"$src/install.sh" ) >"$t/f1.out" 2>"$t/f1.err"
check "F: the installer exits 0" $?
is "$(new_count "$n0" ' plugin marketplace update crew$') $(new_count "$n0" ' plugin install crew@crew$') $(new_count "$n0" ' plugin uninstall issue-flow@crew$')" = '1 1 1' &&
  in_order "$n0" ' plugin marketplace update crew$' ' plugin install crew@crew$' ' plugin uninstall issue-flow@crew$'
check "F: marketplace update, install and uninstall issue-flow@crew each run once, in this order" $?
is "$(new_count "$n0" ' plugin marketplace remove issue-flow$')" -eq 1
check "F: 'claude plugin marketplace remove issue-flow' runs once" $?
is "$(new_count "$n0" ' plugin marketplace add ')" -eq 0
check "F: no 'claude plugin marketplace add' runs" $?
is "$(sort "$t/plugins" | tr '\n' ' ')" = 'caveman@caveman crew@crew ponytail@ponytail '
check "F: crew, ponytail and caveman are the plugins left" $?
grep -qF 'issue-flow@crew replaced by crew@crew' "$t/f1.out" && grep -qF 'issue-flow@issue-flow replaced by crew@crew' "$t/f1.out"
check "F: the installer says both plugins were replaced by crew@crew" $?

printf '%s\n' crew@crew ponytail@ponytail caveman@caveman >"$t/plugins"
n1=$(loglines)
( cd "$t" && detach sh <"$src/install.sh" ) >"$t/f2.out" 2>"$t/f2.err"
is "$(new_count "$n1" ' plugin ')" -eq "$(new_count "$n1" ' plugin list --json$')"
check "F: a second installer run only lists the plugins" $?

# =============================================================================================
echo "== G: a profile with a .worktree works in its own git worktree"
# Throwaway profiles, never crew's own prompts/, so this holds whether or not those ship a .worktree.
# The project clones $t/origin.git, so its origin/HEAD is origin/main. Every launch goes through the
# managed clone's crew with CREW_NO_UPDATE=1: whatever state E and F left it in, it is not updated.
mkdir -p "$t/profiles" || die "setup: profiles directory"
echo 'a profile that works in its own worktree' >"$t/profiles/worker.md"
: >"$t/profiles/worker.worktree"
echo 'a profile without one' >"$t/profiles/lead.md"
g clone -q "$t/origin.git" "$t/wproj" || die "setup: project clone"
wt="$t/wproj/.claude/worktrees/worker"
wrun() { ( cd "$1" && CREW_DIR="$t/profiles" CREW_NO_UPDATE=1 crew run "$2" ); } # <dir> <profile>
line_of() { printf '%s -n %s --append-system-prompt-file %s' "$1" "$2" "$t/profiles/$2.md"; } # <dir> <profile>

n0=$(loglines)
wrun "$t/wproj" worker >"$t/g1.out" 2>"$t/g1.err"
new_has "$n0" "$(line_of "$wt" worker)"
check "G: the first launch starts worker in its worktree" $?
is "$(g -C "$wt" rev-parse HEAD)" = "$(g -C "$t/wproj" rev-parse origin/main)" && ! g -C "$wt" symbolic-ref -q HEAD >/dev/null 2>&1
check "G: the worktree is detached at origin/main" $?
is -z "$(g -C "$t/wproj" status --porcelain)"
check "G: the main checkout's git status stays clean" $?
is ! -s "$t/g1.err"
check "G: the first launch prints nothing on stderr" $?

# reuse: the branch and the untracked file the session made are still there
# (no die here: with no worktree, the check below fails and the rest of G still runs)
g -C "$wt" switch -q -c issue-7 >/dev/null 2>&1
{ echo 'work in progress' >"$wt/wip"; } 2>/dev/null
n0=$(loglines)
wrun "$t/wproj" worker >"$t/g2.out" 2>"$t/g2.err"
new_has "$n0" "$(line_of "$wt" worker)"
check "G: a second launch starts worker in the same worktree" $?
is "$(g -C "$wt" branch --show-current)" = issue-7 && is -e "$wt/wip"
check "G: the second launch leaves the worktree's branch and files alone" $?

# from a subdirectory, the same subdirectory of the worktree when it has one
n0=$(loglines)
wrun "$t/wproj/prompts" worker >"$t/g3.out" 2>"$t/g3.err"
new_has "$n0" "$(line_of "$wt/prompts" worker)"
check "G: from a tracked subdirectory, worker starts in the same one of its worktree" $?
# an exported CDPATH with the same subdirectory must not take the session out of its worktree
mkdir -p "$t/decoy/prompts" || die "setup: CDPATH decoy"
n0=$(loglines)
( export CDPATH="$t/decoy"; wrun "$t/wproj/prompts" worker ) >"$t/g3b.out" 2>"$t/g3b.err"
new_has "$n0" "$(line_of "$wt/prompts" worker)" && is ! -s "$t/g3b.out"
check "G: under an exported CDPATH, worker still starts in the subdirectory of its worktree" $?
mkdir "$t/wproj/local-only" || die "setup: untracked subdirectory"
n0=$(loglines)
wrun "$t/wproj/local-only" worker >"$t/g4.out" 2>"$t/g4.err"
new_has "$n0" "$(line_of "$wt" worker)"
check "G: from an untracked subdirectory, worker starts at the worktree's root" $?

# a relative CREW_DIR still names the profile once crew run has moved into the worktree
n0=$(loglines)
( cd "$t/wproj" && CREW_DIR=../profiles CREW_NO_UPDATE=1 crew run worker ) >"$t/g4b.out" 2>"$t/g4b.err"
new_has "$n0" "$wt -n worker --append-system-prompt-file $t/wproj/../profiles/worker.md"
check "G: a relative CREW_DIR becomes an absolute profile path" $?

n0=$(loglines)
wrun "$t/wproj" lead >"$t/g5.out" 2>"$t/g5.err"
new_has "$n0" "$(line_of "$t/wproj" lead)"
check "G: a profile without a .worktree starts where it was launched" $?

# the launcher loop reaches the same code through 'crew run' in each terminal
n0=$(loglines)
CREW_DIR="$t/profiles" CREW_NO_UPDATE=1 crew "$t/wproj" >"$t/g6.out" 2>"$t/g6.err"
wait_sessions "$n0" 2
new_has "$n0" "$(line_of "$t/wproj" lead)"
check "G: the launcher starts lead in the project" $?
new_has "$n0" "$(line_of "$wt" worker)"
check "G: the launcher starts worker in its worktree" $?
# the same with a CREW_DIR relative to where crew was typed, not to the project the terminals cd into
n0=$(loglines)
( cd "$t" && CREW_DIR=profiles CREW_NO_UPDATE=1 crew "$t/wproj" ) >"$t/g6b.out" 2>"$t/g6b.err"
wait_sessions "$n0" 2
new_has "$n0" "$(line_of "$t/wproj" lead)" && new_has "$n0" "$(line_of "$wt" worker)"
check "G: the launcher resolves a relative CREW_DIR where crew was typed" $?

# not a git repo: as before (GIT_CEILING_DIRECTORIES keeps $t/proj out of any repo)
n0=$(loglines)
wrun "$t/proj" worker >"$t/g7.out" 2>"$t/g7.err"
new_has "$n0" "$(line_of "$t/proj" worker)"
check "G: outside a git repo, worker starts where it was launched" $?
is ! -s "$t/g7.err"
check "G: outside a git repo, nothing on stderr" $?

# failure path: an empty repo has no commit to start the worktree from, and crew run starts
# nothing rather than the session in the main checkout
g init -q "$t/wempty" || die "setup: empty repo"
n0=$(loglines)
wrun "$t/wempty" worker >"$t/g8.out" 2>"$t/g8.err"
rc=$?
is "$rc" -eq 1 && is "$(sessions_after "$n0")" -eq 0
check "G: in an empty repo, worker does not start and crew run exits 1" $?
is "$(grep -c '' "$t/g8.err")" -eq 1
check "G: in an empty repo, exactly one line on stderr" $?
grep -q '^crew: .*commit' "$t/g8.err"
check "G: that line is a crew: line that asks for a first commit" $?
# a plain directory where the worktree goes: the same refusal, naming the path
g clone -q "$t/origin.git" "$t/wblock" || die "setup: project clone for the blocked worktree"
mkdir -p "$t/wblock/.claude/worktrees/worker" || die "setup: directory in the way"
n0=$(loglines)
wrun "$t/wblock" worker >"$t/g8b.out" 2>"$t/g8b.err"
rc=$?
is "$rc" -eq 1 && is "$(sessions_after "$n0")" -eq 0 && is "$(grep -c '' "$t/g8b.err")" -eq 1 &&
  grep -qF "crew: could not set up the worktree of worker at $t/wblock/.claude/worktrees/worker" "$t/g8b.err"
check "G: with a directory in the way, worker does not start and crew run names the path" $?

# a project moved after the first launch: its nested worktree still points at the old path
g clone -q "$t/origin.git" "$t/wmove" || die "setup: project clone to move"
wrun "$t/wmove" worker >/dev/null 2>&1
mv "$t/wmove" "$t/wmoved" || die "setup: move the project"
n0=$(loglines)
wrun "$t/wmoved" worker >"$t/g8c.out" 2>"$t/g8c.err"
new_has "$n0" "$(line_of "$t/wmoved/.claude/worktrees/worker" worker)" && is ! -s "$t/g8c.err"
check "G: after the project moved, worker starts in its worktree at the new path" $?

# an exclude file whose last line has no newline: the worktree's line goes on a line of its own
g clone -q "$t/origin.git" "$t/wnl" || die "setup: project clone for the exclude file"
printf '*.log' >"$t/wnl/.git/info/exclude"
wrun "$t/wnl" worker >"$t/g10.out" 2>"$t/g10.err"
is "$(cat "$t/wnl/.git/info/exclude")" = "$(printf '%s\n' '*.log' /.claude/worktrees/)" && : >"$t/wnl/a.log" &&
  is -z "$(g -C "$t/wnl" status --porcelain)"
check "G: an exclude file without a final newline keeps its last pattern and gets the worktree's" $?

# offline first launch: the same hanging fetch as in C, bounded by crew's watchdog
g clone -q "$t/origin.git" "$t/woff" || die "setup: offline project clone"
g -C "$t/woff" remote set-url origin ssh://crew.invalid/crew.git || die "setup: point the remote at a dead host"
n0=$(loglines)
s0=$(date +%s)
# 'sleep 60 #': git appends the host and the command to GIT_SSH_COMMAND, and sleep rejects them;
# the comment swallows them, so the fetch really hangs until crew's own watchdog stops it.
# git's ssh probe and its sleep are orphaned by that kill and end by themselves within 60 s;
# they hold no pipe of this script (its outputs go to files), and nothing here kills by name.
( cd "$t/woff" && GIT_SSH_COMMAND='sleep 60 #' CREW_DIR="$t/profiles" CREW_NO_UPDATE=1 crew run worker ) >"$t/g9.out" 2>"$t/g9.err"
s1=$(date +%s)
is "$((s1 - s0))" -lt 10
check "G: the offline first launch returns within 10 s" $?
new_has "$n0" "$(line_of "$t/woff/.claude/worktrees/worker" worker)"
check "G: the offline first launch starts worker in its worktree" $?
is ! -s "$t/g9.err"
check "G: the offline first launch prints nothing on stderr" $?

# =============================================================================================
if [ "$nfail" -ne 0 ]; then dump; fi
echo "e2e: $npass ok, $nfail FAIL"
[ "$nfail" -eq 0 ] || exit 1
exit 0
