-- Controller Unit Tests
package.path = '/var/www/web/my-openresty/?.lua;/var/www/web/my-openresty/?/init.lua;/usr/local/lualib/?.lua;;'
package.cpath = '/var/www/web/my-openresty/?.so;/usr/local/lualib/?.so;;'
local Test = require('app.utils.test')
describe = Test.describe; it = Test.it; assert = Test.assert; before_each = Test.before_each

if not ngx then ngx = { log = function() end, ERR = 4, var = {}, req = { get_headers = function() return {} end, get_method = function() return 'GET' end, get_uri_args = function() return {} end, read_body = function() end, get_post_args = function() return {} end, get_body_data = function() return nil end }, header = {}, status = 200, say = function() end, redirect = function() end, now = function() return 1000 end, time = function() return 1000 end, worker = { pid = function() return 1 end } } end
if not ngx.shared then ngx.shared = { my_resty_cache = { get = function() return nil end, set = function() return true end, delete = function() return true end } } end

describe('Controller Module', function()
    describe('new()', function()
        it('should create controller instance', function()
            local Controller = require('app.core.Controller')
            local c = Controller:new()
            assert.is_not_nil(c)
        end)

        it('should create instance with load function', function()
            local Controller = require('app.core.Controller')
            local c = Controller:new()
            assert.is_not_nil(c.load)
            assert.is_function(c.load)
        end)
    end)

    describe('__construct()', function()
        it('should initialize request and response', function()
            local Controller = require('app.core.Controller')
            local c = Controller:new()
            c:__construct()
            assert.is_not_nil(c.request)
            assert.is_not_nil(c.response)
            assert.is_not_nil(c.config)
        end)
    end)

    describe('load_model()', function()
        it('should accept model name', function()
            local Controller = require('app.core.Controller')
            local c = Controller:new()
            c.loaded = {}
            c.load_model = Controller.load_model
            -- Just verify the method exists and returns nil for unknown model
            local m = c:load_model('nonexistent_model')
            assert.is_nil(m)
        end)
    end)

    describe('json/success/fail', function()
        it('should have json method', function()
            local Controller = require('app.core.Controller')
            local c = Controller:new()
            assert.is_function(c.json)
        end)

        it('should have success method', function()
            local Controller = require('app.core.Controller')
            local c = Controller:new()
            assert.is_function(c.success)
        end)

        it('should have fail method', function()
            local Controller = require('app.core.Controller')
            local c = Controller:new()
            assert.is_function(c.fail)
        end)
    end)

    describe('paginate()', function()
        it('should have paginate method', function()
            local Controller = require('app.core.Controller')
            local c = Controller:new()
            assert.is_function(c.paginate)
        end)
    end)

    describe('redirect()', function()
        it('should have redirect method', function()
            local Controller = require('app.core.Controller')
            local c = Controller:new()
            assert.is_function(c.redirect)
        end)
    end)

    describe('is_ajax()', function()
        it('should have is_ajax method', function()
            local Controller = require('app.core.Controller')
            local c = Controller:new()
            assert.is_function(c.is_ajax)
        end)
    end)

    describe('cache/uncache', function()
        it('should have cache method', function()
            local Controller = require('app.core.Controller')
            local c = Controller:new()
            assert.is_function(c.cache)
        end)

        it('should have uncache method', function()
            local Controller = require('app.core.Controller')
            local c = Controller:new()
            assert.is_function(c.uncache)
        end)

        it('should have remember method', function()
            local Controller = require('app.core.Controller')
            local c = Controller:new()
            assert.is_function(c.remember)
        end)
    end)

    describe('site_url()', function()
        it('should generate site URL', function()
            local Controller = require('app.core.Controller')
            local c = Controller:new()
            c.config = { host = 'example.com', port = 8080 }
            local url = c:site_url('/users')
            assert.is_true(url:match('example.com'))
            assert.is_true(url:match('8080'))
            assert.is_true(url:match('/users'))
        end)
    end)
end)
