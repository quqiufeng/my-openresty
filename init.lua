package.path = '/var/www/web/my-openresty/app/?.lua;/var/www/web/my-openresty/app/core/?.lua;/var/www/web/my-openresty/app/libraries/?.lua;/var/www/web/my-openresty/app/middleware/?.lua;;'

local ok, vim = pcall(require, 'vim')
if not ok then
    vim = nil
end

local function deep_extend(force, a, b)
    if not b then return a end
    if not a then return b end
    if vim and vim.tbl_deep_extend then
        return vim.tbl_deep_extend('force', a, b)
    end
    -- Fallback for basic extend
    local result = {}
    for k, v in pairs(a) do result[k] = v end
    for k, v in pairs(b) do result[k] = v end
    return result
end

local Config = require('app.core.Config')
Config.load()

local Mysql = require('app.libraries.mysql')
local Redis = require('app.libraries.redis')
local Session = require('app.libraries.session')
local Cache = require('app.libraries.cache')
local Logger = require('app.libraries.logger')
local Limit = require('app.libraries.limit')
local Validation = require('app.libraries.validation')
local Validator = require('app.libraries.validator')
local Middleware = require('app.middleware')

local mysql_config = Config.get('mysql')
local redis_config = Config.get('redis')
local limit_config = Config.get('limit')
local logger_config = Config.get('logger')

if mysql_config then
    Mysql.init(mysql_config)
end

if redis_config then
    Redis.init(redis_config)
end

if limit_config then
    Limit:new(limit_config)
end

if logger_config then
    Logger:new(logger_config)
end

local middleware_config = Config.get('middleware') or {
    { name = 'logger', phase = 'log', options = { level = logger_config and logger_config.level or 'info' } },
    { name = 'cors', phase = 'header_filter' }
}

Middleware:setup(middleware_config)

ngx.log(ngx.INFO, 'MyResty initialized')
