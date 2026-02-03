-- Header Filter Phase Handler
-- 用途: 修改响应头、CORS

local Middleware = require('app.middleware')

local function run_header_filter()
    Middleware:run_phase('header_filter')
end

local ok, result = pcall(run_header_filter)

if not ok then
    ngx.log(ngx.ERR, 'Header filter error: ', result)
end
