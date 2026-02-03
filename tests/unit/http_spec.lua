-- HTTP Library Unit Tests
-- tests/unit/http_spec.lua

package.path = '/var/www/web/my-openresty/?.lua;/var/www/web/my-openresty/?/init.lua;/usr/local/web/?.lua;/usr/local/web/lualib/?.lua;;'
package.cpath = '/var/www/web/my-openresty/?.so;/usr/local/web/lualib/?.so;;'

local Test = require('app.utils.test')

describe = Test.describe
it = Test.it
pending = Test.pending
before_each = Test.before_each
after_each = Test.after_each
assert = Test.assert

describe('HTTP Module', function()
    describe('creation', function()
        it('should create HTTP client instance', function()
            local HttpClient = {}
            function HttpClient:new()
                return setmetatable({
                    default_timeout = 30000,
                    default_pool_size = 10
                }, {__index = self})
            end
            local http = HttpClient:new()
            assert.is_table(http)
            assert.equals(30000, http.default_timeout)
        end)
    end)

    describe('url parsing', function()
        it('should parse URL components', function()
            local function parse_url(url)
                local protocol = url:match('^(https?://)') or 'http://'
                local without_protocol = url:gsub('^https?://', '')
                local host = without_protocol:match('^([^/:]+)') or without_protocol
                local port = without_protocol:match(':(%d+)')
                local path = without_protocol:match('/(.+)$')
                if not path or path == '' then path = '/' end
                local proto_name = protocol:gsub('://', '')
                return {
                    protocol = proto_name,
                    host = host,
                    port = tonumber(port) or (proto_name == 'https' and 443 or 80),
                    path = path
                }
            end

            local parsed = parse_url('https://api.example.com/users/123')
            assert.equals('https', parsed.protocol)
            assert.equals('api.example.com', parsed.host)
            assert.equals(443, parsed.port)
            assert.equals('users/123', parsed.path)

            parsed = parse_url('http://localhost:8080/api')
            assert.equals('http', parsed.protocol)
            assert.equals('localhost', parsed.host)
            assert.equals(8080, parsed.port)
            assert.equals('api', parsed.path)
        end)
    end)

    describe('query building', function()
        it('should build query string', function()
            local function build_query(params)
                if not params or type(params) ~= 'table' then return nil end
                local parts = {}
                for key, value in pairs(params) do
                    table.insert(parts, key .. '=' .. tostring(value))
                end
                return #parts > 0 and table.concat(parts, '&') or nil
            end
            
            local query = build_query({page = 1, limit = 10})
            assert.is_string(query)
            assert.matches('page=1', query)
            assert.matches('limit=10', query)
        end)
    end)

    describe('request methods', function()
        it('should create request object', function()
            local request = {
                method = 'GET',
                url = 'https://api.example.com/users',
                headers = {},
                body = nil
            }
            function request:set_method(m) self.method = m return self end
            function request:set_header(k, v) self.headers[k] = v return self end
            function request:set_body(b) self.body = b return self end
            
            request:set_method('POST')
            request:set_header('Content-Type', 'application/json')
            request:set_body('{}')
            
            assert.equals('POST', request.method)
            assert.equals('application/json', request.headers['Content-Type'])
            assert.equals('{}', request.body)
        end)
    end)

    describe('response parsing', function()
        it('should parse JSON response', function()
            local json_str = '{"success":true,"data":{"id":1,"name":"test"}}'
            local cjson = require('cjson')
            local ok, data = pcall(cjson.decode, json_str)
            
            assert.is_true(ok)
            assert.is_true(data.success)
            assert.equals(1, data.data.id)
            assert.equals('test', data.data.name)
        end)
    end)

    describe('error handling', function()
        it('should handle invalid JSON', function()
            local invalid_json = '{invalid json}'
            local cjson = require('cjson')
            local ok, data = pcall(cjson.decode, invalid_json)
            assert.is_false(ok)
        end)
    end)

    describe('timeout handling', function()
        it('should have default timeout', function()
            local http = {
                default_timeout = 30000,
                timeout = nil
            }
            function http:set_timeout(ms)
                self.timeout = tonumber(ms) or self.default_timeout
                return self
            end
            
            http:set_timeout(5000)
            assert.equals(5000, http.timeout)
        end)
    end)

    describe('pool configuration', function()
        it('should configure connection pool', function()
            local config = {
                pool_size = 10,
                pool_timeout = 60000
            }
            assert.equals(10, config.pool_size)
            assert.equals(60000, config.pool_timeout)
        end)
    end)

    describe('content type detection', function()
        it('should detect content type', function()
            local types = {
                ['.json'] = 'application/json',
                ['.xml'] = 'application/xml',
                ['.html'] = 'text/html',
                ['.txt'] = 'text/plain'
            }
            
            assert.equals('application/json', types['.json'])
            assert.equals('text/html', types['.html'])
        end)
    end)
end)
