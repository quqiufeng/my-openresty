-- Router Library Unit Tests
-- tests/unit/router_spec.lua

package.path = '/var/www/web/my-openresty/?.lua;/var/www/web/my-openresty/?/init.lua;/usr/local/web/?.lua;/usr/local/web/lualib/?.lua;;'
package.cpath = '/var/www/web/my-openresty/?.so;/usr/local/web/lualib/?.so;;'

local Test = require('app.utils.test')

describe = Test.describe
it = Test.it
pending = Test.pending
before_each = Test.before_each
after_each = Test.after_each
assert = Test.assert

local function create_router()
    local routes = {
        GET = {},
        POST = {},
        PUT = {},
        DELETE = {},
        PATCH = {},
        OPTIONS = {}
    }
    
    local function compile_pattern(pattern)
        local params = {}
        local function repl(m)
            table.insert(params, m:sub(2, -2))
            return '([^/]+)'
        end
        local regex = '^' .. string.gsub(pattern, '({[^}]+})', repl) .. '$'
        return regex, params
    end
    
    local function add_route(method, pattern, handler)
        if not routes[method] then routes[method] = {} end
        local compiled, params = compile_pattern(pattern)
        table.insert(routes[method], {
            pattern = compiled,
            params = params,
            handler = handler
        })
    end
    
    local function match(uri, method)
        local method_routes = routes[method] or {}
        for _, route in ipairs(method_routes) do
            if string.match(uri, route.pattern) then
                local params = {}
                local i = 1
                for param in string.gmatch(uri, '([^/]+)') do
                    if route.params[i] then
                        params[route.params[i]] = param
                    end
                    i = i + 1
                end
                return route.handler, params
            end
        end
        return nil, nil
    end
    
    return {
        get = function(pattern, handler) add_route('GET', pattern, handler) return {get=function() end} end,
        post = function(pattern, handler) add_route('POST', pattern, handler) return {post=function() end} end,
        put = function(pattern, handler) add_route('PUT', pattern, handler) end,
        delete = function(pattern, handler) add_route('DELETE', pattern, handler) end,
        match = match
    }
end

describe('Router Module', function()
    describe('creation', function()
        it('should create router instance', function()
            local router = create_router()
            assert.is_table(router)
            assert.is_function(router.get)
            assert.is_function(router.post)
        end)
    end)

    describe('route registration', function()
        it('should register GET route', function()
            local router = create_router()
            router:get('/users', function() end)
            local handler, params = router:match('/users', 'GET')
            assert.is_function(handler)
        end)

        it('should register POST route', function()
            local router = create_router()
            router:post('/users', function() end)
            local handler = router:match('/users', 'POST')
            assert.is_function(handler)
        end)
    end)

    describe('parameter extraction', function()
        it('should extract single parameter', function()
            local router = create_router()
            router:get('/users/{id}', function() end)
            local handler, params = router:match('/users/123', 'GET')
            assert.is_function(handler)
            assert.equals('123', params.id)
        end)

        it('should extract multiple parameters', function()
            local router = create_router()
            router:get('/users/{user_id}/posts/{post_id}', function() end)
            local handler, params = router:match('/users/456/posts/789', 'GET')
            assert.is_function(handler)
            assert.equals('456', params.user_id)
            assert.equals('789', params.post_id)
        end)
    end)

    describe('route matching', function()
        it('should match exact path', function()
            local router = create_router()
            router:get('/api/users', function() end)
            local handler = router:match('/api/users', 'GET')
            assert.is_function(handler)
        end)

        it('should not match wrong method', function()
            local router = create_router()
            router:get('/users', function() end)
            local handler = router:match('/users', 'POST')
            assert.is_nil(handler)
        end)

        it('should not match non-existent route', function()
            local router = create_router()
            router:get('/users', function() end)
            local handler = router:match('/posts', 'GET')
            assert.is_nil(handler)
        end)
    end)
end)
