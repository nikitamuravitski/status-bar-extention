#!/bin/bash
set -e

# 1. Build and tag in MAIN REPO
echo "Building project..."
./build.sh

PREV_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "none")
echo "Previous version: $PREV_TAG"
read -p "Enter new version (e.g., 1.0.3): " VERSION
TAG="v$VERSION"

git tag "$TAG"
git push origin "$TAG"

# 2. Download tarball and calculate SHA256
TARBALL_URL="https://github.com/nikitamuravitski/homebrew-statusbar/archive/refs/tags/$TAG.tar.gz"
curl -L -o statusbar.tar.gz "$TARBALL_URL"
SHA256=$(shasum -a 256 statusbar.tar.gz | awk '{print $1}')
echo "SHA256: $SHA256"

# 3. Update formula in TAP REPO
# (Assume you have the tap repo cloned locally, or clone it if not)
TAP_REPO_PATH="../homebrew-statusbar"  # Adjust as needed
FORMULA="$TAP_REPO_PATH/Formula/statusbar.rb"

if [ ! -f "$FORMULA" ]; then
  echo "Formula not found at $FORMULA"
  exit 1
fi

# 4. Update url and sha256 in the formula
sed -i '' "s|url \".*\"|url \"$TARBALL_URL\"|" "$FORMULA"
sed -i '' "s|sha256 \".*\"|sha256 \"$SHA256\"|" "$FORMULA"

# 5. Commit and push in TAP REPO
cd "$TAP_REPO_PATH"
git add Formula/statusbar.rb
git commit -m "Bump statusbar to $TAG"
git push

echo "Release $TAG complete! Homebrew formula updated in tap repo."