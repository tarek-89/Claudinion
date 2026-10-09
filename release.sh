#!/usr/bin/env bash
# Builds Claudinion and packages it as build/Claudinion.zip for a GitHub Release.
# Pass --publish to also create the release with the GitHub CLI (gh), tagged v<VERSION>.
#
# Releasing a new version:
#   1. Bump the number in VERSION (for example 1.0.0 -> 1.1.0) and commit/push.
#   2. ./release.sh --publish
# Installed copies of Claudinion will offer the update within a day (or right away via Check for Updates).
set -euo pipefail
cd "$(dirname "$0")"

VERSION="$(tr -d '[:space:]' < VERSION)"
TAG="v$VERSION"

./build.sh
rm -f build/Claudinion.zip
ditto -c -k --keepParent build/Claudinion.app build/Claudinion.zip
echo "Packaged build/Claudinion.zip ($TAG)"

if [[ "${1:-}" == "--publish" ]]; then
    if ! command -v gh >/dev/null; then
        echo "The GitHub CLI (gh) is needed to publish: https://cli.github.com" >&2
        exit 1
    fi
    gh release create "$TAG" build/Claudinion.zip --title "Claudinion $VERSION" --generate-notes
    echo "Published $TAG"
else
    echo "To publish:  gh release create $TAG build/Claudinion.zip --title \"Claudinion $VERSION\" --generate-notes"
fi
