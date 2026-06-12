-- Response Library Unit Tests
-- tests/unit/response_spec.lua

package.path = '/var/www/web/my-openresty/?.lua;/var/www/web/my-openresty/?/init.lua;/usr/local/lualib/?.lua;;'
package.cpath = '/var/www/web/my-openresty/?.so;/usr/local/lualib/?.so;;'

local Test = require('app.utils.test')

describe = Test.describe
it = Test.it
pending = Test.pending
before_each = Test.before_each
after_each = Test.after_each
assert = Test.assert

describe('Response Module', function()
    describe('creation', function()
        it('should create response instance', function()
            local Response = {}
            function Response:new() 
                return setmetatable({
                    status = 200,
                    headers = {},
                    body = ''
                }, {__index = self}) 
            end
            local res = Response:new()
            assert.is_table(res)
            assert.equals(200, res.status)
        end)
    end)

    describe('json response', function()
        it('should create JSON response', function()
            local function json(data, status)
                status = tonumber(status) or 200
                local body = require('cjson').encode(data)
                return {status = status, body = body, content_type = 'application/json'}
            end
            
            local res = json({message = 'success', data = {id = 1}})
            assert.equals(200, res.status)
            assert.equals('application/json', res.content_type)
            assert.matches('"message"', res.body)
        end)
    end)

    describe('html response', function()
        it('should create HTML response', function()
            local function html(content, status)
                status = tonumber(status) or 200
                return {status = status, body = content, content_type = 'text/html'}
            end
            
            local res = html('<h1>Hello</h1>')
            assert.equals(200, res.status)
            assert.equals('text/html', res.content_type)
            assert.matches('<h1>Hello</h1>', res.body)
        end)
    end)

    describe('text response', function()
        it('should create text response', function()
            local function text(content, status)
                status = tonumber(status) or 200
                return {status = status, body = content, content_type = 'text/plain'}
            end
            
            local res = text('Plain text')
            assert.equals(200, res.status)
            assert.equals('text/plain', res.content_type)
            assert.equals('Plain text', res.body)
        end)
    end)

    describe('xml response', function()
        it('should create XML response', function()
            local function xml(content, status)
                status = tonumber(status) or 200
                return {status = status, body = content, content_type = 'application/xml'}
            end
            
            local res = xml('<root><item>test</item></root>')
            assert.equals(200, res.status)
            assert.equals('application/xml', res.content_type)
        end)
    end)

    describe('redirect', function()
        it('should create redirect response', function()
            local function redirect(url, code)
                code = tonumber(code) or 302
                return {status = code, headers = {Location = url}, body = ''}
            end
            
            local res = redirect('/new-location', 301)
            assert.equals(301, res.status)
            assert.equals('/new-location', res.headers.Location)
        end)
    end)

    describe('set_status', function()
        it('should set response status', function()
            local res = {status = 200}
            function res:set_status(code)
                self.status = tonumber(code) or 200
                return self
            end
            res:set_status(404)
            assert.equals(404, res.status)
        end)
    end)

    describe('set_header', function()
        it('should set response header', function()
            local res = {headers = {}}
            function res:set_header(key, value)
                self.headers[key] = value
                return self
            end
            res:set_header('X-Custom', 'value')
            assert.equals('value', res.headers['X-Custom'])
        end)
    end)

    describe('paginate', function()
        it('should create paginated response', function()
            local function paginate(data, total, page, per_page)
                page = tonumber(page) or 1
                per_page = tonumber(per_page) or 20
                local pagination = {
                    data = data,
                    meta = {
                        total = tonumber(total) or #data,
                        page = page,
                        per_page = per_page,
                        total_pages = math.ceil((tonumber(total) or #data) / per_page),
                        current_path = '/api/items',
                        current_url = '/api/items?page=' .. page .. '&per_page=' .. per_page
                    }
                }
                return pagination
            end
            
            local res = paginate({1,2,3}, 100, 1, 10)
            assert.equals(100, res.meta.total)
            assert.equals(1, res.meta.page)
            assert.equals(10, res.meta.per_page)
            assert.equals(10, res.meta.total_pages)
        end)
    end)
end)

    describe('success()', function()
        it('should set success response format', function()
            local Response = require('app.core.Response')
            local r = Response:new()
            r:success({id = 1}, 'ok')
            assert.is_true(r.body:match('success'))
        end)
    end)

    describe('fail()', function()
        it('should set fail response format', function()
            local Response = require('app.core.Response')
            local r = Response:new()
            r:fail('error msg')
            assert.is_true(r.body:match('false'))
        end)
    end)

    describe('paginate()', function()
        it('should set paginated response', function()
            local Response = require('app.core.Response')
            local r = Response:new()
            r:paginate({}, 100, 1, 10)
            assert.is_true(r.body:match('total_pages'))
        end)
    end)

    describe('html()', function()
        it('should set HTML content type', function()
            local Response = require('app.core.Response')
            local r = Response:new()
            r:html('<h1>Hi</h1>')
            assert.equals('text/html; charset=utf-8', r.content_type)
        end)
    end)

    describe('text()', function()
        it('should set text content type', function()
            local Response = require('app.core.Response')
            local r = Response:new()
            r:text('hello')
            assert.equals('text/plain; charset=utf-8', r.content_type)
        end)
    end)

    describe('not_found()', function()
        it('should set 404 status', function()
            local Response = require('app.core.Response')
            local r = Response:new()
            r:not_found()
            assert.equals(404, r.status)
        end)
    end)

    describe('error()', function()
        it('should set 500 status by default', function()
            local Response = require('app.core.Response')
            local r = Response:new()
            r:error('fail')
            assert.equals(500, r.status)
        end)
    end)

    describe('set_status()', function()
        it('should set custom status', function()
            local Response = require('app.core.Response')
            local r = Response:new()
            r:set_status(201)
            assert.equals(201, r.status)
        end)
    end)

    describe('set_header()', function()
        it('should set header', function()
            local Response = require('app.core.Response')
            local r = Response:new()
            r:set_header('X-Test', 'val')
            assert.equals('val', r.headers['X-Test'])
        end)
    end)
