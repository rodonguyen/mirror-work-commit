#!/usr/bin/env bash
set -euo pipefail

WORK_PAT="${WORK_PAT:?}"
WORK_LOGIN="${WORK_LOGIN:?}"
AUTHOR_NAME="rodo"
AUTHOR_EMAIL="rodonguyendd@gmail.com"
DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"
STATE=.mirror_state.json

git config user.name  "$AUTHOR_NAME"
git config user.email "$AUTHOR_EMAIL"

# 1. Last total we recorded
LAST_TOTAL=$(jq -r '.total // 0' "$STATE" 2>/dev/null || echo 0)

# 2. Ask GitHub how many commits the work user has made since last run
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
SINCE=$(jq -r '.timestamp' "$STATE" 2>/dev/null || echo "1970-01-01T00:00:00Z")

read -r TOTAL <<<"$(curl -s -H "Authorization: Bearer $WORK_PAT" \
  -H "Content-Type: application/json" \
  -d @- https://api.github.com/graphql <<EOF | jq -r '.data.user.contributionsCollection.totalCommitContributions // 0'
{ "query": "query(\$login:String!,\$from:DateTime!,\$to:DateTime!){ user(login:\$login){ contributionsCollection(from:\$from,to:\$to){ totalCommitContributions }}}",
  "variables": { "login": "$WORK_LOGIN", "from": "$SINCE", "to": "$NOW" } }
EOF
)"

# Ensure TOTAL is a valid integer
if ! [[ "$TOTAL" =~ ^[0-9]+$ ]]; then
  echo "Failed to fetch total commit contributions from GitHub API."
  exit 1
fi

echo "Commit count: $TOTAL"

DELTA=$(( TOTAL - LAST_TOTAL ))
[[ $DELTA -le 0 ]] && { echo "Nothing new."; exit 0; }

# 3. Forge the same number of empty commits
for ((i=0;i<DELTA;i++)); do
  git commit --allow-empty -m "work-mirror bump"
done

# 4. Update state and push
jq -n --arg ts "$NOW" --argjson tot "$TOTAL" '{timestamp:$ts,total:$tot}' > "$STATE"
git add "$STATE"
git commit -m "chore: mirror state"
git push origin HEAD:"$DEFAULT_BRANCH" --force-with-lease
