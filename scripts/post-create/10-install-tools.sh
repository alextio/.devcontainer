#!/usr/bin/env bash
set -euo pipefail

# Ensure ~/.local/bin is on PATH for interactive shells.
mkdir -p "$HOME/.local/bin"
grep -qxF 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null \
  || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"



# Claude Code
if [ ! -x "$HOME/.local/bin/claude" ]; then
  curl -fsSL https://claude.ai/install.sh | bash
fi

