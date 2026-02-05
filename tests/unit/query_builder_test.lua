#!/usr/bin/env lua
-- Simple QueryBuilder Test Runner

package.path = '/var/www/web/my-openresty/?.lua;/var/www/web/my-openresty/?/init.lua;/usr/local/web/?.lua;/usr/local/web/lualib/?.lua;;'
package.cpath = '/var/www/web/my-openresty/?.so;/usr/local/web/lualib/?.so;;'

local QueryBuilder = require('app.db.query')

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

local function assert_matches(pattern, text, test_name)
    if text and string.find(text, pattern, 1, true) then
        print('✓ PASS: ' .. test_name)
        tests_passed = tests_passed + 1
        return true
    else
        print('✗ FAIL: ' .. test_name)
        print('  Pattern: ' .. tostring(pattern))
        print('  Text:    ' .. tostring(text))
        tests_failed = tests_failed + 1
        return false
    end
end

print('=' .. string.rep('=', 60))
print('QueryBuilder Unit Tests')
print('=' .. string.rep('=', 60))
print()

-- Test 1: new()
print('Test: new()')
local qb = QueryBuilder:new('users')
assert_equals('users', qb.table, 'new() should set table name')
assert_equals('*', qb.fields, 'new() should set default fields to *')
assert_equals(0, #qb.wheres, 'new() should have empty wheres')
assert_equals(0, #qb.joins, 'new() should have empty joins')
print()

-- Test 2: select()
print('Test: select()')
local qb2 = QueryBuilder:new('users')
qb2:select('id, name, email')
assert_equals('id, name, email', qb2.fields, 'select() with string')
local qb3 = QueryBuilder:new('users')
qb3:select({'id', 'name', 'email'})
assert_equals('id, name, email', qb3.fields, 'select() with table')
local qb4 = QueryBuilder:new('users')
qb4:select({'id', 'users.name as user_name', 'email'})
assert_equals('id, users.name AS user_name, email', qb4.fields, 'select() with alias')
print()

-- Test 3: where()
print('Test: where()')
local qb5 = QueryBuilder:new('users')
qb5:where('status', '=', 'active')
assert_equals(1, #qb5.wheres, 'where() should add one condition')
assert_equals('status', qb5.wheres[1].key, 'where() should set key')
assert_equals('=', qb5.wheres[1].operator, 'where() should set operator')
assert_equals('active', qb5.wheres[1].value, 'where() should set value')
print()

-- Test 4: join() with on()
print('Test: join() with on()')
local qb6 = QueryBuilder:new('users')
qb6:join('orders'):on('id', 'user_id')
assert_equals(1, #qb6.joins, 'join() should add one join')
assert_equals('JOIN', qb6.joins[1].type, 'join() should set type')
assert_equals('orders', qb6.joins[1].table, 'join() should set table')
assert_equals('table', type(qb6.joins[1].on), 'join() on should be table')
assert_equals('id', qb6.joins[1].on.left, 'join() on.left should be id')
assert_equals('user_id', qb6.joins[1].on.right, 'join() on.right should be user_id')
print()

-- Test 5: left_join() with on()
print('Test: left_join() with on()')
local qb7 = QueryBuilder:new('users')
qb7:left_join('orders'):on('id', 'user_id')
assert_equals('LEFT JOIN', qb7.joins[1].type, 'left_join() should set LEFT JOIN type')
assert_equals('table', type(qb7.joins[1].on), 'left_join() on should be table')
assert_equals('id', qb7.joins[1].on.left, 'left_join() on.left should be id')
assert_equals('user_id', qb7.joins[1].on.right, 'left_join() on.right should be user_id')
print()

-- Test 6: right_join() with on()
print('Test: right_join() with on()')
local qb8 = QueryBuilder:new('users')
qb8:right_join('orders'):on('id', 'user_id')
assert_equals('RIGHT JOIN', qb8.joins[1].type, 'right_join() should set RIGHT JOIN type')
assert_equals('table', type(qb8.joins[1].on), 'right_join() on should be table')
assert_equals('id', qb8.joins[1].on.left, 'right_join() on.left should be id')
assert_equals('user_id', qb8.joins[1].on.right, 'right_join() on.right should be user_id')
print()

-- Test 7: order_by()
print('Test: order_by()')
local qb9 = QueryBuilder:new('users')
qb9:order_by('created_at', 'DESC')
assert_equals(1, #qb9.orders, 'order_by() should add one order')
assert_equals('created_at', qb9.orders[1].field, 'order_by() should set field')
assert_equals('DESC', qb9.orders[1].direction, 'order_by() should set direction')
print()

-- Test 8: limit() and offset()
print('Test: limit() and offset()')
local qb10 = QueryBuilder:new('users')
qb10:limit(10)
qb10:offset(20)
assert_equals(10, qb10.limit_val, 'limit() should set value')
assert_equals(20, qb10.offset_val, 'offset() should set value')
print()

-- Test 9: to_sql() - basic
print('Test: to_sql() - basic')
local qb11 = QueryBuilder:new('users')
qb11:select('id, name')
local sql = qb11:to_sql()
assert_equals('SELECT id, name FROM users', sql, 'to_sql() should generate basic SQL')
print()

-- Test 10: to_sql() - with WHERE
print('Test: to_sql() - with WHERE')
local qb12 = QueryBuilder:new('users')
qb12:select('*')
qb12:where('status', '=', 'active')
sql = qb12:to_sql()
assert_matches("WHERE status = 'active'", sql, 'to_sql() with WHERE')
print()

-- Test 11: to_sql() - with ORDER BY, LIMIT
print('Test: to_sql() - with ORDER BY, LIMIT')
local qb13 = QueryBuilder:new('users')
qb13:select('*')
qb13:order_by('created_at', 'DESC')
qb13:limit(10)
sql = qb13:to_sql()
assert_matches('ORDER BY created_at DESC', sql, 'to_sql() with ORDER BY')
assert_matches('LIMIT 10', sql, 'to_sql() with LIMIT')
print()

-- Test 12: to_sql() - with LEFT JOIN
print('Test: to_sql() - with LEFT JOIN')
local qb14 = QueryBuilder:new('users')
qb14:select('*')
qb14:left_join('orders'):on('id', 'user_id')
sql = qb14:to_sql()
assert_matches('LEFT JOIN orders ON users.id = orders.user_id', sql, 'to_sql() with LEFT JOIN')
print()

-- Test 13: to_sql() with JOIN - auto table prefix
print('Test: to_sql() with JOIN - auto table prefix')
local qb15 = QueryBuilder:new('users')
qb15:select({'id', 'name', 'orders.total'})
qb15:left_join('orders'):on('id', 'user_id')
sql = qb15:to_sql()
assert_matches('SELECT users.id, users.name, orders.total FROM users', sql, 'to_sql() auto prefix main table fields')
print()

-- Test 14: to_sql() with JOIN - preserve alias
print('Test: to_sql() with JOIN - preserve alias')
local qb16 = QueryBuilder:new('users')
qb16:select({'users.id', 'users.name as user_name', 'orders.total as amount'})
qb16:left_join('orders'):on('id', 'user_id')
sql = qb16:to_sql()
assert_matches('users.name AS user_name', sql, 'to_sql() preserve AS alias')
assert_matches('orders.total AS amount', sql, 'to_sql() preserve AS alias for join table')
print()

-- Test 15: to_sql() - complete query with JOIN
print('Test: to_sql() - complete query with JOIN')
local qb17 = QueryBuilder:new('users')
qb17:select({'users.id', 'users.name', 'orders.total as order_amount', 'orders.created_at'})
qb17:left_join('orders'):on('id', 'user_id')
qb17:where('users.status', '=', 'active')
qb17:order_by('orders.created_at', 'DESC')
qb17:limit(10)
sql = qb17:to_sql()
assert_matches('SELECT users.id, users.name, orders.total AS order_amount, orders.created_at FROM users', sql, 'complete query select')
assert_matches('LEFT JOIN orders ON users.id = orders.user_id', sql, 'complete query JOIN')
assert_matches("WHERE users.status = 'active'", sql, 'complete query WHERE')
assert_matches('ORDER BY orders.created_at DESC', sql, 'complete query ORDER BY')
assert_matches('LIMIT 10', sql, 'complete query LIMIT')
print()

-- Test 16: to_sql() - multiple JOINs
print('Test: to_sql() - multiple JOINs')
local qb18 = QueryBuilder:new('orders')
qb18:select({'orders.id', 'users.name as user_name', 'products.name as product_name'})
qb18:left_join('users'):on('user_id', 'id')
qb18:left_join('order_items'):on('id', 'order_id')
qb18:left_join('products'):on('order_items.product_id', 'id')
sql = qb18:to_sql()
assert_matches('SELECT orders.id, users.name AS user_name, products.name AS product_name FROM orders', sql, 'multiple JOINs select')
assert_matches('LEFT JOIN users ON orders.user_id = users.id', sql, 'multiple JOINs 1')
assert_matches('LEFT JOIN order_items ON orders.id = order_items.order_id', sql, 'multiple JOINs 2')
assert_matches('LEFT JOIN products ON order_items.product_id = products.id', sql, 'multiple JOINs 3')
print()

-- Test 17: reset()
print('Test: reset()')
local qb19 = QueryBuilder:new('users')
qb19:select('id, name')
qb19:where('status', '=', 'active')
qb19:order_by('id', 'DESC')
qb19:limit(10)
qb19:join('orders'):on('id', 'user_id')
qb19:reset()
assert_equals('*', qb19.fields, 'reset() should reset fields')
assert_equals(0, #qb19.wheres, 'reset() should reset wheres')
assert_equals(0, #qb19.joins, 'reset() should reset joins')
assert_equals(0, #qb19.orders, 'reset() should reset orders')
assert_equals(nil, qb19.limit_val, 'reset() should reset limit')
assert_equals(nil, qb19.offset_val, 'reset() should reset offset')
print()

-- Test 18: string escaping
print('Test: string escaping')
local qb20 = QueryBuilder:new('users')
qb20:select('*')
qb20:where('name', '=', "O'Reilly")
sql = qb20:to_sql()
assert_matches("WHERE name = 'O''Reilly'", sql, 'escape single quotes')
print()

-- Test 19: prefix()
print('Test: prefix()')
local qb21 = QueryBuilder:new('users', 'cms_')
assert_equals('cms_', qb21._prefix, 'new() with prefix')
local qb22 = QueryBuilder:new('users')
qb22:prefix('blog_')
assert_equals('blog_', qb22._prefix, 'prefix() should set prefix')
print()

-- Test 20: to_sql() with prefix
print('Test: to_sql() with prefix')
local qb23 = QueryBuilder:new('users', 'app_')
qb23:select('id, name')
qb23:where('status', '=', 'active')
sql = qb23:to_sql()
assert_equals("SELECT id, name FROM app_users WHERE status = 'active'", sql, 'to_sql() with prefix on main table')
print()

-- Test 21: to_sql() with prefix and JOIN
print('Test: to_sql() with prefix and JOIN')
local qb24 = QueryBuilder:new('users', 'app_')
qb24:select({'id', 'name', 'orders.total'})
qb24:left_join('orders'):on('id', 'user_id')
sql = qb24:to_sql()
assert_matches('FROM app_users', sql, 'to_sql() prefix main table with JOIN')
assert_matches('LEFT JOIN app_orders', sql, 'to_sql() prefix join table')
assert_matches('app_users.id = app_orders.user_id', sql, 'to_sql() prefix join condition')
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
