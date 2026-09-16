#!/bin/sh
# Collega crew alle posizioni che Claude Code e la shell si aspettano.
set -e
repo=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
mkdir -p "$HOME/.local/bin" "$HOME/.claude"
ln -sfn "$repo/bin/crew" "$HOME/.local/bin/crew"
ln -sfn "$repo/prompts" "$HOME/.claude/crew"
echo "crew installato. Assicurati che ~/.local/bin sia nel PATH."
