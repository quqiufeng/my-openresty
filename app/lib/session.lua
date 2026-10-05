-- Session Library for MyResty
-- Manages user sessions with encrypted cookie-based storage

local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function(narr, nrec) return {} end
end

local ok, tb_clear = pcall(require, "table.clear")
if not ok then
    tb_clear = function(tab)
        for k, _ in pairs(tab) do tab[k] = nil end
    end
end

local Crypto = require("app.lib.crypto")
local cjson = require("cjson")

-- 读取应用 session 配置（Cookie 安全属性）
local sconf = {}
do
    local ok, Config = pcall(require, 'app.core.Config')
    if ok and Config and Config.get then
        sconf = Config.get('session') or {}
    end
end

local _M = { _VERSION = '1.0.0' }
local mt = { __index = _M }

local COOKIE_NAME = 'session'
local COOKIE_PATH = '/'
local COOKIE_MAX_AGE = 86400

function _M:new(options)
    local self = setmetatable({}, mt)

    self.data = {}
    self.session_id = nil
    self.is_new_session_flag = true
    self.cookie_name = (options and options.cookie_name) or sconf.cookie_name or COOKIE_NAME
    self.cookie_path = (options and options.cookie_path) or sconf.cookie_path or COOKIE_PATH
    self.cookie_max_age = (options and options.cookie_max_age) or sconf.expires or COOKIE_MAX_AGE
    self.cookie_domain = sconf.cookie_domain

    -- Cookie 安全属性（默认 Secure/HttpOnly 开，SameSite=Lax）
    self.cookie_secure = (options and options.cookie_secure)
    if self.cookie_secure == nil then self.cookie_secure = sconf.cookie_secure ~= false end
    self.cookie_httponly = (options and options.cookie_httponly)
    if self.cookie_httponly == nil then self.cookie_httponly = sconf.cookie_httponly ~= false end
    self.cookie_samesite = (options and options.cookie_samesite)
    if self.cookie_samesite == nil then self.cookie_samesite = sconf.cookie_samesite or 'Lax' end

    self.secret_key = Crypto.get_secret_key()

    self:load_from_cookie()

    return self
end

function _M:load_from_cookie()
    local cookie_name = self.cookie_name
    local cookie_str = ngx.var['cookie_' .. cookie_name]

    if not cookie_str or cookie_str == '' then
        return
    end

    local decrypted = self:aes_decrypt(cookie_str)
    if not decrypted then
        return
    end

    local success, data = pcall(function()
        return cjson.decode(decrypted)
    end)

    if success and type(data) == 'table' then
        self.data = data
        self.session_id = data.session_id
        self.is_new_session_flag = false
    end
end

function _M:start()
    if not self.session_id then
        self.session_id = self:generate_id(32)
    end
    self.is_new_session_flag = false
    return self
end

function _M:generate_id(length)
    length = tonumber(length) or 32
    local Crypto = require('app.lib.crypto')
    local random_bytes = Crypto.random_bytes(length)
    if random_bytes then
        -- Use crypto-grade random bytes as session ID (hex encoded)
        local hex = {}
        for i = 1, #random_bytes do
            hex[i] = string.format('%02x', string.byte(random_bytes, i))
        end
        return table.concat(hex, ''):sub(1, length)
    end
    -- Fallback: use time-based ID
    local ngx_now = ngx.now
    local pid = ngx.worker and ngx.worker.pid() or 0
    math.randomseed(ngx_now() * 10000 + pid)
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
    local result = {}
    local n = #chars
    for i = 1, length do
        local r = math.random(1, n)
        result[i] = chars:sub(r, r)
    end
    return table.concat(result)
end

function _M:get(key)
    return self.data[key]
end

function _M:set(key, value)
    self.data[key] = value
    return self
end

function _M:has(key)
    return self.data[key] ~= nil
end

function _M:remove(key)
    self.data[key] = nil
    return self
end

function _M:clear()
    self.data = {}
    return self
end

function _M:get_id()
    return self.session_id
end

function _M:is_new_session()
    return self.is_new_session_flag
end

-- 兼容旧 API
function _M:is_new()
    return self:is_new_session()
end

function _M:count()
    if not self.data or type(self.data) ~= 'table' then
        return 0
    end
    local count = 0
    for _ in pairs(self.data) do
        count = count + 1
    end
    return count
end

function _M:get_all_data()
    return self.data
end

function _M:save()
    if self.session_id then
        self.data.session_id = self.session_id
    end
    return self
end

-- 组装 Cookie 属性（Path/Domain/Max-Age/Secure/HttpOnly/SameSite）
function _M:_cookie_attrs(max_age)
    local a = { 'Path=' .. self.cookie_path }
    if self.cookie_domain and self.cookie_domain ~= '' then
        a[#a + 1] = 'Domain=' .. self.cookie_domain
    end
    a[#a + 1] = 'Max-Age=' .. tostring(max_age or self.cookie_max_age)
    if self.cookie_httponly then a[#a + 1] = 'HttpOnly' end
    if self.cookie_secure then a[#a + 1] = 'Secure' end
    if self.cookie_samesite and self.cookie_samesite ~= '' then
        a[#a + 1] = 'SameSite=' .. self.cookie_samesite
    end
    return table.concat(a, '; ')
end

function _M:to_cookie()
    self:save()

    local json_str = cjson.encode(self.data)
    local encrypted = self:aes_encrypt(json_str)

    return self.cookie_name .. '=' .. encrypted .. '; ' .. self:_cookie_attrs()
end

function _M:set_cookie(value)
    local cookie_str = self.cookie_name .. '=' .. value .. '; ' .. self:_cookie_attrs()
    ngx.header['Set-Cookie'] = cookie_str
end

function _M:destroy()
    self.data = {}
    self.session_id = nil
    self.is_new_session_flag = true
    ngx.header['Set-Cookie'] = self.cookie_name .. '=deleted; ' .. self:_cookie_attrs(0)
    return self
end

function _M:aes_encrypt(plaintext)
    if not plaintext or plaintext == '' then
        return nil
    end

    return Crypto.encrypt_session(plaintext)
end

function _M:aes_decrypt(encrypted_data)
    if not encrypted_data or encrypted_data == '' then
        return nil
    end

    return Crypto.decrypt_session(encrypted_data)
end

return _M
