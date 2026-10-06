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
  row() { # <digit> <id> <text>
    if has "$2"; then mark='(installed)'; else mark='[x]'; fi
    printf '  %s) %s %s\n' "$1" "$mark" "$3"
  }
  if has issue-flow@crew && has ponytail@ponytail && has caveman@caveman; then
    echo "crew: issue-flow, ponytail and caveman already installed"
  else
    repl=
    if has issue-flow@issue-flow && ! has issue-flow@crew; then repl=' — replaces issue-flow@issue-flow'; fi
    echo "crew: plugins for the crew sessions, all selected:"
    row 1 issue-flow@crew "issue-flow   plan and implement through issues    (marketplace crew, this clone)$repl"
    row 2 ponytail@ponytail 'ponytail     the laziest code that works          (DietrichGebert/ponytail)'
    row 3 caveman@caveman 'caveman      terse prose, fewer tokens            (JuliusBrussee/caveman)'
    printf 'crew: Enter installs the selected; type the numbers to leave out (e.g. "3"): '
    read -r skip </dev/tty || skip=123
    plugin 1 issue-flow@crew "$repo"
    plugin 2 ponytail@ponytail DietrichGebert/ponytail
    plugin 3 caveman@caveman JuliusBrussee/caveman
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
# terminals, instead of the external ones bin/crew spawns.
case "$(uname -s)" in
  Darwin) kb="$HOME/Library/Application Support/Code/User/keybindings.json"; key="cmd+shift+c" ;;
  *)      kb="$HOME/.config/Code/User/keybindings.json"; key="meta+shift+c" ;;
esac

if [ -d "$(dirname "$kb")" ] && [ -r /dev/tty ]; then
  printf 'crew: bind %s in VS Code to open the crew in split terminals? [y/N] ' "$key"
  read -r ans </dev/tty || ans=n
  case "$ans" in
    y|Y|yes|YES)
      cmds='' act=new wait=''
      for f in "$repo"/prompts/*.md; do
        n=$(basename "$f" .md)
        m=$(cat "${f%.md}.model" 2>/dev/null | tr -d '[:space:]')
        cmds="$cmds{\"command\":\"workbench.action.terminal.$act\"},{\"command\":\"workbench.action.terminal.sendSequence\",\"args\":{\"text\":\"${wait}claude -n $n${m:+ --model $m} --append-system-prompt-file ~/.claude/crew/$n.md\\u000D\"}},"
        act=split wait='sleep 5; '
      done
      entry="  { \"key\": \"$key\", \"command\": \"runCommands\", \"args\": { \"commands\": [${cmds%,}] } }"
      if [ -s "$kb" ] && [ -n "$(tr -d '[:space:][]' <"$kb")" ]; then
        echo "crew: $kb already has bindings, add this entry to the array yourself:"
        echo "$entry"
      else
        printf '[\n%s\n]\n' "$entry" >"$kb"
        echo "crew: $key bound in $kb"
      fi
      ;;
  esac
fi
