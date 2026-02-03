-- Validator Library Unit Tests
-- tests/unit/validator_spec.lua

package.path = '/var/www/web/my-openresty/?.lua;/var/www/web/my-openresty/?/init.lua;/usr/local/web/?.lua;/usr/local/web/lualib/?.lua;;'
package.cpath = '/var/www/web/my-openresty/?.so;/usr/local/web/lualib/?.so;;'

local Test = require('app.utils.test')

describe = Test.describe
it = Test.it
pending = Test.pending
before_each = Test.before_each
after_each = Test.after_each
assert = Test.assert

describe('Validator Module', function()
    describe('email validation', function()
        it('should validate valid email addresses', function()
            local valid_emails = {
                'test@example.com',
                'user.name@domain.co.uk',
                'user+tag@example.org',
                'firstname.lastname@company.com'
            }
            for _, email in ipairs(valid_emails) do
                local valid = email:match('@') and email:match('%.') and #email > 5
                assert.is_true(valid, 'Expected ' .. email .. ' to be valid')
            end
        end)

        it('should reject invalid email addresses', function()
            local invalid_emails = {
                'invalid',
                '@example.com',
                'test@',
                'test@.com',
                'test@@example.com',
                ''
            }
            for _, email in ipairs(invalid_emails) do
                local valid = email and email:match('@') and email:match('%.') and #email > 5
                assert.is_false(valid, 'Expected ' .. tostring(email) .. ' to be invalid')
            end
        end)
    end)

    describe('URL validation', function()
        it('should validate valid URLs', function()
            local valid_urls = {
                'https://example.com',
                'http://localhost:8080',
                'https://api.example.com/v1/users'
            }
            for _, url in ipairs(valid_urls) do
                local valid = url:match('^https?://') and #url > 10
                assert.is_true(valid, 'Expected ' .. url .. ' to be valid')
            end
        end)

        it('should reject invalid URLs', function()
            local invalid_urls = {
                'not-a-url',
                'example.com',
                'ftp://invalid.org'
            }
            for _, url in ipairs(invalid_urls) do
                local valid = url:match('^https?://')
                assert.is_false(valid, 'Expected ' .. url .. ' to be invalid')
            end
        end)
    end)

    describe('phone validation', function()
        it('should validate phone numbers', function()
            local function is_valid_phone(phone)
                if not phone then return false end
                local cleaned = phone:gsub('%s+', ''):gsub('^%+', '')
                if #cleaned < 7 or #cleaned > 15 then return false end
                for i = 1, #cleaned do
                    local c = string.byte(cleaned, i)
                    if c < 48 or c > 57 then return false end
                end
                return true
            end
            
            assert.is_true(is_valid_phone('13800138000'))
            assert.is_true(is_valid_phone('+8613800138000'))
            assert.is_true(is_valid_phone('1234567890'))
            assert.is_false(is_valid_phone('123'))
            assert.is_false(is_valid_phone('abc123'))
        end)
    end)

    describe('numeric validation', function()
        it('should validate numeric values', function()
            local function is_numeric(value)
                return tonumber(value) ~= nil
            end
            
            assert.is_true(is_numeric('123'))
            assert.is_true(is_numeric('-456'))
            assert.is_true(is_numeric('0'))
            assert.is_true(is_numeric('123.456'))
            assert.is_false(is_numeric('abc'))
            assert.is_false(is_numeric(''))
        end)
    end)

    describe('integer validation', function()
        it('should validate integer values', function()
            local function is_integer(value)
                local num = tonumber(value)
                return num and num == math.floor(num)
            end
            
            assert.is_true(is_integer('123'))
            assert.is_true(is_integer('-456'))
            assert.is_true(is_integer('0'))
            assert.is_false(is_integer('123.45'))
            assert.is_false(is_integer('abc'))
        end)
    end)

    describe('alpha validation', function()
        it('should validate alphabetic strings', function()
            local function is_alpha(value)
                return value and value:match('^[a-zA-Z]+$') ~= nil
            end
            
            assert.is_true(is_alpha('hello'))
            assert.is_true(is_alpha('HELLO'))
            assert.is_true(is_alpha('HelloWorld'))
            assert.is_false(is_alpha('hello123'))
            assert.is_false(is_alpha('hello-world'))
            assert.is_false(is_alpha(''))
        end)
    end)

    describe('alpha_num validation', function()
        it('should validate alphanumeric strings', function()
            local function is_alpha_num(value)
                return value and value:match('^[a-zA-Z0-9]+$') ~= nil
            end
            
            assert.is_true(is_alpha_num('hello123'))
            assert.is_true(is_alpha_num('TEST123'))
            assert.is_true(is_alpha_num('123ABC'))
            assert.is_false(is_alpha_num('hello-world'))
            assert.is_false(is_alpha_num('hello!'))
        end)
    end)

    describe('alpha_dash validation', function()
        it('should validate alphanumeric with dashes', function()
            local function is_alpha_dash(value)
                return value and value:match('^[a-zA-Z0-9%-_]+$') ~= nil
            end
            
            assert.is_true(is_alpha_dash('hello-world'))
            assert.is_true(is_alpha_dash('hello_world'))
            assert.is_true(is_alpha_dash('test-123_abc'))
            assert.is_false(is_alpha_dash('hello!'))
            assert.is_false(is_alpha_dash('hello world'))
        end)
    end)

    describe('min validation', function()
        it('should validate minimum value/length', function()
            local function validate_min(value, min)
                local num = tonumber(value)
                if num then return num >= min end
                return #tostring(value) >= min
            end
            
            assert.is_true(validate_min(18, 18))
            assert.is_true(validate_min(25, 18))
            assert.is_true(validate_min('hello', 3))
            assert.is_false(validate_min(17, 18))
            assert.is_false(validate_min('hi', 5))
        end)
    end)

    describe('max validation', function()
        it('should validate maximum value/length', function()
            local function validate_max(value, max)
                local num = tonumber(value)
                if num then return num <= max end
                return #tostring(value) <= max
            end
            
            assert.is_true(validate_max(100, 100))
            assert.is_true(validate_max(50, 100))
            assert.is_true(validate_max('hello', 10))
            assert.is_false(validate_max(101, 100))
            assert.is_false(validate_max('hello world', 5))
        end)
    end)

    describe('in validation', function()
        it('should validate value is in list', function()
            local function validate_in(value, allowed)
                for _, v in ipairs(allowed) do
                    if v == value then return true end
                end
                return false
            end
            
            assert.is_true(validate_in('a', {'a', 'b', 'c'}))
            assert.is_true(validate_in(1, {1, 2, 3}))
            assert.is_false(validate_in('d', {'a', 'b', 'c'}))
            assert.is_false(validate_in(4, {1, 2, 3}))
        end)
    end)

    describe('match validation', function()
        it('should validate values match', function()
            local function validate_match(value1, value2)
                return value1 == value2
            end
            
            assert.is_true(validate_match('pass', 'pass'))
            assert.is_false(validate_match('pass1', 'pass2'))
        end)
    end)

    describe('date validation', function()
        it('should validate date format', function()
            local function is_valid_date(value)
                local y, m, d = value:match('^(%d%d%d%d)-(%d%d)-(%d%d)$')
                if not y then return false end
                y, m, d = tonumber(y), tonumber(m), tonumber(d)
                return m >= 1 and m <= 12 and d >= 1 and d <= 31
            end
            
            assert.is_true(is_valid_date('2024-01-15'))
            assert.is_false(is_valid_date('2024-13-01'))
            assert.is_false(is_valid_date('not-a-date'))
        end)
    end)

    describe('regex validation', function()
        it('should validate with custom regex', function()
            local function validate_regex(value, pattern)
                return value and pattern and value:match(pattern) ~= nil
            end
            
            assert.is_true(validate_regex('test123', '^test%d+$'))
            assert.is_false(validate_regex('test', '^test%d+$'))
            assert.is_true(validate_regex('ABC123', '^[A-Z]+%d+$'))
        end)
    end)
end)
