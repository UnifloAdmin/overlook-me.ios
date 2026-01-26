#!/bin/bash

# Quick verification script for iOS localhost setup

echo "🔍 Checking iOS Localhost Configuration..."
echo ""

# Check if API server is running
echo "1️⃣ Checking if API server is running on localhost:5273..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:5273/api 2>/dev/null | grep -q "404\|200"; then
    echo "   ✅ API server is running on http://localhost:5273"
else
    echo "   ❌ API server is NOT running"
    echo "   📝 Start it with: cd /Users/nareshchandra/Desktop/uniflo/uniflo.api && dotnet run"
    exit 1
fi

echo ""
echo "2️⃣ Checking if simulator is running..."
SIMULATOR=$(xcrun simctl list devices | grep Booted | head -1)
if [ -n "$SIMULATOR" ]; then
    echo "   ✅ Simulator is running: $SIMULATOR"
else
    echo "   ⚠️  No simulator is currently running"
    echo "   📝 Start simulator from Xcode or run: open -a Simulator"
fi

echo ""
echo "3️⃣ Checking iOS project configuration..."
CONFIG_FILE="/Users/nareshchandra/Desktop/uniflo/IOS/overlook me/overlook me/Config/Environment/APIConfiguration.swift"
if grep -q "targetEnvironment(simulator)" "$CONFIG_FILE"; then
    echo "   ✅ APIConfiguration has simulator detection"
    
    if grep -q "http://localhost:5273/api" "$CONFIG_FILE"; then
        echo "   ✅ Localhost URL is configured correctly"
    else
        echo "   ❌ Localhost URL not found in config"
    fi
else
    echo "   ❌ Simulator detection not found in APIConfiguration"
fi

echo ""
echo "=" 
echo "📋 Next Steps:"
echo "=" 
echo ""
echo "1. ⚠️  IMPORTANT: Clean build in Xcode"
echo "   • Go to: Product → Clean Build Folder (Shift + Cmd + K)"
echo ""
echo "2. 🚀 Run the app in simulator (Cmd + R)"
echo ""
echo "3. 👀 Check Xcode console for this output:"
echo "   ============================================================"
echo "   📋 API Configuration Status"
echo "   ============================================================"
echo "   🔧 Environment: iOS Simulator"
echo "   🌐 Base URL: http://localhost:5273/api"
echo "   🔐 Encryption Enabled: false"
echo "   ============================================================"
echo ""
echo "4. ✅ If you see the above output, localhost is working!"
echo ""
echo "📖 For more details, see: LOCALHOST-SETUP.md"
