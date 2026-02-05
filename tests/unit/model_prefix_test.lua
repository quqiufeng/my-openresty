#!/usr/bin/env lua
-- Model Prefix Test Runner

package.path = '/var/www/web/my-openresty/?.lua;/var/www/web/my-openresty/?/init.lua;/usr/local/web/?.lua;/usr/local/web/lualib/?.lua;;'
package.cpath = '/var/www/web/my-openresty/?.so;/usr/local/web/lualib/?.so;;'

-- Mock Model for testing prefix
local mock_model = {
    table_name = 'admin',
    _prefix = '',
    _db = {},
    _query_builder = nil
}

local function table_prefix(self, prefix)
    self._prefix = prefix or ''
    return self
end

local function get_prefix(self)
    return self._prefix or ''
end

local function get_full_table_name(self)
    return (self._prefix or '') .. (self.table_name or '')
end

mock_model.table_prefix = table_prefix
mock_model.get_prefix = get_prefix
mock_model.get_full_table_name = get_full_table_name

-- Test helper
local tests_passed = 0
local tests_failed = 0

local function assert_equals(expected, actual, test_name)
    if expected == actual then
        print('✓ PASS: ' .. test_name)
        tests_passed = tests_passed + 1
        return true
    else
        print('✗ FAIL: ' .. test_name)
        print('  Expected: ' .. tostring(expected))
        print('  Actual:   ' .. tostring(actual))
        tests_failed = tests_failed + 1
        return false
    end
end

local function assert_true(value, test_name)
    if value then
        print('✓ PASS: ' .. test_name)
        tests_passed = tests_passed + 1
        return true
    else
        print('✗ FAIL: ' .. test_name)
        print('  Expected: truthy value')
        print('  Actual:   ' .. tostring(value))
        tests_failed = tests_failed + 1
        return false
    end
end

print('=' .. string.rep('=', 60))
print('Model Prefix Test')
print('=' .. string.rep('=', 60))
print()

-- Test 1: default prefix is empty
print('Test: default prefix')
assert_equals('', mock_model._prefix, 'default prefix should be empty string')
assert_equals('', mock_model:get_prefix(), 'get_prefix() should return empty string')
print()

-- Test 2: table_prefix() sets prefix
print('Test: table_prefix()')
mock_model:table_prefix('cms_')
assert_equals('cms_', mock_model._prefix, 'table_prefix() should set prefix')
assert_equals('cms_', mock_model:get_prefix(), 'get_prefix() should return set prefix')
print()

-- Test 3: get_full_table_name() returns correct value
print('Test: get_full_table_name()')
mock_model._prefix = ''
mock_model.table_name = 'admin'
assert_equals('admin', mock_model:get_full_table_name(), 'without prefix should return table name')

mock_model._prefix = 'cms_'
assert_equals('cms_admin', mock_model:get_full_table_name(), 'with prefix should return prefix_table')

mock_model._prefix = 'app_'
mock_model.table_name = 'users'
assert_equals('app_users', mock_model:get_full_table_name(), 'with different prefix')
print()

-- Test 4: table_prefix() returns self for chaining
print('Test: table_prefix() returns self')
mock_model = { table_name = 'admin', _prefix = '' }
local result = table_prefix(mock_model, 'test_')
assert_true(result == mock_model, 'table_prefix() should return self')
print()

-- Test 5: empty prefix handling
print('Test: empty prefix handling')
mock_model._prefix = ''
mock_model.table_name = 'admin'
mock_model.get_full_table_name = get_full_table_name
assert_equals('admin', mock_model:get_full_table_name(), 'empty prefix should not add underscore')
print()

-- Test 6: different prefix styles
print('Test: different prefix styles')
mock_model.get_full_table_name = get_full_table_name
local tests = {
    { prefix = 'cms_', table = 'admin', expected = 'cms_admin' },
    { prefix = 'app_', table = 'users', expected = 'app_users' },
    { prefix = '', table = 'role', expected = 'role' },
    { prefix = 'db_', table = 'system_menu', expected = 'db_system_menu' }
}
for _, t in ipairs(tests) do
    mock_model._prefix = t.prefix
    mock_model.table_name = t.table
    assert_equals(t.expected, mock_model:get_full_table_name(), 
        'prefix="' .. t.prefix .. '", table="' .. t.table .. '"')
end
print()

-- Summary
print('=' .. string.rep('=', 60))
print('Test Results')
print('=' .. string.rep('=', 60))
print('Passed: ' .. tests_passed)
print('Failed: ' .. tests_failed)
print('Total:  ' .. (tests_passed + tests_failed))
print()

if tests_failed > 0 then
    print('Some tests failed!')
    os.exit(1)
else
    print('All tests passed!')
    os.exit(0)
end
