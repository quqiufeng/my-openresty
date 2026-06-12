-- user Model Auto-generated Test
package.path = '/var/www/web/my-openresty/?.lua;/var/www/web/my-openresty/?/init.lua;/usr/local/lualib/?.lua;;'
package.cpath = '/var/www/web/my-openresty/?.so;/usr/local/lualib/?.so;;'
local Test = require('app.utils.test')
describe = Test.describe; it = Test.it; assert = Test.assert
describe('UserModel', function()
    it('should require module', function()
        local ok, mod = pcall(require, 'app.models.UserModel')
        assert.is_true(ok)
    end)
    it('should create instance', function()
        local ok, mod = pcall(require, 'app.models.UserModel')
        if ok and mod.new then
            local inst = mod:new()
            assert.is_not_nil(inst)
        end
    end)
end)
