#!/bin/bash

# Script to clear the intro popup flag for testing
# This removes the UserDefaults key that tracks whether the intro has been shown
# Handles both non-sandboxed (global defaults) and sandboxed (container) apps

echo "Clearing intro popup flag..."

# Get the bundle identifier (adjust if needed)
BUNDLE_ID="trabajomofeta.ocr-util"

# Try to get it from the app if it's installed, otherwise use default
APP_INFO_PLIST="/Applications/ocr_util.app/Contents/Info.plist"
if [ -f "$APP_INFO_PLIST" ]; then
    EXTRACTED_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP_INFO_PLIST" 2>&1)
    # Check if extraction was successful (not an error message)
    if [ -n "$EXTRACTED_ID" ] && [[ ! "$EXTRACTED_ID" =~ "Doesn't Exist" ]] && [[ ! "$EXTRACTED_ID" =~ "Error" ]] && [[ ! "$EXTRACTED_ID" =~ "File" ]]; then
        BUNDLE_ID="$EXTRACTED_ID"
    fi
fi

echo "Using bundle ID: $BUNDLE_ID"

# Clear global UserDefaults (for non-sandboxed apps or legacy)
defaults delete "$BUNDLE_ID" "$BUNDLE_ID.hasShownIntro" 2>/dev/null && echo "✓ Cleared global: $BUNDLE_ID.hasShownIntro" || echo "✗ Global key not found: $BUNDLE_ID.hasShownIntro"
defaults delete "$BUNDLE_ID" "ocr_util.hasShownIntro" 2>/dev/null && echo "✓ Cleared global: ocr_util.hasShownIntro" || echo "✗ Global key not found: ocr_util.hasShownIntro"

# Clear sandboxed UserDefaults (for sandboxed apps)
# Sandboxed apps store UserDefaults in ~/Library/Containers/{bundleID}/Library/Preferences/{bundleID}.plist
CONTAINER_PREFS_DIR="$HOME/Library/Containers/$BUNDLE_ID/Library/Preferences"
CONTAINER_PREFS_FILE="$CONTAINER_PREFS_DIR/$BUNDLE_ID.plist"

if [ -f "$CONTAINER_PREFS_FILE" ]; then
    echo "Found sandboxed preferences file: $CONTAINER_PREFS_FILE"
    
    # Remove the key from the plist file
    /usr/libexec/PlistBuddy -c "Delete :$BUNDLE_ID.hasShownIntro" "$CONTAINER_PREFS_FILE" 2>/dev/null && echo "✓ Cleared sandboxed: $BUNDLE_ID.hasShownIntro" || echo "✗ Sandboxed key not found: $BUNDLE_ID.hasShownIntro"
    /usr/libexec/PlistBuddy -c "Delete :ocr_util.hasShownIntro" "$CONTAINER_PREFS_FILE" 2>/dev/null && echo "✓ Cleared sandboxed: ocr_util.hasShownIntro" || echo "✗ Sandboxed key not found: ocr_util.hasShownIntro"
    
    # Also try using defaults with the container path
    defaults delete "$CONTAINER_PREFS_FILE" "$BUNDLE_ID.hasShownIntro" 2>/dev/null && echo "✓ Cleared via defaults: $BUNDLE_ID.hasShownIntro" || true
    defaults delete "$CONTAINER_PREFS_FILE" "ocr_util.hasShownIntro" 2>/dev/null && echo "✓ Cleared via defaults: ocr_util.hasShownIntro" || true
else
    echo "✗ Sandboxed preferences file not found: $CONTAINER_PREFS_FILE"
    echo "  (This is normal if the app hasn't been run yet or isn't sandboxed)"
fi

# Also check for any other possible locations
# Some apps might store in ~/Library/Preferences/ directly
LEGACY_PREFS_FILE="$HOME/Library/Preferences/$BUNDLE_ID.plist"
if [ -f "$LEGACY_PREFS_FILE" ]; then
    echo "Found legacy preferences file: $LEGACY_PREFS_FILE"
    /usr/libexec/PlistBuddy -c "Delete :$BUNDLE_ID.hasShownIntro" "$LEGACY_PREFS_FILE" 2>/dev/null && echo "✓ Cleared legacy: $BUNDLE_ID.hasShownIntro" || true
    /usr/libexec/PlistBuddy -c "Delete :ocr_util.hasShownIntro" "$LEGACY_PREFS_FILE" 2>/dev/null && echo "✓ Cleared legacy: ocr_util.hasShownIntro" || true
fi

echo ""
echo "Intro popup flag cleared!"
echo "The intro popup will show on the next app launch."
echo ""
echo "Note: If the app is currently running, you may need to quit and relaunch it."

