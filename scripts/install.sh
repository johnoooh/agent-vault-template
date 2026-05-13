#!/usr/bin/env bash
# One-time setup: activate the pre-commit hook.
# Run from the vault root after cloning the template.

set -euo pipefail

VAULT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$VAULT_ROOT"

if [ ! -d .git ]; then
  echo "error: not a git repository (run 'git init' first, or clone via 'gh repo create --template')." >&2
  exit 1
fi

git config core.hooksPath .githooks
chmod +x .githooks/pre-commit
chmod +x .claude/hooks/*.sh 2>/dev/null || true
chmod +x scripts/*.py 2>/dev/null || true

echo "✓ pre-commit hook activated (.githooks/pre-commit)"
echo "✓ hooks and scripts marked executable"
echo ""
echo "Next steps:"
echo "  1. Edit .githooks/pre-commit — replace SENSITIVE_PATTERN with regex matching the ID shapes your data uses."
echo "  2. Skim AGENTS.md and adjust the ownership table to your workflow."
echo "  3. Add the session protocol to your global agent config (~/.claude/CLAUDE.md). See TEAM_GUIDE.md §3."
echo "  4. Replace the placeholder block in Work/context.md with a real project."
