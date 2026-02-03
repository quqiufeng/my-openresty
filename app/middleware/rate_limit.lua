local RateLimit = {}

RateLimit.options = {
    zones = {},
    default_limit = 60,
    default_window = 60,
    response_status = 429,
    response_message = 'Too Many Requests',
    headers = true,
    key_by_ip = true,
    key_by_user = false,
    log_blocked = true
}

RateLimit.zones = {
    api = { limit = 60, window = 60 },
    login = { limit = 5, window = 300 },
    upload = { limit = 10, window = 60 },
    default = { limit = 100, window = 60 }
}

function RateLimit:setup(options)
    self.options = vim.tbl_deep_extend('force', self.options, options or {})

    for name, config in pairs(self.zones) do
        if not self.options.zones[name] then
            self.options.zones[name] = config
        end
    end

    return self
end

function RateLimit:handle(options)
    options = vim.tbl_deep_extend('force', self.options, options or {})

    local zone_name = options.zone or 'default'
    local zone = options.zones and options.zones[zone_name] or self.options.zones[zone_name]

    if not zone then
        zone = {
            limit = options.default_limit,
            window = options.default_window
        }
    end

    local key = self:get_key(options, zone_name)

    local Limit = require('app.lib.limit')
    local limit = Limit:new({
        strategy = 'sliding_window',
        default_limit = zone.limit,
        default_window = zone.window,
        log_blocked = options.log_blocked
    })

    local success, info = limit:check(key, ngx.var.uri, zone.limit, zone.window, zone.burst or 0)

    if options.headers then
        self:set_headers(info)
    end

    if not success then
        if options.log_blocked then
            ngx.log(ngx.WARN, 'Rate limit exceeded: ' .. key .. ' (' .. info.current .. '/' .. info.limit .. ')')
        end

        ngx.status = options.response_status
        ngx.header['Content-Type'] = 'application/json'
        ngx.header['Retry-After'] = tostring(info.reset - ngx.now())
        ngx.say('{"success":false,"error":"' .. options.response_message .. '","code":' .. options.response_status .. ',"retry_after":' .. info.reset .. '}')
        ngx.exit(options.response_status)
        return false
    end

    return true
end

function RateLimit:get_key(options, zone_name)
    local key_parts = {}

    -- 按 IP 限流
    if options.key_by_ip ~= false then
        table.insert(key_parts, ngx.var.remote_addr or 'unknown')
    end

    -- 按用户限流
    if options.key_by_user then
        local Session = require('app.lib.session')
        local session = Session:new()
        local user_id = session:get('user_id')
        if user_id then
            table.insert(key_parts, 'user:' .. user_id)
        end
    end

    -- 按路由限流
    table.insert(key_parts, 'zone:' .. zone_name)

    return table.concat(key_parts, ':')
end

function RateLimit:set_headers(info)
    if not info then return end

    ngx.header['X-RateLimit-Limit'] = info.limit
    ngx.header['X-RateLimit-Remaining'] = info.remaining
    ngx.header['X-RateLimit-Reset'] = info.reset
    ngx.header['X-RateLimit-Window'] = info.window
end

function RateLimit:create_zone(name, limit, window, burst)
    self.options.zones[name] = {
        limit = limit,
        window = window,
        burst = burst or 0
    }
    return self
end

function RateLimit:zone(name)
    return {
        limit = function(self, n)
            self.zone_config = self.zone_config or {}
            self.zone_config.limit = n
            return self
        end,
        window = function(self, w)
            self.zone_config = self.zone_config or {}
            self.zone_config.window = w
            return self
        end,
        burst = function(self, b)
            self.zone_config = self.zone_config or {}
            self.zone_config.burst = b
            return self
        end,
        build = function(self)
            local zone = self.zone_config or {}
            self.zone_config = nil
            return zone
        end
    }
end

return RateLimit
