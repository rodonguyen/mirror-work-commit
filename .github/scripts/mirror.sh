#!/usr/bin/env bash
set -euo pipefail
echo "Starting mirror script..."

# Required environment variables
WORK_PAT="${WORK_PAT:?}"
WORK_LOGIN="${WORK_LOGIN:?}"
AUTHOR_NAME="rodo"
AUTHOR_EMAIL="rodonguyendd@gmail.com"
DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"

echo "Configuring git user..."
git config user.name  "$AUTHOR_NAME"
git config user.email "$AUTHOR_EMAIL"

# 2. Fetch current commit count from GitHub API
echo ""
echo "Fetching commit count from GitHub..."
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
# Set SINCE to 24 hours ago (using GNU date format for Linux)
SINCE=$(date -u -d "24 hours ago" +"%Y-%m-%dT%H:%M:%SZ")
echo "Fetching commits from $SINCE to $NOW"

# Make API request and capture full response
API_RESPONSE=$(curl -s -H "Authorization: Bearer $WORK_PAT" \
  -H "Content-Type: application/json" \
  -d @- https://api.github.com/graphql <<EOF
{ "query": "query(\$login:String!,\$from:DateTime!,\$to:DateTime!){ user(login:\$login){ contributionsCollection(from:\$from,to:\$to){ totalCommitContributions }}}",
  "variables": { "login": "$WORK_LOGIN", "from": "$SINCE", "to": "$NOW" } }
EOF
)

echo "Raw API Response:"
echo "$API_RESPONSE"

# Extract total from response
read -r TOTAL <<<"$(echo "$API_RESPONSE" | jq -r '.data.user.contributionsCollection.totalCommitContributions // 0')"

# Validate API response
if ! [[ "$TOTAL" =~ ^[0-9]+$ ]]; then
  echo "Error: Failed to fetch total commit contributions from GitHub API."
  exit 1
fi

echo "Current commit count: $TOTAL"

# 3. Create mirror commits
echo "Creating $TOTAL mirror commits..."
for ((i=0;i<2;i++)); do
  git commit --allow-empty -m "work-mirror bump"
done


git commit -m "chore: mirror state"
echo "Pushing changes to $DEFAULT_BRANCH..."
if git push origin HEAD:"$DEFAULT_BRANCH" --force-with-lease; then
  echo "Successfully pushed changes"
else
  echo "Failed to push changes"
  exit 1
fi

echo "Mirror script completed successfully."
