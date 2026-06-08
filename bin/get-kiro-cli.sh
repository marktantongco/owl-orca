#!/usr/bin/env bash
set -euo pipefail

KIRO_DIR="$(cd "$(dirname "$0")" && pwd)"
ARCH=$(uname -m)

case "$ARCH" in
    x86_64)  TRIPLE="x86_64-unknown-linux-gnu" ;;
    aarch64) TRIPLE="aarch64-unknown-linux-gnu" ;;
    *)       echo "Unsupported arch: $ARCH"; exit 1 ;;
esac

if ldd --version 2>&1 | grep -qi "musl"; then
    TRIPLE="${TRIPLE%-gnu}-musl"
fi

MANIFEST_URL="https://prod.download.cli.kiro.dev/stable/latest/manifest.json"
echo "Fetching manifest from $MANIFEST_URL"
MANIFEST=$(curl -sfL "$MANIFEST_URL") || {
    echo "ERROR: Failed to fetch manifest from $MANIFEST_URL"
    exit 1
}

DOWNLOAD_PATH=$(echo "$MANIFEST" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for pkg in data['packages']:
    if pkg.get('targetTriple') == '$TRIPLE' and pkg.get('fileType') == 'tarGz' and pkg.get('variant') == 'headless':
        print(pkg['download'])
        sys.exit(0)
print('', end='')
sys.exit(1)
") || {
    echo "ERROR: No download found for $TRIPLE"
    exit 1
}

BASE_URL="https://prod.download.cli.kiro.dev/stable"
URL="$BASE_URL/$DOWNLOAD_PATH"
TMP_TAR="/tmp/kiro-cli-$$.tar.gz"

echo "Downloading kiro-cli ($TRIPLE)..."
curl -fSL --connect-timeout 15 --progress-bar -o "$TMP_TAR" "$URL" || {
    echo "ERROR: Download failed from $URL"
    exit 1
}

echo "Extracting..."
tar -xzf "$TMP_TAR" -C "$KIRO_DIR/"
KIRO_BIN=$(find "$KIRO_DIR" -name "kiro-cli" -type f 2>/dev/null | head -1)
if [ -n "$KIRO_BIN" ]; then
    chmod +x "$KIRO_BIN"
    ln -sf "$KIRO_BIN" "$HOME/.local/bin/kiro-cli"
    for wrapper in kiro-cli-chat kiro-cli-term q qchat; do
        WRAPPER_PATH=$(find "$KIRO_DIR" -name "$wrapper" -type f 2>/dev/null | head -1)
        [ -n "$WRAPPER_PATH" ] && ln -sf "$WRAPPER_PATH" "$HOME/.local/bin/$wrapper" 2>/dev/null || true
    done
    echo "kiro-cli installed at $KIRO_BIN (symlinked to ~/.local/bin/)"
else
    echo "WARNING: kiro-cli binary not found after extraction"
    echo "Files extracted to $KIRO_DIR/kirocli/"
fi
rm -f "$TMP_TAR"
