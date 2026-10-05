--[[
Minimal `ngx` mock for running MyResty unit tests under plain LuaJIT.

This is NOT a full OpenResty emulation. It provides just enough of the
`ngx.*` API surface for modules to load and be exercised without a running
nginx. Individual specs may still override `ngx` if they need more control.
]]

if ngx and ngx.config and ngx.config.ngx_lua_version then
    return ngx
end

local function new_dict()
    return {
        get = function() return nil end,
        get_stale = function() return nil end,
        set = function() return true end,
        safe_set = function() return true end,
        add = function() return true end,
        safe_add = function() return true end,
        replace = function() return true end,
        delete = function() return nil end,
        incr = function() return 1 end,
        ttl = function() return 0 end,
        expire = function() return true end,
        flush_all = function() return true end,
        flush_expired = function() return 0 end,
        get_keys = function() return {} end,
        capacity = function() return 0 end,
        free_space = function() return 0 end,
    }
end

local function new_socket()
    return {
        settimeout = function() end,
        settimeouts = function() end,
        connect = function() return 1 end,
        send = function() return 1 end,
        receive = function() return nil, 'timeout' end,
        receiveuntil = function() return nil, 'timeout' end,
        close = function() return 1 end,
        setkeepalive = function() return 1 end,
        set_keepalive = function() return 1 end,
        getreusedtimes = function() return 0 end,
        sslhandshake = function() return true end,
    }
end

local dicts = setmetatable({}, {
    __index = function(t, k)
        local d = new_dict()
        t[k] = d
        return d
    end,
})

_G.ngx = {
    config = { subsystem = 'http', ngx_lua_version = 10025 },
    null = setmetatable({}, { __tostring = function() return 'null' end }),

    -- logging
    log = function() end,
    EMERG = 0, ALERT = 1, CRIT = 2, ERR = 4, WARN = 5,
    NOTICE = 6, INFO = 7, DEBUG = 8,

    -- time
    now = function() return 1700000000 end,
    time = function() return 1700000000 end,
    today = function() return '20260101' end,
    update_time = function() end,

    -- worker
    worker = {
        pid = function() return 1 end,
        id = function() return 0 end,
        count = function() return 1 end,
        exiting = function() return false end,
    },

    socket = { tcp = function() return new_socket() end },

    shared = dicts,

    ctx = {},

    var = setmetatable({}, {
        __index = function(_, k)
            if k == 'request_method' then return 'GET' end
            if k == 'uri' then return '/' end
            if k == 'remote_addr' then return '127.0.0.1' end
            if k == 'server_protocol' then return 'HTTP/1.1' end
            if k == 'server_port' then return '8080' end
            return nil
        end,
    }),

    header = {},

    req = {
        get_method = function() return 'GET' end,
        get_uri_args = function() return {} end,
        get_post_args = function() return {} end,
        get_headers = function() return {} end,
        get_body_files = function() return {} end,
        read_body = function() end,
        get_body_data = function() return nil end,
        set_header = function() end,
    },

    say = function() end,
    print = function() end,
    exit = function() end,
    flush = function() end,
    sleep = function() end,
    redirect = function() end,
    send_headers = function() end,

    re = {
        find = function() return nil end,
        match = function() return nil end,
        gmatch = function() return function() return nil end end,
        sub = function(s) return s end,
    },

    timer = {
        every = function() return true end,
        at = function() return true end,
        running_count = function() return 0 end,
    },

    -- helpers used by some modules
    sha1_bin = function(s) return (s or ''):sub(1, 20) end,
    md5 = function(s) return (s or '') end,
    encode_base64 = function(s) return s end,
    decode_base64 = function(s) return s end,
    encode_json = function() return '{}' end,
    decode_json = function() return {} end,
    escape_uri = function(s) return s end,
    unescape_uri = function(s) return s end,
    quote_sql_str = function(s) return "'" .. tostring(s):gsub("'", "''") .. "'" end,

    get_phase = function() return 'content' end,
}

return ngx
