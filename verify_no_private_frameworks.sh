#!/bin/bash
# Script to verify no private macOS frameworks are linked in the bundle
# This checks all .so files in the Python lib-dynload directory

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_DIR="${SCRIPT_DIR}/OCRAssets/ocr/paddleocr/paddleocr-cli-dir"
PYTHON_LIB_DIR="${BUNDLE_DIR}/_internal/python3.9/lib-dynload"

echo "🔍 Checking for private framework links..."
echo "   Checking directory: ${PYTHON_LIB_DIR}"

if [ ! -d "${PYTHON_LIB_DIR}" ]; then
    echo "❌ Error: Python lib-dynload directory not found at ${PYTHON_LIB_DIR}"
    exit 1
fi

# Private frameworks to check for
PRIVATE_FRAMEWORKS=(
    "TrustEvaluationAgent"
    "Security"
    "CoreServices"
)

FOUND_ISSUES=0

# Check each .so file
for so_file in "${PYTHON_LIB_DIR}"/*.so; do
    if [ ! -f "${so_file}" ]; then
        continue
    fi
    
    filename=$(basename "${so_file}")
    
    # Check for private framework links
    for framework in "${PRIVATE_FRAMEWORKS[@]}"; do
        if otool -L "${so_file}" 2>/dev/null | grep -qi "${framework}"; then
            echo "❌ FOUND: ${filename} links to private framework: ${framework}"
            otool -L "${so_file}" | grep -i "${framework}"
            FOUND_ISSUES=$((FOUND_ISSUES + 1))
        fi
    done
done

# Specifically check for _ssl and _hashlib
echo ""
echo "🔍 Checking for problematic SSL/hashlib modules..."
PROBLEMATIC_FILES=(
    "_ssl.cpython-39-darwin.so"
    "_hashlib.cpython-39-darwin.so"
)

for file in "${PROBLEMATIC_FILES[@]}"; do
    file_path="${PYTHON_LIB_DIR}/${file}"
    if [ -f "${file_path}" ]; then
        echo "❌ FOUND: ${file} exists (should be removed)"
        FOUND_ISSUES=$((FOUND_ISSUES + 1))
        
        # Check what it links to
        echo "   Links to:"
        otool -L "${file_path}" | grep -E "(TrustEvaluationAgent|Security)" || echo "   (no obvious private frameworks, but file should still be removed)"
    else
        echo "   ✅ ${file} - not found (good)"
    fi
done

echo ""
if [ ${FOUND_ISSUES} -eq 0 ]; then
    echo "✅ No private framework links found"
    echo "   Bundle should pass App Store review"
    exit 0
else
    echo "❌ Found ${FOUND_ISSUES} issue(s) that need to be fixed"
    echo "   Run ./remove_ssl_modules.sh to remove problematic files"
    exit 1
fi

