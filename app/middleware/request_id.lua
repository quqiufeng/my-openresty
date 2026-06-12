-- Request ID Middleware
-- Generates unique request ID for tracing and debugging
-- Injects X-Request-Id header into response
local RequestId = {}

RequestId.options = {
    header_name = 'X-Request-Id',
    set_response_header = true,
    log_with_request = true,
    id_format = 'hex',  -- hex, uuid, short
}

local ngx_log = ngx.log
local ngx_ERR = ngx.ERR
local ngx_INFO = ngx.INFO
local ngx_now = ngx.now
local ngx_header = ngx.header
local ngx_ctx = ngx.ctx
local tostring = tostring
local string_format = string.format
local string_byte = string.byte

-- Generate a hex-formatted request ID: {pid}-{timestamp}-{random}
local function generate_hex_id()
    local pid = ngx.worker and ngx.worker.pid() or 0
    local time_ms = ngx_now() * 1000
    local random_part = math.random(100000, 999999)
    return string_format('%x-%x-%x', pid, time_ms, random_part)
end

function RequestId:setup(options)
    if options then
        for k, v in pairs(options) do
            self.options[k] = v
        end
    end
    return self
end

function RequestId:handle(options)
        if options then
        for k, v in pairs(options) do
            self.options[k] = v
        end
    end

    local request_id = ngx_header[self.options.header_name]
    if not request_id or request_id == '' then
        request_id = generate_hex_id()
    end

    -- Store in context for other components
    ngx_ctx.request_id = request_id

    -- Set response header
    if self.options.set_response_header then
        ngx_header[self.options.header_name] = request_id
    end

    -- Log with request
    if self.options.log_with_request then
        ngx_log(ngx_INFO, '[', request_id, '] Request: ', ngx.var.uri)
    end

    return true
end

return RequestId
