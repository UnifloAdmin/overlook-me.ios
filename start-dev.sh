#!/bin/bash

# Helper script to start API server and verify setup

echo "🚀 Starting Uniflo Development Environment"
echo ""

API_DIR="/Users/nareshchandra/Desktop/uniflo/uniflo.api"

# Check if API is already running
if curl -s -o /dev/null -w "%{http_code}" http://localhost:5273/api 2>/dev/null | grep -q "404\|200"; then
    echo "✅ API server is already running on http://localhost:5273"
else
    echo "🔧 Starting API server..."
    cd "$API_DIR"
    
    # Start API in background
    dotnet run &
    API_PID=$!
    
    echo "⏳ Waiting for API to start..."
    sleep 5
    
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:5273/api 2>/dev/null | grep -q "404\|200"; then
        echo "✅ API server started successfully (PID: $API_PID)"
        echo "📝 To stop: kill $API_PID"
    else
        echo "❌ Failed to start API server"
        exit 1
    fi
fi

echo ""
echo "=" 
echo "🔧 iOS Simulator Configuration"
echo "=" 
echo "When running in simulator, the app will use:"
echo "   🌐 Base URL: http://localhost:5273/api"
echo "   🔐 Encryption: Disabled"
echo ""
echo "=" 
echo "📱 Next Steps"
echo "=" 
echo "1. Open Xcode: open 'overlook me.xcodeproj'"
echo "2. Clean Build: Product → Clean Build Folder (Shift + Cmd + K)"
echo "3. Run: Cmd + R"
echo "4. Check Xcode Console for configuration output"
echo ""
