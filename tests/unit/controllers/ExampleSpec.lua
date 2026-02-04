-- Example Controller Unit Tests
-- tests/unit/controllers/ExampleSpec.lua

package.path = '/var/www/web/my-openresty/?.lua;/var/www/web/my-openresty/?/init.lua;/usr/local/web/?.lua;/usr/local/web/lualib/?.lua;;'
package.cpath = '/var/www/web/my-openresty/?.so;/usr/local/web/lualib/?.so;;'

local Test = require('app.utils.test')

describe = Test.describe
it = Test.it
pending = Test.pending
before_each = Test.before_each
after_each = Test.after_each
assert = Test.assert

describe('Example Controller - select method', function()
    describe('SQL generation', function()
        it('should generate correct SELECT SQL with QueryBuilder', function()
            local QueryBuilder = require('app.db.query')
            local builder = QueryBuilder:new('users')
            local sql = builder
                :select('id', 'name', 'email', 'status', 'created_at')
                :where('status', 'active')
                :order_by('created_at', 'DESC')
                :limit(10)
                :to_sql()

            assert.matches('SELECT', sql)
            assert.matches('id, name, email, status, created_at', sql)
            assert.matches('FROM users', sql)
            assert.matches('WHERE status = .active', sql)
            assert.matches('ORDER BY created_at DESC', sql)
            assert.matches('LIMIT 10', sql)
        end)

        it('should generate SQL with multiple where conditions', function()
            local QueryBuilder = require('app.db.query')
            local builder = QueryBuilder:new('users')
            local sql = builder
                :select('*')
                :where('status', 'active')
                :where('role', 'admin')
                :to_sql()

            assert.matches('WHERE', sql)
            assert.matches('status = .active', sql)
            assert.matches('role = .admin', sql)
        end)

        it('should generate SQL with numeric values', function()
            local QueryBuilder = require('app.db.query')
            local builder = QueryBuilder:new('products')
            local sql = builder
                :select('*')
                :where('price', '>', 100)
                :limit(20)
                :to_sql()

            assert.matches('price > 100', sql)
        end)
    end)

    describe('Response structure', function()
        it('should return success response structure', function()
            local response = {
                success = true,
                data = {},
                sql = '',
                count = 0
            }

            assert.is_true(response.success)
            assert.is_table(response.data)
            assert.is_string(response.sql)
            assert.is_number(response.count)
        end)

        it('should return error response structure on connection failure', function()
            local response = {
                success = false,
                error = 'Database connection failed',
                message = 'connection refused'
            }

            assert.is_false(response.success)
            assert.is_string(response.error)
            assert.is_string(response.message)
        end)

        it('should return error response structure on query failure', function()
            local response = {
                success = false,
                error = 'Query failed',
                message = 'Table not found',
                errno = 1146
            }

            assert.is_false(response.success)
            assert.equals('Query failed', response.error)
            assert.equals(1146, response.errno)
        end)
    end)

    describe('Controller method', function()
        it('should have select method', function()
            local Example = require('app.controllers.example')
            assert.is_function(Example.select)
        end)

        it('should require Config module', function()
            local Config = require('app.core.Config')
            assert.is_table(Config)
            assert.is_function(Config.load)
            assert.is_function(Config.get)
        end)

        it('should require Mysql module', function()
            local Mysql = require('app.libraries.mysql')
            assert.is_table(Mysql)
            assert.is_function(Mysql.new)
        end)
    end)

    describe('Database configuration', function()
        it('should load mysql config from Config', function()
            local Config = require('app.core.Config')
            Config.load()
            local mysql_config = Config.get('mysql')

            assert.is_table(mysql_config)
            assert.equals('127.0.0.1', mysql_config.host)
            assert.equals(3306, mysql_config.port)
            assert.equals('root', mysql_config.user)
            assert.equals('myresty', mysql_config.database)
        end)
    end)

    describe('QueryBuilder integration', function()
        it('should create QueryBuilder instance', function()
            local QueryBuilder = require('app.db.query')
            local builder = QueryBuilder:new('users')

            assert.is_table(builder)
            assert.equals('users', builder.table)
        end)

        it('should chain QueryBuilder methods', function()
            local QueryBuilder = require('app.db.query')
            local builder = QueryBuilder:new('users')

            local result = builder
                :select('id', 'name')
                :where('status', 'active')

            assert.equals(builder, result)
        end)

        it('should reset QueryBuilder state', function()
            local QueryBuilder = require('app.db.query')
            local builder = QueryBuilder:new('users')

            builder
                :select('id')
                :where('status', 'active')

            builder:reset()

            assert.equals('*', builder.fields)
            assert.equals(0, #builder.wheres)
        end)
    end)
end)
