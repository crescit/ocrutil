#!/bin/bash
# Script to build Python 3.9 without SSL/hashlib support for App Store compliance
# This creates a "safe" Python build that doesn't link against private macOS frameworks

set -e

PYTHON_VERSION="3.9.18"
PYTHON_SOURCE_DIR="/tmp/Python-${PYTHON_VERSION}"
PYTHON_INSTALL_DIR="/tmp/python39_app"
BUILD_DIR="/tmp/python39_build"

echo "🔧 Building Python ${PYTHON_VERSION} without SSL/hashlib support..."
echo "   This will take several minutes..."

# Clean up any previous builds
if [ -d "${PYTHON_INSTALL_DIR}" ]; then
    echo "   Cleaning previous installation..."
    rm -rf "${PYTHON_INSTALL_DIR}"
fi

if [ -d "${BUILD_DIR}" ]; then
    echo "   Cleaning previous build..."
    rm -rf "${BUILD_DIR}"
fi

# Download Python source if not present
if [ ! -d "${PYTHON_SOURCE_DIR}" ]; then
    echo "📥 Downloading Python ${PYTHON_VERSION} source..."
    cd /tmp
    if [ ! -f "Python-${PYTHON_VERSION}.tgz" ]; then
        curl -L -o "Python-${PYTHON_VERSION}.tgz" "https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz"
    fi
    tar -xzf "Python-${PYTHON_VERSION}.tgz"
fi

# Configure Python build (NO SSL)
echo "⚙️  Configuring Python build (no SSL, no ensurepip)..."
cd "${PYTHON_SOURCE_DIR}"

./configure \
    --prefix="${PYTHON_INSTALL_DIR}" \
    --enable-optimizations \
    --without-ensurepip \
    --with-openssl=no \
    CPPFLAGS="-DOPENSSL_NO_SSL3 -DOPENSSL_NO_TLS1" \
    LDFLAGS=""

# Build Python
echo "🔨 Building Python (this will take 5-10 minutes)..."
make -j$(sysctl -n hw.ncpu)

# Install Python
echo "📦 Installing Python..."
make install

# Verify SSL is disabled
echo ""
echo "🧪 Verifying SSL is disabled..."
if "${PYTHON_INSTALL_DIR}/bin/python3.9" -c "import ssl" 2>&1 | grep -q "No module named '_ssl'"; then
    echo "   ✅ SSL module correctly disabled"
else
    echo "   ❌ ERROR: SSL module still available!"
    exit 1
fi

# Verify hashlib works (but without OpenSSL backend)
echo "🧪 Testing hashlib (should work with builtin modules only)..."
"${PYTHON_INSTALL_DIR}/bin/python3.9" -c "import hashlib; print('hashlib available:', hashlib.algorithms_available)" || true

echo ""
echo "✅ Python ${PYTHON_VERSION} built successfully without SSL support"
echo "   Installation directory: ${PYTHON_INSTALL_DIR}"
echo ""
echo "📝 Next steps:"
echo "   1. Create a virtual environment using this Python:"
echo "      ${PYTHON_INSTALL_DIR}/bin/python3.9 -m venv /path/to/venv"
echo "   2. Install PaddleOCR and dependencies in that venv"
echo "   3. Rebuild with PyInstaller using that venv's Python"
echo "   4. The new bundle will not include _ssl or _hashlib modules"


