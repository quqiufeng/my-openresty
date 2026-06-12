-- Access Phase Handler
-- 用途: 认证、授权、限流

local Middleware = require('app.middleware')

local function run_access_middleware()
    return Middleware:run_phase('access')
end

local ok, result = pcall(run_access_middleware)
if not ok then
    ngx.log(ngx.ERR, 'Access middleware error: ', result)
end
