-- Middleware Unit Tests
package.path = '/var/www/web/my-openresty/?.lua;/var/www/web/my-openresty/?/init.lua;/usr/local/lualib/?.lua;;'
package.cpath = '/var/www/web/my-openresty/?.so;/usr/local/lualib/?.so;;'
local Test = require('app.utils.test')
describe = Test.describe; it = Test.it; assert = Test.assert

if not ngx then ngx = { log = function() end, ERR = 4, WARN = 3, INFO = 2, var = { uri = '/' }, exit = function() end, header = {}, status = 200, say = function() end } end

describe('Middleware Module', function()
    describe('module structure', function()
        it('should export PHASES', function()
            local Middleware = require('app.middleware')
            assert.is_not_nil(Middleware.PHASES)
            assert.is_not_nil(Middleware.PHASES.INIT)
            assert.is_not_nil(Middleware.PHASES.ACCESS)
            assert.is_not_nil(Middleware.PHASES.LOG)
        end)

        it('should have setup method', function()
            local Middleware = require('app.middleware')
            assert.is_function(Middleware.setup)
        end)

        it('should have run method', function()
            local Middleware = require('app.middleware')
            assert.is_function(Middleware.run)
        end)

        it('should have run_phase method', function()
            local Middleware = require('app.middleware')
            assert.is_function(Middleware.run_phase)
        end)

        it('should have register method', function()
            local Middleware = require('app.middleware')
            assert.is_function(Middleware.register)
        end)

        it('should have list method', function()
            local Middleware = require('app.middleware')
            assert.is_function(Middleware.list)
        end)
    end)

    describe('setup()', function()
        it('should accept config table', function()
            local Middleware = require('app.middleware')
            Middleware:setup({
                { name = 'logger', phase = 'log', options = { level = 'info' } }
            })
            local config = Middleware:get_config()
            assert.is_table(config)
            assert.equals('logger', config[1].name)
        end)
    end)

    describe('register()', function()
        it('should register middleware', function()
            local Middleware = require('app.middleware')
            Middleware:register('test_mw', 'access', function() return true end, {})
            local config = Middleware:get_config()
            local found = false
            for _, c in ipairs(config) do
                if c.name == 'test_mw' then found = true end
            end
            assert.is_true(found)
        end)
    end)

    describe('match_routes()', function()
        it('should match exact routes', function()
            local Middleware = require('app.middleware')
            ngx.var.uri = '/api/users'
            local matched = Middleware:match_routes({'/api/*'})
            assert.is_true(matched)
        end)

        it('should not match non-matching routes', function()
            local Middleware = require('app.middleware')
            ngx.var.uri = '/health'
            local matched = Middleware:match_routes({'/api/*'})
            assert.is_false(matched)
        end)
    end)

    describe('enable/disable', function()
        it('should disable middleware', function()
            local Middleware = require('app.middleware')
            Middleware:register('test_disable', 'access', function() return true end)
            Middleware:disable('test_disable')
            local config = Middleware:get_config()
            for _, c in ipairs(config) do
                if c.name == 'test_disable' then
                    assert.is_false(c.enabled)
                end
            end
        end)

        it('should enable middleware', function()
            local Middleware = require('app.middleware')
            Middleware:register('test_enable', 'access', function() return true end)
            Middleware:disable('test_enable')
            Middleware:enable('test_enable')
            local config = Middleware:get_config()
            for _, c in ipairs(config) do
                if c.name == 'test_enable' then
                    assert.is_true(c.enabled)
                end
            end
        end)
    end)

    describe('clear()', function()
        it('should clear all middleware', function()
            local Middleware = require('app.middleware')
            Middleware:register('test_clear', 'access')
            Middleware:clear()
            local config = Middleware:get_config()
            assert.equals(0, #config)
        end)
    end)
end)
