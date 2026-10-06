#!/bin/sh
# Links crew into the places Claude Code and the shell expect it.
# From a clone: ./install.sh. From curl: clones into ~/.local/share/crew and updates.
# It also offers the plugins the crew uses: issue-flow, ponytail and caveman.
set -e
repo=$(CDPATH='' cd -- "$(dirname -- "$0")" 2>/dev/null && pwd) || repo=
url="${CREW_REPO:-https://github.com/devilteo911/crew.git}"

if [ ! -f "$repo/bin/crew" ]; then
  repo="$HOME/.local/share/crew"
  if [ -d "$repo/.git" ]; then
    git -C "$repo" pull --ff-only
  else
    git clone "$url" "$repo"
  fi
fi

mkdir -p "$HOME/.local/bin" "$HOME/.claude"
for l in "$HOME/.local/bin/crew:$repo/bin/crew" "$HOME/.claude/crew:$repo/prompts"; do
  link=${l%%:*}; target=${l#*:}
  old=$(readlink "$link" 2>/dev/null) || old=
  if [ -z "$old" ] && [ -e "$link" ]; then
    echo "crew: $link exists and is not a symlink, move it and rerun" >&2
    exit 1
  fi
  if [ -n "$old" ] && [ "$old" != "$target" ]; then
    echo "crew: $link now points to $target (was: $old)"
  fi
  ln -sfn "$target" "$link"
done
echo "crew $(cat "$repo/VERSION" 2>/dev/null || echo unknown) installed in $repo. Make sure ~/.local/bin is on your PATH."

# Plugins the crew sessions rely on, one menu. Needs claude and a terminal.
installed=
if ! command -v claude >/dev/null 2>&1; then
  echo "crew: claude is not on the PATH, plugins skipped (rerun install.sh once it is)"
elif ! ( : </dev/tty ) 2>/dev/null; then
  echo "crew: no terminal, plugins skipped (rerun install.sh from one)"
else
  have=$(claude plugin list --json 2>/dev/null) || have=
  has() { case $have in *"\"$1\""*) return 0 ;; esac; return 1; }
  plugin() { # <digit> <id> <marketplace source>
    has "$2" && return 0
    case $skip in *"$1"*) return 0 ;; esac
    claude plugin marketplace add "$3" >/dev/null &&
      claude plugin install "$2" >/dev/null &&
      echo "crew: $2 installed" && installed=1 ||
      echo "crew: $2 not installed, retry with: claude plugin marketplace add $3 && claude plugin install $2" >&2
  }
  row() { # <digit> <id> <text> [suffix]: the mark stays 3 chars wide so the columns line up
    if has "$2"; then mark='[=]' sfx=' — installed'; else mark='[x]' sfx=$4; fi
    printf '  %s) %s %s%s\n' "$1" "$mark" "$3" "$sfx"
  }
  if has issue-flow@crew && has ponytail@ponytail && has caveman@caveman; then
    echo "crew: issue-flow, ponytail and caveman already installed"
  else
    repl=
    if has issue-flow@issue-flow && ! has issue-flow@crew; then repl=' — replaces issue-flow@issue-flow'; fi
    echo "crew: plugins for the crew sessions, all selected:"
    row 1 issue-flow@crew "issue-flow   plan and implement through issues    (marketplace crew, this clone)" "$repl"
    row 2 ponytail@ponytail 'ponytail     the laziest code that works          (DietrichGebert/ponytail)'
    row 3 caveman@caveman 'caveman      terse prose, fewer tokens            (JuliusBrussee/caveman)'
    printf 'crew: Enter installs the selected; type the numbers to leave out (e.g. "3"): '
    read -r skip </dev/tty || { skip=123; echo; }
    plugin 1 issue-flow@crew "$repo"
    # https sources: the owner/repo shorthand tries ssh first, which can stall or fail without a GitHub key
    plugin 2 ponytail@ponytail https://github.com/DietrichGebert/ponytail.git
    plugin 3 caveman@caveman https://github.com/JuliusBrussee/caveman.git
  fi
  have=$(claude plugin list --json 2>/dev/null) || have=
  if has issue-flow@crew && has issue-flow@issue-flow; then
    # ponytail: removing the marketplace also uninstalls its plugin, in every scope
    # (Claude Code 2.1.286), so no separate uninstall call is needed.
    claude plugin marketplace remove issue-flow >/dev/null &&
      echo "crew: issue-flow@issue-flow replaced by issue-flow@crew" ||
      echo "crew: remove the old plugin with: claude plugin marketplace remove issue-flow" >&2
  fi
  if [ -n "$installed" ]; then echo "crew: restart open Claude Code sessions to load the plugins"; fi
fi

# Optional: a VS Code keybinding that opens the crew in split integrated
# terminals, instead of the external ones bin/crew spawns. Each terminal runs
# `crew run <name>`, which reads the profile and its model when the session starts.
# A crew entry already in the file is rewritten in place, without asking: the user
# said yes once, and a stale entry is the bug. keybindings.json is JSONC and there is
# no jq, so that happens only on one whole-object line; anything else is printed for
# the user to paste. The y/N prompt is for a file with no crew entry.
case "$(uname -s)" in
  Darwin) kb="$HOME/Library/Application Support/Code/User/keybindings.json"; key="cmd+shift+c" ;;
  *)      kb="$HOME/.config/Code/User/keybindings.json"; key="meta+shift+c" ;;
esac

cmds='' act=new wait=''
for f in "$repo"/prompts/*.md; do
  n=$(basename "$f" .md)
  cmds="$cmds{\"command\":\"workbench.action.terminal.$act\"},{\"command\":\"workbench.action.terminal.sendSequence\",\"args\":{\"text\":\"${wait}crew run $n\\u000D\"}},"
  act=split wait='sleep 5; '
done
entry_for() { printf '  { "key": "%s", "command": "runCommands", "args": { "commands": [%s] } }' "$1" "${cmds%,}"; }
entry=$(entry_for "$key")

# Lines of the file that run the crew: the older entries that call claude with its flags, and the current one.
crew_n=0 hit=
if [ -f "$kb" ] && [ -r "$kb" ]; then
  crew_n=$(grep -c -e '--append-system-prompt-file ~/.claude/crew/' -e 'crew run ' "$kb") || :
  crew_n=${crew_n:-0}
  if [ "$crew_n" -eq 1 ]; then
    hit=$(grep -n -e '--append-system-prompt-file ~/.claude/crew/' -e 'crew run ' "$kb") || hit=
  fi
fi

if [ "$crew_n" -eq 0 ]; then
  if [ -d "$(dirname "$kb")" ] && ( : </dev/tty ) 2>/dev/null; then
    printf 'crew: bind %s in VS Code to open the crew in split terminals? [y/N] ' "$key"
    read -r ans </dev/tty || ans=n
    case "$ans" in
      y|Y|yes|YES)
        if [ -s "$kb" ] && [ -n "$(tr -d '[:space:][]' <"$kb")" ]; then
          echo "crew: $kb already has bindings, add this entry to the array yourself:"
          printf '%s\n' "$entry"
        else
          printf '[\n%s\n]\n' "$entry" >"$kb"
          echo "crew: $key bound in $kb"
        fi
        ;;
    esac
  fi
elif [ "$crew_n" -eq 1 ] && printf '%s\n' "${hit#*:}" | grep -Eq '^[[:space:]]*\{.*\}[[:space:]]*,?[[:space:]]*$'; then
  # hit is "<line number>:<line>". Keep the line's indentation, its trailing comma and the
  # key the user may have rebound. The entry goes into awk through ENVIRON, never -v, which
  # would mangle the \u000D of sendSequence. The new text is copied over with cat, never mv,
  # so a symlinked keybindings.json stays a symlink and keeps its permissions.
  oldkey=$(printf '%s\n' "${hit#*:}" | sed -n 's/.*"key"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
  oldkey=${oldkey:-$key}
  entry=$(entry_for "$oldkey")
  if tmp=$(mktemp) &&
    CREW_ENTRY=$entry CREW_LINE=${hit%%:*} awk '
      BEGIN { n = ENVIRON["CREW_LINE"] + 0; e = ENVIRON["CREW_ENTRY"]; sub(/^[ \t]+/, "", e) }
      NR == n {
        match($0, /^[ \t]*/); ws = substr($0, 1, RLENGTH)
        match($0, /\}[^}]*$/); print ws e substr($0, RSTART + 1)
        next
      }
      { print }' "$kb" >"$tmp" &&
    [ -s "$tmp" ] && { cat "$tmp" >"$kb"; } 2>/dev/null; then
    echo "crew: $oldkey in $kb now runs crew run"
  else
    echo "crew: could not rewrite the crew entry in $kb, it still has the old one" >&2
  fi
  rm -f "$tmp"
else
  echo "crew: replace the crew entry in $kb with:"
  printf '%s\n' "$entry"
fi
