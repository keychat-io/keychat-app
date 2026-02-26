#!/bin/bash

# Install git hooks for pre-commit checks
# This script installs hooks to prevent Chinese, Japanese, and Korean characters in commits

set -e

# ANSI color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOKS_DIR="$ROOT_DIR/.git/hooks"

echo ""
echo "Installing Git Hooks for Keychat"
echo "================================"
echo ""

# Check if .git directory exists
if [ ! -d "$ROOT_DIR/.git" ]; then
  echo "Error: .git directory not found. Are you in a git repository?"
  exit 1
fi

# Create hooks directory if it doesn't exist
mkdir -p "$HOOKS_DIR"

# Install pre-commit hook
echo -e "${YELLOW}Installing pre-commit hook...${NC}"
cat > "$HOOKS_DIR/pre-commit" << 'EOF'
#!/bin/bash
# Git pre-commit hook
HOOK_DIR="$(dirname "$0")"
CHECK_SCRIPT="$HOOK_DIR/../../scripts/check-language.sh"

if [ ! -f "$CHECK_SCRIPT" ]; then
  exit 0
fi

"$CHECK_SCRIPT"
EOF
chmod +x "$HOOKS_DIR/pre-commit"
echo -e "${GREEN}✓ pre-commit hook installed${NC}"

# Install commit-msg hook
echo -e "${YELLOW}Installing commit-msg hook...${NC}"
cat > "$HOOKS_DIR/commit-msg" << 'EOF'
#!/bin/bash
# Git commit-msg hook
HOOK_DIR="$(dirname "$0")"
CHECK_SCRIPT="$HOOK_DIR/../../scripts/check-language.sh"

if [ ! -f "$CHECK_SCRIPT" ]; then
  exit 0
fi

"$CHECK_SCRIPT" commit-msg "$1"
EOF
chmod +x "$HOOKS_DIR/commit-msg"
echo -e "${GREEN}✓ commit-msg hook installed${NC}"

echo ""
echo "================================"
echo -e "${GREEN}✓ Git hooks installed successfully!${NC}"
echo ""
echo "The following checks will run automatically:"
echo "  • Pre-commit: Check staged files for Chinese, Japanese, and Korean characters"
echo "  • Commit-msg: Check commit message for Chinese, Japanese, and Korean characters"
echo ""
echo "To run checks manually:"
echo "  ./scripts/check-language.sh"
echo ""
echo "To uninstall hooks:"
echo "  rm .git/hooks/pre-commit .git/hooks/commit-msg"
echo ""
