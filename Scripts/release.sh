#!/bin/zsh
# Archives the app and uploads it to App Store Connect (TestFlight).
# Prerequisites: Config/Signing.xcconfig with your DEVELOPMENT_TEAM, an Apple ID signed in
# to Xcode (Settings -> Accounts) or an App Store Connect API key passed via
# -authenticationKeyPath/-authenticationKeyID/-authenticationKeyIssuerID.
set -euo pipefail
cd "$(dirname "$0")/.."

BUILD_NUMBER="${1:-$(date +%Y%m%d%H%M)}"
ARCHIVE=build/Guitarro.xcarchive

xcodegen generate
xcodebuild -project Guitarro.xcodeproj -scheme Guitarro -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  -allowProvisioningUpdates archive

xcodebuild -exportArchive -archivePath "$ARCHIVE" \
  -exportOptionsPlist Config/ExportOptions.plist -exportPath build/export \
  -allowProvisioningUpdates "$@"

echo "Uploaded build $BUILD_NUMBER. It appears in App Store Connect -> TestFlight after processing."
