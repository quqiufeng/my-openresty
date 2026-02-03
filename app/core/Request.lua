-- Copyright (c) 2026 MyResty Framework
-- Request handler with JSON and Form data support

local type = type
local tonumber = tonumber
local string_gmatch = string.gmatch
local setmetatable = setmetatable
local ngx_req = ngx.req
local ngx_var = nil
local ngx_log = ngx.log
local ngx_ERR = ngx.ERR

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

local cached_request = nil

local function _parse_cookies(headers)
    local cookies = {}
    local cookie_header = headers['Cookie'] or headers['cookie'] or ''

    if cookie_header ~= '' then
        for key, value in string.gmatch(cookie_header, '([^=]+)=([^;]*)') do
            local k = key:match('^%s*(.-)%s*$')
            local v = value:match('^%s*(.-)%s*$')
            if k and v then
                cookies[k] = v
            end
        end
    end
    return cookies
end

local function _parse_json_body(body)
    if not body or body == '' then
        return nil
    end
    local ok, result = pcall(require('cjson').decode, body)
    if ok and type(result) == 'table' then
        return result
    end
    return nil
end

local function _merge_input(get_args, form_args, json_body)
    local merged = _get_tab_from_pool()

    if get_args then
        for k, v in pairs(get_args) do
            merged[k] = v
        end
    end

    if form_args then
        for k, v in pairs(form_args) do
            merged[k] = v
        end
    end

    if json_body then
        for k, v in pairs(json_body) do
            merged[k] = v
        end
    end

    return merged
end

function _M.new(self)
    local instance = {
        get = {},
        post = {},
        json = {},
        server = {},
        headers = {},
        cookies = {},
        segments = {},
        uri_string = '',
        method = 'GET',
        is_ajax = false,
        is_json = false,
        body = nil,
        raw_post = nil,
        all_input = {}
    }
    return setmetatable(instance, mt)
end

function _M.fetch(self, force)
    if cached_request and not force then
        return cached_request
    end

    self.method = ngx_req.get_method()
    self.uri_string = ngx.var.uri or ''
    self.headers = ngx_req.get_headers() or {}
    self.is_ajax = self.headers['X-Requested-With'] == 'XMLHttpRequest'

    self.get = ngx_req.get_uri_args() or {}
    ngx_req.read_body()

    local content_type = self.headers['Content-Type'] or self.headers['content-type'] or ''
    local body_data = ngx_req.get_body_data()
    self.raw_post = body_data

    self.is_json = string.find(content_type, 'application/json', 1, true) == 1

    if self.is_json then
        self.json = _parse_json_body(body_data) or {}
        self.post = ngx_req.get_post_args() or {}
    else
        self.post = ngx_req.get_post_args() or {}
        self.json = {}
    end

    self.all_input = _merge_input(self.get, self.post, self.json)

    self.cookies = _parse_cookies(self.headers)
    self.server = ngx.var or {}

    self.segments = new_tab(8, 0)
    local seg_count = 0
    for segment in string_gmatch(self.uri_string, '([^/]+)') do
        seg_count = seg_count + 1
        self.segments[seg_count] = segment
    end

    self.ip = self.server.remote_addr or '127.0.0.1'
    self.port = tonumber(self.server.remote_port) or 0
    self.user_agent = self.headers['User-Agent'] or ''
    self.referer = self.headers['Referer'] or self.headers['referer'] or ''

    cached_request = self
    return self
end

function _M.reset_cache()
    cached_request = nil
end

function _M.get_method(self)
    return self.method or ngx.req.get_method()
end

function _M.is_ajax(self)
    return self.is_ajax
end

function _M.is_json(self)
    return self.is_json
end

function _M.is_get(self)
    return self.method == 'GET'
end

function _M.is_post(self)
    return self.method == 'POST'
end

function _M.is_put(self)
    return self.method == 'PUT'
end

function _M.is_delete(self)
    return self.method == 'DELETE'
end

function _M.is_patch(self)
    return self.method == 'PATCH'
end

function _M.is_options(self)
    return self.method == 'OPTIONS'
end

function _M.segment(self, n)
    n = tonumber(n)
    if n then
        return self.segments[n] or nil
    end
    return nil
end

function _M.param(self, name, default)
    local value = self.all_input[name]
    if value == nil then
        return default
    end
    return value
end

function _M.input(self, name, default)
    return self:param(name, default)
end

function _M.get_input(self)
    return self.get
end

function _M.post_input(self)
    return self.post or {}
end

function _M.json_input(self)
    return self.json or {}
end

function _M.all_input(self)
    return self.all_input or {}
end

function _M.only(self, ...)
    local keys = {...}
    local result = new_tab(#keys, 0)
    for _, key in ipairs(keys) do
        local value = self:param(key)
        if value ~= nil then
            result[key] = value
        end
    end
    return result
end

function _M.except(self, ...)
    local exclude = {}
    for _, key in ipairs{...} do
        exclude[key] = true
    end
    local result = new_tab(32, 0)
    for k, v in pairs(self:all_input()) do
        if not exclude[k] then
            result[k] = v
        end
    end
    return result
end

function _M.file(self, name)
    local files = ngx_req.get_body_files()
    if files and files[name] then
        return files[name]
    end
    return nil
end

function _M.get_uploaded_file(self, name)
    local file_info = self:file(name)
    if not file_info then
        return nil, 'File not found'
    end

    local filename = file_info.filename
    local filepath = file_info.path
    local filesize = file_info.size
    local content_type = file_info.content_type or ''

    local name_only = filename
    local ext = ''

    local dot_idx = string.find(filename, '%.%w+$')
    if dot_idx then
        name_only = string.sub(filename, 1, dot_idx - 1)
        ext = string.sub(filename, dot_idx + 1)
    end

    return {
        name = name_only,
        original_name = filename,
        ext = ext:lower(),
        path = filepath,
        size = filesize,
        content_type = content_type,
        size_formatted = self:_format_size(filesize)
    }
end

function _M._format_size(self, bytes)
    if not bytes or bytes == 0 then return '0 B' end

    local units = {'B', 'KB', 'MB', 'GB', 'TB'}
    local idx = 1
    local size = tonumber(bytes) or 0

    while size >= 1024 and idx < #units do
        size = size / 1024
        idx = idx + 1
    end

    if idx == 1 then
        return string.format('%d %s', size, units[idx])
    else
        return string.format('%.2f %s', size, units[idx])
    end
end

function _M.save_file(self, name, save_path, new_name)
    local file, err = self:get_uploaded_file(name)
    if not file then
        return nil, err
    end

    local config = self.config or {}
    local upload_config = config.upload or {}
    local upload_path = save_path or upload_config.path or '/var/www/web/my-resty/uploads'

    local FileHelper = require('app.helpers.file_helper')
    local FileUtil = require('app.utils.file')

    FileUtil.mkdir(upload_path, 493)

    local target_name = new_name or file.original_name
    if upload_config.sanitize_filename ~= false then
        target_name = FileHelper.sanitize_filename(target_name)
    end

    local target_path = upload_path .. '/' .. target_name

    local ok, bytes, err = FileUtil.copy(file.path, target_path)
    if ok then
        return {
            path = target_path,
            name = target_name,
            size = file.size,
            saved = true
        }
    end

    return nil, 'Failed to save file: ' .. tostring(err)
end

function _M.move_file(self, name, save_path, new_name)
    local file, err = self:get_uploaded_file(name)
    if not file then
        return nil, err
    end

    local config = self.config or {}
    local upload_config = config.upload or {}
    local upload_path = save_path or upload_config.path or '/var/www/web/my-resty/uploads'

    local FileHelper = require('app.helpers.file_helper')
    local FileUtil = require('app.utils.file')

    FileUtil.mkdir(upload_path, 493)

    local target_name = new_name or file.original_name
    if upload_config.sanitize_filename ~= false then
        target_name = FileHelper.sanitize_filename(target_name)
    end

    local target_path = upload_path .. '/' .. target_name

    local ok, err = FileUtil.move(file.path, target_path)
    if ok then
        return {
            path = target_path,
            name = target_name,
            size = file.size,
            moved = true
        }
    end

    return nil, 'Failed to move file: ' .. tostring(err)
end

function _M.delete_file(self, filepath)
    if not filepath or filepath == '' then
        return nil, 'Invalid filepath'
    end

    local FileUtil = require('app.utils.file')
    local ok, err = FileUtil.delete(filepath)
    if ok then
        return true
    end

    return nil, err or 'Failed to delete file'
end

function _M.is_uploaded_file(self, name)
    local file = self:file(name)
    if file and file.path and file.size and file.size > 0 then
        local FileUtil = require('app.utils.file')
        return FileUtil.exists(file.path)
    end
    return false
end

function _M.get_upload_config(self)
    local config = self.config or {}
    return config.upload or {}
end

function _M.get_image_config(self)
    local config = self.config or {}
    return config.image or {}
end

function _M.validate_upload(self, name, rules)
    local file, err = self:get_uploaded_file(name)
    if not file then
        return false, err or 'File not found'
    end

    local FileHelper = require('app.helpers.file_helper')
    local errors = {}

    local upload_config = self:get_upload_config()

    if rules.max_size then
        local max_bytes = rules.max_size * 1024 * 1024
        if file.size > max_bytes then
            table.insert(errors, 'File size exceeds ' .. tostring(rules.max_size) .. 'MB (actual: ' .. FileHelper.format_size(file.size) .. ')')
        end
    elseif upload_config.max_size then
        local max_bytes = upload_config.max_size * 1024 * 1024
        if file.size > max_bytes then
            table.insert(errors, 'File size exceeds ' .. tostring(upload_config.max_size) .. 'MB (actual: ' .. FileHelper.format_size(file.size) .. ')')
        end
    end

    if rules.allowed_types then
        local allowed = rules.allowed_types
        local is_allowed = false
        for _, t in ipairs(allowed) do
            if t:lower() == file.ext:lower() or t:lower() == file.content_type then
                is_allowed = true
                break
            end
        end
        if not is_allowed then
            table.insert(errors, 'File type ' .. file.ext .. ' is not allowed (MIME: ' .. file.content_type .. ')')
        end
    end

    if rules.denied_types then
        local denied = rules.denied_types
        for _, t in ipairs(denied) do
            if t:lower() == file.ext:lower() or t:lower() == file.content_type then
                table.insert(errors, 'File type ' .. file.ext .. ' is not allowed')
                break
            end
        end
    end

    if rules.images_only and not FileHelper.is_image(file.content_type) then
        table.insert(errors, 'Only image files are allowed')
    end

    if rules.documents_only and not FileHelper.is_document(file.content_type) then
        table.insert(errors, 'Only document files are allowed')
    end

    if rules.archives_only and not FileHelper.is_archive(file.content_type) then
        table.insert(errors, 'Only archive files are allowed')
    end

    if rules.audio_only and not FileHelper.is_audio(file.content_type) then
        table.insert(errors, 'Only audio files are allowed')
    end

    if rules.video_only and not FileHelper.is_video(file.content_type) then
        table.insert(errors, 'Only video files are allowed')
    end

    if rules.must_have_extension and not file.ext or file.ext == '' then
        table.insert(errors, 'File must have an extension')
    end

    if rules.allowed_extensions then
        local allowed = rules.allowed_extensions
        local is_allowed = false
        for _, ext in ipairs(allowed) do
            if ext:lower() == file.ext:lower() then
                is_allowed = true
                break
            end
        end
        if not is_allowed then
            table.insert(errors, 'File extension .' .. file.ext .. ' is not allowed')
        end
    end

    if #errors > 0 then
        return false, table.concat(errors, '; ')
    end

    return true
end

function _M.multiple_files(self)
    local files = ngx_req.get_body_files()
    local result = {}

    if files then
        for name, file_info in pairs(files) do
            local file = self:get_uploaded_file(name)
            if file then
                result[name] = file
            end
        end
    end

    return result
end

function _M.get_files(self, prefix)
    local files = self:multiple_files()
    local result = {}

    if prefix then
        for name, file in pairs(files) do
            if string.find(name, prefix, 1, true) == 1 then
                result[name] = file
            end
        end
    else
        result = files
    end

    return result
end

function _M.header(self, name)
    return self.headers[name] or self.headers[name:lower()] or nil
end

function _M.cookie(self, name)
    return self.cookies[name] or nil
end

function _M.ip(self)
    return self.ip
end

function _M.user_agent(self)
    return self.user_agent
end

function _M.referer(self)
    return self.referer
end

function _M.uri(self)
    return self.uri_string
end

function _M.url(self)
    local scheme = self.server.server_protocol or 'http'
    local host = self.server.host or 'localhost'
    local port = tonumber(self.server.server_port) or 80

    local url_parts = new_tab(4, 0)
    url_parts[1] = scheme
    url_parts[2] = '://'
    url_parts[3] = host
    if (scheme == 'http' and port ~= 80) or (scheme == 'https' and port ~= 443) then
        url_parts[4] = ':' .. tostring(port)
    end
    local base_url = table.concat(url_parts, '')
    return base_url .. self.uri_string
end

function _M.has(self, name)
    return self.all_input[name] ~= nil
end

function _M.has_get(self, name)
    return self.get[name] ~= nil
end

function _M.has_post(self, name)
    return self.post[name] ~= nil
end

function _M.has_json(self, name)
    return self.json[name] ~= nil
end

function _M.body(self)
    return self.raw_post
end

function _M.json_body(self)
    return self.json
end

function _M.expects_json(self)
    return self.is_json
end

function _M.validation_errors(self)
    return self._validation_errors or {}
end

function _M.set_validation_errors(self, errors)
    self._validation_errors = errors
    return self
end

return _M
