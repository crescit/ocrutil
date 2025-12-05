#!/bin/bash
# Script to remove problematic SSL/hashlib modules from PaddleOCR bundle
# These modules link against private macOS frameworks and cause App Store rejection

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_DIR="${SCRIPT_DIR}/OCRAssets/ocr/paddleocr/paddleocr-cli-dir"
PYTHON_LIB_DIR="${BUNDLE_DIR}/_internal/python3.9/lib-dynload"

echo "🔍 Removing SSL/hashlib modules from PaddleOCR bundle..."
echo "   Bundle directory: ${BUNDLE_DIR}"

if [ ! -d "${PYTHON_LIB_DIR}" ]; then
    echo "❌ Error: Python lib-dynload directory not found at ${PYTHON_LIB_DIR}"
    exit 1
fi

# Files to remove
FILES_TO_REMOVE=(
    "_ssl.cpython-39-darwin.so"
    "_hashlib.cpython-39-darwin.so"
)

REMOVED_COUNT=0
for file in "${FILES_TO_REMOVE[@]}"; do
    file_path="${PYTHON_LIB_DIR}/${file}"
    if [ -f "${file_path}" ]; then
        echo "   Removing: ${file}"
        rm -f "${file_path}"
        REMOVED_COUNT=$((REMOVED_COUNT + 1))
    else
        echo "   ⚠️  Not found (already removed?): ${file}"
    fi
done

if [ ${REMOVED_COUNT} -eq 0 ]; then
    echo "✅ No files to remove (they may have already been removed)"
else
    echo "✅ Removed ${REMOVED_COUNT} file(s)"
fi

# Verify removal
echo ""
echo "🔍 Verifying removal..."
for file in "${FILES_TO_REMOVE[@]}"; do
    file_path="${PYTHON_LIB_DIR}/${file}"
    if [ -f "${file_path}" ]; then
        echo "❌ ERROR: ${file} still exists!"
        exit 1
    else
        echo "   ✅ ${file} - removed"
    fi
done

echo ""
echo "✅ All problematic SSL/hashlib modules have been removed"
echo "   The bundle should now pass App Store review"

