#!/usr/bin/env lua
-- Model Join Test Runner

package.path = '/var/www/web/my-openresty/?.lua;/var/www/web/my-openresty/?/init.lua;/usr/local/web/?.lua;/usr/local/web/lualib/?.lua;;'
package.cpath = '/var/www/web/my-openresty/?.so;/usr/local/web/lualib/?.so;;'

local QueryBuilder = require('app.db.query')

-- Test helper
local tests_passed = 0
local tests_failed = 0

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

print('=' .. string.rep('=', 60))
print('Model Join Methods Test')
print('=' .. string.rep('=', 60))
print()

-- Test 1: join() creates QueryBuilder
print('Test: join()')
local mock_model = {
    table_name = 'admin',
    _query_builder = nil
}
local function join(self, table_name)
    if not self._query_builder then
        self._query_builder = QueryBuilder:new(self.table_name)
    end
    self._query_builder:join(table_name)
    return self
end
mock_model.join = join

mock_model:join('role')
assert_equals('table', type(mock_model._query_builder), 'join() should create QueryBuilder')
assert_equals(1, #mock_model._query_builder.joins, 'join() should add one join')
assert_equals('role', mock_model._query_builder.joins[1].table, 'join() should set table name')
print()

-- Test 2: left_join()
print('Test: left_join()')
mock_model = { table_name = 'admin', _query_builder = nil }
local function left_join(self, table_name)
    if not self._query_builder then
        self._query_builder = QueryBuilder:new(self.table_name)
    end
    self._query_builder:left_join(table_name)
    return self
end
mock_model.left_join = left_join

mock_model:left_join('role')
assert_equals('LEFT JOIN', mock_model._query_builder.joins[1].type, 'left_join() should set LEFT JOIN type')
print()

-- Test 3: right_join()
print('Test: right_join()')
mock_model = { table_name = 'admin', _query_builder = nil }
local function right_join(self, table_name)
    if not self._query_builder then
        self._query_builder = QueryBuilder:new(self.table_name)
    end
    self._query_builder:right_join(table_name)
    return self
end
mock_model.right_join = right_join

mock_model:right_join('role')
assert_equals('RIGHT JOIN', mock_model._query_builder.joins[1].type, 'right_join() should set RIGHT JOIN type')
print()

-- Test 4: on()
print('Test: on()')
mock_model = { table_name = 'admin', _query_builder = nil }
mock_model._query_builder = QueryBuilder:new('admin')
mock_model.join = join
mock_model.on = function(self, left_field, right_field)
    if self._query_builder then
        self._query_builder:on(left_field, right_field)
    end
    return self
end

mock_model:join('role'):on('role_id', 'id')
assert_equals('table', type(mock_model._query_builder.joins[1].on), 'on() should set join condition as table')
assert_equals('role_id', mock_model._query_builder.joins[1].on.left, 'on() should set left field')
assert_equals('id', mock_model._query_builder.joins[1].on.right, 'on() should set right field')
print()

-- Test 5: AdminModel list() style query
print('Test: AdminModel list() style query')
mock_model = {
    table_name = 'admin',
    _query_builder = nil,
    query = function(self, sql) return { sql = sql } end
}
mock_model.join = join
mock_model.left_join = left_join
mock_model.right_join = right_join
mock_model.on = function(self, left_field, right_field)
    if self._query_builder then
        self._query_builder:on(left_field, right_field)
    end
    return self
end
mock_model.select = function(self, fields)
    if self._query_builder then
        self._query_builder:select(fields)
    end
    return self
end
mock_model.where = function(self, k, op, v)
    if self._query_builder then
        self._query_builder:where(k, op, v)
    end
    return self
end
mock_model.order_by = function(self, field, direction)
    if self._query_builder then
        self._query_builder:order_by(field, direction)
    end
    return self
end
mock_model.limit = function(self, n)
    if self._query_builder then
        self._query_builder:limit(n)
    end
    return self
end
mock_model.offset = function(self, n)
    if self._query_builder then
        self._query_builder:offset(n)
    end
    return self
end

mock_model:select('admin.id, admin.username, role.name as role_name')
mock_model:left_join('role'):on('role_id', 'id')
mock_model:where('admin.status', '=', 1)
mock_model:order_by('admin.id', 'DESC')
mock_model:limit(10)

local result = mock_model:query(mock_model._query_builder:to_sql())
local sql = result.sql
print('Generated SQL:')
print(sql)
print()

assert_equals('string', type(sql), 'should generate SQL string')
assert_true(sql:match('SELECT') ~= nil, 'should have SELECT')
assert_true(sql:match('FROM admin') ~= nil, 'should have FROM admin')
assert_true(sql:match('LEFT JOIN role ON admin.role_id = role.id') ~= nil, 'should have LEFT JOIN')
assert_true(sql:match('WHERE admin.status = 1') ~= nil, 'should have WHERE')
assert_true(sql:match('ORDER BY admin.id DESC') ~= nil, 'should have ORDER BY')
assert_true(sql:match('LIMIT 10') ~= nil, 'should have LIMIT')
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
