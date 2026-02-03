-- Set Phase Handler
-- 用途: 设置请求变量

local Middleware = require('app.middleware')

local function generate_request_id()
    local random = require('resty.random')
    local str = require('resty.string')
    local rand = random:bytes(16)
    return str.to_hex(rand)
end

local request_id = ngx.var.http_x_request_id or ngx.var.http_x_requestid
if not request_id then
    request_id = generate_request_id()
end

ngx.var.request_id = request_id
