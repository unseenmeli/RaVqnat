#!/usr/bin/env bash
# Runs the iOS unit and UI tests on a simulator.
#   scripts/test-ios.sh                      # all tests
#   scripts/test-ios.sh RaVqnatUITests       # one target (passed to -only-testing)
#   RV_SCREENSHOT_DIR=/tmp/shots scripts/test-ios.sh RaVqnatUITests   # also save UI screenshots
set -euo pipefail
cd "$(dirname "$0")/.."

DEVICE="${RV_SIMULATOR:-iPhone 16}"
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b >/dev/null
# Skip the one-time "slide to type" keyboard tutorial that would cover the UI under test.
xcrun simctl spawn "$DEVICE" defaults write com.apple.keyboard.preferences DidShowContinuousPathIntroduction -bool true

ONLY=()
if [[ $# -gt 0 ]]; then ONLY=(-only-testing:"$1"); fi

TEST_RUNNER_RV_SCREENSHOT_DIR="${RV_SCREENSHOT_DIR:-}" xcodebuild test \
  -project RaVqnat.xcodeproj -scheme RaVqnat \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -derivedDataPath .build/dd -clonedSourcePackagesDirPath .build/spm \
  ${ONLY[@]+"${ONLY[@]}"}
