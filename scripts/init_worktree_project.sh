#!/bin/sh
# This script initializes a new git worktree project by copying the .git directory
# from the current directory to the new project directory.
# Usage: ./init_worktree_project.sh <new_project_directory>
set -e
current_dir=$(pwd)
new_project_dir=".claude/worktrees/$1"
cp -r .vscode "$new_project_dir/.vscode"
cp packages/app/.env "$new_project_dir/packages/app/"
cp packages/app/firebase.json "$new_project_dir/packages/app/"
cp packages/app/ios/Runner/GoogleService-Info.plist "$new_project_dir/packages/app/ios/Runner/"
cp packages/app/macos/Runner/GoogleService-Info.plist "$new_project_dir/packages/app/macos/Runner/"
cp packages/app/android/app/google-services.json "$new_project_dir/packages/app/android/app/"
cp packages/app/android/key.properties "$new_project_dir/packages/app/android/"
cp packages/app/android/local.properties "$new_project_dir/packages/app/android/"
