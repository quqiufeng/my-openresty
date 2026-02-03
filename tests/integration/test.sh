#!/bin/bash

# MyResty API Integration Test Suite
# Tests all API endpoints defined in routes.lua

#set -e  # Disabled to allow curl to fail gracefully

BASE_URL="${BASE_URL:-http://localhost:8080}"
COOKIE_JAR="/tmp/myresty_test_cookies.txt"
VERBOSE=false

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; TESTS_PASSED=$((TESTS_PASSED+1)); TESTS_RUN=$((TESTS_RUN+1)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; TESTS_FAILED=$((TESTS_FAILED+1)); TESTS_RUN=$((TESTS_RUN+1)); }
log_skip() { echo -e "${YELLOW}[SKIP]${NC} $1"; }

curl_get() {
    local endpoint="$1"
    local description="$2"

    local response=$(curl -s --max-time 5 -w "\n%{http_code}" "$BASE_URL$endpoint" -c "$COOKIE_JAR" -b "$COOKIE_JAR")
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        log_pass "$description (HTTP $http_code)"
    else
        log_fail "$description (HTTP $http_code)"
    fi

    [ "$VERBOSE" = "true" ] && echo "  Response: $body" | head -c 200
}

curl_post() {
    local endpoint="$1"
    local data="$2"
    local description="$3"
    local content_type="${4:-application/json}"

    local response=$(curl -s --max-time 5 -w "\n%{http_code}" -X POST \
        -H "Content-Type: $content_type" \
        -d "$data" \
        "$BASE_URL$endpoint" \
        -c "$COOKIE_JAR" -b "$COOKIE_JAR")
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ] || [ "$http_code" = "204" ]; then
        log_pass "$description (HTTP $http_code)"
    else
        log_fail "$description (HTTP $http_code)"
    fi

    [ "$VERBOSE" = "true" ] && echo "  Response: $body" | head -c 200
}

curl_put() {
    local endpoint="$1"
    local data="$2"
    local description="$3"

    local response=$(curl -s --max-time 5 -w "\n%{http_code}" -X PUT \
        -H "Content-Type: application/json" \
        -d "$data" \
        "$BASE_URL$endpoint" \
        -c "$COOKIE_JAR" -b "$COOKIE_JAR")
    local http_code=$(echo "$response" | tail -n1)

    if [ "$http_code" = "200" ]; then
        log_pass "$description (HTTP $http_code)"
    else
        log_fail "$description (HTTP $http_code)"
    fi
}

curl_delete() {
    local endpoint="$1"
    local description="$2"

    local response=$(curl -s --max-time 5 -w "\n%{http_code}" -X DELETE \
        "$BASE_URL$endpoint" \
        -c "$COOKIE_JAR" -b "$COOKIE_JAR")
    local http_code=$(echo "$response" | tail -n1)

    if [ "$http_code" = "200" ] || [ "$http_code" = "204" ]; then
        log_pass "$description (HTTP $http_code)"
    else
        log_fail "$description (HTTP $http_code)"
    fi
}

curl_any() {
    local endpoint="$1"
    local description="$2"

    local response=$(curl -s --max-time 5 -w "\n%{http_code}" -X ANY "$BASE_URL$endpoint" -c "$COOKIE_JAR" -b "$COOKIE_JAR")
    local http_code=$(echo "$response" | tail -n1)

    if [ "$http_code" = "200" ]; then
        log_pass "$description (HTTP $http_code)"
    else
        log_fail "$description (HTTP $http_code)"
    fi
}

init() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  MyResty API Integration Test Suite${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo "Base URL: $BASE_URL"
    echo ""

    rm -f "$COOKIE_JAR"

    if ! curl -s --connect-timeout 2 "$BASE_URL/" > /dev/null 2>&1; then
        echo -e "${YELLOW}Warning: Cannot connect to $BASE_URL${NC}"
        echo "Make sure nginx is running."
        echo ""
    fi
}

print_header() {
    echo ""
    echo -e "${CYAN}--- $1 ---${NC}"
}

# ==================== Health Check ====================
test_health() {
    print_header "Health Check"

    curl_get "/" "GET / - Root endpoint"
    curl_get "/test" "GET /test - Test endpoint"
}

# ==================== User Routes ====================
test_users() {
    print_header "User Routes"

    curl_get "/users" "GET /users - List users"
    curl_get "/users/123" "GET /users/123 - Get user by ID"
    curl_post "/users" '{"name":"test","email":"test@example.com"}' "POST /users - Create user"
    curl_put "/users/123" '{"name":"updated"}' "PUT /users/123 - Update user"
    curl_delete "/users/123" "DELETE /users/123 - Delete user"
}

# ==================== Hello Route ====================
test_hello() {
    print_header "Hello Route"

    curl_get "/hello/World" "GET /hello/{name} - Hello with name"
}

# ==================== Session Routes ====================
test_session() {
    print_header "Session Routes"

    curl_get "/session" "GET /session - Session index"
    curl_post "/session/set" '{"key":"test_key","value":"test_value"}' "POST /session/set - Set session value"
    curl_post "/session/get" '{"key":"test_key"}' "POST /session/get - Get session value"
    curl_post "/session/remove" '{"key":"test_key"}' "POST /session/remove - Remove session value"
    curl_post "/session/clear" '' "POST /session/clear - Clear session"
    curl_post "/session/regenerate" '' "POST /session/regenerate - Regenerate session ID"
    curl_post "/session/destroy" '' "POST /session/destroy - Destroy session"
    curl_post "/session/flash/set" '{"key":"flash_msg","value":"Hello"}' "POST /session/flash/set - Set flash message"
    curl_post "/session/flash/get" '{"key":"flash_msg"}' "POST /session/flash/get - Get flash message"
    curl_post "/session/touch" '' "POST /session/touch - Touch session"
    curl_get "/session/counter" "GET /session/counter - Session counter"

    # Session user authentication
    curl_post "/session/user/login" '{"username":"testuser","password":"testpass"}' "POST /session/user/login - User login"
    curl_get "/session/user/info" "GET /session/user/info - Get user info"
    curl_post "/session/user/logout" '' "POST /session/user/logout - User logout"
}

# ==================== Captcha Routes ====================
test_captcha() {
    print_header "Captcha Routes"

    curl_get "/captcha" "GET /captcha - Captcha index"
    curl_get "/captcha/code" "GET /captcha/code - Get captcha code"
    curl_post "/captcha/verify" '{"code":"TEST"}' "POST /captcha/verify - Verify captcha"
    curl_post "/captcha/refresh" '' "POST /captcha/refresh - Refresh captcha"
    curl_post "/captcha/verify-ajax" '{"code":"TEST"}' "POST /captcha/verify-ajax - Verify captcha AJAX"
}

# ==================== Cache Routes ====================
test_cache() {
    print_header "Cache Routes"

    curl_get "/cache" "GET /cache - Cache index"
    curl_get "/cache/keys" "GET /cache/keys - Get cache keys"
    curl_get "/cache/stats" "GET /cache/stats - Get cache stats"
    curl_get "/cache/user" "GET /cache/user - Get user cache"
    curl_get "/cache/pageview" "GET /cache/pageview - Page view cache"

    curl_post "/cache/set" '{"key":"test:key","value":"test_value","ttl":60}' "POST /cache/set - Set cache value"
    curl_post "/cache/get" '{"key":"test:key"}' "POST /cache/get - Get cache value"
    curl_post "/cache/delete" '{"key":"test:key"}' "POST /cache/delete - Delete cache"
    curl_post "/cache/clear" '' "POST /cache/clear - Clear cache"
    curl_post "/cache/incr" '{"key":"test:counter","step":1}' "POST /cache/incr - Increment cache"
    curl_post "/cache/decr" '{"key":"test:counter","step":1}' "POST /cache/decr - Decrement cache"
    curl_post "/cache/remember" '{"key":"test:remember","ttl":60,"callback":"function() return {} end"}' "POST /cache/remember - Remember mode"
    curl_post "/cache/user/invalidate" '{"user_id":123}' "POST /cache/user/invalidate - Invalidate user cache"
}

# ==================== Query Builder Routes ====================
test_query_builder() {
    print_header "Query Builder Routes"

    curl_get "/query/basic" "GET /query/basic - Basic query"
    curl_get "/query/joins" "GET /query/joins - Joins query"
    curl_get "/query/where" "GET /query/where - Where conditions"
    curl_get "/query/aggregates" "GET /query/aggregates - Aggregates query"
    curl_post "/query/insert" '{"table":"users","data":{"name":"test"}}' "POST /query/insert - Insert query"
    curl_post "/query/update" '{"table":"users","data":{"name":"updated"},"where":{"id":1}}' "POST /query/update - Update query"
    curl_post "/query/delete" '{"table":"users","where":{"id":1}}' "POST /query/delete - Delete query"
    curl_get "/query/complex" "GET /query/complex - Complex query"
    curl_get "/query/raw" "GET /query/raw - Raw expressions"
}

# ==================== Request Routes ====================
test_request() {
    print_header "Request Routes"

    curl_get "/request" "GET /request - Request index"
    curl_get "/request/get" "GET /request/get - GET request"
    curl_post "/request/post/form" '' "POST /request/post/form - POST form request"
    curl_post "/request/post/json" '{"key":"value"}' "POST /request/post/json - POST JSON request"
    curl_any "/request/mixed" "ANY /request/mixed - Mixed request"
    curl_get "/request/all" "GET /request/all - All request methods"
}

curl_any() {
    local endpoint="$1"
    local description="$2"

    local response=$(curl -s -w "\n%{http_code}" -X ANY "$BASE_URL$endpoint" -c "$COOKIE_JAR" -b "$COOKIE_JAR")
    local http_code=$(echo "$response" | tail -n1)

    if [ "$http_code" = "200" ]; then
        log_pass "$description (HTTP $http_code)"
    else
        log_fail "$description (HTTP $http_code)"
    fi
}

# ==================== Upload Routes ====================
test_upload() {
    print_header "Upload Routes"

    curl_get "/upload" "GET /upload - Upload index"
    curl_get "/upload/form" "GET /upload/form - Upload form"
    # Note: File uploads require multipart form data, tested manually
    log_skip "POST /upload - File upload (manual test required)"
    log_skip "POST /upload/multiple - Multiple file upload (manual test required)"
    log_skip "POST /upload/validate - File upload with validation (manual test required)"
}

# ==================== Image Routes ====================
test_image() {
    print_header "Image Routes"

    curl_get "/image" "GET /image - Image index"
    # Note: Image uploads require multipart form data
    log_skip "POST /image/upload - Image upload (manual test required)"
    log_skip "POST /image/upload/multiple - Multiple image upload (manual test required)"
    log_skip "POST /image/upload/avatar - Avatar upload (manual test required)"
    log_skip "POST /image/upload/variants - Image variants (manual test required)"
    log_skip "GET /image/info/{path} - Image info (manual test required)"
    log_skip "GET /image/thumbnail/{path} - Image thumbnail (manual test required)"
    log_skip "GET /image/optimize/{path} - Image optimize (manual test required)"
}

# ==================== HTTP Client Routes ====================
test_http_client() {
    print_header "HTTP Client Routes"

    curl_get "/httpclient" "GET /httpclient - HTTP client index"
    curl_get "/httpclient/get" "GET /httpclient/get - HTTP GET"
    curl_post "/httpclient/post" '{"url":"http://example.com","data":"test"}' "POST /httpclient/post - HTTP POST"
    curl_post "/httpclient/json" '{"url":"http://example.com","json":{"key":"value"}}' "POST /httpclient/json - HTTP JSON"
    curl_post "/httpclient/api" '{"method":"GET","url":"http://example.com"}' "POST /httpclient/api - HTTP API"
    curl_get "/httpclient/benchmark" "GET /httpclient/benchmark - HTTP benchmark"
}

# ==================== Rate Limit Routes ====================
test_rate_limit() {
    print_header "Rate Limit Routes"

    curl_get "/rate-limit" "GET /rate-limit - Rate limit index"
    curl_get "/rate-limit/test" "GET /rate-limit/test - Rate limit test"
    curl_get "/rate-limit/status" "GET /rate-limit/status - Rate limit status"
    curl_get "/rate-limit/zone" "GET /rate-limit/zone - Rate limit zone"
    curl_get "/rate-limit/keys" "GET /rate-limit/keys - Rate limit keys"
    curl_get "/rate-limit/login" "GET /rate-limit/login - Login rate limit"
    curl_get "/rate-limit/api" "GET /rate-limit/api - API rate limit"
    curl_get "/rate-limit/strict" "GET /rate-limit/strict - Strict rate limit"
    curl_get "/rate-limit/combined" "GET /rate-limit/combined - Combined rate limit"
    curl_get "/rate-limit/user" "GET /rate-limit/user - User rate limit"

    curl_post "/rate-limit/check" '{"key":"test","limit":10,"window":60}' "POST /rate-limit/check - Rate limit check"
    curl_post "/rate-limit/reset" '{"key":"test"}' "POST /rate-limit/reset - Rate limit reset"
}

# ==================== Validation Routes ====================
test_validation() {
    print_header "Validation Routes"

    curl_get "/validate" "GET /validate - Validation index"
    curl_post "/validate/basic" '{"email":"test@example.com","password":"password123"}' "POST /validate/basic - Basic validation"
    curl_post "/validate/login" '{"username":"testuser","password":"password123"}' "POST /validate/login - Login validation"
    curl_post "/validate/register" '{"email":"test@example.com","password":"password123","confirm_password":"password123"}' "POST /validate/register - Register validation"
    curl_post "/validate/update" '{"name":"Updated User","email":"update@example.com"}' "POST /validate/update - Update validation"
    curl_post "/validate/custom" '{"value":"test","rule":"custom_rule"}' "POST /validate/custom - Custom validation"
    curl_post "/validate/messages" '{"email":"test@example.com"}' "POST /validate/messages - Custom messages"
    curl_post "/validate/array" '{"items":[{"name":"item1"},{"name":"item2"}]}' "POST /validate/array - Array validation"
    curl_post "/validate/all" '{"email":"test@example.com","password":"password123","name":"Test User"}' "POST /validate/all - All validations"
    curl_post "/validate/login-captcha" '{"username":"testuser","password":"password123","code":"TEST"}' "POST /validate/login-captcha - Login with captcha"
    curl_post "/validate/api-key" '{"api_key":"test-api-key-12345"}' "POST /validate/api-key - API key validation"
}

# ==================== Validation Config Routes ====================
test_validate_config() {
    print_header "Validation Config Routes"

    curl_get "/validate-config" "GET /validate-config - Validation config index"
    curl_get "/validate-config/tables" "GET /validate-config/tables - Get tables"
    curl_get "/validate-config/table/users" "GET /validate-config/table/{table} - Get table info"
    curl_post "/validate-config/users" '{"name":"Test User","email":"test@example.com"}' "POST /validate-config/users - Validate users"
    curl_post "/validate-config/users/create" '{"name":"New User","email":"new@example.com","password":"password123"}' "POST /validate-config/users/create - Validate user create"
    curl_post "/validate-config/users/login" '{"email":"test@example.com","password":"password123"}' "POST /validate-config/users/login - Validate user login"
    curl_post "/validate-config/users/profile" '{"name":"Updated Name","bio":"Test bio"}' "POST /validate-config/users/profile - Validate user profile"
    curl_post "/validate-config/products" '{"name":"Test Product","price":99.99}' "POST /validate-config/products - Validate products"
    curl_post "/validate-config/products/create" '{"name":"New Product","price":49.99,"sku":"SKU123"}' "POST /validate-config/products/create - Validate product create"
    curl_post "/validate-config/products/update" '{"name":"Updated Product","price":79.99}' "POST /validate-config/products/update - Validate product update"
    curl_post "/validate-config/orders" '{"user_id":1,"total":99.99}' "POST /validate-config/orders - Validate orders"
    curl_post "/validate-config/orders/create" '{"user_id":1,"items":[{"product_id":1,"quantity":2}]}' "POST /validate-config/orders/create - Validate order create"
    curl_post "/validate-config/orders/ship" '{"order_id":123,"tracking_number":"TRACK123"}' "POST /validate-config/orders/ship - Validate order ship"
    curl_post "/validate-config/custom" '{"data":{"key":"value"}}' "POST /validate-config/custom - Custom validation config"
}

# ==================== Middleware Routes ====================
test_middleware() {
    print_header "Middleware Routes"

    curl_get "/middleware" "GET /middleware - Middleware index"
    curl_get "/middleware/list" "GET /middleware/list - Middleware list"
    curl_get "/middleware/info" "GET /middleware/info - Middleware info"
    curl_get "/middleware/headers" "GET /middleware/headers - Middleware headers"
    curl_get "/middleware/cors-test" "GET /middleware/cors-test - CORS test"
    curl_get "/middleware/rate-limit-test" "GET /middleware/rate-limit-test - Rate limit test"

    curl_post "/middleware/auth-test" '{"token":"test-token"}' "POST /middleware/auth-test - Auth test"
    curl_post "/middleware/login" '{"username":"test","password":"test"}' "POST /middleware/login - Middleware login"
    curl_post "/middleware/logout" '' "POST /middleware/logout - Middleware logout"
}

# ==================== Demo Routes ====================
test_demo() {
    print_header "Demo Routes"

    curl_get "/demo" "GET /demo - Demo index"
    curl_get "/demo/log-levels" "GET /demo/log-levels - Log levels demo"
    curl_get "/demo/performance" "GET /demo/performance - Performance demo"
    curl_get "/demo/logs-stats" "GET /demo/logs-stats - Logs stats demo"
    curl_get "/demo/recent-logs" "GET /demo/recent-logs - Recent logs demo"
    curl_get "/demo/context" "GET /demo/context - Context logging demo"

    curl_post "/demo/clear-logs" '' "POST /demo/clear-logs - Clear logs"
}

# ==================== Request Demo Routes ====================
test_request_demo() {
    print_header "Request Demo Routes"

    curl_get "/request-demo" "GET /request-demo - Request demo index"
    curl_post "/request-demo/basic" '{"name":"Test","email":"test@example.com"}' "POST /request-demo/basic - Basic request demo"
    curl_post "/request-demo/typed" '{"name":"Test","age":25,"email":"test@example.com"}' "POST /request-demo/typed - Typed request demo"
    curl_post "/request-demo/validate" '{"name":"Test","email":"test@example.com","age":25}' "POST /request-demo/validate - Validate request demo"
    curl_post "/request-demo/pagination" '{"page":1,"per_page":10}' "POST /request-demo/pagination - Pagination demo"
    curl_post "/request-demo/search" '{"query":"test","filters":{"status":"active"}}' "POST /request-demo/search - Search demo"
    curl_post "/request-demo/filter" '{"status":"active","role":"admin"}' "POST /request-demo/filter - Filter demo"
    curl_post "/request-demo/only" '{"id":1,"name":"Test","email":"test@example.com"}' "POST /request-demo/only - Only fields demo"
    curl_post "/request-demo/except" '{"id":1,"name":"Test","password":"secret","email":"test@example.com"}' "POST /request-demo/except - Except fields demo"
    curl_post "/request-demo/complete" '{"id":1,"name":"Test","email":"test@example.com","age":25}' "POST /request-demo/complete - Complete request demo"
    curl_post "/request-demo/direct-types" '{"name":"Test","age":25,"active":true,"amount":99.99}' "POST /request-demo/direct-types - Direct types demo"
    curl_post "/request-demo/get-post" '{"get_param":"test","post_param":"value"}' "POST /request-demo/get-post - GET and POST demo"
    curl_post "/request-demo/post-only" '{"post_only":"test"}' "POST /request-demo/post-only - POST only demo"
    curl_post "/request-demo/shorthand-types" '{"name":"Test","count":5,"price":29.99}' "POST /request-demo/shorthand-types - Shorthand types demo"
}

# ==================== Test Routes ====================
test_test_routes() {
    print_header "Test Routes"

    curl_get "/test" "GET /test - Test index"
    curl_get "/test/all" "GET /test/all - Run all tests"
    curl_get "/test/users" "GET /test/users - Test users"
    curl_get "/test/session" "GET /test/session - Test session"
    curl_get "/test/cache" "GET /test/cache - Test cache"
    curl_get "/test/captcha" "GET /test/captcha - Test captcha"
}

# ==================== API Test Route ====================
test_api_test() {
    print_header "API Test Route"

    curl_get "/api/test" "GET /api/test - API test"
}

# ==================== Main ====================
main() {
    init

    test_health
    test_api_test
    test_users
    test_hello
    test_session
    test_captcha
    test_cache
    test_query_builder
    test_request
    test_upload
    test_image
    test_http_client
    test_rate_limit
    test_validation
    test_validate_config
    test_middleware
    test_demo
    test_request_demo
    test_test_routes

    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Test Results Summary${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo -e "Total tests: ${TESTS_RUN}"
    echo -e "${GREEN}Passed: ${TESTS_PASSED}${NC}"
    echo -e "${RED}Failed: ${TESTS_FAILED}${NC}"
    echo ""

    if [ $TESTS_FAILED -gt 0 ]; then
        echo -e "${RED}Some tests failed!${NC}"
        exit 1
    else
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    fi
}

main
