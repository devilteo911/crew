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
for l in "$HOME/.local/bin/crew:$repo/bin/crew" "$HOME/.claude/crew:$repo/prompts"; do
  link=${l%%:*}; target=${l#*:}
  old=$(readlink "$link" 2>/dev/null) || old=
  if [ -z "$old" ] && [ -e "$link" ]; then
    echo "crew: $link esiste e non è un symlink, spostalo e rilancia" >&2
    exit 1
  fi
  if [ -n "$old" ] && [ "$old" != "$target" ]; then
    echo "crew: $link ora punta a $target (prima: $old)"
  fi
  ln -sfn "$target" "$link"
done
echo "crew $(cat "$repo/VERSION" 2>/dev/null || echo sconosciuta) installato in $repo. Assicurati che ~/.local/bin sia nel PATH."
