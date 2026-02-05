#!/bin/bash
# Admin Test
BASE_URL="${BASE_URL:-http://localhost:8080}"
echo "===Admin==="
curl -s "$BASE_URL/admin"|head -c200
echo ""
echo "Done"
