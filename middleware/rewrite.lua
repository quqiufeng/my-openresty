-- Rewrite Phase Handler
-- 用途: URI 重写、路径标准化

local Middleware = require('app.middleware')

local function run_rewrite_middleware()
    return Middleware:run_phase('rewrite')
end

run_rewrite_middleware()
