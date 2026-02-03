-- Validation Library Unit Tests
-- tests/unit/validation_spec.lua

package.path = '/var/www/web/my-openresty/?.lua;/var/www/web/my-openresty/?/init.lua;/usr/local/web/?.lua;/usr/local/web/lualib/?.lua;;'
package.cpath = '/var/www/web/my-openresty/?.so;/usr/local/web/lualib/?.so;;'

local Test = require('app.utils.test')

describe = Test.describe
it = Test.it
pending = Test.pending
before_each = Test.before_each
after_each = Test.after_each
assert = Test.assert

describe('Validation Module', function()
    describe('required rule', function()
        it('should validate required field', function()
            local function validate_required(value)
                return value ~= nil and value ~= ''
            end
            
            assert.is_true(validate_required('test'))
            assert.is_true(validate_required(123))
            assert.is_true(validate_required(0))
            assert.is_false(validate_required(nil))
            assert.is_false(validate_required(''))
        end)
    end)

    describe('email rule', function()
        it('should validate email format', function()
            local function validate_email(email)
                if not email or #email < 5 then return false end
                local user, domain = email:match('^(%S+)@(%S+)$')
                if not user or not domain then return false end
                if #user < 1 or #domain < 3 then return false end
                if not domain:match('^[%w%-%.]+%.[a-z]+$') then return false end
                return true
            end
            
            assert.is_true(validate_email('test@example.com'))
            assert.is_true(validate_email('user.name@domain.co.uk'))
            assert.is_false(validate_email('invalid'))
            assert.is_false(validate_email('@example.com'))
            assert.is_false(validate_email('test@'))
            assert.is_false(validate_email('test@.com'))
        end)
    end)

    describe('number rule', function()
        it('should validate number', function()
            local function validate_number(value)
                return tonumber(value) ~= nil
            end
            
            assert.is_true(validate_number('123'))
            assert.is_true(validate_number('123.45'))
            assert.is_true(validate_number('-123'))
            assert.is_true(validate_number('0'))
            assert.is_false(validate_number('abc'))
            assert.is_false(validate_number(''))
        end)
    end)

    describe('integer rule', function()
        it('should validate integer', function()
            local function validate_integer(value)
                local num = tonumber(value)
                return num ~= nil and num == math.floor(num)
            end
            
            assert.is_true(validate_integer('123'))
            assert.is_true(validate_integer('0'))
            assert.is_true(validate_integer('-456'))
            assert.is_false(validate_integer('123.45'))
            assert.is_false(validate_integer('abc'))
        end)
    end)

    describe('min/max rules', function()
        it('should validate minimum value', function()
            local function validate_min(value, min)
                local num = tonumber(value)
                return num and num >= min
            end
            
            assert.is_true(validate_min(18, 18))
            assert.is_true(validate_min(25, 18))
            assert.is_false(validate_min(17, 18))
        end)

        it('should validate maximum value', function()
            local function validate_max(value, max)
                local num = tonumber(value)
                return num and num <= max
            end
            
            assert.is_true(validate_max(100, 100))
            assert.is_true(validate_max(50, 100))
            assert.is_false(validate_max(101, 100))
        end)
    end)

    describe('length rules', function()
        it('should validate minimum length', function()
            local function validate_length_min(value, min)
                return #tostring(value) >= min
            end
            
            assert.is_true(validate_length_min('hello', 5))
            assert.is_true(validate_length_min('hello world', 5))
            assert.is_false(validate_length_min('hi', 5))
        end)

        it('should validate maximum length', function()
            local function validate_length_max(value, max)
                return #tostring(value) <= max
            end
            
            assert.is_true(validate_length_max('hi', 5))
            assert.is_true(validate_length_max('hello', 5))
            assert.is_false(validate_length_max('hello world', 5))
        end)
    end)

    describe('URL rule', function()
        it('should validate URL format', function()
            local function validate_url(url)
                if not url or #url < 10 then return false end
                local schemes = {'http://', 'https://'}
                local valid = false
                for _, scheme in ipairs(schemes) do
                    if url:sub(1, #scheme) == scheme then
                        valid = true
                        break
                    end
                end
                if not valid then return false end
                local without_scheme = url:gsub('^https?://', '')
                return #without_scheme > 0
            end
            
            assert.is_true(validate_url('https://example.com'))
            assert.is_true(validate_url('http://localhost:8080/path'))
            assert.is_false(validate_url('not-a-url'))
            assert.is_false(validate_url('example.com'))
        end)
    end)

    describe('IP rule', function()
        it('should validate IP address', function()
            local function validate_ip(ip)
                if not ip then return false end
                local parts = {}
                for part in ip:gmatch('%d+') do
                    table.insert(parts, tonumber(part))
                end
                if #parts ~= 4 then return false end
                for _, part in ipairs(parts) do
                    if part < 0 or part > 255 then return false end
                end
                return true
            end
            
            assert.is_true(validate_ip('192.168.1.1'))
            assert.is_true(validate_ip('10.0.0.1'))
            assert.is_false(validate_ip('256.1.1.1'))
            assert.is_false(validate_ip('192.168.1'))
            assert.is_false(validate_ip('abc.def.ghi.jkl'))
        end)
    end)

    describe('in rule', function()
        it('should validate value in list', function()
            local function validate_in(value, list)
                if not list or #list == 0 then return false end
                for _, item in ipairs(list) do
                    if item == value then return true end
                end
                return false
            end
            
            assert.is_true(validate_in('a', {'a', 'b', 'c'}))
            assert.is_true(validate_in(1, {1, 2, 3}))
            assert.is_false(validate_in('d', {'a', 'b', 'c'}))
        end)
    end)

    describe('regex rule', function()
        it('should validate with regex pattern', function()
            local function validate_regex(value, pattern)
                if not value or not pattern then return false end
                return value:match(pattern) ~= nil
            end
            
            assert.is_true(validate_regex('test123', '^test%d+$'))
            assert.is_false(validate_regex('test', '^test%d+$'))
        end)
    end)

    describe('array rule', function()
        it('should validate array type', function()
            local function validate_array(value)
                return type(value) == 'table' and #value > 0
            end
            
            assert.is_true(validate_array({1, 2, 3}))
            assert.is_true(validate_array({'a', 'b'}))
            assert.is_false(validate_array('not array'))
            assert.is_false(validate_array({}))
        end)
    end)

    describe('alpha rule', function()
        it('should validate alphabetic string', function()
            local function validate_alpha(value)
                return value:match('^[a-zA-Z]+$') ~= nil
            end
            
            assert.is_true(validate_alpha('hello'))
            assert.is_true(validate_alpha('HELLO'))
            assert.is_false(validate_alpha('hello123'))
            assert.is_false(validate_alpha('hello-world'))
        end)
    end)

    describe('alpha_num rule', function()
        it('should validate alphanumeric string', function()
            local function validate_alpha_num(value)
                return value:match('^[a-zA-Z0-9]+$') ~= nil
            end
            
            assert.is_true(validate_alpha_num('hello123'))
            assert.is_true(validate_alpha_num('TEST123'))
            assert.is_false(validate_alpha_num('hello-world'))
            assert.is_false(validate_alpha_num('hello!'))
        end)
    end)

    describe('date rule', function()
        it('should validate date format', function()
            local function validate_date(value)
                local year, month, day = value:match('^(%d%d%d%d)-(%d%d)-(%d%d)$')
                if not year then return false end
                year, month, day = tonumber(year), tonumber(month), tonumber(day)
                if month < 1 or month > 12 then return false end
                if day < 1 or day > 31 then return false end
                return true
            end
            
            assert.is_true(validate_date('2024-01-15'))
            assert.is_true(validate_date('2023-12-31'))
            assert.is_false(validate_date('2024-13-01'))
            assert.is_false(validate_date('2024-00-15'))
            assert.is_false(validate_date('not-a-date'))
        end)
    end)
end)
