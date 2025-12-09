#!/bin/bash
# GPG Sign Script for CI/CD
# Usage: ./gpg-sign.sh <dist_dir> <extensions>
# Example: ./gpg-sign.sh ./dist "deb rpm AppImage"
# Example: ./gpg-sign.sh ./dist "exe"
# Example: ./gpg-sign.sh ./dist "apk"

DIST_DIR="${1:-./dist}"
EXTENSIONS="${2:-deb rpm AppImage}"

if [ -z "$GPG_PASSPHRASE" ]; then
    echo "Error: GPG_PASSPHRASE environment variable is not set"
    exit 1
fi

echo "Signing files in $DIST_DIR with extensions: $EXTENSIONS"
echo "Files in dist directory (recursive):"
find "$DIST_DIR" -type f 2>/dev/null || echo "Directory not found or empty"

SIGNED_COUNT=0

for ext in $EXTENSIONS; do
    echo "Looking for *.$ext files (recursive)..."
    # Use find recursively to search in all subdirectories
    while IFS= read -r -d '' file; do
        if [ -f "$file" ]; then
            echo "Signing: $file"
            if gpg --batch --yes --pinentry-mode loopback \
                --passphrase "$GPG_PASSPHRASE" \
                --detach-sign --armor "$file"; then
                echo "Created: ${file}.asc"
                SIGNED_COUNT=$((SIGNED_COUNT + 1))
            else
                echo "Warning: Failed to sign $file"
            fi
        fi
    done < <(find "$DIST_DIR" -type f -name "*.$ext" -print0 2>/dev/null)
done

echo ""
echo "Total files signed: $SIGNED_COUNT"
echo ""
echo "Signed files (.asc):"
find "$DIST_DIR" -name "*.asc" -type f 2>/dev/null || echo "No .asc files found"
echo ""
echo "All files in $DIST_DIR:"
find "$DIST_DIR" -type f 2>/dev/null
