-- Copyright (c) 2026 MyResty Framework
-- MySQL connection pool library with official resty pattern

local bit = require "bit"
local tcp = ngx.socket.tcp
local tonumber = tonumber
local type = type
local pairs = pairs
local ipairs = ipairs
local setmetatable = setmetatable
local pcall = pcall
local error = error
local ngx_log = ngx.log
local ngx_ERR = ngx.ERR
local ngx_INFO = ngx.INFO

local ok, new_tab = pcall(require, "table.new")
if not ok then
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

local STATE_CONNECTED = 1
local STATE_COMMAND_SENT = 2

local COM_QUIT = 0x01
local COM_QUERY = 0x03

local RESP_OK = "OK"
local RESP_ERR = "ERR"
local RESP_EOF = "EOF"
local RESP_DATA = "DATA"

local CHARSET_MAP = {
    _default = 0,
    utf8 = 3,
    utf8mb4 = 45,
    latin1 = 8,
    gbk = 28,
    big5 = 1
}

local converters = new_tab(0, 9)
for i = 0x01, 0x05 do
    converters[i] = tonumber
end
converters[0x00] = tonumber
converters[0x09] = tonumber
converters[0x0d] = tonumber

local function _get_byte2(data, i)
    local a, b = string.byte(data, i, i + 1)
    return bit.bor(a, bit.lshift(b, 8)), i + 2
end

local function _get_byte3(data, i)
    local a, b, c = string.byte(data, i, i + 2)
    return bit.bor(a, bit.lshift(b, 8), bit.lshift(c, 16)), i + 3
end

local function _set_byte2(n)
    return string.char(bit.band(n, 0xff), bit.rshift(n, 8))
end

local function _set_byte3(n)
    return string.char(bit.band(n, 0xff), bit.rshift(n, 8), bit.rshift(n, 16))
end

local function _to_cstring(data)
    return data .. "\0"
end

local function _escape_str(str)
    if not str then return '' end
    return string.gsub(str, "'", "''")
end

local function _from_length_coded_bin(data, pos)
    local first = string.byte(data, pos)
    if not first then return nil, pos end

    if first >= 0 and first <= 250 then
        return first, pos + 1
    end
    if first == 251 then
        return nil, pos + 1
    end
    if first == 252 then
        return _get_byte2(data, pos + 1)
    end
    if first == 253 then
        return _get_byte3(data, pos + 1)
    end
    return nil, pos + 1
end

local function _from_length_coded_str(data, pos)
    local len
    len, pos = _from_length_coded_bin(data, pos)
    if not len then return nil, pos end
    return string.sub(data, pos, pos + len - 1), pos + len
end

local function _parse_ok_packet(packet)
    local res = new_tab(0, 5)
    local pos = 2
    res.affected_rows, pos = _from_length_coded_bin(packet, pos)
    res.insert_id, pos = _from_length_coded_bin(packet, pos)
    res.server_status = tonumber(string.byte(packet, pos)) + bit.lshift(tonumber(string.byte(packet, pos + 1)), 8)
    res.warning_count = tonumber(string.byte(packet, pos + 2)) + bit.lshift(tonumber(string.byte(packet, pos + 3)), 8)
    local message = _from_length_coded_str(packet, pos + 4)
    if message then res.message = message end
    return res
end

local function _parse_err_packet(packet)
    local errno = tonumber(string.byte(packet, 2)) + bit.lshift(tonumber(string.byte(packet, 3)), 8)
    local pos = 5
    if string.byte(packet, pos) == 35 then pos = pos + 6 end
    local message = string.sub(packet, pos)
    return errno, message
end

local function _parse_result_set_header_packet(packet)
    return tonumber(string.byte(packet, 1))
end

local function _parse_row_packet(data, cols, compact)
    local pos = 1
    local ncols = #cols
    local row = new_tab(ncols, 0)

    for i = 1, ncols do
        local value, pos = _from_length_coded_str(data, pos)

        if compact and converters[cols[i].type] and value then
            row[i] = converters[cols[i].type](value)
        else
            row[i] = value
        end
    end

    return row
end

local function _parse_field_packet(data)
    local col = new_tab(0, 2)
    local pos = 1

    local db, pos = _from_length_coded_str(data, pos)
    local table, pos = _from_length_coded_str(data, pos)
    col.name, pos = _from_length_coded_str(data, pos)
    col.type = tonumber(string.byte(data, pos))

    return col
end

local function _read_packet(self)
    local sock = self.sock
    local data, err = sock:receive(4)
    if not data then return nil, nil, err end

    local len = tonumber(string.byte(data, 1)) + bit.lshift(tonumber(string.byte(data, 2)), 8) + bit.lshift(tonumber(string.byte(data, 3)), 16)
    if len == 0 then return nil, nil, "empty packet" end

    local num = tonumber(string.byte(data, 4))
    self.packet_no = num

    data, err = sock:receive(len)
    if not data then return nil, nil, err end

    local field_count = tonumber(string.byte(data, 1))
    local typ
    if field_count == 0x00 then typ = RESP_OK
    elseif field_count == 0xff then typ = RESP_ERR
    elseif field_count == 0xfe then typ = RESP_EOF
    else typ = RESP_DATA end

    return data, typ
end

local function _send_packet(self, packet)
    self.packet_no = self.packet_no + 1
    local header = _set_byte3(#packet) .. string.char(bit.band(self.packet_no, 255))
    return self.sock:send(header .. packet)
end

local function _send_query(self, query)
    if self.state ~= STATE_CONNECTED then
        return nil, "not connected"
    end
    self.packet_no = -1
    local packet = string.char(COM_QUERY) .. query
    return _send_packet(self, packet)
end

local _Pool = {}
_Pool.free = {}
_Pool.size = 100
_Pool.idle_timeout = 10000
_Pool.config = {}

function _M.init(config)
    _Pool.config = config or {}
    _Pool.size = config.pool_size or 100
    _Pool.idle_timeout = config.idle_timeout or 10000
    ngx_log(ngx_INFO, 'MySQL pool initialized with size: ', _Pool.size)
end

function _M.new(self)
    local sock, err = tcp()
    if not sock then
        return nil, err
    end
    return setmetatable({
        sock = sock,
        state = nil,
        packet_no = nil,
        compact = false
    }, mt)
end

function _M.set_timeout(self, timeout)
    local sock = self.sock
    if not sock then return nil, "not initialized" end
    return sock:settimeout(timeout)
end

function _M.connect(self, opts)
    opts = opts or _Pool.config
    if not opts or not opts.host then
        local Config = require('app.core.Config')
        Config.load()
        opts = Config.get('mysql') or _Pool.config
    end
    local sock = self.sock
    if not sock then return nil, "not initialized" end

    self.database = opts.database or ""
    self.user = opts.user or "root"
    self.password = opts.password or ""
    self.charset = opts.charset or "utf8mb4"

    local host = opts.host or "127.0.0.1"
    local port = opts.port or 3306

    local pool = opts.pool
    if not pool then
        local pool_parts = new_tab(4, 0)
        pool_parts[1] = self.user
        pool_parts[2] = ":"
        pool_parts[3] = self.database
        pool_parts[4] = ":"
        pool = table.concat(pool_parts, '')
        pool_parts[5] = host
        pool_parts[6] = ":"
        pool_parts[7] = tostring(port)
        pool = table.concat(pool_parts, '')
    end

    local ok, err = sock:connect(host, port, {
        pool = pool,
        pool_size = opts.pool_size or _Pool.size,
        backlog = opts.backlog or 100
    })

    if not ok then
        local err_parts = new_tab(2, 0)
        err_parts[1] = "failed to connect: "
        err_parts[2] = err
        return nil, table.concat(err_parts, '')
    end

    local reused = sock:getreusedtimes()
    if reused and reused > 0 then
        self.state = STATE_CONNECTED
        return 1
    end

    self.state = STATE_CONNECTED
    return 1
end

function _M.set_keepalive(self, ...)
    local sock = self.sock
    if not sock then return nil, "not initialized" end
    if self.state ~= STATE_CONNECTED then
        return nil, "cannot be reused"
    end
    self.state = nil
    return sock:setkeepalive(_Pool.idle_timeout, _Pool.size)
end

function _M.get_reused_times(self)
    local sock = self.sock
    if not sock then return nil, "not initialized" end
    return sock:getreusedtimes()
end

function _M.close(self)
    local sock = self.sock
    if not sock then return nil, "not initialized" end
    self.state = nil
    return sock:close()
end

function _M.query(self, query, est_nrows)
    local bytes, err = _send_query(self, query)
    if not bytes then
        return nil, "failed to send query: " .. err
    end

    self.state = STATE_COMMAND_SENT

    local packet, typ = _read_packet(self)
    if not packet then
        self.state = STATE_CONNECTED
        return nil, typ
    end

    if typ == RESP_ERR then
        local errno, msg = _parse_err_packet(packet)
        self.state = STATE_CONNECTED
        return nil, msg, errno
    end

    if typ == RESP_OK then
        local res = _parse_ok_packet(packet)
        self.state = STATE_CONNECTED
        return res
    end

    local field_count = _parse_result_set_header_packet(packet)

    local cols = new_tab(field_count, 0)
    for i = 1, field_count do
        local col_packet, col_typ = _read_packet(self)
        if col_typ == RESP_ERR then
            local errno, msg = _parse_err_packet(col_packet)
            self.state = STATE_CONNECTED
            return nil, msg, errno
        end
        cols[i] = _parse_field_packet(col_packet)
    end

    _read_packet(self)

    local rows = new_tab(est_nrows or 4, 0)
    local i = 0
    while true do
        local row_packet, row_typ = _read_packet(self)
        if row_typ == RESP_EOF then break end
        i = i + 1
        rows[i] = _parse_row_packet(row_packet, cols, self.compact)
    end

    self.state = STATE_CONNECTED
    return rows
end

function _M.set_compact_arrays(self, value)
    self.compact = value
end

function _M.insert(self, query)
    local res = self:query(query)
    if res then
        return res.insert_id
    end
    return nil
end

function _M.escape(self, str)
    return _escape_str(str)
end

function _M.get_connection(self)
    return self
end

function _M.get_stats(self)
    return {
        pool_size = _Pool.size,
        pool_free = #_Pool.free,
        idle_timeout = _Pool.idle_timeout
    }
end

return _M
