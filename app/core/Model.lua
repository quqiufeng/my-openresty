-- Copyright (c) 2026 MyResty Framework
-- Model layer using resty.mysql

local tonumber = tonumber
local tostring = tostring
local type = type
local pairs = pairs
local ipairs = ipairs
local setmetatable = setmetatable

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

local function _escape_str(str)
    if not str then return '' end
    return string.gsub(str, "'", "''")
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

function _M.new(self)
    local Mysql = require('app.lib.mysql')
    local db, config = Mysql.new()
    
    -- 读取配置中的表前缀
    local ok, config_module = pcall(require, 'app.config.config')
    local table_prefix = ''
    if ok and config_module and config_module.table_prefix then
        table_prefix = config_module.table_prefix
    end
    
    return setmetatable({
        _db = db,
        _config = config,
        table_name = nil,
        _prefix = table_prefix
    }, mt)
end

function _M.set_table(self, name)
    self.table_name = name
    return self
end

function _M.table_prefix(self, prefix)
    self._prefix = prefix or ''
    return self
end

function _M.get_prefix(self)
    return self._prefix or ''
end

function _M.get_full_table_name(self)
    return (self._prefix or '') .. (self.table_name or '')
end

function _M.connect(self)
    local Mysql = require('app.lib.mysql')
    local ok, err = Mysql.connect(self._db)
    if not ok then
        return nil, err
    end
    return true
end

function _M.set_keepalive(self)
    local Mysql = require('app.lib.mysql')
    return Mysql.set_keepalive(self._db)
end

function _M.close(self)
    local Mysql = require('app.lib.mysql')
    return Mysql.close(self._db)
end

function _M.query(self, query, est_nrows)
    local Mysql = require('app.lib.mysql')
    local ok, err = Mysql.connect(self._db)
    if not ok then
        return nil, "connect failed: " .. err
    end
    local res, err, errno = Mysql.query(self._db, query)
    Mysql.set_keepalive(self._db)
    if err then
        return nil, err, errno
    end
    return res
end

function _M.get_all(self, where, limit, offset)
    local full_table = self:get_full_table_name()
    local sql_parts = new_tab(4, 0)
    sql_parts[1] = "SELECT * FROM "
    sql_parts[2] = full_table
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
    local full_table = self:get_full_table_name()
    local sql = "SELECT * FROM " .. full_table ..
                " WHERE id = " .. tonumber(id)
    local result = self:query(sql, 1)
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

    local full_table = self:get_full_table_name()
    local sql_parts = new_tab(4, 0)
    sql_parts[1] = "INSERT INTO "
    sql_parts[2] = full_table
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

    local full_table = self:get_full_table_name()
    local sql_parts = new_tab(4, 0)
    sql_parts[1] = "UPDATE "
    sql_parts[2] = full_table
    sql_parts[3] = " SET "
    sql_parts[4] = table.concat(set_parts, ",")
    sql_parts[5] = _build_where_clause(where)

    local sql = table.concat(sql_parts, '')
    self:query(sql)
    return true
end

function _M.delete(self, where)
    local full_table = self:get_full_table_name()
    local sql_parts = new_tab(3, 0)
    sql_parts[1] = "DELETE FROM "
    sql_parts[2] = full_table
    sql_parts[3] = _build_where_clause(where)

    local sql = table.concat(sql_parts, '')
    self:query(sql)
    return true
end

function _M.count(self, where)
    local full_table = self:get_full_table_name()
    local sql_parts = new_tab(3, 0)
    sql_parts[1] = "SELECT COUNT(*) as cnt FROM "
    sql_parts[2] = full_table
    sql_parts[3] = _build_where_clause(where)

    local sql = table.concat(sql_parts, '')
    local result = self:query(sql, 1)
    return result and result[1] and tonumber(result[1].cnt) or 0
end

function _M.query_one(self, query)
    local result = self:query(query, 1)
    return result and result[1] or nil
end

-- ========== JOIN 关联查询方法 ==========

function _M.join(self, table_name)
    if not self._query_builder then
        self._query_builder = require('app.db.query'):new(self.table_name)
    end
    self._query_builder:join(table_name)
    return self
end

function _M.left_join(self, table_name)
    if not self._query_builder then
        self._query_builder = require('app.db.query'):new(self.table_name, self._prefix)
    end
    self._query_builder:left_join(table_name)
    return self
end

function _M.right_join(self, table_name)
    if not self._query_builder then
        self._query_builder = require('app.db.query'):new(self.table_name, self._prefix)
    end
    self._query_builder:right_join(table_name)
    return self
end

function _M.on(self, left_field, right_field)
    if self._query_builder then
        self._query_builder:on(left_field, right_field)
    end
    return self
end

function _M.get_all_join(self, options)
    options = options or {}
    local prefix = self._prefix or ''
    local builder = self._query_builder or require('app.db.query'):new(self.table_name, prefix)

    -- 设置字段
    if options.fields and options.fields ~= '' then
        builder:select(options.fields)
    end

    -- WHERE 条件
    if options.where then
        for k, v in pairs(options.where) do
            builder:where(k, '=', v)
        end
    end

    -- 排序
    if options.order_by then
        builder:order_by(options.order_by, options.order or 'DESC')
    end

    -- 分页
    if options.limit then
        builder:limit(options.limit)
        if options.offset then
            builder:offset(options.offset)
        end
    end

    -- 重置 QueryBuilder
    self._query_builder = nil

    local sql = builder:to_sql()
    return self:query(sql)
end

return _M
