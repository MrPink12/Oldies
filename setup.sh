#!/usr/bin/env bash
# setup.sh — One-shot project setup for Oldies
# Run this once after cloning the repo:
#
#   chmod +x setup.sh && ./setup.sh
#
# What it does:
#   1. Checks for / installs Homebrew
#   2. Installs XcodeGen via Homebrew
#   3. Generates Oldies.xcodeproj from project.yml
#   4. Opens the project in Xcode

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║         Oldies – Project Setup               ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# ── 1. Homebrew ──────────────────────────────────────────────────────────────
if ! command -v brew &>/dev/null; then
    echo "→ Installing Homebrew…"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add brew to PATH for Apple Silicon
    if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
else
    echo "✓ Homebrew already installed ($(brew --version | head -1))"
fi

# ── 2. XcodeGen ──────────────────────────────────────────────────────────────
if ! command -v xcodegen &>/dev/null; then
    echo "→ Installing XcodeGen…"
    brew install xcodegen
else
    echo "✓ XcodeGen already installed ($(xcodegen --version))"
fi

# ── 3. Generate .xcodeproj ───────────────────────────────────────────────────
echo ""
echo "→ Generating Oldies.xcodeproj from project.yml…"
xcodegen generate --spec project.yml
echo "✓ Oldies.xcodeproj generated"

# ── 4. Open in Xcode ─────────────────────────────────────────────────────────
echo ""
echo "→ Opening in Xcode…"
open Oldies.xcodeproj

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  Done! Next steps in Xcode:                  ║"
echo "║                                              ║"
echo "║  1. Select your iPhone as the run target     ║"
echo "║  2. Build & run (⌘R)                         ║"
echo "║  3. If signing fails: Xcode → Signing &      ║"
echo "║     Capabilities → Team: WU26G28D5P          ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
