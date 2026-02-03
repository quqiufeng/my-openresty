-- Body Filter Phase Handler
-- 用途: 修改响应体、压缩

local Middleware = require('app.middleware')

local function run_body_filter()
    Middleware:run_phase('body_filter')
end

local ok, result = pcall(run_body_filter)

if not ok then
    ngx.log(ngx.ERR, 'Body filter error: ', result)
end
