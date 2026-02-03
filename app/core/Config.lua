-- Copyright (c) 2026 MyResty Framework
-- Configuration loader with file support

local type = type
local pairs = pairs
local ipairs = ipairs
local io_open = io.open
local io_lines = io.lines
local setmetatable = setmetatable
local ngx_log = ngx.log
local ngx_ERR = ngx.ERR
local ngx_INFO = ngx.INFO

local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function(narr, nrec) return {} end
end

local _M = { _VERSION = '1.0.0' }
local mt = { __index = _M }

local config = nil
local config_path = '/var/www/web/my-openresty/app/config/config.lua'
local loaded = false

local function _load_file(path)
    local f, err = io_open(path, 'r')
    if not f then
        return nil, err
    end

    local content = f:read('*a')
    f:close()

    local func, err = loadstring(content)
    if not func then
        ngx_log(ngx_ERR, 'Failed to load config: ', err)
        return nil, err
    end

    local ok, result = pcall(func)
    if not ok then
        ngx_log(ngx_ERR, 'Failed to execute config: ', result)
        return nil, result
    end

    if type(result) ~= 'table' then
        ngx_log(ngx_ERR, 'Config must return a table')
        return nil, 'invalid config'
    end

    return result
end

local function _parse_env(prefix)
    local conf = {}
    prefix = prefix or 'MYRESTY_'

    local env = os.environ or {}
    for key, value in pairs(env) do
        if key:find(prefix, 1, true) == 1 then
            local config_key = key:sub(#prefix + 1):lower()
            local parts = new_tab(8, 0)
            local part_count = 0

            for part in string.gmatch(config_key, '([^_]+)') do
                part_count = part_count + 1
                parts[part_count] = part
            end

            local current = conf
            for i = 1, part_count - 1 do
                if not current[parts[i]] then
                    current[parts[i]] = {}
                end
                current = current[parts[i]]
            end

            current[parts[part_count]] = value
        end
    end

    return conf
end

function _M.load(self)
    if loaded then
        return config
    end

    local ok, result = pcall(_load_file, config_path)

    if ok then
        config = result or {}
        loaded = true
        ngx_log(ngx_INFO, 'Config loaded from: ', config_path)
    else
        ngx_log(ngx_ERR, 'Failed to load config: ', result)
        config = {}
        loaded = true
    end

    return config
end

function _M.get(self, key)
    if not loaded then
        self:load()
    end

    if not key then
        return config
    end

    local keys = {}
    for part in string.gmatch(key, '([^%.]+)') do
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

function _M.get_all(self)
    if not loaded then
        self:load()
    end
    return config
end

function _M.reload(self)
    loaded = false
    config = nil
    return self:load()
end

function _M.load_env(self, prefix)
    local env_config = _parse_env(prefix)
    for section, values in pairs(env_config) do
        if not config[section] then
            config[section] = {}
        end
        for k, v in pairs(values) do
            config[section][k] = v
        end
    end
    return config
end

function _M.is_loaded(self)
    return loaded
end

function _M.get_path(self)
    return config_path
end

function _M.set_path(self, path)
    config_path = path
    loaded = false
end

function _M.has(self, key)
    if not loaded then
        self:load()
    end

    local keys = new_tab(8, 0)
    local key_count = 0

    for part in string.gmatch(key, '([^%.]+)') do
        key_count = key_count + 1
        keys[key_count] = part
    end

    local value = config
    for i = 1, key_count do
        if type(value) == 'table' and value[keys[i]] ~= nil then
            value = value[keys[i]]
        else
            return false
        end
    end

    return true
end

function _M.unset(self, key)
    if not loaded then
        self:load()
    end

    local keys = new_tab(8, 0)
    local key_count = 0

    for part in string.gmatch(key, '([^%.]+)') do
        key_count = key_count + 1
        keys[key_count] = part
    end

    if key_count == 1 then
        config[keys[1]] = nil
        return true
    end

    local current = config
    for i = 1, key_count - 1 do
        if type(current) == 'table' and current[keys[i]] then
            current = current[keys[i]]
        else
            return false
        end
    end

    current[keys[key_count]] = nil
    return true
end

function _M.item(self, key, value)
    if not loaded then
        self:load()
    end

    if value ~= nil then
        local keys = {}
        for part in string.gmatch(key, '([^%.]+)') do
            table.insert(keys, part)
        end

        local current = config
        for i = 1, #keys - 1 do
            if not current[keys[i]] then
                current[keys[i]] = {}
            end
            current = current[keys[i]]
        end

        current[keys[#keys]] = value
    end

    local keys = {}
    for part in string.gmatch(key, '([^%.]+)') do
        table.insert(keys, part)
    end

    local result = config
    for _, k in ipairs(keys) do
        if type(result) == 'table' then
            result = result[k]
        else
            return nil
        end
    end

    return result
end

function _M.get_mysql(self)
    return self:get('mysql') or {}
end

function _M.get_redis(self)
    return self:get('redis') or {}
end

function _M.get_app(self)
    return self:get('app') or {}
end

function _M.snapshot(self)
    if not loaded then
        self:load()
    end

    local function deep_copy(orig)
        local copy
        if type(orig) == 'table' then
            copy = {}
            for k, v in pairs(orig) do
                copy[k] = type(v) == 'table' and deep_copy(v) or v
            end
        else
            copy = orig
        end
        return copy
    end

    return deep_copy(config)
end

return _M
