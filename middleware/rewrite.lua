-- Rewrite Phase Handler
local ok, result = pcall(function()
    local Middleware = require('app.middleware')
    return Middleware:run_phase('rewrite')
end)
if not ok then
    ngx.log(ngx.ERR, 'Rewrite middleware error: ', result)
end
