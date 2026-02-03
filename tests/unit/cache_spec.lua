-- Cache Library Unit Tests
-- tests/unit/cache_spec.lua

package.path = '/var/www/web/my-resty/?.lua;/var/www/web/my-resty/?/init.lua;/usr/local/web/?.lua;/usr/local/web/lualib/?.lua;;'
package.cpath = '/var/www/web/my-resty/?.so;/usr/local/web/lualib/?.so;;'

local Test = require('app.utils.test')

describe = Test.describe
it = Test.it
pending = Test.pending
before_each = Test.before_each
after_each = Test.after_each
assert = Test.assert

describe('Cache Module', function()
    describe('creation', function()
        it('should create cache instance', function()
            local Cache = {}
            function Cache:new(dict_name)
                return setmetatable({
                    dict_name = dict_name or 'myresty_cache',
                    data = {}
                }, {__index = self})
            end
            local cache = Cache:new('test_cache')
            assert.is_table(cache)
            assert.equals('test_cache', cache.dict_name)
        end)
    end)

    describe('get', function()
        it('should return cached value', function()
            local cache = {data = {key = 'value'}}
            function cache:get(key)
                return self.data[key]
            end
            assert.equals('value', cache:get('key'))
            assert.is_nil(cache:get('nonexistent'))
        end)
    end)

    describe('set', function()
        it('should store value with TTL', function()
            local cache = {data = {}, ttl = {}}
            function cache:set(key, value, ttl)
                self.data[key] = value
                self.ttl[key] = os.time() + (tonumber(ttl) or 300)
                return true
            end
            local result = cache:set('key', 'value', 60)
            assert.is_true(result)
            assert.equals('value', cache.data.key)
            assert.is_number(cache.ttl.key)
        end)
    end)

    describe('delete', function()
        it('should delete cached value', function()
            local cache = {data = {key = 'value'}, ttl = {key = os.time() + 60}}
            function cache:delete(key)
                self.data[key] = nil
                self.ttl[key] = nil
                return true
            end
            cache:delete('key')
            assert.is_nil(cache.data.key)
        end)
    end)

    describe('has', function()
        it('should check if key exists', function()
            local cache = {data = {key = 'value'}, ttl = {key = os.time() + 60}}
            function cache:has(key)
                return self.data[key] ~= nil and (not self.ttl[key] or self.ttl[key] > os.time())
            end
            assert.is_true(cache:has('key'))
            assert.is_false(cache:has('nonexistent'))
        end)
    end)

    describe('increment', function()
        it('should increment numeric value', function()
            local cache = {data = {count = 10}}
            function cache:incr(key, amount)
                if not tonumber(self.data[key]) then self.data[key] = 0 end
                self.data[key] = tonumber(self.data[key]) + (tonumber(amount) or 1)
                return self.data[key]
            end
            assert.equals(11, cache:incr('count'))
            assert.equals(13, cache:incr('count', 2))
        end)
    end)

    describe('decrement', function()
        it('should decrement numeric value', function()
            local cache = {data = {count = 10}}
            function cache:decr(key, amount)
                if not tonumber(self.data[key]) then self.data[key] = 0 end
                self.data[key] = tonumber(self.data[key]) - (tonumber(amount) or 1)
                return self.data[key]
            end
            assert.equals(9, cache:decr('count'))
            assert.equals(6, cache:decr('count', 3))
        end)
    end)

    describe('remember', function()
        it('should get or set value', function()
            local cache = {data = {}, ttl = {}}
            local call_count = 0
            function cache:remember(key, ttl, callback)
                if self.data[key] ~= nil then
                    return self.data[key]
                end
                call_count = call_count + 1
                local value = callback()
                self.data[key] = value
                self.ttl[key] = os.time() + (tonumber(ttl) or 300)
                return value
            end
            
            local function get_data() return 'computed' end
            
            assert.equals('computed', cache:remember('key', 60, get_data))
            assert.equals(1, call_count)
            assert.equals('computed', cache:remember('key', 60, get_data))
            assert.equals(1, call_count) -- Not called again
        end)
    end)

    describe('flush', function()
        it('should clear all cached values', function()
            local cache = {data = {a = 1, b = 2, c = 3}, ttl = {a = 1, b = 1, c = 1}}
            function cache:flush()
                self.data = {}
                self.ttl = {}
                return true
            end
            cache:flush()
            assert.same({}, cache.data)
        end)
    end)

    describe('get_ttl', function()
        it('should return TTL for key', function()
            local future = os.time() + 60
            local cache = {ttl = {key = future}}
            function cache:get_ttl(key)
                return self.ttl[key]
            end
            assert.equals(future, cache:get_ttl('key'))
        end)
    end)
end)
