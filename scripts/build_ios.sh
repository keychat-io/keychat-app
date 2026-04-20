#!/bin/sh
# Script Name: iOS build + upload to App Store Connect
#
# Required environment variables:
#   ASC_API_KEY      App Store Connect API Key ID (e.g. 8Y6J352PMA)
#   ASC_API_ISSUER   App Store Connect API Issuer ID (UUID)
#   ASC_TEAM_ID      Apple Developer Team ID (10-char alphanumeric)
#
# The .p8 key file must live in one of:
#   ./private_keys
#   ~/private_keys
#   ~/.private_keys
#   ~/.appstoreconnect/private_keys
#
set -e

missing=""
[ -z "$ASC_API_KEY" ]    && missing="$missing ASC_API_KEY"
[ -z "$ASC_API_ISSUER" ] && missing="$missing ASC_API_ISSUER"
[ -z "$ASC_TEAM_ID" ]    && missing="$missing ASC_TEAM_ID"
if [ -n "$missing" ]; then
    echo "ERROR: missing required env var(s):$missing"
    echo "Add to your shell rc (~/.zshrc):"
    echo "  export ASC_API_KEY=<your-key-id>"
    echo "  export ASC_API_ISSUER=<your-issuer-uuid>"
    echo "  export ASC_TEAM_ID=<your-team-id>"
    exit 1
fi

start_ts=$(date +%s)
current_path=$(pwd)

# Generate ExportOptions.plist at build time so teamID stays out of git.
export_options="$current_path/build/ExportOptions.ios.plist"
mkdir -p "$(dirname "$export_options")"
cat > "$export_options" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>teamID</key>
	<string>${ASC_TEAM_ID}</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>uploadSymbols</key>
	<true/>
	<key>destination</key>
	<string>export</string>
	<key>stripSwiftSymbols</key>
	<true/>
</dict>
</plist>
EOF

echo "Update app starting..."
cd packages/app/

flutter build ipa \
    --dart-define=dart.vm.product=true \
    --release \
    --analyze-size \
    --export-options-plist="$export_options"
    # --obfuscate --split-debug-info=./build/obfuscate/ios/

ipa="$current_path/packages/app/build/ios/ipa/keychat.ipa"

if [ ! -f "$ipa" ]; then
    echo "ERROR: IPA was not produced at $ipa"
    echo "Open the archive manually to diagnose signing:"
    echo "  open $current_path/packages/app/build/ios/archive/Runner.xcarchive"
    exit 1
fi

xcrun altool --validate-app --type ios -f "$ipa" \
    --apiKey "$ASC_API_KEY" --apiIssuer "$ASC_API_ISSUER"
xcrun -v altool --upload-app --type ios -f "$ipa" \
    --apiKey "$ASC_API_KEY" --apiIssuer "$ASC_API_ISSUER"

end_ts=$(date +%s)
elapsed=$(( end_ts - start_ts ))
echo "🚀🚀🚀🚀Success: ${elapsed} seconds🚀🚀🚀🚀"
