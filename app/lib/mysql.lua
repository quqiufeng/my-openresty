local _M = {}

local resty_mysql = require('resty.mysql')
local mysql_config = require('app.config.mysql')

local pools = {}

local function get_pool_name(config)
    return string.format('%s:%s:%d:%s',
        config.user or '',
        config.database or '',
        config.port or 3306,
        config.host or '127.0.0.1'
    )
end

function _M.new(db_name)
    local config = mysql_config.get(db_name)

    local db = resty_mysql:new()
    db:set_timeout(config.timeout or 5000)

    return db, config
end

function _M.connect(db, db_name)
    local config = mysql_config.get(db_name)

    local ok, err = db:connect({
        host = config.host,
        port = config.port,
        user = config.user,
        password = config.password,
        database = config.database,
        charset = config.charset,
        pool = get_pool_name(config)
    })

    if not ok then
        return nil, err
    end

    return true
end

function _M.query(db, sql, db_name)
    local config = mysql_config.get(db_name)
    return db:query(sql)
end

function _M.close(db)
    if db then
        return db:close()
    end
end

function _M.set_keepalive(db, db_name)
    if not db then
        return nil, 'not initialized'
    end

    local config = mysql_config.get(db_name)
    local pool_size = config.pool_size or 20
    local idle_timeout = config.pool_idle_timeout or 60000

    return db:set_keepalive(idle_timeout, pool_size)
end

function _M.get_config(db_name)
    return mysql_config.get(db_name)
end

function _M.set_default_config(config)
    mysql_config.setup(config)
end

function _M.add_named_connection(name, config)
    mysql_config.add_connection(name, config)
end

return _M
