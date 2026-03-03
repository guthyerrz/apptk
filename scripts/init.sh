#!/usr/bin/env bash
set -euo pipefail

# 1. Ensure JAVA_HOME is set
if [ -z "${JAVA_HOME:-}" ]; then
  export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))
fi

# 2. Neutralise Nix stdenv — these point to a Nix Apple SDK that conflicts
#    with the Swift 6.2 toolchain managed by swiftly.
unset SDKROOT DEVELOPER_DIR CC CXX NIX_CFLAGS_COMPILE NIX_LDFLAGS \
      MACOSX_DEPLOYMENT_TARGET NIX_APPLE_SDK_VERSION NIX_ENFORCE_PURITY

# 3. Source host swiftly env — puts swiftly-managed swift ahead of Nix tools on PATH
source "$HOME/.swiftly/env.sh"

# 4. Auto-install pinned Swift version from .swift-version if missing
if [ -f .swift-version ] && ! swiftly list 2>/dev/null | grep -q "$(cat .swift-version)"; then
  swiftly install --assume-yes
fi

# 5. Add project-local bin to PATH
mkdir -p "$PWD/bin"
export PATH="$PWD/bin:$PATH"

# 6. Doctor check
just doctor
