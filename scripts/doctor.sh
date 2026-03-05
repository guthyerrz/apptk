#!/usr/bin/env bash
set -euo pipefail

SWIFT_MIN="6.2"
PASS="\033[32m✓\033[0m"
FAIL="\033[31m✗\033[0m"
WARN="\033[33m⚠\033[0m"
errors=0

check_just() {
  if ! command -v just &> /dev/null; then
    echo -e "$FAIL just: not found"
    errors=$((errors + 1))
  else
    echo -e "$PASS $(just --version)"
  fi
}

check_swiftly() {
  if ! command -v swiftly &> /dev/null; then
    echo -e "$FAIL swiftly: not found"
    errors=$((errors + 1))
    swiftly_help
    return
  fi
  echo -e "$PASS swiftly $(swiftly --version 2>&1 | head -1)"
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

check_nix_vars() {
  local nix_vars=(SDKROOT DEVELOPER_DIR CC CXX NIX_CFLAGS_COMPILE NIX_LDFLAGS)
  local leaked=()
  for var in "${nix_vars[@]}"; do
    if [ -n "${!var:-}" ]; then
      leaked+=("$var")
    fi
  done
  if [ ${#leaked[@]} -gt 0 ]; then
    echo -e "$WARN Nix stdenv vars still set: ${leaked[*]}"
    echo "  These may conflict with the swiftly-managed Swift toolchain."
    echo "  Try exiting and re-entering devbox shell."
  else
    echo -e "$PASS Nix stdenv vars neutralised"
  fi
}

swiftly_help() {
  echo ""
  echo "  swiftly must be installed on your host machine."
  echo "  Install it from: https://www.swift.org/install/"
  echo ""
}

swift_help() {
  echo ""
  echo "  apptk requires Swift >= $SWIFT_MIN, managed by swiftly."
  echo "  The pinned version is read from .swift-version."
  echo ""
  echo "  Install it with: swiftly install"
  echo ""
}

echo "Checking apptk development environment..."
echo ""
check_just
check_swiftly
check_swift
check_nix_vars
echo ""

if [ "$errors" -gt 0 ]; then
  echo -e "\033[31m$errors problem(s) found.\033[0m"
  exit 1
else
  echo "All good!"
fi
