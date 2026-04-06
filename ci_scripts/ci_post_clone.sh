#!/bin/sh

# ============================================================
# Xcode Cloud — Post Clone Script
# ============================================================
# This script runs after Xcode Cloud clones the repo.
# Use it to install dependencies, set env vars, etc.
#
# Available environment variables from Xcode Cloud:
#   $CI                        — Always "TRUE" in Xcode Cloud
#   $CI_WORKSPACE              — Path to the workspace
#   $CI_PRODUCT                — Product name
#   $CI_XCODEBUILD_ACTION      — "build", "test", "archive"
#   $CI_BRANCH                 — Current branch
#   $CI_COMMIT                 — Current commit SHA
#   $CI_BUILD_NUMBER           — Auto-incrementing build number
#   $CI_PRODUCT_PLATFORM       — "iOS", "macOS", etc.
# ============================================================

set -e

echo "🚀 Xcode Cloud — Post Clone"
echo "   Branch:  $CI_BRANCH"
echo "   Commit:  $CI_COMMIT"
echo "   Build:   $CI_BUILD_NUMBER"
echo "   Action:  $CI_XCODEBUILD_ACTION"

# -----------------------------------------------------------
# 1) Resolve Swift Package Manager dependencies (automatic,
#    but this logs it explicitly)
# -----------------------------------------------------------
echo "📦 Resolving SPM dependencies..."
# Xcode Cloud resolves SPM automatically, but if you ever
# need custom resolution, add it here.

# -----------------------------------------------------------
# 2) Set build number from Xcode Cloud's auto-increment
# -----------------------------------------------------------
if [ "$CI_XCODEBUILD_ACTION" = "archive" ]; then
    echo "🔢 Setting build number to $CI_BUILD_NUMBER"
    cd "$CI_WORKSPACE"
    
    # Update the build number in the Xcode project
    agvtool new-version -all "$CI_BUILD_NUMBER"
    
    echo "✅ Build number set to $CI_BUILD_NUMBER"
fi

echo "✅ Post-clone complete"
