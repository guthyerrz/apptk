#!/bin/sh
set -euo pipefail

REPO="guthyerrz/apptk"
INSTALL_DIR="${HOME}/.local/bin"

echo "Fetching latest release..."
TAG=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name"' | sed -E 's/.*"tag_name":\s*"([^"]+)".*/\1/')

if [ -z "$TAG" ]; then
    echo "Error: could not determine latest release tag" >&2
    exit 1
fi

echo "Downloading apptk ${TAG}..."
mkdir -p "$INSTALL_DIR"
curl -fsSL "https://github.com/${REPO}/releases/download/${TAG}/apptk" -o "${INSTALL_DIR}/apptk"
chmod +x "${INSTALL_DIR}/apptk"

echo "Installed apptk ${TAG} to ${INSTALL_DIR}/apptk"

case ":${PATH}:" in
    *":${INSTALL_DIR}:"*) ;;
    *)
        echo ""
        echo "Add ~/.local/bin to your PATH:"
        echo '  export PATH="$HOME/.local/bin:$PATH"'
        ;;
esac
