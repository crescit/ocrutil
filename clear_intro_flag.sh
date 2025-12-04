#!/bin/bash

# Script to clear the intro popup flag for testing
# This removes the UserDefaults key that tracks whether the intro has been shown

echo "Clearing intro popup flag..."

# Get the bundle identifier (adjust if needed)
BUNDLE_ID="trabajomofeta.ocr-util"

# Try to get it from the app if it's installed, otherwise use default
if [ -d "/Applications/ocr_util.app" ]; then
    BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "/Applications/ocr_util.app/Contents/Info.plist" 2>/dev/null || echo "$BUNDLE_ID")
fi

# Clear the UserDefaults keys (they're stored with the full path as the key name)
defaults delete "$BUNDLE_ID" "$BUNDLE_ID.hasShownIntro" 2>/dev/null && echo "Cleared $BUNDLE_ID.hasShownIntro" || echo "Key $BUNDLE_ID.hasShownIntro not found"
defaults delete "$BUNDLE_ID" "ocr_util.hasShownIntro" 2>/dev/null && echo "Cleared ocr_util.hasShownIntro" || echo "Key ocr_util.hasShownIntro not found"

echo "Intro popup flag cleared!"
echo "The intro popup will show on the next app launch."
echo ""
echo "Note: If the app is currently running, you may need to quit and relaunch it."

