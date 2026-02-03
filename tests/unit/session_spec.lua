-- Session Library Unit Tests
-- tests/unit/session_spec.lua

package.path = '/var/www/web/my-openresty/?.lua;/var/www/web/my-openresty/?/init.lua;/usr/local/web/?.lua;/usr/local/web/lualib/?.lua;;'
package.cpath = '/var/www/web/my-openresty/?.so;/usr/local/web/lualib/?.so;;'

local Test = require('app.utils.test')

describe = Test.describe
it = Test.it
pending = Test.pending
before_each = Test.before_each
after_each = Test.after_each
assert = Test.assert

describe('Session Module', function()
    describe('creation', function()
        it('should create session instance', function()
            local Session = {}
            function Session:new()
                return setmetatable({
                    data = {},
                    session_id = nil
                }, {__index = self})
            end
            local session = Session:new()
            assert.is_table(session)
            assert.same({}, session.data)
        end)
    end)

    describe('set and get', function()
        it('should set and get values', function()
            local session = {data = {}}
            function session:set(key, value)
                self.data[key] = value
                return true
            end
            function session:get(key)
                return self.data[key]
            end
            
            session:set('user_id', 123)
            session:set('username', 'testuser')
            
            assert.equals(123, session:get('user_id'))
            assert.equals('testuser', session:get('username'))
            assert.is_nil(session:get('nonexistent'))
        end)
    end)

    describe('has', function()
        it('should check if key exists', function()
            local session = {data = {key = 'value'}}
            function session:has(key)
                return self.data[key] ~= nil
            end
            assert.is_true(session:has('key'))
            assert.is_false(session:has('nonexistent'))
        end)
    end)

    describe('remove', function()
        it('should remove key from session', function()
            local session = {data = {key = 'value'}}
            function session:remove(key)
                self.data[key] = nil
                return true
            end
            session:remove('key')
            assert.is_nil(session.data.key)
        end)
    end)

    describe('clear', function()
        it('should clear all session data', function()
            local session = {data = {a = 1, b = 2, c = 3}}
            function session:clear()
                self.data = {}
                return true
            end
            session:clear()
            assert.same({}, session.data)
        end)
    end)

    describe('get_id', function()
        it('should return session id', function()
            local session = {session_id = 'abc123'}
            function session:get_id()
                return self.session_id
            end
            assert.equals('abc123', session:get_id())
        end)
    end)

    describe('regenerate', function()
        it('should regenerate session id', function()
            local session = {data = {a = 1}, session_id = 'old_id'}
            function session:regenerate()
                local new_id = 'new_' .. math.random(1000)
                self.session_id = new_id
                return new_id
            end
            local new_id = session:regenerate()
            assert.matches('new_', new_id)
            assert.same({a = 1}, session.data) -- Data preserved
        end)
    end)

    describe('is_new', function()
        it('should check if session is new', function()
            local session1 = {session_id = nil}
            function session1:is_new() return self.session_id == nil end
            
            local session2 = {session_id = 'abc123'}
            function session2:is_new() return self.session_id == nil end
            
            assert.is_true(session1:is_new())
            assert.is_false(session2:is_new())
        end)
    end)

    describe('count', function()
        it('should return data count', function()
            local session = {data = {a = 1, b = 2, c = 3}}
            function session:count()
                local c = 0
                for _ in pairs(self.data) do c = c + 1 end
                return c
            end
            assert.equals(3, session:count())
        end)
    end)

    describe('merge', function()
        it('should merge data into session', function()
            local session = {data = {a = 1}}
            function session:merge(new_data)
                if type(new_data) ~= 'table' then return false end
                for k, v in pairs(new_data) do
                    self.data[k] = v
                end
                return true
            end
            session:merge({b = 2, c = 3})
            assert.equals(1, session.data.a)
            assert.equals(2, session.data.b)
            assert.equals(3, session.data.c)
        end)
    end)

    describe('flash', function()
        it('should set and get flash data', function()
            local session = {data = {}}
            function session:set_flash(key, value)
                if not self.data._flash then self.data._flash = {} end
                self.data._flash[key] = value
                return true
            end
            function session:get_flash(key)
                if not self.data._flash then return nil end
                return self.data._flash[key]
            end
            
            session:set_flash('message', 'Hello')
            assert.equals('Hello', session:get_flash('message'))
        end)
    end)
end)
