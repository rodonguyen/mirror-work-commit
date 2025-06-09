#!/usr/bin/env bash
set -euo pipefail
echo "Starting mirror script..."

# Required environment variables
WORK_PAT="${WORK_PAT:?}"
WORK_LOGIN="${WORK_LOGIN:?}"
PERSONAL_PAT="${PERSONAL_PAT:?}"
AUTHOR_NAME="rodo"
AUTHOR_EMAIL="rodonguyendd@gmail.com"

echo "Configuring git user..."
git config user.name  "$AUTHOR_NAME"
git config user.email "$AUTHOR_EMAIL"

# Configure git to use personal token for authentication
echo "Configuring git authentication..."
git remote set-url origin "https://x-access-token:${PERSONAL_PAT}@github.com/rodonguyen/mirror-work-commit.git"

# --------------------------------------------
# 1. Fetch current commit count from GitHub API
echo "Fetching commit count from GitHub..."
SINCE=$(date -u -d "24 hours ago" +"%Y-%m-%dT%H:%M:%SZ")
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "Fetching commits from $SINCE to $NOW"

Q="author:$WORK_LOGIN committer-date:$SINCE..$NOW"
ENCODED=$(jq -rn --arg q "$Q" '$q|@uri')

TOTAL=$(curl -s \
  -H "Authorization: Bearer $WORK_PAT" \
  -H "Accept: application/vnd.github.cloak-preview+json" \
  "https://api.github.com/search/commits?q=$ENCODED&per_page=1" |
  jq '.total_count')

echo "Commits in the last 24 h across all repos: $TOTAL"

# 1.1. Validate API response
if ! [[ "$TOTAL" =~ ^[0-9]+$ ]]; then
  echo "Error: Failed to fetch total commit contributions from GitHub API."
  exit 1
fi

# 1.2. Sanity check
echo "Sanity check"
echo "Current branch:"
git branch
echo "Current commit:"
git log -1

# --------------------------------------------
# 2. Create mirror commits
echo "Creating $TOTAL mirror commits..."
for ((i=0;i<TOTAL;i++)); do
  git commit --allow-empty -m "< mirror work commits $((i+1)) >"
done

# --------------------------------------------
# 3. Push changes
echo "Pushing changes to main..."
git push origin HEAD:main --force-with-lease || {
  echo "Failed to push changes"
  exit 1
}

echo "Mirror script completed successfully."
