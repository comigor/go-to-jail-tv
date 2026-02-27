#!/usr/bin/env bash
set -euo pipefail

# Usage: ./jail.sh <slack_handle> "reason why they go to jail"
# Requires: SLACK_TOKEN env var (Bot token with users:read scope)
#
# Example:
#   export SLACK_TOKEN=xoxb-your-token-here
#   ./jail.sh igor "threw garbage on the floor"

BASE_URL="https://comigor.github.io/go-to-jail-tv"

if [[ $# -lt 1 ]]; then
  echo "Usage: ./jail.sh <slack_handle> [reason]"
  echo ""
  echo "Requires SLACK_TOKEN env var (Bot token with users:read scope)"
  exit 1
fi

USER="$1"
MESSAGE="${2:-}"

: "${SLACK_TOKEN:?Set SLACK_TOKEN env var (Bot token with users:read scope)}"

# Lookup user in Slack workspace
RESPONSE=$(curl -s -H "Authorization: Bearer $SLACK_TOKEN" \
  "https://slack.com/api/users.list?limit=1000")

OK=$(echo "$RESPONSE" | jq -r '.ok')
if [[ "$OK" != "true" ]]; then
  ERROR=$(echo "$RESPONSE" | jq -r '.error // "unknown error"')
  echo "Slack API error: $ERROR" >&2
  exit 1
fi

# Try matching by display_name, then name (username), then real_name (case-insensitive)
AVATAR=$(echo "$RESPONSE" | jq -r --arg user "$USER" '
  .members[] |
  select(
    (.profile.display_name | ascii_downcase) == ($user | ascii_downcase) or
    (.name | ascii_downcase) == ($user | ascii_downcase) or
    (.profile.display_name_normalized | ascii_downcase) == ($user | ascii_downcase)
  ) |
  .profile.image_512 // .profile.image_192 // .profile.image_72
' | head -1)

if [[ -z "$AVATAR" || "$AVATAR" == "null" ]]; then
  echo "Could not find user '$USER' in Slack workspace" >&2
  echo "Generating link without avatar..." >&2
  AVATAR=""
fi

# Build URL
URL="${BASE_URL}/?user=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$USER'))")"

if [[ -n "$MESSAGE" ]]; then
  URL="${URL}&message=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$MESSAGE'))")"
fi

if [[ -n "$AVATAR" ]]; then
  URL="${URL}&avatar=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$AVATAR'))")"
fi

echo "$URL"
