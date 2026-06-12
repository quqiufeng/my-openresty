local ngx_log = ngx.log
local ngx_WARN = ngx.WARN

local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function(narr, nrec) return {} end
end

local _M = { _VERSION = '1.0.0' }

local resty_mysql = require('resty.mysql')
local Config = require('app.config.config')

function _M.new()
    local config = Config.mysql or {}

    local db = resty_mysql:new()
    db:set_timeout(config.timeout or 5000)

    return db, config
end

function _M.connect(db, db_name)
    local config = Config.mysql or {}
    local conn_config = Config.connections and Config.connections[db_name] or {}

    local final_config = new_tab(0, 8)
    for k, v in pairs(config) do final_config[k] = v end
    for k, v in pairs(conn_config) do final_config[k] = v end

    local pool_name = string.format('%s:%s:%d:%s',
        final_config.user or '',
        final_config.database or '',
        final_config.port or 3306,
        final_config.host or '127.0.0.1'
    )

    local ok, err = db:connect({
        host = final_config.host,
        port = final_config.port,
        user = final_config.user,
        password = final_config.password,
        database = final_config.database,
        charset = final_config.charset,
        pool = pool_name
    })

    if not ok then
        return nil, err
    end

    return true
end

function _M.query(db, sql)
    return db:query(sql)
end

-- DEPRECATED: Use set_keepalive() instead.
-- Calling close() may cause "Got packets out of order" errors.
-- See CLAUDE.md Bug#1 for details.
function _M.close(db)
    if db then
        ngx.log(ngx.WARN, 'mysql:close() is deprecated, use set_keepalive() instead')
        return db:close()
    end
end

function _M.set_keepalive(db)
    if not db then
        return nil, 'not initialized'
    end

    local config = Config.mysql or {}
    local pool_size = config.pool_size or 100
    local idle_timeout = config.idle_timeout or 10000

    return db:set_keepalive(idle_timeout, pool_size)
end

return _M
