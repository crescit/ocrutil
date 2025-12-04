#!/usr/bin/env bash

# Child Process Monitor - paddleocr-cli only
#
# Usage:
#   1. In one terminal, run this script:
#        ./sandbox-sniffer.sh
#   2. In another, run your sandboxed app / applet and reproduce the issue.
#   3. Watch this terminal for all events from paddleocr-cli child process.

# Don't use set -e here as it can cause issues with pipes

echo "=== Child Process Monitor: paddleocr-cli ==="
echo "Monitoring ONLY the paddleocr-cli child process"
echo ""
echo "Press Ctrl+C to stop."
echo "=========================================="
echo ""

# Function to categorize and display events
display_event() {
  local line="$1"
  local category="$2"
  
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🔍 [$category]"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "$line"
  echo ""
  
  # Analyze and provide suggestions for sandbox denies
  if echo "$line" | grep -qi "deny"; then
    echo "⚠️  SANDBOX VIOLATION DETECTED!"
    echo ""
    
    suggestion=""
    
    if echo "$line" | grep -qi "file-read-data"; then
      suggestion="📁 FILE READ DENIED
  Likely need:
  - com.apple.security.files.user-selected.read-only
  - com.apple.security.files.read-only (for app bundle access)"
    elif echo "$line" | grep -qi "file-write-data\|file-issue-extension"; then
      suggestion="📝 FILE WRITE DENIED
  Likely need:
  - com.apple.security.files.user-selected.read-write"
    elif echo "$line" | grep -qi "network-outbound"; then
      suggestion="🌐 NETWORK OUTBOUND DENIED
  Likely need: com.apple.security.network.client"
    elif echo "$line" | grep -qi "network-inbound"; then
      suggestion="🌐 NETWORK INBOUND DENIED
  Likely need: com.apple.security.network.server"
    elif echo "$line" | grep -qi "mach-lookup"; then
      suggestion="🔌 MACH LOOKUP DENIED
  Likely need: com.apple.security.temporary-exception.mach-lookup.global-name"
    elif echo "$line" | grep -qi "sysctl"; then
      suggestion="⚙️  SYSCTL DENIED
  May need: com.apple.security.temporary-exception.sysctl-by-name"
    elif echo "$line" | grep -qi "posix-sem\|shm"; then
      suggestion="🔗 POSIX IPC DENIED
  May need POSIX IPC entitlements"
    elif echo "$line" | grep -qi "process-exec"; then
      suggestion="🚀 PROCESS EXECUTION DENIED
  May need:
  - com.apple.security.cs.allow-jit
  - com.apple.security.cs.allow-unsigned-executable-memory
  - com.apple.security.cs.disable-library-validation"
    fi
    
    if [ -n "$suggestion" ]; then
      echo "💡 SUGGESTED FIX:"
      echo "$suggestion"
      echo ""
    fi
  fi
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
}

# Monitor ONLY paddleocr-cli process - ALL events
PREDICATE='process == "paddleocr-cli"'

echo "Starting monitor for paddleocr-cli process..."
echo "Capturing ALL events from this child process..."
echo ""

log stream --predicate "$PREDICATE" --style syslog --level debug 2>&1 | \
  while IFS= read -r line; do
    # Show ALL events from paddleocr-cli - no filtering
    # This includes: sandbox events, process lifecycle, library loading, etc.
    display_event "$line" "paddleocr-cli"
  done

