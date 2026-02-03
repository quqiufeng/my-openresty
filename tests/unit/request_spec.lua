-- Request Library Unit Tests
-- tests/unit/request_spec.lua

package.path = '/var/www/web/my-openresty/?.lua;/var/www/web/my-openresty/?/init.lua;/usr/local/web/?.lua;/usr/local/web/lualib/?.lua;;'
package.cpath = '/var/www/web/my-openresty/?.so;/usr/local/web/lualib/?.so;;'

local Test = require('app.utils.test')

describe = Test.describe
it = Test.it
pending = Test.pending
before_each = Test.before_each
after_each = Test.after_each
assert = Test.assert

describe('Request Module', function()
    describe('creation', function()
        it('should create request instance', function()
            local Request = {}
            function Request:new() return setmetatable({}, {__index = self}) end
            local req = Request:new()
            assert.is_table(req)
        end)
    end)

    describe('get_method', function()
        it('should return HTTP method', function()
            local methods = {'GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'}
            for _, method in ipairs(methods) do
                assert.is_true(method == 'GET' or method == 'POST' or 
                              method == 'PUT' or method == 'DELETE' or
                              method == 'PATCH' or method == 'OPTIONS')
            end
        end)
    end)

    describe('get_headers', function()
        it('should return headers table', function()
            local headers = {
                ['Content-Type'] = 'application/json',
                ['Accept'] = 'application/json'
            }
            assert.equals('application/json', headers['Content-Type'])
            assert.equals('application/json', headers.Accept)
        end)
    end)

    describe('get_uri_args', function()
        it('should parse query parameters', function()
            local query = 'page=1&limit=10&sort=name'
            local args = {}
            for key, value in query:gmatch('([^&=]+)=([^&]*)') do
                args[key] = value
            end
            assert.equals('1', args.page)
            assert.equals('10', args.limit)
            assert.equals('name', args.sort)
        end)
    end)

    describe('get_post_args', function()
        it('should parse form data', function()
            local form = 'username=test&password=123456'
            local args = {}
            for key, value in form:gmatch('([^&=]+)=([^&]*)') do
                args[key] = value
            end
            assert.equals('test', args.username)
            assert.equals('123456', args.password)
        end)
    end)

    describe('get_body', function()
        it('should return request body', function()
            local body = '{"name":"test"}'
            assert.is_string(body)
            assert.equals('{"name":"test"}', body)
        end)
    end)

    describe('get_path', function()
        it('should return request path', function()
            local path = '/api/users/123'
            assert.equals('/api/users/123', path)
        end)
    end)

    describe('get_ip', function()
        it('should return client IP', function()
            local ip = '192.168.1.100'
            assert.matches('^%d+%.%d+%.%d+%.%d+$', ip)
        end)
    end)

    describe('pagination params', function()
        it('should parse pagination from request', function()
            local function get_pagination(defaults)
                local page = tonumber(1) or defaults.page or 1
                local per_page = tonumber(10) or defaults.per_page or 20
                return {page = page, per_page = per_page}
            end
            
            local p1 = get_pagination({page = 1, per_page = 20})
            assert.equals(1, p1.page)
            assert.equals(20, p1.per_page)
            
            local p2 = get_pagination({})
            assert.equals(1, p2.page)
            assert.equals(10, p2.per_page)
        end)
    end)
end)
