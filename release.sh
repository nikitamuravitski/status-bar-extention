#!/usr/bin/env bash
set -e

# 1. Build and tag in MAIN REPO
echo "Building project..."
./build.sh

# Fetch latest tags from origin
git fetch --tags origin
LATEST_TAG=$(git tag --list 'v[0-9]*.[0-9]*.[0-9]*' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n 1)

if [[ $LATEST_TAG =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  MAJOR="${BASH_REMATCH[1]}"
  MINOR="${BASH_REMATCH[2]}"
  PATCH="${BASH_REMATCH[3]}"
  NEXT_PATCH=$((PATCH + 1))
  SUGGESTED_VERSION="$MAJOR.$MINOR.$NEXT_PATCH"
else
  SUGGESTED_VERSION="1.0.0"
fi

echo "Latest release version tag: $LATEST_TAG"
read -e -i "$SUGGESTED_VERSION" -p "Enter new version: " VERSION
TAG="v$VERSION"

# Tag and push in MAIN REPO
git tag "$TAG"
git push origin "$TAG"

# Create a GitHub release and attach binaries
RELEASE_TITLE="Statusbar $VERSION"
RELEASE_BODY="Automated release for version $VERSION"

# Create the release (will fail if it already exists, so you may want to check)
gh release create "$TAG" \
  --title "$RELEASE_TITLE" \
  --notes "$RELEASE_BODY" \
  bin/statusbar bin/statusbar-bin

# Download tarball from MAIN REPO and calculate SHA256
TARBALL_URL="https://github.com/nikitamuravitski/status-bar-extention/archive/refs/tags/$TAG.tar.gz"
curl -L -o statusbar.tar.gz "$TARBALL_URL"
SHA256=$(shasum -a 256 statusbar.tar.gz | awk '{print $1}')
echo "SHA256: $SHA256"

# Update formula in TAP REPO
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

cd -
rm -f statusbar.tar.gz

echo "Release $TAG complete! Homebrew formula updated in tap repo and GitHub release created."