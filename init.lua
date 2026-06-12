package.path = '/var/www/web/my-openresty/?.lua;/var/www/web/my-openresty/?/init.lua;/usr/local/lualib/?.lua;;'

local Config = require('app.core.Config')
Config.load()

-- Initialize middleware system (runs once at nginx startup)
local Middleware = require('app.middleware')
local middleware_config = Config.get('middleware') or {
    { name = 'logger', phase = 'log', options = { level = 'info' } },
    { name = 'cors', phase = 'header_filter' }
}
Middleware:setup(middleware_config)

-- Lazy-init optional services (will be initialized on first use)
local mysql_config = Config.get('mysql')
if mysql_config then
    -- Only log, don't force connection at startup
    ngx.log(ngx.INFO, 'MySQL config loaded (pool: ', mysql_config.pool_size or 100, ')')
end

ngx.log(ngx.INFO, 'MyResty initialized')
