-- Access Phase Handler
-- 用途: 认证、授权、限流

local Middleware = require('app.middleware')

local function run_access_middleware()
    -- Ensure middleware config is loaded before the first access phase
    -- (bootstrap.lua sets it up in the content phase, which runs later).
    if #Middleware:get_config() == 0 then
        local Config = require('app.core.Config')
        Config.load()
        Middleware:setup(Config.get('middleware') or {})
    end
    return Middleware:run_phase('access')
end

local ok, result = pcall(run_access_middleware)
if not ok then
    ngx.log(ngx.ERR, 'Access middleware error: ', result)
end
