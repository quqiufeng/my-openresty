-- 运行路径：优先 nginx 前缀（-p）
local _prefix = (ngx and ngx.config and ngx.config.prefix and ngx.config.prefix()) or ''
if _prefix ~= '' and _prefix:sub(-1) ~= '/' then _prefix = _prefix .. '/' end
package.path = _prefix .. '?.lua;' .. _prefix .. '?/init.lua;'
            .. _prefix .. 'lib/?.lua;' .. _prefix .. 'lib/?/init.lua;'
            .. '/var/www/web/my-openresty/?.lua;/var/www/web/my-openresty/?/init.lua;/usr/local/lualib/?.lua;;'

local Config = require('app.core.Config')
Config.load()

-- Initialize middleware system (runs once at nginx startup)
local Middleware = require('app.middleware')
local middleware_config = Config.get('middleware') or {
    { name = 'logger', phase = 'log', options = { level = 'info' } },
    { name = 'cors', phase = 'header_filter' }
}
Middleware:setup(middleware_config)

-- Register all routes once per worker (instead of on every request).
local Router = require('app.core.Router')
local Routes = require('app.routes')
Router:reset_routes()
Routes(Router)
Router:get('/test', function(req, res)
    res:json({message = 'Direct route works!'})
end)
ngx.log(ngx.INFO, 'MyResty routes registered: ', Router:count_routes())

-- Lazy-init optional services (will be initialized on first use)
local mysql_config = Config.get('mysql')
if mysql_config then
    -- Only log, don't force connection at startup
    ngx.log(ngx.INFO, 'MySQL config loaded (pool: ', mysql_config.pool_size or 100, ')')
end

ngx.log(ngx.INFO, 'MyResty initialized')
