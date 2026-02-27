#!/bin/bash

# Pre-commit hook to prevent Chinese, Japanese, and Korean characters in code
# This script checks for Chinese, Japanese, and Korean characters in:
# 1. Code files (.dart, .rs, .ts, .js, .md except i18n files)
# 2. Comments in code files
# 3. Variable/function names
# 4. Commit messages (when used as commit-msg hook)

set -e

# ANSI color codes
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Check if running as commit-msg hook
if [ "$1" = "commit-msg" ] && [ -n "$2" ]; then
  COMMIT_MSG_FILE="$2"
  MODE="commit-msg"
else
  MODE="pre-commit"
fi

# CJK character regex patterns (Unicode ranges)
CHINESE_PATTERN='[\x{4e00}-\x{9fff}\x{3400}-\x{4dbf}\x{20000}-\x{2a6df}\x{2a700}-\x{2b73f}\x{2b740}-\x{2b81f}\x{2b820}-\x{2ceaf}\x{f900}-\x{faff}\x{2f800}-\x{2fa1f}]'
JAPANESE_PATTERN='[\x{3040}-\x{309f}\x{30a0}-\x{30ff}\x{31f0}-\x{31ff}]'
KOREAN_PATTERN='[\x{ac00}-\x{d7af}\x{1100}-\x{11ff}\x{3130}-\x{318f}\x{a960}-\x{a97f}\x{d7b0}-\x{d7ff}]'
CJK_PATTERN="(${CHINESE_PATTERN}|${JAPANESE_PATTERN}|${KOREAN_PATTERN})"

# Exclude patterns for directories and files where Language is allowed
EXCLUDE_PATTERNS=(
  "packages/app/lib/l10n"
  "packages/app/lib/i18n"
  "assets/i18n"
  ".arb"
  "_zh.dart"
  "_zh_CN.dart"
  "locale_zh"
  ".git"
  ".dart_tool"
  "build/"
  "target/"
  ".fvm"
  "node_modules"
  ".idea"
  "*.g.dart"
  "*.freezed.dart"
  "pubspec.lock"
  "Podfile.lock"
  "yarn.lock"
  "package-lock.json"
)

HAS_ERROR=0

# Function to check if file should be excluded
should_exclude() {
  local file="$1"
  for pattern in "${EXCLUDE_PATTERNS[@]}"; do
    if [[ "$file" == *"$pattern"* ]]; then
      return 0
    fi
  done
  return 1
}

# Function to check for Chinese, Japanese, or Korean characters in a string
has_cjk() {
  echo "$1" | perl -C -ne "exit 1 if /$CJK_PATTERN/o" && return 1 || return 0
}

# Check commit message
check_commit_message() {
  if [ "$MODE" = "commit-msg" ]; then
    echo -e "${YELLOW}Checking commit message for CJK characters...${NC}"
    
    COMMIT_MSG=$(cat "$COMMIT_MSG_FILE")
    
    if has_cjk "$COMMIT_MSG"; then
      echo -e "${RED}✗ Error: Commit message contains CJK characters!${NC}"
      echo -e "${RED}Commit message must be in English only.${NC}"
      echo ""
      echo -e "Your commit message:"
      echo -e "${YELLOW}$COMMIT_MSG${NC}"
      echo ""
      return 1
    else
      echo -e "${GREEN}✓ Commit message is clean (no CJK characters)${NC}"
      return 0
    fi
  fi
}

# Check staged files
check_staged_files() {
  echo -e "${YELLOW}Checking staged files for CJK characters...${NC}"
  
  # Get list of staged files
  STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM)
  
  if [ -z "$STAGED_FILES" ]; then
    echo -e "${GREEN}✓ No staged files to check${NC}"
    return 0
  fi
  
  local file_count=0
  local error_count=0
  
  while IFS= read -r file; do
    # Skip if file doesn't exist (deleted files)
    [ ! -f "$file" ] && continue
    
    # Skip if file should be excluded
    should_exclude "$file" && continue
    
    # Only check text files with relevant extensions
    case "$file" in
      *.dart|*.rs|*.ts|*.js|*.md|*.yaml|*.yml|*.toml|*.sh|*.h|*.c|*.cpp)
        file_count=$((file_count + 1))
        
        # Check the file content
        if git show ":$file" | perl -C -ne "exit 1 if /$CJK_PATTERN/o"; then
          # File is clean
          :
        else
          error_count=$((error_count + 1))
          echo -e "${RED}✗ Found CJK characters in: $file${NC}"
          
          git show ":$file" | perl -C -ne "print \"  Line $.: $_\" if /$CJK_PATTERN/o" | head -5
          
          if [ $(git show ":$file" | perl -C -ne "print if /$CJK_PATTERN/o" | wc -l) -gt 5 ]; then
            echo -e "  ${YELLOW}... and more lines${NC}"
          fi
          echo ""
        fi
        ;;
    esac
  done <<< "$STAGED_FILES"
  
  echo -e "${YELLOW}Checked $file_count files${NC}"
  
  if [ $error_count -gt 0 ]; then
    echo -e "${RED}✗ Found CJK characters in $error_count file(s)${NC}"
    return 1
  else
    echo -e "${GREEN}✓ All checked files are clean (no CJK characters)${NC}"
    return 0
  fi
}

# Print usage instructions
print_usage() {
  echo ""
  echo "Usage:"
  echo "  Run manually:           ./scripts/check-language.sh"
  echo "  As commit-msg hook:     ./scripts/check-language.sh commit-msg .git/COMMIT_EDITMSG"
  echo ""
  echo "To install as git hooks:"
  echo "  ln -sf ../../scripts/check-language.sh .git/hooks/pre-commit"
  echo "  ln -sf ../../scripts/check-language.sh .git/hooks/commit-msg"
  echo ""
}

# Main execution
main() {
  echo ""
  echo "================================"
  echo "Language Check"
  echo "================================"
  echo ""
  
  # Check commit message if in commit-msg mode
  if [ "$MODE" = "commit-msg" ]; then
    if ! check_commit_message; then
      HAS_ERROR=1
    fi
  fi
  
  # Check staged files
  if ! check_staged_files; then
    HAS_ERROR=1
  fi
  
  echo ""
  echo "================================"
  
  if [ $HAS_ERROR -eq 1 ]; then
    echo -e "${RED}✗ Check failed!${NC}"
    echo -e "${RED}Please remove CJK characters from your code/comments.${NC}"
    echo -e "${YELLOW}Note: CJK is allowed only in i18n/l10n files and user-facing content.${NC}"
    print_usage
    exit 1
  else
    echo -e "${GREEN}✓ All checks passed!${NC}"
    exit 0
  fi
}

# Run main function
main "$@"
