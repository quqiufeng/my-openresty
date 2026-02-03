-- Session Library for MyResty
-- Manages user sessions with encrypted cookie-based storage

local Session = {}
Session.__index = Session

local COOKIE_NAME = 'session'
local COOKIE_PATH = '/'
local COOKIE_MAX_AGE = 86400

function Session:new(options)
    local self = setmetatable({}, Session)

    self.data = {}
    self.session_id = nil
    self.is_new_session_flag = true
    self.cookie_name = (options and options.cookie_name) or COOKIE_NAME
    self.cookie_path = (options and options.cookie_path) or COOKIE_PATH
    self.cookie_max_age = (options and options.cookie_max_age) or COOKIE_MAX_AGE

    local Crypto = require('app.lib.crypto')
    self.secret_key = Crypto.get_secret_key()

    self:load_from_cookie()

    return self
end

function Session:load_from_cookie()
    local cookie_name = self.cookie_name
    local cookie_str = ngx.var['cookie_' .. cookie_name]

    if not cookie_str or cookie_str == '' then
        return
    end

    local decrypted = self:aes_decrypt(cookie_str)
    if not decrypted then
        return
    end

    local cjson = require('cjson')
    local success, data = pcall(function()
        return cjson.decode(decrypted)
    end)

    if success and type(data) == 'table' then
        self.data = data
        self.session_id = data.session_id
        self.is_new_session_flag = false
    end
end

function Session:start()
    if not self.session_id then
        self.session_id = self:generate_id(32)
    end
    self.is_new_session_flag = false
    return self
end

function Session:generate_id(length)
    length = tonumber(length) or 32
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
    local result = {}
    local n = #chars
    for i = 1, length do
        local r = math.random(1, n)
        result[i] = chars:sub(r, r)
    end
    return table.concat(result)
end

function Session:get(key)
    return self.data[key]
end

function Session:set(key, value)
    self.data[key] = value
    return self
end

function Session:has(key)
    return self.data[key] ~= nil
end

function Session:remove(key)
    self.data[key] = nil
    return self
end

function Session:clear()
    self.data = {}
    return self
end

function Session:get_id()
    return self.session_id
end

function Session:is_new_session()
    return self.is_new_session_flag
end

-- 兼容旧 API
function Session:is_new()
    return self:is_new_session()
end

function Session:count()
    if not self.data or type(self.data) ~= 'table' then
        return 0
    end
    local count = 0
    for _ in pairs(self.data) do
        count = count + 1
    end
    return count
end

function Session:get_all_data()
    return self.data
end

function Session:save()
    if self.session_id then
        self.data.session_id = self.session_id
    end
    return self
end

function Session:to_cookie()
    self:save()

    local cjson = require('cjson')
    local json_str = cjson.encode(self.data)
    local encrypted = self:aes_encrypt(json_str)

    return self.cookie_name .. '=' .. encrypted .. '; Path=' .. self.cookie_path .. '; HttpOnly; Max-Age=' .. self.cookie_max_age
end

function Session:set_cookie(value)
    local cookie_str = self.cookie_name .. '=' .. value .. '; Path=' .. self.cookie_path .. '; HttpOnly; Max-Age=' .. self.cookie_max_age
    ngx.header['Set-Cookie'] = cookie_str
end

function Session:destroy()
    self.data = {}
    self.session_id = nil
    self.is_new_session_flag = true
    ngx.header['Set-Cookie'] = self.cookie_name .. '=deleted; Path=' .. self.cookie_path .. '; Max-Age=0'
    return self
end

function Session:aes_encrypt(plaintext)
    if not plaintext or plaintext == '' then
        return nil
    end

    local Crypto = require('app.lib.crypto')
    return Crypto.encrypt_session(plaintext)
end

function Session:aes_decrypt(encrypted_data)
    if not encrypted_data or encrypted_data == '' then
        return nil
    end

    local Crypto = require('app.lib.crypto')
    return Crypto.decrypt_session(encrypted_data)
end

return Session
