#!/usr/bin/env bash
set -euo pipefail
echo "Starting mirror script…"

# ─── Required env vars ──────────────────────────────────────────────────────────
WORK_PAT="${WORK_PAT:?}"        
PERSONAL_PAT="${PERSONAL_PAT:?}"  
WORK_LOGIN="rodo_codify" #"${WORK_LOGIN:?}"     

AUTHOR_NAME="rodo"
AUTHOR_EMAIL="rodonguyendd@gmail.com"

# ─── Git setup ──────────────────────────────────────────────────────────────────
git config user.name  "$AUTHOR_NAME"
git config user.email "$AUTHOR_EMAIL"
git remote set-url origin \
  "https://x-access-token:${PERSONAL_PAT}@github.com/rodonguyen/mirror-work-commit.git"

# ─── Time window (last 24 h) ────────────────────────────────────────────────────
SINCE=$(date -u -d "24 hours ago" +"%Y-%m-%dT%H:%M:%SZ")
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "Counting contributions from $SINCE to $NOW"

# Helper: search() → prints total_count
search () {
  local QUERY="$1"
  local ENCODED
  ENCODED=$(jq -rn --arg q "$QUERY" '$q|@uri')

  curl -s \
    -H "Authorization: Bearer $WORK_PAT" \
    -H "Accept: application/vnd.github.cloak-preview+json" \
    "https://api.github.com/search/$2?q=$ENCODED&per_page=1" |
    jq '.total_count'
}

# ─── 1. Commits (Search-Commits API) ────────────────────────────────────────────
COMMITS=$(search "author:$WORK_LOGIN committer-date:$SINCE..$NOW" commits)
echo "  commits:          $COMMITS"

# ─── 2. PRs opened ──────────────────────────────────────────────────────────────
PRS_OPENED=$(search "type:pr author:$WORK_LOGIN created:$SINCE..$NOW" issues)
echo "  PRs opened:       $PRS_OPENED"

# ─── 3. PRs reviewed ────────────────────────────────────────────────────────────
PRS_REVIEWED=$(search \
  "type:pr reviewed-by:$WORK_LOGIN updated:$SINCE..$NOW" issues)
echo "  PRs reviewed:     $PRS_REVIEWED"

# ─── 4. Issues opened ───────────────────────────────────────────────────────────
ISSUES_OPENED=$(search "type:issue author:$WORK_LOGIN created:$SINCE..$NOW" issues)
echo "  issues opened:    $ISSUES_OPENED"

# ─── 5. Grand total ─────────────────────────────────────────────────────────────
GRAND_TOTAL=$(( COMMITS + PRS_OPENED + PRS_REVIEWED + ISSUES_OPENED ))
echo "Grand total contributions: $GRAND_TOTAL"

[[ $GRAND_TOTAL -eq 0 ]] && { echo "Nothing to mirror."; exit 0; }

# ─── 6. Forge mirror commits ───────────────────────────────────────────────────
for ((i=0;i<GRAND_TOTAL;i++)); do
  git commit --allow-empty -m "< mirror work contribution $((i+1)) >"
done

# ─── 7. Push ────────────────────────────────────────────────────────────────────
git push origin HEAD:main --force-with-lease
echo "Mirror script completed successfully."
