#!/bin/zsh
# One-time setup: signing config, project generation.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ ! -f Config/Signing.xcconfig ]; then
  cp Config/Signing.example.xcconfig Config/Signing.xcconfig
  echo "Created Config/Signing.xcconfig. Fill in DEVELOPMENT_TEAM before archiving."
fi
command -v xcodegen >/dev/null || brew install xcodegen
xcodegen generate
echo "Done. Open Guitarro.xcodeproj"
