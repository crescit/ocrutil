#!/bin/bash
# Test script to run paddleocr-cli directly and see what happens

APP_PATH="/Users/josh/Library/Developer/Xcode/DerivedData/ocr_util-hjsdibmplfxvhqeeeghtelxuxvok/Build/Products/Debug/ocr_util.app"
EXECUTABLE="$APP_PATH/Contents/Resources/paddleocr-cli-dir/paddleocr-cli"
TEST_IMAGE="/Users/josh/Library/Containers/trabajomofeta.ocr-util/Data/Library/Application Support/OCR_Temp/paddleocr-3710299A-1407-419B-8EE1-DAE711268A29.png"

if [ ! -f "$EXECUTABLE" ]; then
    echo "Executable not found at $EXECUTABLE"
    exit 1
fi

echo "Testing executable: $EXECUTABLE"
echo "Working directory: $(dirname "$EXECUTABLE")"
echo "Test image: $TEST_IMAGE"
echo ""
echo "Running with dtruss to see system calls..."
echo ""

cd "$(dirname "$EXECUTABLE")"
sudo dtruss -f -n "$(basename "$EXECUTABLE")" "$EXECUTABLE" "$TEST_IMAGE" 2>&1 | head -50
