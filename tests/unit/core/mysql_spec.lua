-- MySQL Library Unit Tests
-- Tests mysql.lua config and SQL generation (no actual connection)
package.path = '/var/www/web/my-openresty/?.lua;/var/www/web/my-openresty/?/init.lua;/usr/local/lualib/?.lua;;'
package.cpath = '/var/www/web/my-openresty/?.so;/usr/local/lualib/?.so;;'
local Test = require('app.utils.test')
describe = Test.describe; it = Test.it; assert = Test.assert

if not ngx then ngx = { log = function() end, ERR = 4, WARN = 3 } end

describe('MySQL Library', function()
    describe('module structure', function()
        it('should export _VERSION', function()
            local mysql = require('app.lib.mysql')
            assert.is_not_nil(mysql._VERSION)
        end)

        it('should have new() function', function()
            local mysql = require('app.lib.mysql')
            assert.is_function(mysql.new)
        end)

        it('should have query() function', function()
            local mysql = require('app.lib.mysql')
            assert.is_function(mysql.query)
        end)

        it('should have set_keepalive() function', function()
            local mysql = require('app.lib.mysql')
            assert.is_function(mysql.set_keepalive)
        end)

        it('should have close() function', function()
            local mysql = require('app.lib.mysql')
            assert.is_function(mysql.close)
        end)
    end)

    describe('new()', function()
        it('should return db and config', function()
            local mysql = require('app.lib.mysql')
            local db, config = mysql.new()
            assert.is_not_nil(db)
            assert.is_table(config)
        end)
    end)

    describe('set_keepalive()', function()
        it('should handle nil db', function()
            local mysql = require('app.lib.mysql')
            local ok, err = mysql.set_keepalive(nil)
            assert.is_nil(ok)
            assert.is_not_nil(err)
        end)
    end)
end)
