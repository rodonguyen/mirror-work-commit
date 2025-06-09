#!/usr/bin/env bash
set -euo pipefail

echo "Starting mirror script..."

# Required environment variables
WORK_PAT="${WORK_PAT:?}"
WORK_LOGIN="${WORK_LOGIN:?}"
AUTHOR_NAME="rodo"
AUTHOR_EMAIL="rodonguyendd@gmail.com"
DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"
STATE=mirror_state.json

echo "Configuring git user..."
git config user.name  "$AUTHOR_NAME"
git config user.email "$AUTHOR_EMAIL"

# 1. Get last recorded total from state file
echo "Reading previous state..."
if [[ ! -f "$STATE" ]]; then
  echo "No state file found, creating new one..."
  jq -n --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" --argjson tot 0 '{timestamp:$ts,total:$tot}' > "$STATE"
  echo "Created state file with contents:"
  cat "$STATE"
  git add "$STATE"
  git commit -m "chore: initialize state file" || true
fi

LAST_TOTAL=$(jq -r '.total // 0' "$STATE" 2>/dev/null || echo 0)
echo "Last recorded total: $LAST_TOTAL"
echo "Current state file contents:"
cat "$STATE"

# 2. Fetch current commit count from GitHub API
echo "Fetching commit count from GitHub..."
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
SINCE=$(jq -r '.timestamp' "$STATE" 2>/dev/null || echo "1970-01-01T00:00:00Z")

read -r TOTAL <<<"$(curl -s -H "Authorization: Bearer $WORK_PAT" \
  -H "Content-Type: application/json" \
  -d @- https://api.github.com/graphql <<EOF | jq -r '.data.user.contributionsCollection.totalCommitContributions // 0'
{ "query": "query(\$login:String!,\$from:DateTime!,\$to:DateTime!){ user(login:\$login){ contributionsCollection(from:\$from,to:\$to){ totalCommitContributions }}}",
  "variables": { "login": "$WORK_LOGIN", "from": "$SINCE", "to": "$NOW" } }
EOF
)"

# Validate API response
if ! [[ "$TOTAL" =~ ^[0-9]+$ ]]; then
  echo "Error: Failed to fetch total commit contributions from GitHub API."
  exit 1
fi

echo "Current commit count: $TOTAL"

# Calculate difference and check if there are new commits
DELTA=$(( TOTAL - LAST_TOTAL ))
if [[ $DELTA -le 0 ]]; then 
  echo "No new commits to mirror."
  exit 0
fi

# 3. Create mirror commits
echo "Creating $DELTA mirror commits..."
for ((i=0;i<DELTA;i++)); do
  git commit --allow-empty -m "work-mirror bump"
done

# 4. Update state file and push changes
echo "Updating state file and pushing changes..."
if ! jq -n --arg ts "$NOW" --argjson tot "$TOTAL" '{timestamp:$ts,total:$tot}' > "$STATE"; then
  echo "Error: Failed to update state file"
  exit 1
fi

echo "Updated state file contents:"
cat "$STATE"

git add "$STATE"
git commit -m "chore: mirror state"
echo "Pushing changes to $DEFAULT_BRANCH..."
if git push origin HEAD:"$DEFAULT_BRANCH" --force-with-lease; then
  echo "Successfully pushed changes"
else
  echo "Failed to push changes"
  exit 1
fi

echo "Mirror script completed successfully."
