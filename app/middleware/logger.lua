local Logger = {}

Logger.options = {
    level = 'info',  -- debug, info, warn, error
    format = 'combined',  -- combined, json, custom
    include_headers = false,
    exclude_paths = {'/health', '/favicon.ico'},
    request_id = true,
    timing = true,
    user_agent = true,
    referer = true
}

Logger.request_id_header = 'X-Request-ID'

function Logger:setup(options)
    self.options = vim.tbl_deep_extend('force', self.options, options or {})
    return self
end

function Logger:handle(options)
    options = vim.tbl_deep_extend('force', self.options, options or {})

    local uri = ngx.var.uri

    -- 排除路径
    for _, path in ipairs(options.exclude_paths or {}) do
        if uri == path then
            return true
        end
    end

    -- 生成或获取 Request ID
    if options.request_id then
        local request_id = ngx.var.http_x_request_id or ngx.var.http_x_requestid
        if not request_id then
            request_id = self:generate_request_id()
        end
        ngx.ctx.request_id = request_id
        ngx.header[self.request_id_header] = request_id
    end

    -- 记录请求开始时间
    if options.timing then
        ngx.ctx.request_start = ngx.now()
    end

    -- 记录请求信息
    local log_data = self:build_request_log(options)

    self:log_request(log_data, options)

    return true
end

function Logger:generate_request_id()
    local bytes = 16
    local random = require('resty.random')
    local str = require('resty.string')

    local rand = random:bytes(bytes)
    return str.to_hex(rand)
end

function Logger:build_request_log(options)
    local log = {
        request_id = ngx.ctx.request_id or '',
        timestamp = os.date('%Y-%m-%dT%H:%M:%S'),
        method = ngx.var.request_method or '',
        uri = ngx.var.uri or '',
        query = ngx.var.query_string or '',
        protocol = ngx.var.server_protocol or '',
        ip = ngx.var.remote_addr or '',
        real_ip = ngx.var.http_x_forwarded_for or ngx.var.remote_addr,
        status = 0
    }

    if options.user_agent then
        log.user_agent = ngx.var.http_user_agent or ''
    end

    if options.referer then
        log.referer = ngx.var.http_referer or ''
    end

    log.body_size = tonumber(ngx.var.http_content_length or 0)

    return log
end

function Logger:log_request(log, options)
    local level = self:get_log_level(options.level)

    local message = self:format_message(log, options.format)

    if options.timing then
        message.duration = 0  -- 在 log 阶段更新
    end

    ngx.log(level, '[' .. log.request_id .. '] ' .. message.raw)
end

function Logger:get_log_level(level)
    local levels = {
        debug = ngx.DEBUG,
        info = ngx.INFO,
        warn = ngx.WARN,
        error = ngx.ERR
    }
    return levels[level] or ngx.INFO
end

function Logger:format_message(log, format)
    if format == 'json' then
        return {
            raw = ngx.encode_json(log)
        }
    end

    -- combined 格式
    local combined = string.format(
        '%s - %s [%s] "%s %s%s %s" %d %d "%s" "%s"',
        log.ip,
        '-',
        log.timestamp,
        log.method,
        log.uri,
        log.query ~= '' and '?' .. log.query or '',
        log.protocol,
        log.status,
        log.body_size,
        log.referer or '-',
        log.user_agent or '-'
    )

    return {
        raw = combined,
        json = log
    }
end

function Logger:log_response()
    local duration = 0
    if ngx.ctx.request_start then
        duration = (ngx.now() - ngx.ctx.request_start) * 1000
    end

    local log = ngx.ctx.request_log or {}
    log.status = ngx.status
    log.duration = duration

    local level = self:get_log_level(self.options.level)

    local message = self:format_message(log, self.options.format)

    ngx.log(level, '[' .. (ngx.ctx.request_id or '-') .. '] ' ..
            message.raw .. ' ' .. string.format('%.2f', duration) .. 'ms')
end

function Logger:get_request_id()
    return ngx.ctx.request_id
end

function Logger:set_context(key, value)
    if not ngx.ctx.request_log then
        ngx.ctx.request_log = {}
    end
    ngx.ctx.request_log[key] = value
end

function Logger:get_context(key)
    return ngx.ctx.request_log and ngx.ctx.request_log[key]
end

return Logger
