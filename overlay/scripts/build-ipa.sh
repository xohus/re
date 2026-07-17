#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_ROOT="$ROOT/build/XCode"
DERIVED_DATA="$BUILD_ROOT/DerivedData"
OUTPUT_DIR="$ROOT/build/output"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "XCode requires macOS with Xcode installed."
  exit 1
fi

cd "$ROOT"

if [ ! -d "$ROOT/Resources" ]; then
  echo "Downloading Code App runtime frameworks..."
  ./downloadFrameworks.sh
fi

rm -rf "$BUILD_ROOT" "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

xcodebuild \
  -resolvePackageDependencies \
  -project "$ROOT/Code.xcodeproj" \
  -scheme "Code App" \
  -derivedDataPath "$DERIVED_DATA"

RUNESTONE_HELPER="$DERIVED_DATA/SourcePackages/checkouts/Runestone/Sources/Runestone/TextView/SearchAndReplace/UITextSearchingHelper.swift"
if [ ! -f "$RUNESTONE_HELPER" ]; then
  echo "Runestone compatibility source was not found."
  exit 1
fi

# Xcode 26 exposes this delegate requirement on iOS 14, while Runestone 0.5.1
# incorrectly limits its implementation to iOS 16. The app itself targets iOS 16.
perl -0pi -e 's/\n    \@available\(iOS 16, \*\)\n    func findInteraction/\n    func findInteraction/' "$RUNESTONE_HELPER"

xcodebuild \
  -project "$ROOT/Code.xcodeproj" \
  -scheme "Code App" \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build

APP_PATH="$(find "$DERIVED_DATA/Build/Products/Release-iphoneos" -maxdepth 1 -type d -name '*.app' -print -quit)"

if [ -z "$APP_PATH" ]; then
  echo "Build succeeded but no .app bundle was found."
  exit 1
fi

PAYLOAD_DIR="$BUILD_ROOT/Payload"
mkdir -p "$PAYLOAD_DIR"
cp -R "$APP_PATH" "$PAYLOAD_DIR/XCode.app"

cd "$BUILD_ROOT"
/usr/bin/zip -qry "$OUTPUT_DIR/XCode.ipa" Payload

echo "Created: $OUTPUT_DIR/XCode.ipa"
echo "The IPA is unsigned and must be signed with your own Apple certificate before installation."
