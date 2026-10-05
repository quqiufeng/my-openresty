-- Framework behaviour tests
-- Exercises real modules (not reimplementations) for the behaviours that
-- were fixed during the audit: routing, response dedup, request caching,
-- per-request instantiation, SQL escaping and QueryBuilder conditions.
-- tests/unit/framework_behavior_spec.lua

package.path = '/var/www/web/my-openresty/?.lua;/var/www/web/my-openresty/?/init.lua;/usr/local/lualib/?.lua;;'
package.cpath = '/var/www/web/my-openresty/?.so;/usr/local/lualib/?.so;;'

local Test = require('app.utils.test')

describe = Test.describe
it = Test.it
before_each = Test.before_each
assert = Test.assert

describe('Router behaviour', function()
    local Router

    before_each(function()
        Router = require('app.core.Router')
        Router:reset_routes()
    end)

    it('matches static routes via exact lookup', function()
        local r = Router:new()
        r:get('/admin/list', 'admin:list')
        local handler, params, captures = Router:match('/admin/list', 'GET')
        assert.equals('admin:list', handler)
        assert.equals(0, #captures)
    end)

    it('matches dynamic routes and extracts params', function()
        local r = Router:new()
        r:get('/users/{id}', 'user:show')
        local handler, params = Router:match('/users/42', 'GET')
        assert.equals('user:show', handler)
        assert.equals('42', params.id)
    end)

    it('does not forward the URI as an action argument for capture-less routes', function()
        local r = Router:new()
        r:post('/admin/update', 'admin:update')
        local _, _, captures = Router:match('/admin/update', 'POST')
        assert.equals(0, #captures)
    end)

    it('de-duplicates repeated registration', function()
        local r = Router:new()
        require('app.routes')(r)
        local once = Router:count_routes()
        require('app.routes')(r)
        require('app.routes')(r)
        assert.equals(once, Router:count_routes())
    end)
end)

describe('Response double-send guard', function()
    it('sends the body only once', function()
        local Response = require('app.core.Response')
        local saved_say = ngx.say
        local calls = 0
        ngx.say = function() calls = calls + 1 end
        local ok = pcall(function()
            local res = Response:new():json({ ok = true })
            res:send()
            res:send()
            assert.is_true(res:is_sent())
        end)
        ngx.say = saved_say
        assert.is_true(ok)
        assert.equals(1, calls)
    end)
end)

describe('Request caching', function()
    before_each(function()
        ngx.ctx = {}
        require('app.core.Request'):reset_cache()
    end)

    it('reuses the same instance within a request', function()
        local Request = require('app.core.Request')
        local r1 = Request:new():fetch()
        local r2 = Request:new():fetch()
        assert.is_true(r1 == r2)
    end)

    it('creates a new instance after reset', function()
        local Request = require('app.core.Request')
        local r1 = Request:new():fetch()
        Request:reset_cache()
        local r2 = Request:new():fetch()
        assert.is_true(r1 ~= r2)
    end)
end)

describe('Loader per-request instantiation', function()
    it('returns fresh model instances', function()
        local Loader = require('app.core.Loader')
        local l = Loader:new()
        local m1 = l:model('UserModel')
        local m2 = l:model('UserModel')
        assert.is_not_nil(m1)
        assert.is_not_nil(m2)
        assert.is_true(m1 ~= m2)
        assert.is_true(m1._db ~= m2._db)
    end)

    it('returns fresh library instances', function()
        local Loader = require('app.core.Loader')
        local l = Loader:new()
        assert.is_true(l:library('session') ~= l:library('session'))
    end)
end)

describe('Model safety', function()
    it('refuses UPDATE without a WHERE clause', function()
        local Model = require('app.core.Model')
        local m = Model:new()
        m:set_table('users')
        assert.is_false(m:update({ name = 'x' }, {}))
        assert.is_false(m:update({ name = 'x' }))
    end)

    it('refuses DELETE without a WHERE clause', function()
        local Model = require('app.core.Model')
        local m = Model:new()
        m:set_table('users')
        assert.is_false(m:delete({}))
        assert.is_false(m:delete())
    end)

    it('escapes quotes when inserting', function()
        local Model = require('app.core.Model')
        local m = Model:new()
        m:set_table('users')
        local sql
        m.query = function(_, s) sql = s; return { insert_id = 1 } end
        m:insert({ name = "O'Brien" })
        assert.is_true(sql:find("O''Brien", 1, true) ~= nil)
    end)
end)

describe('QueryBuilder conditions', function()
    it('builds OR / IN / LIKE clauses', function()
        local QB = require('app.db.query')
        local sql = QB:new('users')
            :where('a', '=', 1)
            :or_where('b', '=', 2)
            :where_in('id', { 1, 2, 3 })
            :like('name', 'john')
            :to_sql()
        assert.is_true(sql:find('OR b = 2', 1, true) ~= nil)
        assert.is_true(sql:find('id IN (1, 2, 3)', 1, true) ~= nil)
        assert.is_true(sql:find("name LIKE '%john%'", 1, true) ~= nil)
    end)

    it('handles an empty IN list without producing invalid SQL', function()
        local QB = require('app.db.query')
        local sql = QB:new('users'):where_in('id', {}):to_sql()
        assert.is_true(sql:find('1 = 0', 1, true) ~= nil)
    end)
end)

describe('Config call compatibility', function()
    it('treats Config.get(k) and Config:get(k) the same', function()
        local Config = require('app.core.Config')
        Config.load()
        assert.is_true(Config.get('mysql') == Config:get('mysql'))
        assert.is_table(Config.get('mysql'))
    end)
end)
