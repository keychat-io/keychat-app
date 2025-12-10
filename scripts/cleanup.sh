#!/bin/bash
# Cleanup Script for CI/CD
# Usage: ./cleanup.sh <fingerprint> [workspace_root]
# Example: ./cleanup.sh "6148AFB29A77E655C6E22567546B80237DAF6BDA" "/path/to/workspace"

FINGERPRINT="${1}"
WORKSPACE_ROOT="${2:-.}"

echo "=== Cleanup Started ==="

# Clean up .env files
echo "Cleaning up .env files..."
rm -f "$WORKSPACE_ROOT/.env"
rm -f "$WORKSPACE_ROOT/packages/app/.env"
echo ".env files cleaned"

# Clean up GPG keys (ignore errors if keys don't exist)
if [ -n "$FINGERPRINT" ]; then
    echo "Cleaning up GPG keys for fingerprint: $FINGERPRINT"
    gpg --batch --yes --delete-secret-keys "$FINGERPRINT" 2>/dev/null || true
    gpg --batch --yes --delete-keys "$FINGERPRINT" 2>/dev/null || true
    echo "GPG keys cleanup attempted"
else
    echo "No GPG fingerprint provided, skipping GPG key cleanup"
fi

echo "=== Cleanup Completed ==="
