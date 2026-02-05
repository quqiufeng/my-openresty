local _M = {}

_M.default = {
    host = '127.0.0.1',
    port = 3306,
    user = 'root',
    password = '123456',
    database = 'project',
    charset = 'utf8mb4',
    timeout = 5000,
    pool_size = 20,
    pool_idle_timeout = 60000
}

_M.connections = {}

function _M.setup(config)
    for k, v in pairs(config) do
        _M.default[k] = v
    end
end

function _M.add_connection(name, config)
    local conn = {}
    for k, v in pairs(_M.default) do
        conn[k] = v
    end
    for k, v in pairs(config or {}) do
        conn[k] = v
    end
    _M.connections[name] = conn
end

function _M.get(name)
    if name then
        return _M.connections[name] or _M.default
    end
    return _M.default
end

return _M
