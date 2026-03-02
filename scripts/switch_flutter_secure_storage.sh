#!/usr/bin/env bash

set -euo pipefail

mode="${1:-}"
if [[ -z "$mode" ]]; then
  echo "Usage: $0 <macos|non-macos>" >&2
  exit 1
fi

pubspec_file="packages/app/pubspec.yaml"

python3 - <<'PY' "$mode" "$pubspec_file"
import pathlib
import re
import sys

mode = sys.argv[1]
pubspec_path = pathlib.Path(sys.argv[2])
text = pubspec_path.read_text(encoding='utf-8')

hosted = "  flutter_secure_storage: ^10.0.0"
path_dep = "  flutter_secure_storage:\n    path: ../../../flutter_secure_storage/flutter_secure_storage"
pattern = re.compile(
    r"  flutter_secure_storage:\s*\n\s*path:\s*\.\./\.\./\.\./flutter_secure_storage/flutter_secure_storage|"
    r"  flutter_secure_storage:\s*\^10\.0\.0"
)

if mode == 'macos':
  replacement = path_dep
elif mode == 'non-macos':
  replacement = hosted
else:
  raise SystemExit(f"Unsupported mode: {mode}")

new_text, count = pattern.subn(replacement, text, count=1)
if count == 0:
  raise SystemExit('Failed to find flutter_secure_storage dependency in pubspec.')

pubspec_path.write_text(new_text, encoding='utf-8')
print(f'Switched flutter_secure_storage to {mode} mode in {pubspec_path}.')
PY
