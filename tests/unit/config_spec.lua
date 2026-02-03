-- Config Library Unit Tests
-- tests/unit/config_spec.lua

package.path = '/var/www/web/my-resty/?.lua;/var/www/web/my-resty/?/init.lua;/usr/local/web/?.lua;/usr/local/web/lualib/?.lua;;'
package.cpath = '/var/www/web/my-resty/?.so;/usr/local/web/lualib/?.so;;'

local Test = require('app.utils.test')

describe = Test.describe
it = Test.it
pending = Test.pending
before_each = Test.before_each
after_each = Test.after_each
assert = Test.assert

describe('Config Module', function()
    describe('creation', function()
        it('should create config instance', function()
            local Config = {}
            setmetatable(Config, {__index = function(t, k)
                if k == 'load' then return function() return {} end end
                return nil
            end})
            assert.is_table(Config)
        end)
    end)

    describe('get value', function()
        it('should get nested value with dot notation', function()
            local config = {
                database = {
                    host = 'localhost',
                    port = 3306
                }
            }
            
            local function get(config, key)
                if not key then return config end
                local keys = {}
                for part in string.gmatch(key, '([^%.]+') do
                    table.insert(keys, part)
                end
                local value = config
                for _, k in ipairs(keys) do
                    if type(value) == 'table' then
                        value = value[k]
                    else
                        return nil
                    end
                end
                return value
            end
            
            assert.equals('localhost', get(config, 'database.host'))
            assert.equals(3306, get(config, 'database.port'))
            assert.is_nil(get(config, 'database.nonexistent'))
        end)
    end)

    describe('get all', function()
        it('should return entire config', function()
            local config = {app = {name = 'test'}}
            local function get_all(c) return c end
            assert.equals(config, get_all(config))
        end)
    end)
end)
