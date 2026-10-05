-- Crypto Library Unit Tests (tests the real app.lib.crypto implementation)
-- tests/unit/crypto_spec.lua

package.path = '/var/www/web/my-openresty/?.lua;/var/www/web/my-openresty/?/init.lua;/usr/local/lualib/?.lua;;'
package.cpath = '/var/www/web/my-openresty/?.so;/usr/local/lualib/?.so;;'

local Test = require('app.utils.test')

describe = Test.describe
it = Test.it
pending = Test.pending
before_each = Test.before_each
after_each = Test.after_each
assert = Test.assert

describe('Crypto Module', function()
    describe('base64', function()
        it('encodes a known value', function()
            local Crypto = require('app.lib.crypto')
            assert.equals('SGVsbG8=', Crypto.base64_encode('Hello'))
        end)

        it('round-trips arbitrary binary data', function()
            local Crypto = require('app.lib.crypto')
            local data = 'Hello, World! \0\1\2\255'
            assert.equals(data, Crypto.base64_decode(Crypto.base64_encode(data)))
        end)

        it('handles empty input safely', function()
            local Crypto = require('app.lib.crypto')
            assert.equals('', Crypto.base64_decode(''))
        end)
    end)

    describe('random_bytes', function()
        it('returns the requested number of bytes', function()
            local Crypto = require('app.lib.crypto')
            local a = Crypto.random_bytes(16)
            assert.is_string(a)
            assert.equals(16, #a)
        end)

        it('produces distinct values', function()
            local Crypto = require('app.lib.crypto')
            assert.is_true(Crypto.random_bytes(16) ~= Crypto.random_bytes(16))
        end)
    end)

    describe('AES-256-CBC', function()
        it('encrypt/decrypt round-trips', function()
            local Crypto = require('app.lib.crypto')
            local ciphertext = Crypto.encrypt('session payload')
            assert.is_string(ciphertext)
            assert.equals('session payload', Crypto.decrypt(ciphertext))
        end)

        it('uses a random IV (distinct ciphertext per call)', function()
            local Crypto = require('app.lib.crypto')
            assert.is_true(Crypto.encrypt('same input') ~= Crypto.encrypt('same input'))
        end)

        it('rejects data that is too short', function()
            local Crypto = require('app.lib.crypto')
            local plain, err = Crypto.decrypt('short')
            assert.is_nil(plain)
            assert.is_string(err)
        end)
    end)
end)
