#!/bin/sh
# Prints JSON: {"five_hour":{"utilization":..,"resets_at":..},"seven_day":{...}} using Claude Code's OAuth token.
tok=$(jq -r '.claudeAiOauth.accessToken' ~/.claude/.credentials.json) || exit 1
curl -sf --max-time 10 https://api.anthropic.com/api/oauth/usage \
  -H "Authorization: Bearer $tok" -H "anthropic-beta: oauth-2025-04-20" -H "User-Agent: claude-code/2.0"
