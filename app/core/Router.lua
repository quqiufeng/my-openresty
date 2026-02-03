-- Copyright (c) 2026 MyResty Framework
-- Router with pattern matching and RESTful support

local type = type
local ipairs = ipairs
local pairs = pairs
local string_gmatch = string.gmatch
local string_match = string.match
local setmetatable = setmetatable
local tonumber = tonumber
local ngx_log = ngx.log
local ngx_ERR = ngx.ERR

local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function(narr, nrec) return {} end
end

local _M = { _VERSION = '1.0.0' }
local mt = { __index = _M }

local routes = {
    GET = {},
    POST = {},
    PUT = {},
    DELETE = {},
    PATCH = {},
    OPTIONS = {}
}

local function _compile_pattern(pattern)
    local params = new_tab(8, 0)
    local param_count = 0

    local function repl(m)
        param_count = param_count + 1
        local key = m:sub(2, -2)
        params[param_count] = key
        return '([^/]+)'
    end

    -- Support both :param and {param} syntax
    pattern = pattern:gsub(':%([a-zA-Z_][a-zA-Z0-9_]*%)', function(m)
        return '{' .. m:sub(2, -2) .. '}'
    end)
    pattern = pattern:gsub(':[a-zA-Z_][a-zA-Z0-9_]*', function(m)
        return '{' .. m:sub(2) .. '}'
    end)

    local regex = '^' .. string.gsub(pattern, '({[^}]+})', repl) .. '$'
    return regex, params
end

local function _add_route(method, pattern, handler)
    if not routes[method] then
        routes[method] = {}
    end
    local compiled_pattern, params = _compile_pattern(pattern)
    table.insert(routes[method], {
        original_pattern = pattern,
        pattern = compiled_pattern,
        params = params,
        handler = handler
    })
end

function _M.new(self)
    return setmetatable({
        routes = routes,
        controller = 'welcome',
        method = 'index',
        params = {},
        uri_string = ''
    }, mt)
end

function _M.get(self, pattern, handler)
    _add_route('GET', pattern, handler)
    return self
end

function _M.post(self, pattern, handler)
    _add_route('POST', pattern, handler)
    return self
end

function _M.put(self, pattern, handler)
    _add_route('PUT', pattern, handler)
    return self
end

function _M.delete(self, pattern, handler)
    _add_route('DELETE', pattern, handler)
    return self
end

function _M.patch(self, pattern, handler)
    _add_route('PATCH', pattern, handler)
    return self
end

function _M.options(self, pattern, handler)
    _add_route('OPTIONS', pattern, handler)
    return self
end

function _M.any(self, pattern, handler)
    local methods = {'GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'}
    for _, method in ipairs(methods) do
        _add_route(method, pattern, handler)
    end
    return self
end

function _M.resource(self, name, controller)
    local base = '/' .. name

    local routes_parts = new_tab(14, 0)
    local idx = 0

    idx = idx + 1; routes_parts[idx] = {'GET', base, controller .. ':index'}
    idx = idx + 1; routes_parts[idx] = {'GET', base .. '/new', controller .. ':new'}
    idx = idx + 1; routes_parts[idx] = {'GET', base .. '/{id}', controller .. ':show'}
    idx = idx + 1; routes_parts[idx] = {'GET', base .. '/{id}/edit', controller .. ':edit'}
    idx = idx + 1; routes_parts[idx] = {'POST', base, controller .. ':create'}
    idx = idx + 1; routes_parts[idx] = {'PUT', base .. '/{id}', controller .. ':update'}
    idx = idx + 1; routes_parts[idx] = {'DELETE', base .. '/{id}', controller .. ':destroy'}

    for i = 1, idx do
        local r = routes_parts[i]
        _add_route(r[1], r[2], r[3])
    end
end

function _M.reverse(self, name, params)
    local url_parts = new_tab(8, 0)
    local count = 1
    url_parts[1] = '/' .. name

    if params then
        for _, v in pairs(params) do
            count = count + 1
            url_parts[count] = '/' .. tostring(v)
        end
    end

    return table.concat(url_parts, '')
end

function _M.match(self, uri, http_method)
    http_method = http_method or 'GET'
    local method_routes = routes[http_method]
    if not method_routes then
        return nil
    end

    for _, route in ipairs(method_routes) do
        local matches = { string_match(uri, route.pattern) }
        if #matches > 0 then
            local params = {}
            for i, key in ipairs(route.params) do
                params[key] = matches[i]
            end
            return route.handler, params, matches
        end
    end

    return nil
end



function _M.parse_uri(self, uri)
    self.uri_string = uri

    if not uri or uri == '/' then
        return 'welcome', 'index', {}
    end

    local segments = new_tab(8, 0)
    local segment_count = 0

    for segment in string_gmatch(uri, '([^/]+') do
        segment_count = segment_count + 1
        segments[segment_count] = segment
    end

    if segment_count >= 1 then
        self.controller = segments[1]
    end
    if segment_count >= 2 then
        self.method = segments[2]
    end

    local params = new_tab(4, 0)
    local param_count = 0

    if segment_count > 2 then
        for i = 3, segment_count do
            param_count = param_count + 1
            params[param_count] = segments[i]
        end
    end

    return self.controller, self.method, params
end

function _M.dispatch(self, Request)
    local uri = Request.uri_string or ngx.var.uri or ''
    local method = Request.method or ngx.req.get_method() or 'GET'

    self.uri_string = uri

    local handler, route_params, matches = self:match(uri, method)

    if handler then
        if type(handler) == 'string' then
            local parts = {}
            for segment in string_gmatch(handler, '([^%.]+') do
                table.insert(parts, segment)
            end
            if #parts == 2 then
                self.controller = parts[1]
                self.method = parts[2]
            end
        else
            self.controller = handler.controller or 'welcome'
            self.method = handler.action or 'index'
        end
        if route_params then
            for k, v in pairs(route_params) do
                table.insert(self.params, v)
            end
        end
    else
        self:parse_uri(uri)
    end

    if matches then
        self.params = matches
    end

    return self.controller, self.method, self.params
end

function _M.set_controller(self, name)
    self.controller = name
    return self
end

function _M.set_method(self, name)
    self.method = name
    return self
end

function _M.set_default_controller(self, name)
    self.default_controller = name or 'welcome'
    return self
end

function _M.reverse(self, name, params)
    local url = '/' .. name
    if params then
        for k, v in pairs(params) do
            url = url .. '/' .. v
        end
    end
    return url
end

function _M.get_routes(self, method)
    if method then
        return routes[method] or {}
    end
    return routes
end

function _M.count_routes(self)
    local count = 0
    for _, method_routes in pairs(routes) do
        count = count + #method_routes
    end
    return count
end

return _M
