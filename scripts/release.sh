#!/usr/bin/env bash
set -euo pipefail

# ── Usage ─────────────────────────────────────────────────────────────────────

usage() {
    cat <<EOF
Usage: $(basename "$0") <--major | --minor | --patch | --alpha>

Bump the version, generate changelog, tag (signed), push, and create a GitHub Release.

Flags:
  --major   Bump major version (e.g. 0.3.0 → 1.0.0)
  --minor   Bump minor version (e.g. 0.3.0 → 0.4.0)
  --patch   Bump patch version or promote alpha (e.g. 0.3.0-alpha.3 → 0.3.0)
  --alpha   Next alpha (e.g. 0.3.0-alpha.3 → 0.3.0-alpha.4, or 0.3.0 → 0.4.0-alpha.0)
EOF
    exit 1
}

# ── Parse arguments ───────────────────────────────────────────────────────────

BUMP=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --major) [[ -n "$BUMP" ]] && { echo "Error: only one bump flag allowed."; exit 1; }; BUMP="major" ;;
        --minor) [[ -n "$BUMP" ]] && { echo "Error: only one bump flag allowed."; exit 1; }; BUMP="minor" ;;
        --patch) [[ -n "$BUMP" ]] && { echo "Error: only one bump flag allowed."; exit 1; }; BUMP="patch" ;;
        --alpha) [[ -n "$BUMP" ]] && { echo "Error: only one bump flag allowed."; exit 1; }; BUMP="alpha" ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
    shift
done

[[ -z "$BUMP" ]] && usage

# ── Precondition checks ──────────────────────────────────────────────────────

if ! command -v gh &>/dev/null; then
    echo "Error: gh CLI is not installed. Install it from https://cli.github.com"
    exit 1
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$BRANCH" != "master" ]]; then
    echo "Error: must be on master branch (currently on $BRANCH)."
    exit 1
fi

if [[ -n $(git status --porcelain) ]]; then
    echo "Error: working tree is not clean. Commit or stash changes first."
    exit 1
fi

git fetch origin master --quiet
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/master)
if [[ "$LOCAL" != "$REMOTE" ]]; then
    echo "Error: master is not up to date with origin/master."
    echo "  Local:  $LOCAL"
    echo "  Remote: $REMOTE"
    exit 1
fi

if git describe --exact-match HEAD &>/dev/null; then
    EXISTING_TAG=$(git describe --exact-match HEAD)
    echo "Error: HEAD is already tagged as $EXISTING_TAG."
    exit 1
fi

# ── Parse latest tag ─────────────────────────────────────────────────────────

LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

if [[ -z "$LATEST_TAG" ]]; then
    echo "Error: no existing tags found. Create an initial tag first (e.g. git tag -s 0.1.0 -m '0.1.0')."
    exit 1
fi

# Validate tag format
if [[ ! "$LATEST_TAG" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(-alpha\.([0-9]+))?$ ]]; then
    echo "Error: latest tag '$LATEST_TAG' does not match expected format (X.Y.Z or X.Y.Z-alpha.N)."
    exit 1
fi

MAJOR="${BASH_REMATCH[1]}"
MINOR="${BASH_REMATCH[2]}"
PATCH="${BASH_REMATCH[3]}"
IS_ALPHA="${BASH_REMATCH[4]}"
ALPHA_NUM="${BASH_REMATCH[5]}"

# Check there are commits since last tag
COMMIT_COUNT=$(git rev-list "$LATEST_TAG"..HEAD --count)
if [[ "$COMMIT_COUNT" -eq 0 ]]; then
    echo "Error: no new commits since $LATEST_TAG."
    exit 1
fi

# ── Compute next version ─────────────────────────────────────────────────────

case "$BUMP" in
    major)
        NEXT_VERSION="$((MAJOR + 1)).0.0"
        ;;
    minor)
        NEXT_VERSION="$MAJOR.$((MINOR + 1)).0"
        ;;
    patch)
        if [[ -n "$IS_ALPHA" ]]; then
            # Promote alpha to stable
            NEXT_VERSION="$MAJOR.$MINOR.$PATCH"
        else
            NEXT_VERSION="$MAJOR.$MINOR.$((PATCH + 1))"
        fi
        ;;
    alpha)
        if [[ -n "$IS_ALPHA" ]]; then
            NEXT_VERSION="$MAJOR.$MINOR.$PATCH-alpha.$((ALPHA_NUM + 1))"
        else
            NEXT_VERSION="$MAJOR.$((MINOR + 1)).0-alpha.0"
        fi
        ;;
esac

echo "Releasing: $LATEST_TAG → $NEXT_VERSION"
echo ""

# ── Generate changelog ────────────────────────────────────────────────────────

TODAY=$(date +%Y-%m-%d)

# Collect commit messages (exclude merge commits)
COMMITS=$(git log "$LATEST_TAG"..HEAD --no-merges --format="%s")

ADDED=""
CHANGED=""
FIXED=""
OTHER=""

while IFS= read -r msg; do
    [[ -z "$msg" ]] && continue
    case "$msg" in
        Add\ *|Add:\ *)
            ADDED+="- $msg"$'\n'
            ;;
        Replace\ *|Refactor\ *|Update\ *|Redefine\ *|Simplify\ *|Remove\ *|Keep\ *|Rename\ *)
            CHANGED+="- $msg"$'\n'
            ;;
        Fix\ *|Fix:\ *)
            FIXED+="- $msg"$'\n'
            ;;
        *)
            OTHER+="- $msg"$'\n'
            ;;
    esac
done <<< "$COMMITS"

# Build the changelog section
SECTION="## [$NEXT_VERSION] - $TODAY"$'\n'

if [[ -n "$ADDED" ]]; then
    SECTION+=$'\n'"### Added"$'\n'
    SECTION+="$ADDED"
fi

if [[ -n "$CHANGED" ]]; then
    SECTION+=$'\n'"### Changed"$'\n'
    SECTION+="$CHANGED"
fi

if [[ -n "$FIXED" ]]; then
    SECTION+=$'\n'"### Fixed"$'\n'
    SECTION+="$FIXED"
fi

if [[ -n "$OTHER" ]]; then
    SECTION+=$'\n'"### Other"$'\n'
    SECTION+="$OTHER"
fi

# Update CHANGELOG.md
CHANGELOG="CHANGELOG.md"

if [[ -f "$CHANGELOG" ]]; then
    # Insert after the "# Changelog" header
    HEADER_LINE=$(grep -n "^# Changelog" "$CHANGELOG" | head -1 | cut -d: -f1)
    if [[ -n "$HEADER_LINE" ]]; then
        {
            head -n "$HEADER_LINE" "$CHANGELOG"
            echo ""
            echo "$SECTION"
            tail -n +"$((HEADER_LINE + 1))" "$CHANGELOG"
        } > "${CHANGELOG}.tmp"
        mv "${CHANGELOG}.tmp" "$CHANGELOG"
    else
        echo "Warning: could not find '# Changelog' header. Prepending section."
        {
            echo "# Changelog"
            echo ""
            echo "$SECTION"
            echo ""
            cat "$CHANGELOG"
        } > "${CHANGELOG}.tmp"
        mv "${CHANGELOG}.tmp" "$CHANGELOG"
    fi
else
    {
        echo "# Changelog"
        echo ""
        echo "$SECTION"
    } > "$CHANGELOG"
fi

echo "Updated $CHANGELOG"

# ── Commit, tag, push ────────────────────────────────────────────────────────

git add "$CHANGELOG"
git commit -m "Release $NEXT_VERSION"
git tag -s "$NEXT_VERSION" -m "$NEXT_VERSION"

echo "Pushing to origin..."
git push origin master
git push origin "$NEXT_VERSION"

# ── Create GitHub Release ────────────────────────────────────────────────────

if [[ "$NEXT_VERSION" == *"-alpha"* ]]; then
    gh release create "$NEXT_VERSION" --title "$NEXT_VERSION" --generate-notes --prerelease
else
    gh release create "$NEXT_VERSION" --title "$NEXT_VERSION" --generate-notes
fi

echo ""
echo "Released $NEXT_VERSION"
