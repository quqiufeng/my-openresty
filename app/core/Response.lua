-- Copyright (c) 2026 MyResty Framework
-- Response handler with JSON/XML support

local type = type
local tonumber = tonumber
local setmetatable = setmetatable
local ngx_header = ngx.header
local ngx_status = ngx.status
local ngx_say = ngx.say
local ngx_print = ngx.print
local ngx_redirect = ngx.redirect
local table_insert = table.insert
local table_concat = table.concat

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

local tab_pool_len = 0
local tab_pool = new_tab(16, 0)

local function _get_tab_from_pool()
    if tab_pool_len > 0 then
        tab_pool_len = tab_pool_len - 1
        return tab_pool[tab_pool_len + 1]
    end
    return new_tab(8, 0)
end

local function _put_tab_into_pool(tab)
    if tab_pool_len >= 32 then return end
    tb_clear(tab)
    tab_pool_len = tab_pool_len + 1
    tab_pool[tab_pool_len] = tab
end

local _M = { _VERSION = '1.0.0' }
local mt = { __index = _M }

local function _json_encode(data)
    local json = require('cjson')
    if json.encode_empty_table_as_object then
        return json.encode(data)
    end
    return json.encode(data)
end

function _M.new(self)
    return setmetatable({
        status = 200,
        content_type = 'application/json',
        body = '',
        headers = {}
    }, mt)
end

function _M.set_status(self, status)
    self.status = tonumber(status) or 200
    return self
end

function _M.get_status(self)
    return self.status
end

function _M.set_content_type(self, content_type)
    self.content_type = content_type
    return self
end

function _M.json(self, data, status)
    self.content_type = 'application/json'
    self.body = _json_encode(data)
    if status then
        self.status = tonumber(status) or 200
    end
    return self
end

function _M.jsonp(self, data, callback, status)
    self.content_type = 'application/javascript'
    local json_str = _json_encode(data)
    if callback and callback ~= '' then
        self.body = callback .. '(' .. json_str .. ')'
    else
        self.body = json_str
    end
    if status then
        self.status = tonumber(status) or 200
    end
    return self
end

function _M.jsonp(self, data, callback, status)
    self.content_type = 'application/javascript'
    local json_str = _json_encode(data)
    if callback and callback ~= '' then
        self.body = callback .. '(' .. json_str .. ')'
    else
        self.body = json_str
    end
    if status then
        self.status = tonumber(status) or 200
    end
    return self
end

function _M.xml(self, data, status)
    self.content_type = 'application/xml'
    if type(data) == 'table' then
        self.body = self:_table_to_xml(data)
    else
        self.body = tostring(data)
    end
    if status then
        self.status = tonumber(status) or 200
    end
    return self
end

function _M._table_to_xml(self, t, root_name, indent)
    root_name = root_name or 'response'
    indent = indent or ''

    local xml_parts = _get_tab_from_pool()
    local idx = 1
    xml_parts[idx] = indent .. '<' .. root_name .. '>'
    idx = idx + 1

    local is_array = #t > 0
    local total = 0
    for _ in pairs(t) do total = total + 1 end

    local i = 0
    for k, v in pairs(t) do
        i = i + 1
        local key = tostring(k)

        if is_array then
            xml_parts[idx] = '\n'
            idx = idx + 1
            xml_parts[idx] = indent .. '  '
            idx = idx + 1
        else
            xml_parts[idx] = '<'
            idx = idx + 1
            xml_parts[idx] = key
            idx = idx + 1
            xml_parts[idx] = '>'
            idx = idx + 1
        end

        if type(v) == 'table' then
            xml_parts[idx] = self:_table_to_xml(v, 'item', indent .. '  ')
            idx = idx + 1
        else
            xml_parts[idx] = tostring(v)
            idx = idx + 1
        end

        xml_parts[idx] = '</'
        idx = idx + 1
        xml_parts[idx] = key
        idx = idx + 1
        xml_parts[idx] = '>'
        idx = idx + 1

        if is_array then
            xml_parts[idx] = '\n'
            idx = idx + 1
        end
    end

    xml_parts[idx] = indent .. '</'
    idx = idx + 1
    xml_parts[idx] = root_name
    idx = idx + 1
    xml_parts[idx] = '>'

    local xml = table_concat(xml_parts, '')
    _put_tab_into_pool(xml_parts)
    return xml
end

function _M.html(self, content, status)
    self.content_type = 'text/html; charset=utf-8'
    self.body = tostring(content)
    if status then
        self.status = tonumber(status) or 200
    end
    return self
end

function _M.text(self, content, status)
    self.content_type = 'text/plain; charset=utf-8'
    self.body = tostring(content)
    if status then
        self.status = tonumber(status) or 200
    end
    return self
end

function _M.output(self, content, content_type)
    if content_type then
        self.content_type = content_type
    end
    self.body = tostring(content)
    return self
end

function _M.download(self, file_path, file_name)
    self.content_type = 'application/octet-stream'
    self.headers['Content-Disposition'] = 'attachment; filename="' .. (file_name or 'download') .. '"'
    local f = io.open(file_path, 'rb')
    if f then
        self.body = f:read('*a')
        f:close()
    else
        self.body = ''
    end
    return self
end

function _M.redirect(self, uri, code)
    code = tonumber(code) or 302
    ngx_redirect(uri, code)
end

function _M.redirect_back(self, default)
    local referer = ngx_header['Referer'] or default or '/'
    self:redirect(referer)
end

function _M.set_header(self, name, value)
    self.headers[name] = value
    return self
end

function _M.set_headers(self, headers)
    for k, v in pairs(headers) do
        self.headers[k] = v
    end
    return self
end

function _M.delete_header(self, name)
    self.headers[name] = nil
    return self
end

function _M.no_content(self)
    self.status = 204
    self.body = ''
    return self
end

function _M.not_found(self, message)
    self.status = 404
    self.body = _json_encode({ error = message or 'Not Found' })
    return self
end

function _M.error(self, message, status)
    self.status = tonumber(status) or 500
    self.body = _json_encode({ error = message or 'Internal Server Error' })
    return self
end

function _M.success(self, data, message)
    return self.json({
        success = true,
        data = data,
        message = message
    })
end

function _M.fail(self, message, data, status)
    return self.json({
        success = false,
        message = message,
        data = data or nil
    }, status or 400)
end

function _M.paginate(self, data, total, page, per_page)
    local total_pages = math.ceil(total / per_page)
    return self.json({
        success = true,
        data = data,
        pagination = {
            page = page,
            per_page = per_page,
            total = total,
            total_pages = total_pages,
            has_next = page < total_pages,
            has_prev = page > 1
        }
    })
end

function _M.send(self)
    ngx.status = self.status or 200
    ngx_header['Content-Type'] = self.content_type or 'application/json'

    if self.headers then
        for k, v in pairs(self.headers) do
            ngx_header[k] = v
        end
    end

    ngx_say(self.body)
end

function _M.send_raw(self)
    ngx.status = self.status
    ngx_header['Content-Type'] = self.content_type

    for k, v in pairs(self.headers) do
        ngx_header[k] = v
    end

    ngx_print(self.body)
end

function _M.flush(self)
    ngx.flush(true)
end

function _M.download_lua(self, lua_table, file_name)
    local json = require('cjson')
    local minified = json.encode(lua_table)

    self.content_type = 'text/plain; charset=utf-8'
    self.headers['Content-Disposition'] = 'attachment; filename="' .. (file_name or 'data') .. '.lua"'

    local parts = new_tab(4, 0)
    parts[1] = '-- Generated by MyResty\n'
    parts[2] = 'local data = '
    parts[3] = minified
    parts[4] = '\nreturn data'

    self.body = table.concat(parts, '')
    return self
end

function _M._table_to_lua(self, t, indent)
    indent = indent or '    '
    local result = '{\n'

    local is_array = #t > 0
    local count = 0
    local total = 0
    for k, v in pairs(t) do
        total = total + 1
    end

    local i = 0
    for k, v in pairs(t) do
        i = i + 1
        result = result .. indent
        if is_array then
        else
            if type(k) == 'number' then
                result = result .. '[' .. k .. '] = '
            else
                result = result .. '["' .. tostring(k) .. '"] = '
            end
        end

        if type(v) == 'table' then
            result = result .. self:_table_to_lua(v, indent .. '    ')
        elseif type(v) == 'string' then
            result = result .. '"' .. v .. '"'
        elseif type(v) == 'boolean' then
            result = result .. tostring(v)
        else
            result = result .. tostring(v)
        end

        if i < total then
            result = result .. ',\n'
        else
            result = result .. '\n'
        end
    end

    result = result .. indent .. '}'
    return result
end

return _M
