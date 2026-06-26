#!/bin/bash
# Configure iOS code signing after adding Apple ID in Xcode.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
TEAM_FILE="$ROOT/Flutter/DevelopmentTeam.xcconfig"

echo "Checking for code signing identities..."
if ! security find-identity -v -p codesigning 2>/dev/null | grep -q "Apple Development"; then
  echo ""
  echo "No Apple Development certificate found."
  echo "1. Open Xcode → Settings (⌘,) → Accounts"
  echo "2. Click + → Apple ID → sign in"
  echo "3. Select your account → Manage Certificates → + → Apple Development"
  echo "4. Run this script again"
  echo ""
  open -a Xcode "$ROOT/Runner.xcworkspace"
  exit 1
fi

echo "Opening Xcode — select your Team on Runner → Signing & Capabilities,"
echo "then note the 10-character Team ID and enter it below."
echo ""
read -r -p "Team ID (e.g. AB12CD34EF): " TEAM_ID

if [[ ! "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]]; then
  echo "Invalid Team ID. It must be exactly 10 letters/numbers."
  exit 1
fi

cat > "$TEAM_FILE" <<EOF
DEVELOPMENT_TEAM=$TEAM_ID
EOF

echo "Saved Team ID to Flutter/DevelopmentTeam.xcconfig"
echo "Run: cd frontend && flutter run"
