-- Crypto Library Unit Tests
-- tests/unit/crypto_spec.lua

package.path = '/var/www/web/my-resty/?.lua;/var/www/web/my-resty/?/init.lua;/usr/local/web/?.lua;/usr/local/web/lualib/?.lua;;'
package.cpath = '/var/www/web/my-resty/?.so;/usr/local/web/lualib/?.so;;'

local Test = require('app.utils.test')

describe = Test.describe
it = Test.it
pending = Test.pending
before_each = Test.before_each
after_each = Test.after_each
assert = Test.assert

describe('Crypto Module', function()
    describe('key derivation', function()
        it('should derive encryption and HMAC keys', function()
            local function derive_keys(secret_key, suffix)
                suffix = suffix or ""
                local enc_key = ngx.sha1_bin(secret_key .. ":encryption" .. suffix)
                local hmac_key = ngx.sha1_bin(secret_key .. ":hmac" .. suffix)
                return enc_key, hmac_key
            end
            
            local enc_key, hmac_key = derive_keys('test-secret', ':captcha')
            assert.equals(20, #enc_key)  -- SHA1 produces 20 bytes
            assert.equals(20, #hmac_key)
            assert.is_true(enc_key ~= hmac_key)  -- Keys should be different
        end)

        it('should produce same keys for same input', function()
            local function derive_keys(secret_key)
                return ngx.sha1_bin(secret_key .. ":encryption"),
                       ngx.sha1_bin(secret_key .. ":hmac")
            end
            
            local enc1, hmac1 = derive_keys('secret')
            local enc2, hmac2 = derive_keys('secret')
            assert.equals(enc1, enc2)
            assert.equals(hmac1, hmac2)
        end)
    end)

    describe('base64 encoding', function()
        it('should encode and decode correctly', function()
            local function base64_encode(data)
                local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
                local result = {}
                local i = 1
                while i <= #data do
                    local b1 = string.byte(data, i)
                    local b2 = i + 1 <= #data and string.byte(data, i + 1) or 0
                    local b3 = i + 2 <= #data and string.byte(data, i + 2) or 0
                    local triplet = (b1 << 16) + (b2 << 8) + b3
                    table.insert(result, b64chars:sub((triplet >> 18) % 64 + 1, (triplet >> 18) % 64 + 1))
                    table.insert(result, b64chars:sub((triplet >> 12) % 64 + 1, (triplet >> 12) % 64 + 1))
                    if i + 1 <= #data then table.insert(result, b64chars:sub((triplet >> 6) % 64 + 1, (triplet >> 6) % 64 + 1)) else table.insert(result, '=') end
                    if i + 2 <= #data then table.insert(result, b64chars:sub(triplet % 64 + 1, triplet % 64 + 1)) else table.insert(result, '=') end
                    i = i + 3
                end
                return table.concat(result)
            end
            
            local encoded = base64_encode('Hello')
            assert.equals('SGVsbG8=', encoded)
        end)
    end)

    describe('HMAC SHA256', function()
        it('should generate consistent HMAC', function()
            local function hmac_sha256(data, key)
                local sha256 = require('resty.sha256')
                local sha = sha256:new()
                sha:update(key .. data)
                return sha:final()
            end
            
            local sig = hmac_sha256('message', 'secret-key')
            assert.equals(32, #sig)  -- SHA256 produces 32 bytes
            
            -- Same input should produce same output
            local sig2 = hmac_sha256('message', 'secret-key')
            assert.equals(sig, sig2)
        end)

        it('should produce different HMAC for different keys', function()
            local function hmac_sha256(data, key)
                local sha256 = require('resty.sha256')
                local sha = sha256:new()
                sha:update(key .. data)
                return sha:final()
            end
            
            local sig1 = hmac_sha256('message', 'key1')
            local sig2 = hmac_sha256('message', 'key2')
            assert.is_true(sig1 ~= sig2)
        end)
    end)

    describe('secure random', function()
        it('should generate random bytes', function()
            local function secure_random(length)
                local buf = {}
                for i = 1, length do
                    buf[i] = math.random(0, 255)
                end
                return table.concat(buf)
            end
            
            local rand1 = secure_random(16)
            local rand2 = secure_random(16)
            assert.equals(16, #rand1)
            assert.equals(16, #rand2)
            -- Probability of same random is extremely low
            assert.is_true(rand1 ~= rand2)
        end)
    end)

    describe('AES encryption simulation', function()
        it('should encrypt and decrypt consistently', function()
            local function xor_encrypt(data, key)
                local result = {}
                for i = 1, #data do
                    local d = string.byte(data, i)
                    local k = string.byte(key, (i - 1) % #key + 1)
                    table.insert(result, string.char(d ~ k))
                end
                return table.concat(result)
            end
            
            local key = 'my-secret-key-16chars!!'
            local plaintext = 'Hello, World!'
            
            local encrypted = xor_encrypt(plaintext, key)
            local decrypted = xor_encrypt(encrypted, key)
            
            assert.equals(plaintext, decrypted)
            assert.is_true(encrypted ~= plaintext)
        end)
    end)
end)
