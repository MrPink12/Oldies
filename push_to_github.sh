#!/usr/bin/env bash
# push_to_github.sh
# Initialises git (if needed), stages all files, and pushes to MrPink12/Oldies.
# Run once from this directory:
#   cd "Meta Glasses/Oldies" && chmod +x push_to_github.sh && ./push_to_github.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Configure identity if not already set
git config --global user.email 2>/dev/null || git config --global user.email "peter.t.hagstrom@gmail.com"
git config --global user.name  2>/dev/null || git config --global user.name  "Peter Hagström"

# Init repo if needed
if [ ! -d ".git" ]; then
    git init
    git branch -m main
fi

# Set remote
git remote remove origin 2>/dev/null || true
git remote add origin https://github.com/MrPink12/Oldies.git

# Try to pull existing history so we don't lose it
git fetch origin main 2>/dev/null && git reset --soft origin/main 2>/dev/null || true

# Stage all new/changed files
git add \
    Sources/ \
    project.yml \
    setup.sh \
    .gitignore \
    README.md

git status

# Commit
git commit -m "$(cat <<'EOF'
feat: complete Oldies iOS app — Swedish AI assistant for Meta Ray-Ban glasses

- Full MVVM SwiftUI app (iOS 17+)
- Multi-provider AI: OpenAI GPT-4o, Anthropic Claude, Ollama (self-hosted)
- Swedish STT (SFSpeechRecognizer sv-SE) + TTS (AVSpeechSynthesizer, Alva voice)
- Meta Wearables DAT integration (camera stream, photo capture, registration)
- 4-step onboarding flow
- Settings: API keys, model picker, system prompt editor
- XcodeGen project.yml + setup.sh for one-command project generation

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"

# Push
git push -u origin main

echo ""
echo "✓ Pushed to https://github.com/MrPink12/Oldies"
