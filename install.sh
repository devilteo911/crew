#!/bin/sh
# Collega crew alle posizioni che Claude Code e la shell si aspettano.
# Da un clone: ./install.sh. Da curl: clona in ~/.local/share/crew e aggiorna.
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
ln -sfn "$repo/bin/crew" "$HOME/.local/bin/crew"
ln -sfn "$repo/prompts" "$HOME/.claude/crew"
echo "crew installato. Assicurati che ~/.local/bin sia nel PATH."
