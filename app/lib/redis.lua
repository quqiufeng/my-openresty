-- Copyright (c) 2026 MyResty Framework
-- Redis connection pool library with official resty pattern
-- Reference: lua-resty-redis

local sub = string.sub
local byte = string.byte
local tab_insert = table.insert
local tab_remove = table.remove
local tcp = ngx.socket.tcp
local null = ngx.null
local ipairs = ipairs
local type = type
local pairs = pairs
local unpack = unpack
local setmetatable = setmetatable
local tonumber = tonumber
local tostring = tostring
local rawget = rawget
local select = select
local ngx_log = ngx.log
local ngx_ERR = ngx.ERR
local ngx_INFO = ngx.INFO

local ok, new_tab = pcall(require, "table.new")
if not ok or type(new_tab) ~= "function" then
    new_tab = function(narr, nrec) return {} end
end

local ok, tb_clear = pcall(require, "table.clear")
if not ok then
    tb_clear = function(tab)
        for k, _ in pairs(tab) do tab[k] = nil end
    end
end

local _M = { _VERSION = '1.0.0' }
local mt = { __index = _M }

local RESPONSE_PREFIX = {
    ['+'] = true,
    ['-'] = true,
    [':'] = true,
    ['$'] = true,
    ['*'] = true
}

local _Pool = {}
_Pool.free = {}
_Pool.size = 100
_Pool.idle_timeout = 10000
_Pool.config = {}

-- Table pool (aligned with lua-resty-redis)
local tab_pool_len = 0
local tab_pool = new_tab(16, 0)

local function _get_tab_from_pool()
    if tab_pool_len > 0 then
        tab_pool_len = tab_pool_len - 1
        return tab_pool[tab_pool_len + 1]
    end
    return new_tab(24, 0)
end

local function _put_tab_into_pool(tab)
    if tab_pool_len >= 32 then
        return
    end
    tb_clear(tab)
    tab_pool_len = tab_pool_len + 1
    tab_pool[tab_pool_len] = tab
end

local function _gen_req(args)
    local nargs = #args
    local req = _get_tab_from_pool()
    local nbits = 1

    req[1] = "*"
    req[2] = nargs
    req[3] = "\r\n"

    for i = 1, nargs do
        local arg = args[i]
        if type(arg) ~= "string" then
            arg = tostring(arg)
        end
        local len = #arg
        req[nbits + 3] = "$"
        req[nbits + 4] = len
        req[nbits + 5] = "\r\n"
        req[nbits + 6] = arg
        req[nbits + 7] = "\r\n"
        nbits = nbits + 5
    end

    return req
end

local function _read_reply(self, sock)
    local line, err = sock:receive()
    if not line then
        if err == "timeout" then
            sock:close()
        end
        return nil, err
    end

    local prefix = string_byte(line)

    if prefix == 36 then
        local size = tonumber(string_sub(line, 2))
        if size < 0 then return nil end

        local data, err = sock:receive(size)
        if not data then
            if err == "timeout" then sock:close() end
            return nil, err
        end
        sock:receive(2)
        return data

    elseif prefix == 43 then
        return string_sub(line, 2)

    elseif prefix == 42 then
        local n = tonumber(string_sub(line, 2))
        if n < 0 then return nil end

        local vals = new_tab(n, 0)
        local nvals = 0
        for i = 1, n do
            local res, err = _read_reply(self, sock)
            if res then
                nvals = nvals + 1
                vals[nvals] = res
            elseif res == nil then
                return nil, err
            else
                nvals = nvals + 1
                vals[nvals] = {false, err}
            end
        end
        return vals

    elseif prefix == 58 then
        return tonumber(string_sub(line, 2))

    elseif prefix == 45 then
        return nil, string_sub(line, 2)

    else
        return nil, "unknown prefix: " .. tostring(prefix)
    end
end

local function _do_cmd(self, ...)
    local args = {...}

    local sock = rawget(self, "_sock")
    if not sock then
        return nil, "not initialized"
    end

    local req = _gen_req(args)

    local reqs = rawget(self, "_reqs")
    if reqs then
        reqs[#reqs + 1] = req
        return
    end

    local bytes, err = sock:send(req)
    _put_tab_into_pool(req)

    if not bytes then
        return nil, err
    end

    return _read_reply(self, sock)
end

function _M.init(config)
    _Pool.config = config or {}
    _Pool.size = config.pool_size or 100
    _Pool.idle_timeout = config.idle_timeout or 10000
    ngx_log(ngx_INFO, 'Redis pool initialized with size: ', _Pool.size)
end

function _M.new(self)
    local sock, err = tcp()
    if not sock then
        return nil, err
    end
    return setmetatable({ _sock = sock,
                          _subscribed = false,
                          _n_channel = {
                            unsubscribe = 0,
                            punsubscribe = 0,
                          },
                        }, mt)
end

function _M.set_timeout(self, timeout)
    local sock = rawget(self, "_sock")
    if not sock then return nil, "not initialized" end
    return sock:settimeout(timeout)
end

function _M.set_timeouts(self, connect_timeout, send_timeout, read_timeout)
    local sock = rawget(self, "_sock")
    if not sock then return nil, "not initialized" end
    return sock:settimeouts(connect_timeout, send_timeout, read_timeout)
end

function _M.connect(self, host, port_or_opts, opts)
    local sock = rawget(self, "_sock")
    if not sock then return nil, "not initialized" end

    local unix = false
    if type(host) == "string" and string_sub(host, 1, 5) == "unix:" then
        unix = true
    end

    local ok, err
    if unix then
        ok, err = sock:connect(host, port_or_opts)
    else
        ok, err = sock:connect(host, port_or_opts, opts)
    end

    if not ok then
        return ok, err
    end

    if opts and opts.ssl then
        ok, err = sock:sslhandshake(false, opts.server_name, opts.ssl_verify)
        if not ok then
            return ok, "ssl handshake failed: " .. err
        end
    end

    self._subscribed = false
    return ok, err
end

function _M.set_keepalive(self, ...)
    local sock = rawget(self, "_sock")
    if not sock then return nil, "not initialized" end
    if rawget(self, "_subscribed") then
        return nil, "subscribed state"
    end
    return sock:setkeepalive(_Pool.idle_timeout, _Pool.size)
end

function _M.get_reused_times(self)
    local sock = rawget(self, "_sock")
    if not sock then return nil, "not initialized" end
    return sock:getreusedtimes()
end

function _M.close(self)
    local sock = rawget(self, "_sock")
    if not sock then return nil, "not initialized" end
    self._subscribed = false
    return sock:close()
end

function _M.init_pipeline(self, n)
    self._reqs = new_tab(n or 4, 0)
end

function _M.cancel_pipeline(self)
    self._reqs = nil
end

function _M.commit_pipeline(self)
    local reqs = rawget(self, "_reqs")
    if not reqs then return nil, "no pipeline" end

    self._reqs = nil

    local sock = rawget(self, "_sock")
    if not sock then return nil, "not initialized" end

    local bytes, err = sock:send(reqs)
    for _, req in ipairs(reqs) do
        _put_tab_into_pool(req)
    end

    if not bytes then return nil, err end

    local nvals = 0
    local nreqs = #reqs
    local vals = new_tab(nreqs, 0)
    for i = 1, nreqs do
        local res, err = _read_reply(self, sock)
        if res then
            nvals = nvals + 1
            vals[nvals] = res
        elseif res == nil then
            if err == "timeout" then self:close() end
            return nil, err
        else
            nvals = nvals + 1
            vals[nvals] = {false, err}
        end
    end

    return vals
end

function _M.read_reply(self)
    local sock = rawget(self, "_sock")
    if not sock then return nil, "not initialized" end
    if not rawget(self, "_subscribed") then
        return nil, "not subscribed"
    end
    return _read_reply(self, sock)
end

function _M.auth(self, password)
    return _do_cmd(self, "AUTH", password)
end

function _M.ping(self)
    return _do_cmd(self, "PING")
end

function _M.echo(self, message)
    return _do_cmd(self, "ECHO", message)
end

function _M.select(self, index)
    return _do_cmd(self, "SELECT", index)
end

function _M.get(self, key)
    return _do_cmd(self, "GET", key)
end

function _M.set(self, key, value)
    return _do_cmd(self, "SET", key, value)
end

function _M.setex(self, key, seconds, value)
    return _do_cmd(self, "SETEX", key, seconds, value)
end

function _M.psetex(self, key, milliseconds, value)
    return _do_cmd(self, "PSETEX", key, milliseconds, value)
end

function _M.setnx(self, key, value)
    return _do_cmd(self, "SETNX", key, value)
end

function _M.mset(self, ...)
    return _do_cmd(self, "MSET", ...)
end

function _M.mget(self, ...)
    return _do_cmd(self, "MGET", ...)
end

function _M.del(self, ...)
    return _do_cmd(self, "DEL", ...)
end

function _M.exists(self, key)
    return _do_cmd(self, "EXISTS", key)
end

function _M.expire(self, key, seconds)
    return _do_cmd(self, "EXPIRE", key, seconds)
end

function _M.pexpire(self, key, milliseconds)
    return _do_cmd(self, "PEXPIRE", key, milliseconds)
end

function _M.ttl(self, key)
    return _do_cmd(self, "TTL", key)
end

function _M.pttl(self, key)
    return _do_cmd(self, "PTTL", key)
end

function _M.persist(self, key)
    return _do_cmd(self, "PERSIST", key)
end

function _M.incr(self, key)
    return _do_cmd(self, "INCR", key)
end

function _M.incrby(self, key, increment)
    return _do_cmd(self, "INCRBY", key, increment)
end

function _M.decr(self, key)
    return _do_cmd(self, "DECR", key)
end

function _M.decrby(self, key, decrement)
    return _do_cmd(self, "DECRBY", key, decrement)
end

function _M.hget(self, key, field)
    return _do_cmd(self, "HGET", key, field)
end

function _M.hset(self, key, field, value)
    return _do_cmd(self, "HSET", key, field, value)
end

function _M.hmset(self, key, ...)
    return _do_cmd(self, "HMSET", key, ...)
end

function _M.hmget(self, key, ...)
    return _do_cmd(self, "HMGET", key, ...)
end

function _M.hgetall(self, key)
    return _do_cmd(self, "HGETALL", key)
end

function _M.hdel(self, key, ...)
    return _do_cmd(self, "HDEL", key, ...)
end

function _M.hexists(self, key, field)
    return _do_cmd(self, "HEXISTS", key, field)
end

function _M.hincrby(self, key, field, increment)
    return _do_cmd(self, "HINCRBY", key, field, increment)
end

function _M.lpush(self, key, ...)
    return _do_cmd(self, "LPUSH", key, ...)
end

function _M.rpush(self, key, ...)
    return _do_cmd(self, "RPUSH", key, ...)
end

function _M.lpop(self, key)
    return _do_cmd(self, "LPOP", key)
end

function _M.rpop(self, key)
    return _do_cmd(self, "RPOP", key)
end

function _M.llen(self, key)
    return _do_cmd(self, "LLEN", key)
end

function _M.lrange(self, key, start, stop)
    return _do_cmd(self, "LRANGE", key, start, stop)
end

function _M.sadd(self, key, ...)
    return _do_cmd(self, "SADD", key, ...)
end

function _M.srem(self, key, ...)
    return _do_cmd(self, "SREM", key, ...)
end

function _M.smembers(self, key)
    return _do_cmd(self, "SMEMBERS", key)
end

function _M.sismember(self, key, member)
    return _do_cmd(self, "SISMEMBER", key, member)
end

function _M.zadd(self, key, score, member)
    return _do_cmd(self, "ZADD", key, score, member)
end

function _M.zrange(self, key, start, stop, withscores)
    if withscores then
        return _do_cmd(self, "ZRANGE", key, start, stop, "WITHSCORES")
    end
    return _do_cmd(self, "ZRANGE", key, start, stop)
end

function _M.zrem(self, key, member)
    return _do_cmd(self, "ZREM", key, member)
end

function _M.subscribe(self, ...)
    if not rawget(self, "_subscribed") then
        self._subscribed = true
    end
    return _do_cmd(self, "SUBSCRIBE", ...)
end

function _M.psubscribe(self, ...)
    if not rawget(self, "_subscribed") then
        self._subscribed = true
    end
    return _do_cmd(self, "PSUBSCRIBE", ...)
end

function _M.unsubscribe(self, ...)
    return _do_cmd(self, "UNSUBSCRIBE", ...)
end

function _M.punsubscribe(self, ...)
    return _do_cmd(self, "PUNSUBSCRIBE", ...)
end

function _M.eval(self, script, numkeys, ...)
    return _do_cmd(self, "EVAL", script, numkeys, ...)
end

function _M.evalsha(self, sha1, numkeys, ...)
    return _do_cmd(self, "EVALSHA", sha1, numkeys, ...)
end

function _M.script_load(self, script)
    return _do_cmd(self, "SCRIPT", "LOAD", script)
end

function _M.get_stats(self)
    return {
        pool_size = _Pool.size,
        pool_free = #_Pool.free,
        idle_timeout = _Pool.idle_timeout
    }
end

setmetatable(_M, {
    __index = function(self, cmd)
        local method = function(self, ...)
            return _do_cmd(self, cmd, ...)
        end
        _M[cmd] = method
        return method
    end
})

return _M
