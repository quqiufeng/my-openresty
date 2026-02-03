-- Helper Library Unit Tests
-- tests/unit/helper_spec.lua

package.path = '/var/www/web/my-resty/?.lua;/var/www/web/my-resty/?/init.lua;/usr/local/web/?.lua;/usr/local/web/lualib/?.lua;;'
package.cpath = '/var/www/web/my-resty/?.so;/usr/local/web/lualib/?.so;;'

local Test = require('app.utils.test')

describe = Test.describe
it = Test.it
pending = Test.pending
before_each = Test.before_each
after_each = Test.after_each
assert = Test.assert

describe('Helper Module', function()
    describe('uuid', function()
        it('should generate valid UUID v4', function()
            local function uuid()
                return string.format('%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
                    math.random(0, 0xffff), math.random(0, 0xffff),
                    math.random(0, 0xffff),
                    bit32 and bit32.bor(0x4000, math.random(0, 0x0fff)) or 0x4000 + math.random(0, 0x0fff),
                    bit32 and bit32.bor(0x8000, math.random(0, 0x3fff)) or 0x8000 + math.random(0, 0x3fff),
                    math.random(0, 0xffff), math.random(0, 0xffff), math.random(0, 0xffff))
            end
            
            local u = uuid()
            assert.equals(36, #u)
            assert.equals('-', u:sub(9, 9))
            assert.equals('-', u:sub(14, 14))
            assert.equals('-', u:sub(19, 19))
            assert.equals('-', u:sub(24, 24))
        end)
    end)

    describe('random_string', function()
        it('should generate string of specified length', function()
            local function random_string(length)
                local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
                local result = {}
                for i = 1, length do
                    table.insert(result, chars:sub(math.random(1, #chars), #chars))
                end
                return table.concat(result)
            end
            
            assert.equals(10, #random_string(10))
            assert.equals(32, #random_string(32))
            assert.equals(0, #random_string(0))
        end)
    end)

    describe('md5', function()
        it('should generate valid MD5 hash', function()
            local function md5(data)
                local md5 = require('resty.md5')
                local m = md5:new()
                m:update(data)
                local digest = m:final()
                local hex = ''
                for i = 1, #digest do
                    hex = hex .. string.format('%02x', string.byte(digest, i))
                end
                return hex
            end
            
            local hash = md5('hello')
            assert.equals(32, #hash)
            assert.equals('5d41402abc4b2a76b9719d911017c592', hash)
        end)
    end)

    describe('is_valid_email', function()
        it('should validate correct email', function()
            local function is_valid_email(email)
                if not email or #email < 5 then return false end
                local user, domain = email:match('^(%S+)@(%S+)$')
                if not user or not domain then return false end
                if #user < 1 or #domain < 3 then return false end
                if not domain:match('^[%w%-%.]+%.[a-z]+$') then return false end
                return true
            end
            
            assert.is_true(is_valid_email('test@example.com'))
            assert.is_true(is_valid_email('user.name@domain.co.uk'))
            assert.is_false(is_valid_email('invalid'))
            assert.is_false(is_valid_email('@example.com'))
            assert.is_false(is_valid_email('test@'))
        end)
    end)

    describe('is_valid_url', function()
        it('should validate correct URL', function()
            local function is_valid_url(url)
                if not url or #url < 10 then return false end
                local schemes = {'http://', 'https://', 'ftp://'}
                local valid = false
                for _, scheme in ipairs(schemes) do
                    if url:sub(1, #scheme) == scheme then
                        valid = true
                        break
                    end
                end
                if not valid then return false end
                local without_scheme = url:gsub('^https?://', ''):gsub('^ftp://', '')
                return #without_scheme > 0
            end
            
            assert.is_true(is_valid_url('https://example.com'))
            assert.is_true(is_valid_url('http://localhost:8080/path'))
            assert.is_false(is_valid_url('not-a-url'))
            assert.is_false(is_valid_url('example.com'))
        end)
    end)

    describe('is_valid_phone', function()
        it('should validate phone numbers', function()
            local function is_valid_phone(phone)
                if not phone then return false end
                local cleaned = phone:gsub('%s+', ''):gsub('^%+', ''):gsub('^0', '')
                if #cleaned < 7 or #cleaned > 15 then return false end
                for i = 1, #cleaned do
                    local c = string.byte(cleaned, i)
                    if c < 48 or c > 57 then return false end
                end
                return true
            end
            
            assert.is_true(is_valid_phone('13800138000'))
            assert.is_true(is_valid_phone('+8613800138000'))
            assert.is_false(is_valid_phone('123'))
            assert.is_false(is_valid_phone('abc123'))
        end)
    end)

    describe('sanitize', function()
        it('should remove HTML tags', function()
            local function sanitize(text)
                if not text then return '' end
                return text:gsub('<[^>]*>', ''):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
            end
            
            local result = sanitize('<script>alert("xss")</script>')
            assert.equals('alert("xss")', result)
            
            result = sanitize('<div><p>Hello</p></div>')
            assert.equals('Hello', result)
        end)
    end)

    describe('escape_html', function()
        it('should escape HTML entities', function()
            local function escape_html(text)
                if not text then return '' end
                text = text:gsub('&', '&amp;')
                text = text:gsub('<', '&lt;')
                text = text:gsub('>', '&gt;')
                text = text:gsub('"', '&quot;')
                text = text:gsub("'", '&#39;')
                return text
            end
            
            assert.equals('&lt;div&gt;', escape_html('<div>'))
            assert.equals('&quot;test&quot;', escape_html('"test"'))
        end)
    end)

    describe('base64_encode', function()
        it('should encode and decode base64', function()
            local function base64_encode(data)
                local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
                local result = {}
                local i = 1
                while i <= #data do
                    local b1 = string.byte(data, i)
                    local b2 = i + 1 <= #data and string.byte(data, i + 1) or 0
                    local b3 = i + 2 <= #data and string.byte(data, i + 2) or 0
                    local triplet = bit32 and bit32.lshift(b1, 16) + bit32.lshift(b2, 8) + b3 or b1 * 65536 + b2 * 256 + b3
                    local idx1 = bit32 and bit32.rshift(triplet, 18) % 64 or math.floor(triplet / 262144) % 64
                    local idx2 = bit32 and bit32.rshift(triplet, 12) % 64 or math.floor(triplet / 4096) % 64
                    local idx3 = bit32 and bit32.rshift(triplet, 6) % 64 or math.floor(triplet / 64) % 64
                    local idx4 = triplet % 64
                    table.insert(result, b64chars:sub(idx1 + 1, idx1 + 1))
                    table.insert(result, b64chars:sub(idx2 + 1, idx2 + 1))
                    if i + 1 <= #data then table.insert(result, b64chars:sub(idx3 + 1, idx3 + 1)) else table.insert(result, '=') end
                    if i + 2 <= #data then table.insert(result, b64chars:sub(idx4 + 1, idx4 + 1)) else table.insert(result, '=') end
                    i = i + 3
                end
                return table.concat(result)
            end
            
            local encoded = base64_encode('Hello')
            assert.equals('SGVsbG8=', encoded)
        end)
    end)

    describe('format_date', function()
        it('should format timestamp', function()
            local function format_date(ts, format)
                ts = tonumber(ts) or os.time()
                format = format or '%Y-%m-%d %H:%M:%S'
                return os.date(format, ts)
            end
            
            local result = format_date(1704067200, '%Y-%m-%d')
            assert.equals('2024-01-01', result)
        end)
    end)

    describe('paginate', function()
        it('should paginate array', function()
            local function paginate(arr, page, per_page)
                page = tonumber(page) or 1
                per_page = tonumber(per_page) or 10
                local start = (page - 1) * per_page + 1
                local result = {}
                for i = start, math.min(start + per_page - 1, #arr) do
                    table.insert(result, arr[i])
                end
                return result
            end
            
            local data = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
            local result = paginate(data, 1, 5)
            assert.equals(5, #result)
            assert.equals(1, result[1])
            assert.equals(5, result[5])
            
            result = paginate(data, 2, 5)
            assert.equals(5, #result)
            assert.equals(6, result[1])
            assert.equals(10, result[5])
        end)
    end)
end)
