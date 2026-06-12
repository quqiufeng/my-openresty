-- Timeout & Degradation Middleware
-- Tracks request execution time and provides graceful degradation
-- when upstream services are unavailable
local Timeout = {}

Timeout.options = {
    max_execution_time = 30,  -- seconds
    degradation_mode = false,  -- auto-enabled when errors detected
    degraded_cache_ttl = 60,   -- seconds to serve stale cache
    health_check_path = '/health',
}

local ngx_log = ngx.log
local ngx_ERR = ngx.ERR
local ngx_WARN = ngx.WARN
local ngx_INFO = ngx.INFO
local ngx_now = ngx.now
local ngx_ctx = ngx.ctx
local ngx_exit = ngx.exit
local ngx_header = ngx.header

local degradation_count = 0
local degradation_threshold = 5  -- errors within window triggers degradation
local degradation_window = 60    -- seconds
local degradation_start = nil
local window_start = ngx_now()

function Timeout:setup(options)
    if options then
        for k, v in pairs(options) do
            self.options[k] = v
        end
    end
    return self
end

function Timeout:handle(options)
    local opts = options or self.options

    -- Record start time
    ngx_ctx._request_start = ngx_now()
    ngx_ctx._max_execution = opts.max_execution_time or 30

    -- Check if we're in degradation mode
    if self:is_degraded() then
        ngx_ctx._degraded = true
        ngx_header['X-Degradation-Mode'] = 'true'
    end

    return true
end

function Timeout:check_timeout()
    local start = ngx_ctx._request_start
    if not start then return true end

    local elapsed = ngx_now() - start
    local max_time = ngx_ctx._max_execution or 30

    if elapsed > max_time then
        ngx_log(ngx_ERR, 'Request timeout after ', elapsed, 's (max: ', max_time, 's)')
        ngx_header['Content-Type'] = 'application/json'
        ngx.status = 408
        ngx.say('{"success":false,"error":"Request timeout","code":408}')
        ngx_exit(408)
        return false
    end
    return true
end

function Timeout:record_error()
    local now = ngx_now()
    -- Reset window if expired
    if now - window_start > degradation_window then
        degradation_count = 0
        window_start = now
    end

    degradation_count = degradation_count + 1

    if degradation_count >= degradation_threshold and not degradation_start then
        degradation_start = now
        ngx_log(ngx_WARN, 'Entering degradation mode after ', degradation_count, ' errors')
    end
end

function Timeout:is_degraded()
    if not degradation_start then return false end
    -- Auto-recover after 2x degradation_window
    if ngx_now() - degradation_start > degradation_window * 2 then
        degradation_count = 0
        degradation_start = nil
        ngx_log(ngx_INFO, 'Exiting degradation mode')
        return false
    end
    return true
end

function Timeout:recover()
    degradation_count = 0
    degradation_start = nil
    ngx_log(ngx_INFO, 'Manual recovery from degradation mode')
end

return Timeout
