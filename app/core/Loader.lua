-- Copyright (c) 2026 MyResty Framework
-- Auto loader with lazy loading and caching

local type = type
local pairs = pairs
local ipairs = ipairs
local setmetatable = setmetatable
local ngx_log = ngx.log
local ngx_ERR = ngx.ERR

local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function(narr, nrec) return {} end
end

local _M = new_tab(0, 20)
_M._VERSION = '1.0.0'

local mt = { __index = _M }

local loaded_models = {}
local loaded_libs = {}
local loaded_helpers = {}
local loaded_controllers = {}

local function _load_module(path)
    local ok, mod = pcall(require, path)
    if ok then
        return true, mod
    end
    return false, mod
end

function _M.new(self)
    return setmetatable({}, mt)
end

function _M.library(self, name)
    if loaded_libs[name] then
        return loaded_libs[name]
    end

    local path = 'app.lib.' .. name
    local ok, lib = _load_module(path)

    if ok and lib then
        if type(lib) == 'table' and lib.init then
            local Config = require('app.core.Config')
            local config = Config.get(name) or {}
            lib:init(config)
        elseif type(lib) == 'table' and lib.new then
            lib = lib:new()
        end
        loaded_libs[name] = lib
        return lib
    end

    ngx_log(ngx_ERR, 'Library not found: ', path)
    return nil
end

function _M.model(self, name)
    if loaded_models[name] then
        return loaded_models[name]
    end

    local path = 'app.models.' .. name
    local ok, model = _load_module(path)

    if ok and model then
        if type(model) == 'table' and model.new then
            model = model:new()
        end
        loaded_models[name] = model
        return model
    end

    ngx_log(ngx_ERR, 'Model not found: ', path)
    return nil
end

function _M.controller(self, name, response)
    local path = 'app.controllers.' .. name
    local ok, ctrl_module = _load_module(path)

    if ok and ctrl_module then
        local Controller = require('app.core.Controller')
        local ctrl = Controller:new()

        ctrl.response = response

        for k, v in pairs(ctrl_module) do
            if k ~= '_M' and k ~= 'new' and k ~= '__construct' then
                ctrl[k] = v
            end
        end

        if ctrl.__construct and type(ctrl.__construct) == "function" then
            ctrl:__construct()
        end

        return ctrl
    end

    ngx_log(ngx_ERR, 'Controller not found: ', path)
    return nil
end

function _M.helper(self, name)
    if loaded_helpers[name] then
        return loaded_helpers[name]
    end

    local path = 'app.helpers.' .. name .. '_helper'
    local ok, helper = _load_module(path)

    if ok and helper then
        loaded_helpers[name] = helper
        return helper
    end

    ngx_log(ngx_ERR, 'Helper not found: ', path)
    return nil
end

function _M.config(self, name)
    local Config = require('app.core.Config')
    return Config.get(name)
end

function _M.view(self, template, data)
    local view_path = '/var/www/web/my-resty/app/views/' .. template .. '.html'
    local f = io.open(view_path, 'r')
    if not f then
        ngx_log(ngx_ERR, 'View not found: ', view_path)
        return ''
    end
    local content = f:read('*a')
    f:close()

    if data then
        for k, v in pairs(data) do
            content = string.gsub(content, '{' .. k .. '}', tostring(v))
        end
    end

    return content
end

function _M.autoload(self, items)
    for _, item in ipairs(items) do
        local parts = new_tab(4, 0)
        local part_count = 0

        for part in string.gmatch(item, '([^/]+') do
            part_count = part_count + 1
            parts[part_count] = part
        end

        local type = parts[1]
        local name = parts[2]

        if type == 'library' then
            self:library(name)
        elseif type == 'model' then
            self:model(name)
        elseif type == 'helper' then
            self:helper(name)
        end
    end
end

function _M.is_loaded(self, type, name)
    if type == 'model' then
        return loaded_models[name] ~= nil
    elseif type == 'library' then
        return loaded_libs[name] ~= nil
    elseif type == 'helper' then
        return loaded_helpers[name] ~= nil
    elseif type == 'controller' then
        return loaded_controllers[name] ~= nil
    end
    return false
end

function _M.get_loaded(self, type)
    if type == 'model' then
        return loaded_models
    elseif type == 'library' then
        return loaded_libs
    elseif type == 'helper' then
        return loaded_helpers
    elseif type == 'controller' then
        return loaded_controllers
    end
    return nil
end

function _M.clear_cache(self, type)
    if not type or type == 'all' then
        tb_clear(loaded_models)
        tb_clear(loaded_libs)
        tb_clear(loaded_helpers)
        tb_clear(loaded_controllers)
    elseif type == 'model' then
        tb_clear(loaded_models)
    elseif type == 'library' then
        tb_clear(loaded_libs)
    elseif type == 'helper' then
        tb_clear(loaded_helpers)
    elseif type == 'controller' then
        tb_clear(loaded_controllers)
    end
end

function _M.get_stats(self)
    return {
        models = #loaded_models,
        libraries = #loaded_libs,
        helpers = #loaded_helpers,
        controllers = #loaded_controllers
    }
end

setmetatable(_M, {
    __index = function(self, key)
        local method = function(...)
            return _M[key](_M, ...)
        end
        _M[key] = method
        return method
    end
})

return _M
