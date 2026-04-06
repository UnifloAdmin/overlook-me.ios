#!/bin/sh

# ============================================================
# Xcode Cloud — Post Build Script (for xcodebuild)
# ============================================================
# Runs after the xcodebuild step completes.
# Use for notifications, artifact processing, etc.
# ============================================================

set -e

echo "🏗️ Xcode Cloud — Post Build"
echo "   Action:  $CI_XCODEBUILD_ACTION"
echo "   Result:  $CI_XCODEBUILD_EXIT_CODE"

if [ "$CI_XCODEBUILD_EXIT_CODE" -eq 0 ]; then
    echo "✅ Build succeeded!"
else
    echo "❌ Build failed with exit code $CI_XCODEBUILD_EXIT_CODE"
fi
