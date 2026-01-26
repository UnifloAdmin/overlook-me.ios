# iOS Simulator Localhost Configuration

## ✅ Changes Made

The iOS app now automatically detects when running in the simulator and switches to localhost endpoints.

### Modified Files:
1. **`overlook me/Config/Environment/APIConfiguration.swift`**
   - Automatically uses `http://localhost:5273/api` in simulator
   - Uses `https://uniflo-data.com/api` on real devices
   - Disables encryption in simulator for easier debugging
   - Adds debug logging to show which URL is active

2. **`overlook me/overlook_meApp.swift`**
   - Added `APIConfiguration.printConfiguration()` call on app launch
   - Prints configuration details to Xcode console

---

## 🔧 How to Use

### Step 1: Clean Build in Xcode
**IMPORTANT:** Xcode may have cached the old configuration. You MUST do a clean build:

1. In Xcode, go to **Product → Clean Build Folder** (Shift + Cmd + K)
2. Or manually delete derived data:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```

### Step 2: Start Your Local API Server
```bash
cd /Users/nareshchandra/Desktop/uniflo/uniflo.api
dotnet run
```

The server should start on `http://localhost:5273`

### Step 3: Build and Run in Simulator
1. Select any iOS Simulator (not a real device)
2. Run the app (Cmd + R)
3. Check Xcode console for this output:

```
============================================================
📋 API Configuration Status
============================================================
🔧 Environment: iOS Simulator
🌐 Base URL: http://localhost:5273/api
🔐 Encryption Enabled: false
============================================================
```

### Step 4: Verify Network Requests
Watch the Xcode console for API requests. You should see logs like:
```
📤 [APIClient] Request body for GET /tasks:
📦 [APIClient] Raw JSON response for /tasks:
```

If you see errors connecting, the requests are hitting localhost ✓

---

## 🐛 Troubleshooting

### Problem: Still seeing production URL
**Solution:** You MUST clean build. Xcode caches compiled code.
```bash
# Option 1: In Xcode
Product → Clean Build Folder (Shift + Cmd + K)

# Option 2: Terminal
cd "/Users/nareshchandra/Desktop/uniflo/IOS/overlook me"
xcodebuild clean -project "overlook me.xcodeproj"
```

### Problem: Connection refused / Network error
**Solution:** Make sure your API is running:
```bash
# Check if API is running
curl http://localhost:5273/api

# If not running, start it:
cd /Users/nareshchandra/Desktop/uniflo/uniflo.api
dotnet run
```

### Problem: Authentication fails
**Solution:** You may need to:
1. Clear app data (delete and reinstall app in simulator)
2. Use a test token for local development
3. Check Auth0 configuration in `appsettings.json`

### Problem: Still showing encrypted responses
**Solution:** The encryption is disabled in simulator. If you still see encrypted data:
1. Clean build
2. Verify console shows `Encryption Enabled: false`
3. Check your API isn't forcing encryption server-side

---

## 📱 Switching Between Environments

| Environment | URL | Encryption | How to Use |
|------------|-----|------------|-----------|
| **Simulator** | `http://localhost:5273/api` | ❌ Disabled | Just run in any simulator |
| **Real Device** | `https://uniflo-data.com/api` | ✅ Enabled | Connect real iPhone/iPad via cable |

The switch happens automatically based on build target - no manual changes needed!

---

## 🔍 Debugging Network Issues

### View All Network Traffic
Add this to any API call to see full request/response:
```swift
print("🌐 Making request to: \(url)")
print("📤 Headers: \(request.allHTTPHeaderFields ?? [:])")
print("📦 Response: \(String(data: data, encoding: .utf8) ?? "binary data")")
```

### Test Localhost Directly
From Terminal:
```bash
# Test if API is reachable
curl http://localhost:5273/api

# Test specific endpoint (example)
curl -H "Authorization: Bearer YOUR_TOKEN" http://localhost:5273/api/tasks
```

### Check Simulator Network
The simulator shares your Mac's network. Test from Terminal:
```bash
# If this fails, localhost isn't accessible
curl http://localhost:5273/api
```

---

## 💡 Tips

1. **Keep API Running:** The API server must be running before launching the app
2. **Watch Console:** Xcode console shows which URL is being used on app launch
3. **Use Simulator:** Real devices can't access `localhost` - they'll use production
4. **Clean Build:** Always clean build after changing environment configuration
5. **Disable Encryption:** Localhost has encryption disabled for easier debugging

---

## 🔄 Reverting to Production Only

If you want to go back to production URL only, edit `APIConfiguration.swift`:

```swift
static let baseURL = URL(string: "https://uniflo-data.com/api")!
```

Remove the `#if targetEnvironment(simulator)` block.
