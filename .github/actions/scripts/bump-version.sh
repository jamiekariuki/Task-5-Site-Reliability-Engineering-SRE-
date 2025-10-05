#!/bin/bash
set -e

# Accept ENVIRONMENT and COMPONENT (default to dev + frontend)
ENVIRONMENT=${ENVIRONMENT:-dev}
COMPONENT=${COMPONENT:-app}

echo "Environment: $ENVIRONMENT"
echo "Component: $COMPONENT"

# 1. Fetch all tags
git fetch --tags

# 2. Get last tag for this env + component
LAST_TAG=$(git tag --sort=-v:refname | grep "^${ENVIRONMENT}-${COMPONENT}-v" | head -n1 || echo "")

if [ -z "$LAST_TAG" ]; then
  echo "No previous ${ENVIRONMENT}-${COMPONENT} tag found. Using all commits."
  COMMITS=$(git log HEAD --pretty=format:"%s")
else
  echo "Last ${ENVIRONMENT}-${COMPONENT} tag: $LAST_TAG"
  COMMITS=$(git log $LAST_TAG..HEAD --pretty=format:"%s")
fi

echo "Commits to analyze:"
echo "$COMMITS"

# 3. Decide bump type
if echo "$COMMITS" | grep -q "BREAKING CHANGE"; then
  BUMP="major"
elif echo "$COMMITS" | grep -q "^feat"; then
  BUMP="minor"
elif echo "$COMMITS" | grep -q "^fix"; then
  BUMP="patch"
else
  BUMP="patch"
fi
echo "Version bump: $BUMP"

# 4. Determine last tag version numbers (strip env + component prefix)
if [ -z "$LAST_TAG" ]; then
  MAJOR=0
  MINOR=0
  PATCH=0
else
  TAG_NO_ENV_COMP=${LAST_TAG#*-${COMPONENT}-}   # remove "dev-frontend-", "dev-backend-"
  IFS='.' read -r MAJOR MINOR PATCH <<< "${TAG_NO_ENV_COMP#v}"
fi

# 5. Increment version
case $BUMP in
  major) MAJOR=$((MAJOR+1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR+1)); PATCH=0 ;;
  patch) PATCH=$((PATCH+1)) ;;
esac

# 6. Compose new tag with environment + component prefix
NEW_TAG="${ENVIRONMENT}-${COMPONENT}-v$MAJOR.$MINOR.$PATCH"
echo "New version: $NEW_TAG"

# 7. Expose version to GitHub Actions
echo "version=$NEW_TAG" >> $GITHUB_OUTPUT
