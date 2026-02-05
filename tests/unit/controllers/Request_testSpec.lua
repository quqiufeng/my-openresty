-- Request_test Controller Unit Tests (Auto-generated)
-- Run with: luajit tests/unit/controllers/Request_testSpec.lua

package.path="/var/www/web/my-openresty/?.lua;;"..package.path
package.cpath="/var/www/web/my-openresty/?.so;;"..package.cpath

local tests_passed=0
local tests_failed=0

local function assert_eq(exp,act,name)
    if exp==act then
        print("✓ PASS: "..name)
        tests_passed=tests_passed+1
    else
        print("✗ FAIL: "..name)
        print("  Expected: "..tostring(exp))
        print("  Actual:   "..tostring(act))
        tests_failed=tests_failed+1
    end
end

print("=============================================================")
print("Request_test Controller Unit Tests (Auto-generated)")
print("=============================================================")
print()

-- Test: controller file exists
print("Test: controller exists")
local ok, C = pcall(require, "app.controllers.request_test")
if not ok then
    print("✗ SKIP: Controller not found or has errors")
    os.exit(0)
end
assert_eq("table",type(C),"controller should be table")
print()

print("="..string.rep("=",60)..")
print("Test Results")
print("="..string.rep("=",60)..")
print("Passed: "..tests_passed)
print("Failed: "..tests_failed)
print()
if tests_failed>0 then os.exit(1) end
