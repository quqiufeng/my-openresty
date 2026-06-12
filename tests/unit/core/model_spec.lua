-- Model Unit Tests
-- Tests SQL generation and model logic without MySQL connection

package.path = '/var/www/web/my-openresty/?.lua;/var/www/web/my-openresty/?/init.lua;/usr/local/lualib/?.lua;;'
package.cpath = '/var/www/web/my-openresty/?.so;/usr/local/lualib/?.so;;'

local Test = require('app.utils.test')
describe = Test.describe; it = Test.it; assert = Test.assert; before_each = Test.before_each

-- Mock ngx for standalone testing
if not ngx then ngx = { log = function() end, ERR = 4, WARN = 3, INFO = 2, DEBUG = 1, now = function() return 1000 end, time = function() return 1000 end, worker = { pid = function() return 1 end } } end
if not ngx.shared then ngx.shared = { my_resty_cache = { get = function() end, set = function() end, delete = function() end, incr = function() return 1 end } } end

describe('Model Module', function()
    describe('new()', function()
        it('should create model instance', function()
            local Model = require('app.core.Model')
            local m = Model:new()
            assert.is_not_nil(m)
            assert.is_not_nil(m._db)
            assert.is_not_nil(m._config)
        end)

        it('should create instance with default prefix', function()
            local Model = require('app.core.Model')
            local m = Model:new()
            assert.is_string(m._prefix)
        end)
    end)

    describe('set_table()', function()
        it('should set table name', function()
            local Model = require('app.core.Model')
            local m = Model:new()
            m:set_table('users')
            assert.equals('users', m.table_name)
        end)

        it('should return self for chaining', function()
            local Model = require('app.core.Model')
            local m = Model:new()
            local ret = m:set_table('users')
            assert.equals(ret, m)
        end)
    end)

    describe('get_full_table_name()', function()
        it('should return table name without prefix', function()
            local Model = require('app.core.Model')
            local m = Model:new()
            m:set_table('users')
            assert.equals('users', m:get_full_table_name())
        end)

        it('should return table name with prefix', function()
            local Model = require('app.core.Model')
            local m = Model:new()
            m:set_table('users')
            m:table_prefix('app_')
            assert.equals('app_users', m:get_full_table_name())
        end)
    end)

    describe('table_prefix()', function()
        it('should set and get prefix', function()
            local Model = require('app.core.Model')
            local m = Model:new()
            m:table_prefix('pre_')
            assert.equals('pre_', m:get_prefix())
        end)
    end)

    describe('SQL generation via get_all()', function()
        it('should generate SELECT * FROM table', function()
            -- Mock query to capture SQL
            local Model = require('app.core.Model')
            local m = Model:new()
            m:set_table('users')
            local captured_sql = nil
            m.query = function(self, sql) captured_sql = sql; return {} end
            m:get_all()
            assert.is_true(captured_sql:match('^SELECT %* FROM users'))
        end)

        it('should include WHERE clause', function()
            local Model = require('app.core.Model')
            local m = Model:new()
            m:set_table('users')
            local captured_sql = nil
            m.query = function(self, sql) captured_sql = sql; return {} end
            m:get_all({status = 1})
            assert.is_true(captured_sql:match('WHERE'))
            assert.is_true(captured_sql:match('status = 1'))
        end)

        it('should include LIMIT and OFFSET', function()
            local Model = require('app.core.Model')
            local m = Model:new()
            m:set_table('users')
            local captured_sql = nil
            m.query = function(self, sql) captured_sql = sql; return {} end
            m:get_all(nil, 10, 20)
            assert.is_true(captured_sql:match('LIMIT 10'))
            assert.is_true(captured_sql:match('OFFSET 20'))
        end)
    end)

    describe('get_by_id()', function()
        it('should generate SELECT with id', function()
            local Model = require('app.core.Model')
            local m = Model:new()
            m:set_table('users')
            local captured_sql = nil
            m.query = function(self, sql) captured_sql = sql; return {{id=1, name='test'}} end
            local result = m:get_by_id(1)
            assert.is_true(captured_sql:match('WHERE id = 1'))
            assert.is_not_nil(result)
            assert.equals(1, result.id)
        end)

        it('should return nil when no result', function()
            local Model = require('app.core.Model')
            local m = Model:new()
            m:set_table('users')
            m.query = function(self, sql) return nil end
            local result = m:get_by_id(999)
            assert.is_nil(result)
        end)
    end)

    describe('insert()', function()
        it('should generate INSERT SQL', function()
            local Model = require('app.core.Model')
            local m = Model:new()
            m:set_table('users')
            local captured_sql = nil
            m.query = function(self, sql) captured_sql = sql; return {insert_id = 1} end
            local id = m:insert({name = 'John', email = 'john@test.com'})
            assert.is_true(captured_sql:match('^INSERT INTO'))
            assert.is_true(captured_sql:match('name'))
            assert.is_true(captured_sql:match('email'))
            assert.equals(1, id)
        end)

        it('should return false for empty data', function()
            local Model = require('app.core.Model')
            local m = Model:new()
            m:set_table('users')
            local result = m:insert({})
            assert.is_false(result)
        end)

        it('should escape string values', function()
            local Model = require('app.core.Model')
            local m = Model:new()
            m:set_table('users')
            local captured_sql = nil
            m.query = function(self, sql) captured_sql = sql; return {insert_id = 1} end
            m:insert({name = "O'Brien"})
            assert.is_true(captured_sql:match("O''Brien"))
        end)
    end)

    describe('update()', function()
        it('should generate UPDATE SQL', function()
            local Model = require('app.core.Model')
            local m = Model:new()
            m:set_table('users')
            local captured_sql = nil
            m.query = function(self, sql) captured_sql = sql; return {} end
            m:update({name = 'New Name'}, {id = 1})
            assert.is_true(captured_sql:match('^UPDATE users'))
            assert.is_true(captured_sql:match("name = 'New Name'"))
            assert.is_true(captured_sql:match('id = 1'))
        end)

        it('should handle raw string where', function()
            local Model = require('app.core.Model')
            local m = Model:new()
            m:set_table('users')
            local captured_sql = nil
            m.query = function(self, sql) captured_sql = sql; return {} end
            m:update({name = 'Test'}, 'id = 5')
            assert.is_true(captured_sql:match('WHERE id = 5'))
        end)
    end)

    describe('delete()', function()
        it('should generate DELETE SQL', function()
            local Model = require('app.core.Model')
            local m = Model:new()
            m:set_table('users')
            local captured_sql = nil
            m.query = function(self, sql) captured_sql = sql; return {} end
            m:delete({id = 1})
            assert.is_true(captured_sql:match('^DELETE FROM users'))
            assert.is_true(captured_sql:match('id = 1'))
        end)
    end)

    describe('count()', function()
        it('should generate COUNT SQL', function()
            local Model = require('app.core.Model')
            local m = Model:new()
            m:set_table('users')
            local captured_sql = nil
            m.query = function(self, sql) captured_sql = sql; return {{cnt = 5}} end
            local cnt = m:count()
            assert.is_true(captured_sql:match('COUNT%(%*%)'))
            assert.equals(5, cnt)
        end)

        it('should return 0 on no results', function()
            local Model = require('app.core.Model')
            local m = Model:new()
            m:set_table('users')
            m.query = function(self, sql) return nil end
            assert.equals(0, m:count())
        end)
    end)

    describe('query_one()', function()
        it('should return first row', function()
            local Model = require('app.core.Model')
            local m = Model:new()
            m:set_table('users')
            m.query = function(self, sql) return {{id=1}} end
            local row = m:query_one('SELECT 1')
            assert.equals(1, row.id)
        end)
    end)

    describe('insert_batch()', function()
        it('should generate batch INSERT SQL', function()
            local Model = require('app.core.Model')
            local m = Model:new()
            m:set_table('users')
            local captured_sql = nil
            m.query = function(self, sql) captured_sql = sql; return {} end
            m:insert_batch({{name='A', email='a@t.com'}, {name='B', email='b@t.com'}})
            assert.is_true(captured_sql:match('INSERT INTO'))
            assert.is_true(captured_sql:match("'A'"))
            assert.is_true(captured_sql:match("'B'"))
        end)

        it('should return false for empty list', function()
            local Model = require('app.core.Model')
            local m = Model:new()
            m:set_table('users')
            assert.is_false(m:insert_batch({}))
        end)
    end)

    describe('JOIN methods', function()
        it('should create query builder on join', function()
            local Model = require('app.core.Model')
            local m = Model:new()
            m:set_table('users')
            local ret = m:left_join('orders')
            assert.equals(ret, m)
            assert.is_not_nil(m._query_builder)
        end)

        it('should generate JOIN SQL via get_all_join', function()
            local Model = require('app.core.Model')
            local m = Model:new()
            m:set_table('users')
            local captured_sql = nil
            m.query = function(self, sql) captured_sql = sql; return {} end
            m:left_join('orders'):on('id', 'user_id')
            m:get_all_join({fields = 'users.name, orders.total', limit = 10})
            assert.is_true(captured_sql:match('LEFT JOIN'))
            assert.is_true(captured_sql:match('users%.name'))
        end)
    end)
end)
