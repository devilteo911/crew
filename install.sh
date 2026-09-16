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
