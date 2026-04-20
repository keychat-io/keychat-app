#!/bin/sh
# Script Name: iOS build + upload to App Store Connect
#
# Required environment variables:
#   ASC_API_KEY      App Store Connect API Key ID (e.g. 8Y6J352PMA)
#   ASC_API_ISSUER   App Store Connect API Issuer ID (UUID)
#
# Optional:
#   ASC_API_KEY_PATH Directory holding AuthKey_<ASC_API_KEY>.p8
#                    (altool searches the default locations if unset)
#
# The .p8 key file must live in one of:
#   ./private_keys
#   ~/private_keys
#   ~/.private_keys
#   ~/.appstoreconnect/private_keys
#
set -e

if [ -z "$ASC_API_KEY" ] || [ -z "$ASC_API_ISSUER" ]; then
    echo "ERROR: ASC_API_KEY and ASC_API_ISSUER must be set in the environment."
    echo "Add to your shell rc (~/.zshrc):"
    echo "  export ASC_API_KEY=<your-key-id>"
    echo "  export ASC_API_ISSUER=<your-issuer-uuid>"
    exit 1
fi

start_ts=$(date +%s)
current_path=$(pwd)
export_options="$current_path/scripts/ExportOptions.ios.plist"

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
