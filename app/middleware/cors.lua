local CORS = {}

CORS.options = {
    origin = '*',  -- Origin to allow, * for all, false to disable
    methods = {'GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'},
    headers = {
        'Content-Type',
        'Authorization',
        'X-Requested-With',
        'X-Request-ID',
        'Accept',
        'Origin',
        'Cache-Control',
        'X-Requested-With'
    },
    expose_headers = {
        'X-Request-ID',
        'X-Total-Count',
        'X-Page-Count'
    },
    credentials = true,
    max_age = 86400,
    options_passthrough = true,  -- Auto handle OPTIONS
    allowed_origins = {},  -- Specific origins list
    origin_patterns = {}  -- Origin patterns (wildcards)
}

function CORS:setup(options)
    self.options = vim.tbl_deep_extend('force', self.options, options or {})
    return self
end

function CORS:handle(options)
    options = vim.tbl_deep_extend('force', self.options, options or {})

    local request_method = ngx.var.request_method

    -- 1. 处理 OPTIONS 预检请求
    if request_method == 'OPTIONS' and options.options_passthrough then
        self:handle_options(options)
        ngx.exit(204)
        return false
    end

    -- 2. 获取请求 Origin
    local origin = ngx.var.http_origin or ngx.var.http_x_origin or ''

    -- 3. 验证 Origin
    if options.origin ~= '*' then
        if #options.allowed_origins > 0 then
            local allowed = false
            for _, o in ipairs(options.allowed_origins) do
                if origin == o then
                    allowed = true
                    break
                end
            end
            if not allowed and origin ~= '' then
                return true  -- Origin not allowed, but continue
            end
        end
    end

    -- 4. 设置 CORS 头
    if options.origin then
        if options.origin == '*' then
            ngx.header['Access-Control-Allow-Origin'] = origin ~= '' and origin or '*'
        else
            ngx.header['Access-Control-Allow-Origin'] = options.origin
        end
    end

    -- 5. 设置允许的方法
    ngx.header['Access-Control-Allow-Methods'] = table.concat(options.methods, ', ')

    -- 6. 设置允许的请求头
    ngx.header['Access-Control-Allow-Headers'] = table.concat(options.headers, ', ')

    -- 7. 设置暴露的响应头
    if options.expose_headers and #options.expose_headers > 0 then
        ngx.header['Access-Control-Expose-Headers'] = table.concat(options.expose_headers, ', ')
    end

    -- 8. 凭证
    if options.credentials then
        ngx.header['Access-Control-Allow-Credentials'] = 'true'
    end

    -- 9. 预检缓存时间
    if options.max_age then
        ngx.header['Access-Control-Max-Age'] = tostring(options.max_age)
    end

    return true
end

function CORS:handle_options(options)
    local origin = ngx.var.http_origin or ngx.var.http_x_origin or ''

    if options.origin ~= '*' and #options.allowed_origins > 0 then
        local allowed = false
        for _, o in ipairs(options.allowed_origins) do
            if origin == o then
                allowed = true
                break
            end
        end
        if not allowed then
            origin = ''
        end
    end

    if options.origin then
        ngx.header['Access-Control-Allow-Origin'] = options.origin == '*' and (origin ~= '' and origin or '*') or options.origin
    end

    ngx.header['Access-Control-Allow-Methods'] = table.concat(options.methods, ', ')
    ngx.header['Access-Control-Allow-Headers'] = table.concat(options.headers, ', ')

    if options.expose_headers and #options.expose_headers > 0 then
        ngx.header['Access-Control-Expose-Headers'] = table.concat(options.expose_headers, ', ')
    end

    if options.credentials then
        ngx.header['Access-Control-Allow-Credentials'] = 'true'
    end

    if options.max_age then
        ngx.header['Access-Control-Max-Age'] = tostring(options.max_age)
    end
end

function CORS:allow_origin(origin, options)
    options = options or self.options
    table.insert(options.allowed_origins, origin)
    return self
end

function CORS:add_origin_pattern(pattern, options)
    options = options or self.options
    table.insert(options.origin_patterns, pattern)
    return self
end

function CORS:add_header(header, options)
    options = options or self.options
    table.insert(options.headers, header)
    return self
end

function CORS:add_expose_header(header, options)
    options = options or self.options
    table.insert(options.expose_headers, header)
    return self
end

function CORS:disable_credentials()
    self.options.credentials = false
    return self
end

function CORS:restrict_to_origins(origins, options)
    options = options or self.options
    options.allowed_origins = origins
    options.origin = nil  -- Disable wildcard
    return self
end

return CORS
