-- Copyright (c) 2026 MyResty Framework
-- Model layer with connection pool and performance optimization

local bit = require "bit"
local tcp = ngx.socket.tcp
local tonumber = tonumber
local tostring = tostring
local type = type
local pairs = pairs
local ipairs = ipairs
local setmetatable = setmetatable
local error = error
local ngx_log = ngx.log
local ngx_ERR = ngx.ERR

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

local function _get_byte2(data, i)
    local a, b = string.byte(data, i, i + 1)
    return bit.bor(a, bit.lshift(b, 8)), i + 2
end

local function _escape_str(str)
    if not str then return '' end
    return string.gsub(str, "'", "''")
end

local function _to_cstring(data)
    return data .. "\0"
end

local function _build_where_clause(where)
    if not where then return '' end
    if type(where) == 'table' then
        local parts = new_tab(#where, 0)
        local count = 0
        for k, v in pairs(where) do
            count = count + 1
            local val_str
            if type(v) == 'string' then
                val_str = "'" .. _escape_str(v) .. "'"
            else
                val_str = tostring(v)
            end
            parts[count] = k .. " = " .. val_str
        end
        local where_parts = new_tab(2, 0)
        where_parts[1] = ' WHERE '
        where_parts[2] = table.concat(parts, ' AND ')
        return table.concat(where_parts, '')
    end
    return ' WHERE ' .. where
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
        pos = pos + 1
        return _get_byte2(data, pos)
    end
    if first == 253 then
        pos = pos + 1
        return tonumber(string.sub(data, pos, pos + 2):byte(1)) +
               bit.lshift(string.sub(data, pos, pos + 2):byte(2), 8) +
               bit.lshift(string.sub(data, pos, pos + 2):byte(3), 16), pos + 3
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
    pos = pos + 2
    res.warning_count = tonumber(string.byte(packet, pos)) + bit.lshift(tonumber(string.byte(packet, pos + 1)), 8)
    local message = _from_length_coded_str(packet, pos + 2)
    if message then res.message = message end
    return res
end

local function _parse_err_packet(packet)
    local errno = tonumber(string.byte(packet, 2)) + bit.lshift(tonumber(string.byte(packet, 3)), 8)
    local pos = 5
    if string.byte(packet, pos) == 35 then
        pos = pos + 6
    end
    local message = string.sub(packet, pos)
    return errno, message
end

local function _parse_result_set_header_packet(packet)
    local field_count = tonumber(string.byte(packet, 1))
    return field_count
end

local function _parse_row_packet(data, cols, compact)
    local pos = 1
    local ncols = #cols
    local row
    if compact then
        row = new_tab(ncols, 0)
    else
        row = new_tab(0, ncols)
    end
    for i = 1, ncols do
        local value, pos = _from_length_coded_str(data, pos)
        if compact then
            row[i] = value
        else
            row[cols[i].name] = value
        end
    end
    return row
end

local converters = new_tab(0, 9)
for i = 0x01, 0x05 do
    converters[i] = tonumber
end
converters[0x00] = tonumber
converters[0x09] = tonumber
converters[0x0d] = tonumber

local function _read_packet(self)
    local sock = self.sock
    local data, err = sock:receive(4)
    if not data then
        return nil, nil, "failed to receive packet: " .. err
    end
    local len = tonumber(string.byte(data, 1)) +
                bit.lshift(tonumber(string.byte(data, 2)), 8) +
                bit.lshift(tonumber(string.byte(data, 3)), 16)
    if len == 0 then
        return nil, nil, "empty packet"
    end
    local num = tonumber(string.byte(data, 4))
    self.packet_no = num
    data, err = sock:receive(len)
    if not data then
        return nil, nil, "failed to read packet: " .. err
    end
    local field_count = tonumber(string.byte(data, 1))
    local typ
    if field_count == 0x00 then typ = "OK"
    elseif field_count == 0xff then typ = "ERR"
    elseif field_count == 0xfe then typ = "EOF"
    else typ = "DATA" end
    return data, typ
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
    local sock = self.sock
    if not sock then return nil, "not initialized" end

    self.database = opts.database or ""
    self.user = opts.user or ""
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
        pool_size = opts.pool_size or 100,
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
        return nil, "cannot be reused in current state"
    end
    self.state = nil
    return sock:setkeepalive(...)
end

function _M.close(self)
    local sock = self.sock
    if not sock then return nil, "not initialized" end
    self.state = nil
    return sock:close()
end

local function _send_query(self, query)
    if self.state ~= STATE_CONNECTED then
        return nil, "cannot send query in current state"
    end
    local sock = self.sock
    if not sock then return nil, "not initialized" end

    self.packet_no = -1
    local packet = string.char(0x03) .. query
    local bytes, err = sock:send(packet)
    if not bytes then return nil, err end

    self.state = 2
    return bytes
end

function _M.query(self, query, est_nrows)
    local bytes, err = _send_query(self, query)
    if not bytes then
        return nil, "failed to send query: " .. err
    end

    local packet, typ, err = _read_packet(self)
    if not packet then
        return nil, err
    end

    if typ == "ERR" then
        local errno, msg = _parse_err_packet(packet)
        self.state = STATE_CONNECTED
        return nil, msg, errno
    end

    if typ == "OK" then
        local res = _parse_ok_packet(packet)
        self.state = STATE_CONNECTED
        return res
    end

    local field_count = _parse_result_set_header_packet(packet)

    local cols = new_tab(field_count, 0)
    for i = 1, field_count do
        local col_packet, col_typ = _read_packet(self)
        if col_typ == "ERR" then
            local errno, msg = _parse_err_packet(col_packet)
            return nil, msg, errno
        end
        local col = new_tab(0, 2)
        local pos = 1
        local db, pos = _from_length_coded_str(col_packet, pos)
        local table, pos = _from_length_coded_str(col_packet, pos)
        col.name, pos = _from_length_coded_str(col_packet, pos)
        col.type = tonumber(string.byte(col_packet, pos))
        cols[i] = col
    end

    local eof_packet, eof_typ = _read_packet(self)

    local rows = new_tab(est_nrows or 4, 0)
    local i = 0
    while true do
        local row_packet, row_typ = _read_packet(self)
        if row_typ == "EOF" then
            break
        end
        i = i + 1
        rows[i] = _parse_row_packet(row_packet, cols, self.compact)
    end

    self.state = STATE_CONNECTED
    return rows
end

function _M.set_compact_arrays(self, value)
    self.compact = value
end

function _M.set_table(self, name)
    self.table_name = name
    return self
end

function _M.get_all(self, where, limit, offset)
    local sql_parts = new_tab(4, 0)
    sql_parts[1] = "SELECT * FROM "
    sql_parts[2] = self.table_name or ""
    sql_parts[3] = _build_where_clause(where)

    if limit then
        sql_parts[#sql_parts + 1] = " LIMIT " .. tonumber(limit)
        if offset then
            sql_parts[#sql_parts + 1] = " OFFSET " .. tonumber(offset)
        end
    end

    return self:query(table.concat(sql_parts, ''))
end

function _M.get_by_id(self, id)
    local sql_parts = new_tab(3, 0)
    sql_parts[1] = "SELECT * FROM "
    sql_parts[2] = self.table_name or ""
    sql_parts[3] = " WHERE id = " .. tonumber(id)

    local result = self:query(table.concat(sql_parts, ''), 1)
    return result and result[1] or nil
end

function _M.get_by_id(self, id)
    local sql = "SELECT * FROM " .. (self.table_name or "") ..
                " WHERE id = " .. tonumber(id)
    local result = self:query(sql)
    return result and result[1] or nil
end

function _M.insert(self, data)
    if not data or type(data) ~= 'table' then return false end

    local fields = new_tab(#data, 0)
    local values = new_tab(#data, 0)
    local count = 0

    for k, v in pairs(data) do
        count = count + 1
        fields[count] = k
        if type(v) == "string" then
            values[count] = "'" .. _escape_str(v) .. "'"
        else
            values[count] = tostring(v)
        end
    end

    local sql_parts = new_tab(4, 0)
    sql_parts[1] = "INSERT INTO "
    sql_parts[2] = self.table_name or ""
    sql_parts[3] = " ("
    sql_parts[4] = table.concat(fields, ",")
    sql_parts[5] = ") VALUES ("
    sql_parts[6] = table.concat(values, ",")
    sql_parts[7] = ")"

    local sql = table.concat(sql_parts, '')
    local res = self:query(sql)
    return res and res.insert_id or false
end

function _M.update(self, data, where)
    if not data or type(data) ~= 'table' then return false end

    local set_parts = new_tab(#data, 0)
    local count = 0

    for k, v in pairs(data) do
        count = count + 1
        if type(v) == "string" then
            set_parts[count] = k .. " = '" .. _escape_str(v) .. "'"
        else
            set_parts[count] = k .. " = " .. tostring(v)
        end
    end

    local sql_parts = new_tab(4, 0)
    sql_parts[1] = "UPDATE "
    sql_parts[2] = self.table_name or ""
    sql_parts[3] = " SET "
    sql_parts[4] = table.concat(set_parts, ",")
    sql_parts[5] = _build_where_clause(where)

    local sql = table.concat(sql_parts, '')
    self:query(sql)
    return true
end

function _M.delete(self, where)
    local sql_parts = new_tab(3, 0)
    sql_parts[1] = "DELETE FROM "
    sql_parts[2] = self.table_name or ""
    sql_parts[3] = _build_where_clause(where)

    local sql = table.concat(sql_parts, '')
    self:query(sql)
    return true
end

function _M.count(self, where)
    local sql_parts = new_tab(3, 0)
    sql_parts[1] = "SELECT COUNT(*) as cnt FROM "
    sql_parts[2] = self.table_name or ""
    sql_parts[3] = _build_where_clause(where)

    local sql = table.concat(sql_parts, '')
    local result = self:query(sql, 1)
    return result and result[1] and tonumber(result[1].cnt) or 0
end

function _M.query_one(self, query)
    local result = self:query(query, 1)
    return result and result[1] or nil
end

return _M
