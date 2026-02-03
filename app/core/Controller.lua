-- Copyright (c) 2026 MyResty Framework
-- Base Controller with CI-style syntax

local type = type
local pairs = pairs
local setmetatable = setmetatable
local ngx_log = ngx.log
local ngx_ERR = ngx.ERR

local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function(narr, nrec) return {} end
end

local _M = { _VERSION = '1.0.0' }
local mt = { __index = _M }

function _M.new(self)
    local instance = {
        request = nil,
        response = nil,
        config = nil,
        load = nil,
        loaded = {}
    }

    instance.load = function(name, alias)
        return self:load_model(name, alias)
    end

    return setmetatable(instance, mt)
end

function _M.__construct(self)
    local Request = require('app.core.Request')
    local Response = require('app.core.Response')
    local Config = require('app.core.Config')

    self.request = Request:new()
    self.request:fetch()

    self.response = Response:new()
    self.config = Config

    self:load_helper('url')

    local Loader = require('app.core.Loader')
    local autoload = Config.get('autoload') or {}
    for _, item in ipairs(autoload) do
        if item == 'helper' then
            self:load_helper('url')
        else
            self:load_model(item)
        end
    end
end

function _M.before_action(self, action)
    return true
end

function _M.after_action(self, action)
end

function _M._action_wrapper(self, action, ...)
    if not self:before_action(action) then
        return
    end

    local method = self[action]
    if method then
        method(self, ...)
    end

    self:after_action(action)
end

function _M.load_model(self, name, alias)
    local Loader = require('app.core.Loader')
    alias = alias or name

    if not self.loaded['model_' .. name] then
        local model = Loader:model(name)
        if model then
            self[alias] = model
            self.loaded['model_' .. name] = model
            return model
        end
    end

    return self.loaded['model_' .. name]
end

function _M.load_library(self, name)
    local Loader = require('app.core.Loader')

    if not self.loaded['lib_' .. name] then
        local lib = Loader:library(name)
        if lib then
            self[name] = lib
            self.loaded['lib_' .. name] = lib
            return lib
        end
    end

    return self.loaded['lib_' .. name]
end

function _M.load_helper(self, name)
    local Loader = require('app.core.Loader')
    local helper = Loader:helper(name)
    if helper then
        for k, v in pairs(helper) do
            self[k] = v
        end
    end
end

function _M.load_config(self, name)
    local Config = require('app.core.Config')
    return Config.get(name)
end

function _M.load_view(self, template, data)
    local Loader = require('app.core.Loader')
    return Loader:view(template, data)
end

function _M.json(self, data, status)
    self.response:json(data, status)
end

function _M.jsonp(self, data, callback, status)
    self.response:jsonp(data, callback, status)
    self.response:send()
end

function _M.xml(self, data, status)
    self.response:xml(data, status)
    self.response:send()
end

function _M.html(self, content, status)
    self.response:html(content, status)
    self.response:send()
end

function _M.text(self, content, status)
    self.response:text(content, status)
    self.response:send()
end

function _M.output(self, content, content_type)
    self.response:output(content, content_type)
    self.response:send()
end

function _M.redirect(self, uri, code)
    self.response:redirect(uri, code)
end

function _M.redirect_back(self, default)
    self.response:redirect_back(default)
end

function _M.set_status(self, status)
    self.response:set_status(status)
    return self
end

function _M.set_content_type(self, content_type)
    self.response:set_content_type(content_type)
    return self
end

function _M.set_header(self, name, value)
    self.response:set_header(name, value)
    return self
end

function _M.success(self, data, message)
    self.response:success(data, message)
    self.response:send()
end

function _M.fail(self, message, data, status)
    self.response:fail(message, data, status)
    self.response:send()
end

function _M.paginate(self, data, total, page, per_page)
    self.response:paginate(data, total, page, per_page)
    self.response:send()
end

function _M.not_found(self, message)
    self.response:not_found(message)
    self.response:send()
end

function _M.error(self, message, status)
    self.response:error(message, status)
    self.response:send()
end

function _M.get_post(self, key, default)
    local value = self.request:param(key)
    if value == nil then
        return default
    end
    return value
end

function _M.get_get(self, key, default)
    return self.request.get[key] or default
end

function _M.get_input(self)
    return self.request:all_input()
end

function _M.log(self, message, level)
    level = level or ngx.INFO
    ngx_log(level, message)
end

function _M.debug(self, message)
    if self.config and self.config.log_threshold and self.config.log_threshold <= 4 then
        ngx_log(ngx.DEBUG, message)
    end
end

function _M.is_ajax(self)
    return self.request:is_ajax()
end

function _M.is_post(self)
    return self.request:is_post()
end

function _M.is_get(self)
    return self.request:is_get()
end

function _M.uri_segment(self, n)
    return self.request:segment(n)
end

function _M.site_url(self, uri)
    local base_url = self.config and self.config.base_url or ''
    if base_url == '' then
        local host = self.config and self.config.host or 'localhost'
        local port = self.config and self.config.port or 8080
        local protocol = self.config and self.config.url_protocol or 'http'

        local url_parts = new_tab(4, 0)
        url_parts[1] = protocol
        url_parts[2] = '://'
        url_parts[3] = host

        if port ~= 80 and port ~= 443 then
            url_parts[4] = ':' .. tostring(port)
        end

        base_url = table.concat(url_parts, '')
    end

    local uri_parts = new_tab(2, 0)
    uri_parts[1] = base_url
    uri_parts[2] = uri

    return table.concat(uri_parts, '/')
end

function _M.base_url(self)
    local base_url = self.config and self.config.base_url or ''
    if base_url == '' then
        local host = self.config and self.config.host or 'localhost'
        local port = self.config and self.config.port or 8080
        local protocol = self.config and self.config.url_protocol or 'http'

        local url_parts = new_tab(4, 0)
        url_parts[1] = protocol
        url_parts[2] = '://'
        url_parts[3] = host

        if port ~= 80 and port ~= 443 then
            url_parts[4] = ':' .. tostring(port)
        end

        base_url = table.concat(url_parts, '')
    end
    return base_url
end

function _M.display(self, template, data)
    local content = self:load_view(template, data)
    self:html(content)
end

function _M.cache(self, key, ttl)
    local shdict = ngx.shared.my_resty_cache
    if shdict then
        if ttl then
            shdict:set(key, 1, ttl)
        else
            return shdict:get(key)
        end
    end
end

function _M.uncache(self, key)
    local shdict = ngx.shared.my_resty_cache
    if shdict then
        shdict:delete(key)
    end
end

return _M
