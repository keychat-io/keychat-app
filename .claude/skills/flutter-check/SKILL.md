---
name: flutter-check
description: Run comprehensive Flutter checks including lint, analyze, test, and format verification. Use before commits to ensure code quality.
invoke: user
---

# Flutter Check

Run a comprehensive Flutter quality check pipeline for the Keychat project.

## Steps

1. **Analyze**: Run `melos run analyze` to check for Dart analyzer warnings and errors
2. **Format Check**: Run `dart format --set-exit-if-changed .` to verify formatting
3. **Test**: Run `melos run test:flutter` to execute Flutter unit tests
4. **Generated Code**: Check if generated files (`.g.dart`) are up to date by running `melos run build:runner` and verifying no diff

## Behavior

- Run all steps sequentially
- Report results for each step clearly
- If any step fails, continue running remaining steps but report all failures at the end
- Provide actionable fix suggestions for any issues found
