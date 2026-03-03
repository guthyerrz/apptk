#!/usr/bin/env bash
set -euo pipefail

SWIFT_MIN="6.2"
JAVA_MIN="17"
PASS="\033[32m✓\033[0m"
FAIL="\033[31m✗\033[0m"
errors=0

check_java() {
  if ! command -v java &> /dev/null; then
    echo -e "$FAIL java: not found"
    errors=$((errors + 1))
    return
  fi

  java_ver=$(java -version 2>&1 | sed -n 's/.*version "\([0-9]*\).*/\1/p')
  if [ -z "$java_ver" ] || [ "$java_ver" -lt "$JAVA_MIN" ]; then
    echo -e "$FAIL java: found $java_ver, need >= $JAVA_MIN"
    errors=$((errors + 1))
  else
    echo -e "$PASS java $(java -version 2>&1 | head -1)"
  fi
}

check_java_home() {
  if [ -z "${JAVA_HOME:-}" ]; then
    echo -e "$FAIL JAVA_HOME: not set"
    errors=$((errors + 1))
  else
    echo -e "$PASS JAVA_HOME=$JAVA_HOME"
  fi
}

check_just() {
  if ! command -v just &> /dev/null; then
    echo -e "$FAIL just: not found"
    errors=$((errors + 1))
  else
    echo -e "$PASS $(just --version)"
  fi
}

check_swift() {
  if ! command -v swift &> /dev/null; then
    echo -e "$FAIL swift: not found"
    errors=$((errors + 1))
    swift_help
    return
  fi

  swift_ver=$(swift --version 2>&1 | sed -n 's/.*Swift version \([0-9]*\.[0-9]*\).*/\1/p')
  if [ -z "$swift_ver" ] || [ "$(printf '%s\n' "$SWIFT_MIN" "$swift_ver" | sort -V | head -1)" != "$SWIFT_MIN" ]; then
    echo -e "$FAIL swift: found $swift_ver, need >= $SWIFT_MIN"
    errors=$((errors + 1))
    swift_help
  else
    echo -e "$PASS swift $(swift --version 2>&1 | head -1)"
  fi
}

swift_help() {
  echo ""
  echo "  apptk requires Swift >= $SWIFT_MIN (provided by Xcode 26+)."
  echo ""
  echo "  To install using xcodes:"
  echo "    brew install xcodesorg/made/xcodes"
  echo "    xcodes install 26"
  echo "    xcodes select 26"
  echo ""
  echo "  Or install Xcode 26+ from the App Store."
}

echo "Checking apptk development environment..."
echo ""
check_java
check_java_home
check_just
check_swift
echo ""

if [ "$errors" -gt 0 ]; then
  echo -e "\033[31m$errors problem(s) found.\033[0m"
  exit 1
else
  echo "All good!"
fi
