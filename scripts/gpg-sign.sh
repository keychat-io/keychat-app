#!/bin/bash
# GPG Sign Script for CI/CD
# Usage: ./gpg-sign.sh <dist_dir> <extensions>
# Example: ./gpg-sign.sh ./dist "deb rpm AppImage"
# Example: ./gpg-sign.sh ./dist "exe"
# Example: ./gpg-sign.sh ./dist "apk"

set -e

DIST_DIR="${1:-./dist}"
EXTENSIONS="${2:-deb rpm AppImage}"

if [ -z "$GPG_PASSPHRASE" ]; then
    echo "Error: GPG_PASSPHRASE environment variable is not set"
    exit 1
fi

echo "Signing files in $DIST_DIR with extensions: $EXTENSIONS"

for ext in $EXTENSIONS; do
    for file in "$DIST_DIR"/*."$ext"; do
        if [ -f "$file" ]; then
            echo "Signing: $file"
            gpg --batch --yes --pinentry-mode loopback \
                --passphrase "$GPG_PASSPHRASE" \
                --detach-sign --armor "$file"
            echo "Created: ${file}.asc"
        fi
    done
done

echo ""
echo "Signed files:"
ls -la "$DIST_DIR"/*.asc 2>/dev/null || echo "No .asc files found"
echo ""
echo "All files in $DIST_DIR:"
ls -la "$DIST_DIR"/
