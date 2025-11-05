#!/bin/zsh

set -e
echo "🟩 Building Linux AppImage using fastforge"

if ! command -v appimagetool >/dev/null 2>&1; then
  wget -O appimagetool "https://gh-proxy.com/https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
  chmod +x appimagetool
  sudo mv appimagetool /usr/local/bin/
fi

fastforge package \
    --flutter-build-args "dart-define-from-file=.env,target=lib/main.dart,verbose" \
    --platform linux \
    --targets appimage \
    --skip-clean
    # --artifact-name 'Keychat-1.36.5+6459-linux-amd64.AppImage' \

# ./keychat-1.36.5+6459-linux.AppImage --appimage-extract
# # build lisisar.so on glibc 3.35
# cp packages/app/libisar.so squashfs-root/
# ARCH=x86_64 appimagetool squashfs-root keychat-1.36.5+6459-linux.AppImage
# Full name  Keychat-1.35.6+6428-linux-amd64.AppImage


# echo "🟩 Building Linux deb using fastforge"
# fastforge package \
#     --flutter-build-args "dart-define-from-file=.env,target=lib/main.dart,verbose" \
#     --platform linux \
#     --targets deb \
#     --artifact-name 'Keychat-1.36.5+6459-linux-amd64.deb'
#     --skip-clean


# echo "🟩 Building Linux rpm using fastforge"
# fastforge package \
#     --flutter-build-args "dart-define-from-file=.env,target=lib/main.dart,verbose" \
#     --platform linux \
#     --targets rpm \
#     --artifact-name 'Keychat-1.36.5+6459-linux-amd64.rpm'
#     --skip-clean

exit 0