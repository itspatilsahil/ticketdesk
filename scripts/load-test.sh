#!/usr/bin/env bash
# Milestone 8's "light load sanity check": 20 concurrent users, 5 minutes,
# looking for zero errors - not percentile targets. Uses `hey`
# (single static Go binary, nothing to configure).
#
# Usage: ./load-test.sh https://<your-cloudfront-domain>
set -euo pipefail

URL="${1:?Usage: ./load-test.sh <base-url>}"

if ! command -v hey &> /dev/null; then
  echo "Installing hey..."
  if [[ "$(uname)" == "Darwin" ]]; then
    brew install hey
  else
    curl -sSL -o /tmp/hey https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_amd64
    chmod +x /tmp/hey
    sudo mv /tmp/hey /usr/local/bin/hey
  fi
fi

echo "Load testing $URL/api/tickets - 20 concurrent, 5 minutes"
hey -z 5m -c 20 -m GET "$URL/api/tickets"

echo
echo "Read the output above: 'Status code distribution' should show only 200s."
echo "Any non-200 codes there means the sanity check failed - go read the ECS task logs before changing anything."
