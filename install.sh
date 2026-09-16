#!/bin/sh
# Links crew into the places Claude Code and the shell expect it.
# From a clone: ./install.sh. From curl: clones into ~/.local/share/crew and updates.
set -e
repo=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd) || repo=
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
      cmds= act=new
      for f in "$repo"/prompts/*.md; do
        n=$(basename "$f" .md)
        cmds="$cmds{\"command\":\"workbench.action.terminal.$act\"},{\"command\":\"workbench.action.terminal.sendSequence\",\"args\":{\"text\":\"claude -n $n --append-system-prompt-file ~/.claude/crew/$n.md\\u000D\"}},"
        act=split
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
