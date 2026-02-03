#!/bin/bash
# User Integration Test

BASE_URL="${BASE_URL:-http://localhost:8080}"

echo "=== User CRUD Tests ==="

test_endpoint() {
    local method=$1
    local endpoint=$2
    local data=$3
    local desc=$4
    
    if [ -n "$data" ]; then
        response=$(curl -s -w "\n%{http_code}" -X $method "$BASE_URL$endpoint" -H "Content-Type: application/json" -d "$data")
    else
        response=$(curl -s -w "\n%{http_code}" -X $method "$BASE_URL$endpoint")
    fi
    
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        echo "[PASS] $desc (HTTP $http_code)"
    else
        echo "[FAIL] $desc (HTTP $http_code)"
    fi
}

test_endpoint "GET" "/users" "" "List items"
test_endpoint "POST" "/users" '{"name":"Test"}' "Create item"
test_endpoint "GET" "/users/1" "" "Get item"
test_endpoint "PUT" "/users/1" '{"name":"Updated"}' "Update item"
test_endpoint "DELETE" "/users/1" "" "Delete item"

echo "=== Tests Complete ==="
