-- Log Phase Handler
-- 用途: 请求日志记录

local Middleware = require('app.middleware')

local function run_log()
    Middleware:run_phase('log')
end

local ok, result = pcall(run_log)

if not ok then
    ngx.log(ngx.ERR, 'Log middleware error: ', result)
end
