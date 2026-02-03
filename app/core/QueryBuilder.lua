-- Copyright (c) 2026 MyResty Framework
-- Query Builder with chainable API

local type = type
local ipairs = ipairs
local pairs = pairs
local tonumber = tonumber
local setmetatable = setmetatable
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

local function _escape(str)
    if not str then return '' end
    return string.gsub(str, "'", "''")
end

local function _quote(str)
    if type(str) == 'string' then
        return "'" .. _escape(str) .. "'"
    end
    return tostring(str)
end

local function _build_where(self)
    if #self.wheres == 0 then return '' end

    local parts = new_tab(#self.wheres + 1, 0)
    parts[1] = ' WHERE '
    for i, w in ipairs(self.wheres) do
        parts[i + 1] = w
    end
    return table.concat(parts, '')
end

local function _build_join(self)
    if #self.joins == 0 then return '' end
    return table.concat(self.joins, ' ')
end

local function _build_order(self)
    if #self.orders == 0 then return '' end
    return ' ORDER BY ' .. table.concat(self.orders, ', ')
end

local function _build_limit(self)
    if self.limit then
        local parts = new_tab(2, 0)
        parts[1] = ' LIMIT '
        parts[2] = tostring(self.limit)
        if self.offset then
            parts[3] = ' OFFSET '
            parts[4] = tostring(self.offset)
        end
        return table.concat(parts, '')
    end
    return ''
end

local function _build_group(self)
    if #self.groups == 0 then return '' end
    return ' GROUP BY ' .. table.concat(self.groups, ', ')
end

local function _build_having(self)
    if #self.havings == 0 then return '' end
    return ' HAVING ' .. table.concat(self.havings, ' AND ')
end

local function _build_select(self)
    if #self.selects == 0 then
        return '*'
    end
    return table.concat(self.selects, ', ')
end

function _M.new(table_name)
    local instance = {
        table = table_name or '',
        selects = {},
        wheres = {},
        or_wheres = {},
        joins = {},
        orders = {},
        limit = nil,
        offset = nil,
        groups = {},
        havings = {},
        distinct = false,
        bindings = {}
    }
    return setmetatable(instance, mt)
end

function _M.table(self, name)
    self.table = name
    return self
end

function _M.select(self, ...)
    local cols = {...}
    if #cols == 1 and type(cols[1]) == 'table' then
        cols = cols[1]
    end
    for _, col in ipairs(cols) do
        self.selects[#self.selects + 1] = col
    end
    return self
end

function _M.distinct(self)
    self.distinct = true
    return self
end

function _M.from(self, table)
    self.table = table
    return self
end

function _M.where(self, column, operator, value)
    if value == nil then
        value = operator
        operator = '='
    end

    local cond
    if type(value) == 'function' then
        local subqb = _M.new()
        value(subqb)
        local sub_where = subqb:_build_where()
        if #sub_where > 7 then
            cond = column .. ' IN (SELECT 1' .. sub_where .. ')'
        else
            cond = column .. ' = ' .. _quote(value)
        end
    elseif operator == 'IN' or operator == 'NOT IN' then
        if type(value) == 'table' then
            local vals = new_tab(#value, 0)
            for i, v in ipairs(value) do
                vals[i] = _quote(v)
            end
            cond = column .. ' ' .. operator .. ' (' .. table.concat(vals, ',') .. ')'
        else
            cond = column .. ' ' .. operator .. ' (' .. tostring(value) .. ')'
        end
    elseif operator == 'BETWEEN' or operator == 'NOT BETWEEN' then
        local v1, v2 = value[1], value[2]
        cond = column .. ' ' .. operator .. ' ' .. _quote(v1) .. ' AND ' .. _quote(v2)
    elseif operator == 'IS NULL' or operator == 'IS NOT NULL' then
        cond = column .. ' ' .. operator
    elseif operator == 'LIKE' or operator == 'NOT LIKE' or operator == 'ILIKE' then
        cond = column .. ' ' .. operator .. ' ' .. _quote(value)
    else
        cond = column .. ' ' .. operator .. ' ' .. _quote(value)
    end

    if #self.wheres == 0 then
        self.wheres[#self.wheres + 1] = cond
    else
        self.wheres[#self.wheres + 1] = ' AND ' .. cond
    end
    return self
end

function _M.or_where(self, column, operator, value)
    if value == nil then
        value = operator
        operator = '='
    end

    local cond
    if operator == 'IN' or operator == 'NOT IN' then
        if type(value) == 'table' then
            local vals = new_tab(#value, 0)
            for i, v in ipairs(value) do
                vals[i] = _quote(v)
            end
            cond = column .. ' ' .. operator .. ' (' .. table.concat(vals, ',') .. ')'
        else
            cond = column .. ' ' .. operator .. ' (' .. tostring(value) .. ')'
        end
    elseif operator == 'IS NULL' or operator == 'IS NOT NULL' then
        cond = column .. ' ' .. operator
    else
        cond = column .. ' ' .. operator .. ' ' .. _quote(value)
    end

    if #self.wheres == 0 then
        self.wheres[#self.wheres + 1] = cond
    else
        self.wheres[#self.wheres + 1] = ' OR ' .. cond
    end
    return self
end

function _M.where_null(self, column)
    self.wheres[#self.wheres + 1] = ( #self.wheres == 0 and '' or ' AND ' ) .. column .. ' IS NULL'
    return self
end

function _M.where_not_null(self, column)
    self.wheres[#self.wheres + 1] = ( #self.wheres == 0 and '' or ' AND ' ) .. column .. ' IS NOT NULL'
    return self
end

function _M.where_in(self, column, values)
    if type(values) == 'table' and #values > 0 then
        local vals = new_tab(#values, 0)
        for i, v in ipairs(values) do
            vals[i] = _quote(v)
        end
        local conjunction = #self.wheres == 0 and '' or ' AND '
        self.wheres[#self.wheres + 1] = conjunction .. column .. ' IN (' .. table.concat(vals, ',') .. ')'
    end
    return self
end

function _M.where_not_in(self, column, values)
    if type(values) == 'table' and #values > 0 then
        local vals = new_tab(#values, 0)
        for i, v in ipairs(values) do
            vals[i] = _quote(v)
        end
        local conjunction = #self.wheres == 0 and '' or ' AND '
        self.wheres[#self.wheres + 1] = conjunction .. column .. ' NOT IN (' .. table.concat(vals, ',') .. ')'
    end
    return self
end

function _M.like(self, column, value)
    self.wheres[#self.wheres + 1] = ( #self.wheres == 0 and '' or ' AND ' ) .. column .. ' LIKE ' .. _quote(value)
    return self
end

function _M.or_like(self, column, value)
    self.wheres[#self.wheres + 1] = ( #self.wheres == 0 and '' or ' OR ' ) .. column .. ' LIKE ' .. _quote(value)
    return self
end

function _M.where_raw(self, raw_sql)
    self.wheres[#self.wheres + 1] = ( #self.wheres == 0 and '' or ' AND ' ) .. raw_sql
    return self
end

function _M.join(self, table, type)
    self.joins[#self.joins + 1] = (type or 'INNER') .. ' JOIN ' .. table
    return self
end

function _M.left_join(self, table)
    self.joins[#self.joins + 1] = 'LEFT JOIN ' .. table
    return self
end

function _M.right_join(self, table)
    self.joins[#self.joins + 1] = 'RIGHT JOIN ' .. table
    return self
end

function _M.cross_join(self, table)
    self.joins[#self.joins + 1] = 'CROSS JOIN ' .. table
    return self
end

function _M.on(self, first, operator, second)
    if #self.joins > 0 then
        local join_part = self.joins[#self.joins]
        if operator == '=' then
            self.joins[#self.joins] = join_part .. ' ON ' .. first .. ' = ' .. second
        else
            self.joins[#self.joins] = join_part .. ' ON ' .. first .. ' ' .. operator .. ' ' .. second
        end
    end
    return self
end

function _M.or_on(self, first, operator, second)
    if #self.joins > 0 then
        local join_part = self.joins[#self.joins]
        if operator == '=' then
            self.joins[#self.joins] = join_part .. ' OR ' .. first .. ' = ' .. second
        else
            self.joins[#self.joins] = join_part .. ' OR ' .. first .. ' ' .. operator .. ' ' .. second
        end
    end
    return self
end

function _M.order_by(self, column, direction)
    direction = direction or 'ASC'
    if direction == true then direction = 'ASC' end
    if direction == false then direction = 'DESC' end
    if direction:upper() ~= 'DESC' then direction = 'ASC' end
    self.orders[#self.orders + 1] = column .. ' ' .. direction
    return self
end

function _M.order_by_raw(self, raw_sql)
    self.orders[#self.orders + 1] = raw_sql
    return self
end

function _M.limit(self, num)
    self.limit = tonumber(num)
    return self
end

function _M.offset(self, num)
    self.offset = tonumber(num)
    return self
end

function _M.page(self, page, per_page)
    per_page = tonumber(per_page) or 10
    page = tonumber(page) or 1

    if page < 1 then page = 1 end
    if per_page < 1 then per_page = 10 end

    self.limit = per_page
    self.offset = (page - 1) * per_page

    return self
end

function _M.simple_page(self, page, per_page)
    per_page = tonumber(per_page) or 10
    page = tonumber(page) or 1

    if page < 1 then page = 1 end
    if per_page < 1 then per_page = 10 end

    self.offset = (page - 1) * per_page

    return self
end

function _M.group_by(self, ...)
    local cols = {...}
    for _, col in ipairs(cols) do
        self.groups[#self.groups + 1] = col
    end
    return self
end

function _M.having(self, column, operator, value)
    if value == nil then
        value = operator
        operator = '='
    end
    self.havings[#self.havings + 1] = column .. ' ' .. operator .. ' ' .. _quote(value)
    return self
end

function _M.having_raw(self, raw_sql)
    self.havings[#self.havings + 1] = raw_sql
    return self
end

function _M.get_sql(self)
    local parts = new_tab(10, 0)
    local idx = 1

    parts[idx] = 'SELECT '; idx = idx + 1
    if self.distinct then
        parts[idx] = 'DISTINCT '; idx = idx + 1
    end
    parts[idx] = _build_select(self); idx = idx + 1

    parts[idx] = ' FROM '; idx = idx + 1
    parts[idx] = self.table; idx = idx + 1

    local join_str = _build_join(self)
    if join_str ~= '' then
        parts[idx] = ' '; idx = idx + 1
        parts[idx] = join_str; idx = idx + 1
    end

    local where_str = _build_where(self)
    if where_str ~= '' then
        parts[idx] = where_str; idx = idx + 1
    end

    local group_str = _build_group(self)
    if group_str ~= '' then
        parts[idx] = group_str; idx = idx + 1
    end

    local having_str = _build_having(self)
    if having_str ~= '' then
        parts[idx] = having_str; idx = idx + 1
    end

    local order_str = _build_order(self)
    if order_str ~= '' then
        parts[idx] = order_str; idx = idx + 1
    end

    local limit_str = _build_limit(self)
    if limit_str ~= '' then
        parts[idx] = limit_str
    end

    return table.concat(parts, '')
end

function _M.count(self, column)
    column = column or '*'
    local parts = new_tab(8, 0)
    parts[1] = 'SELECT COUNT('
    if self.distinct then
        parts[2] = 'DISTINCT '
    end
    parts[3] = column
    parts[4] = ') as cnt FROM '
    parts[5] = self.table
    local join_str = _build_join(self)
    if join_str ~= '' then
        parts[6] = ' '
        parts[7] = join_str
    end
    local where_str = _build_where(self)
    if where_str ~= '' then
        parts[#parts + 1] = where_str
    end
    return table.concat(parts, '')
end

function _M.paginate(self, page, per_page, total_count)
    page = tonumber(page) or 1
    per_page = tonumber(per_page) or 10

    if page < 1 then page = 1 end
    if per_page < 1 then per_page = 10 end

    self:page(page, per_page)

    local total_pages = math.ceil((total_count or 0) / per_page)
    if total_pages < 1 then total_pages = 1 end

    return {
        current_page = page,
        per_page = per_page,
        total_count = total_count or 0,
        total_pages = total_pages,
        from_record = (page - 1) * per_page + 1,
        to_record = math.min(page * per_page, total_count or 0),
        has_prev = page > 1,
        has_next = page < total_pages,
        prev_page = page > 1 and page - 1 or nil,
        next_page = page < total_pages and page + 1 or nil,
        sql = self:get_sql()
    }
end

function _M.get_pagination_info(self, page, per_page, total_count)
    return self:paginate(page, per_page, total_count)
end

function _M.sum(self, column)
    local parts = new_tab(6, 0)
    parts[1] = 'SELECT SUM('
    parts[2] = column
    parts[3] = ') as sum FROM '
    parts[4] = self.table
    local where_str = _build_where(self)
    if where_str ~= '' then
        parts[5] = where_str
    end
    return table.concat(parts, '')
end

function _M.avg(self, column)
    local parts = new_tab(6, 0)
    parts[1] = 'SELECT AVG('
    parts[2] = column
    parts[3] = ') as avg FROM '
    parts[4] = self.table
    local where_str = _build_where(self)
    if where_str ~= '' then
        parts[5] = where_str
    end
    return table.concat(parts, '')
end

function _M.max(self, column)
    local parts = new_tab(6, 0)
    parts[1] = 'SELECT MAX('
    parts[2] = column
    parts[3] = ') as max FROM '
    parts[4] = self.table
    local where_str = _build_where(self)
    if where_str ~= '' then
        parts[5] = where_str
    end
    return table.concat(parts, '')
end

function _M.min(self, column)
    local parts = new_tab(6, 0)
    parts[1] = 'SELECT MIN('
    parts[2] = column
    parts[3] = ') as min FROM '
    parts[4] = self.table
    local where_str = _build_where(self)
    if where_str ~= '' then
        parts[5] = where_str
    end
    return table.concat(parts, '')
end

function _M.insert(self, data)
    if type(data) ~= 'table' then return nil end

    local fields = new_tab(#data, 0)
    local values = new_tab(#data, 0)
    local idx = 0

    for k, v in pairs(data) do
        idx = idx + 1
        fields[idx] = k
        values[idx] = _quote(v)
    end

    local parts = new_tab(6, 0)
    parts[1] = 'INSERT INTO '
    parts[2] = self.table
    parts[3] = ' ('
    parts[4] = table.concat(fields, ',')
    parts[5] = ') VALUES ('
    parts[6] = table.concat(values, ',')
    parts[7] = ')'

    return table.concat(parts, '')
end

function _M.insert_batch(self, data)
    if type(data) ~= 'table' or #data == 0 then return nil end

    local fields = {}
    for k, _ in pairs(data[1]) do
        fields[#fields + 1] = k
    end

    local value_parts = new_tab(#data, 0)
    for i, row in ipairs(data) do
        local vals = new_tab(#fields, 0)
        for j, k in ipairs(fields) do
            vals[j] = _quote(row[k])
        end
        value_parts[i] = '(' .. table.concat(vals, ',') .. ')'
    end

    local parts = new_tab(6, 0)
    parts[1] = 'INSERT INTO '
    parts[2] = self.table
    parts[3] = ' ('
    parts[4] = table.concat(fields, ',')
    parts[5] = ') VALUES '
    parts[6] = table.concat(value_parts, ',')

    return table.concat(parts, '')
end

function _M.update(self, data)
    if type(data) ~= 'table' then return nil end

    local sets = new_tab(#data, 0)
    local idx = 0
    for k, v in pairs(data) do
        idx = idx + 1
        sets[idx] = k .. ' = ' .. _quote(v)
    end

    local parts = new_tab(4, 0)
    parts[1] = 'UPDATE '
    parts[2] = self.table
    parts[3] = ' SET '
    parts[4] = table.concat(sets, ',')
    local where_str = _build_where(self)
    if where_str ~= '' then
        parts[5] = where_str
    end

    return table.concat(parts, '')
end

function _M.delete(self)
    local parts = new_tab(4, 0)
    parts[1] = 'DELETE FROM '
    parts[2] = self.table
    local where_str = _build_where(self)
    if where_str ~= '' then
        parts[3] = where_str
    end
    return table.concat(parts, '')
end

function _M.reset(self)
    tb_clear(self.selects)
    tb_clear(self.wheres)
    tb_clear(self.joins)
    tb_clear(self.orders)
    tb_clear(self.groups)
    tb_clear(self.havings)
    self.limit = nil
    self.offset = nil
    self.distinct = false
    return self
end

function _M.clone(self)
    local copy = _M.new(self.table)
    for i, v in ipairs(self.selects) do copy.selects[i] = v end
    for i, v in ipairs(self.wheres) do copy.wheres[i] = v end
    for i, v in ipairs(self.joins) do copy.joins[i] = v end
    for i, v in ipairs(self.orders) do copy.orders[i] = v end
    for i, v in ipairs(self.groups) do copy.groups[i] = v end
    for i, v in ipairs(self.havings) do copy.havings[i] = v end
    copy.limit = self.limit
    copy.offset = self.offset
    copy.distinct = self.distinct
    return copy
end

return _M
