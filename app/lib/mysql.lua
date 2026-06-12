local ngx_log = ngx.log
local ngx_WARN = ngx.WARN

local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function(narr, nrec) return {} end
end

local _M = { _VERSION = '1.0.0' }

local resty_mysql = require('resty.mysql')
local Config = require('app.config.config')

-- Cache MySQL config once at module load
local mysql_config = Config.mysql or {}
local pool_size = mysql_config.pool_size or 100
local idle_timeout = mysql_config.idle_timeout or 10000
local default_timeout = mysql_config.timeout or 5000

-- Pre-compute pool name from config (avoids string.format per connect)
local pool_name = string.format('%s:%s:%d:%s',
    mysql_config.user or '',
    mysql_config.database or '',
    mysql_config.port or 3306,
    mysql_config.host or '127.0.0.1'
)

function _M.new()
    local db = resty_mysql:new()
    db:set_timeout(default_timeout)
    return db, mysql_config
end

function _M.connect(db, db_name)
    local config = mysql_config
    if db_name then
        local conn_config = Config.connections and Config.connections[db_name]
        if conn_config then
            local final_config = new_tab(0, 8)
            for k, v in pairs(config) do final_config[k] = v end
            for k, v in pairs(conn_config) do final_config[k] = v end
            config = final_config
        end
    end

    local ok, err = db:connect({
        host = config.host,
        port = config.port,
        user = config.user,
        password = config.password,
        database = config.database,
        charset = config.charset,
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
    return db:set_keepalive(idle_timeout, pool_size)
end

return _M
