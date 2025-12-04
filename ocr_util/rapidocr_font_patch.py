"""
Patch for RapidOCR to redirect font copy operations to writable locations.
This script monkey-patches shutil.copy and shutil.copy2 to intercept font copies.
"""
import os
import shutil
from pathlib import Path

# Get the writable models directory from environment
RAPIDOCR_MODELS_DIR = os.environ.get("RAPIDOCR_MODELS_DIR")
RAPIDOCR_FONT_DIR = os.environ.get("RAPIDOCR_FONT_DIR", RAPIDOCR_MODELS_DIR)

# Store original functions
_original_copy = shutil.copy
_original_copy2 = shutil.copy2

def _patched_copy(src, dst, *args, **kwargs):
    """Patched shutil.copy that redirects font copies to writable location."""
    dst_path = Path(dst)
    
    # Check if this is a font copy to the bundle's models directory
    if '_internal' in str(dst_path) and 'rapidocr/models' in str(dst_path) and dst_path.suffix.lower() in ['.ttf', '.ttc']:
        # Redirect to writable location
        if RAPIDOCR_FONT_DIR:
            font_name = dst_path.name
            writable_path = Path(RAPIDOCR_FONT_DIR) / font_name
            try:
                # Copy to writable location instead
                return _original_copy(src, str(writable_path), *args, **kwargs)
            except Exception:
                # If that fails, try original location (will fail but at least we tried)
                pass
    
    # For all other cases, use original
    return _original_copy(src, dst, *args, **kwargs)

def _patched_copy2(src, dst, *args, **kwargs):
    """Patched shutil.copy2 that redirects font copies to writable location."""
    dst_path = Path(dst)
    
    # Check if this is a font copy to the bundle's models directory
    if '_internal' in str(dst_path) and 'rapidocr/models' in str(dst_path) and dst_path.suffix.lower() in ['.ttf', '.ttc']:
        # Redirect to writable location
        if RAPIDOCR_FONT_DIR:
            font_name = dst_path.name
            writable_path = Path(RAPIDOCR_FONT_DIR) / font_name
            try:
                # Copy to writable location instead
                return _original_copy2(src, str(writable_path), *args, **kwargs)
            except Exception:
                # If that fails, try original location (will fail but at least we tried)
                pass
    
    # For all other cases, use original
    return _original_copy2(src, dst, *args, **kwargs)

# Patch shutil functions
shutil.copy = _patched_copy
shutil.copy2 = _patched_copy2

