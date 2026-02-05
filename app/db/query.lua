-- QueryBuilder for MyResty
-- Simple SQL query builder with SQL injection protection

local QueryBuilder = {}
QueryBuilder.__index = QueryBuilder

-- SQL 转义函数
local function escape_sql(value)
    if value == nil then
        return 'NULL'
    end
    local t = type(value)
    if t == 'number' then
        return tostring(value)
    elseif t == 'boolean' then
        return value and '1' or '0'
    elseif t == 'string' then
        return "'" .. tostring(value):gsub("'", "''") .. "'"
    else
        return "'" .. tostring(value):gsub("'", "''") .. "'"
    end
end

-- 验证表名和字段名（防止 SQL 注入）
local function validate_identifier(identifier)
    if not identifier or type(identifier) ~= 'string' then
        return nil
    end
    if not identifier:match('^[a-zA-Z_][a-zA-Z0-9_]*$') then
        return nil
    end
    return identifier
end

-- 验证字段名（允许 table.field 格式）
local function validate_field_name(field_name)
    if not field_name or type(field_name) ~= 'string' then
        return nil
    end
    -- 允许简单字段名或 table.field 格式
    if not field_name:match('^[a-zA-Z_.][a-zA-Z0-9_.]*$') then
        return nil
    end
    return field_name
end

-- 清理字符串首尾空白
local function trim(str)
    if not str then return nil end
    return str:gsub('^%s+', ''):gsub('%s+$', '')
end

-- 处理字段名，支持 table.field 和 table.field as alias 格式
local function parse_field(field)
    if not field or type(field) ~= 'string' then
        return field, nil
    end

    -- 检查是否包含 AS 别名 (不区分大小写)
    local upper_field = field:upper()
    local alias_start = upper_field:find('%s+AS%s+', 1, false)
    if alias_start then
        local field_part = trim(field:sub(1, alias_start - 1))
        local alias = trim(field:sub(alias_start + 3))
        return field_part, alias
    end

    return field, nil
end

-- 检查字段是否已有表名前缀
local function has_table_prefix(field)
    if not field or type(field) ~= 'string' then
        return false
    end
    return field:find('%.'), nil
end

function QueryBuilder:new(table_name, prefix)
    local self = setmetatable({}, QueryBuilder)
    self.table = table_name or ''
    self._prefix = prefix or ''
    self.fields = '*'
    self.wheres = {}
    self.joins = {}
    self.orders = {}
    self.limit_val = nil
    self.offset_val = nil
    self._last_join_table = nil
    return self
end

function QueryBuilder:prefix(p)
    self._prefix = p or ''
    return self
end

function QueryBuilder:table_prefix(tp)
    self._prefix = tp or ''
    return self
end

function QueryBuilder:from_config(config)
    local prefix = config.table_prefix or ''
    return self:new(self.table, prefix)
end

function QueryBuilder:prefix(p)
    self._prefix = p or ''
    return self
end

function QueryBuilder:get_prefix()
    return self._prefix or ''
end

function QueryBuilder:select(fields)
    if type(fields) == 'table' then
        -- 支持 table 格式: {'id', 'name', 'orders.total as order_amount'}
        -- 字段直接存储，JOIN 时在 to_sql() 中自动添加表前缀
        local parts = {}
        for _, field in ipairs(fields) do
            local field_part, alias = parse_field(field)
            if alias then
                table.insert(parts, field_part .. ' AS ' .. alias)
            else
                table.insert(parts, field_part)
            end
        end
        self.fields = table.concat(parts, ', ')
    else
        self.fields = fields or '*'
    end
    return self
end

-- 自动为 JOIN 查询添加表名前缀
function QueryBuilder:auto_prefix_fields()
    if #self.joins == 0 then
        return
    end

    if type(self.fields) == 'string' and self.fields ~= '*' then
        -- 处理字符串格式: 'id, name, email' 或 'id, users.name as user_name, orders.total'
        local parts = {}
        for field in string.gmatch(self.fields, '[^,]+') do
            field = field:gsub('^%s+', ''):gsub('%s+$', '')
            local field_part, alias = parse_field(field)
            -- 如果不包含 . 且不是 *，添加主表名前缀
            if not has_table_prefix(field_part) and field_part ~= '*' then
                field_part = self.table .. '.' .. field_part
            end
            if alias then
                table.insert(parts, field_part .. ' AS ' .. alias)
            else
                table.insert(parts, field_part)
            end
        end
        self.fields = table.concat(parts, ', ')
    elseif type(self.fields) == 'table' then
        -- 处理 table 格式
        local parts = {}
        for _, field in ipairs(self.fields) do
            local field_part, alias = parse_field(field)
            -- 如果不包含 . 且不是 *，添加主表名前缀
            if not has_table_prefix(field_part) and field_part ~= '*' then
                field_part = self.table .. '.' .. field_part
            end
            if alias then
                table.insert(parts, field_part .. ' AS ' .. alias)
            else
                table.insert(parts, field_part)
            end
        end
        self.fields = table.concat(parts, ', ')
    end
end

function QueryBuilder:join(table_name)
    if not table_name then
        return self
    end
    self._last_join_table = table_name
    table.insert(self.joins, { type = 'JOIN', table = table_name, on = nil })
    return self
end

function QueryBuilder:left_join(table_name)
    if not table_name then
        return self
    end
    self._last_join_table = table_name
    table.insert(self.joins, { type = 'LEFT JOIN', table = table_name, on = nil })
    return self
end

function QueryBuilder:right_join(table_name)
    if not table_name then
        return self
    end
    self._last_join_table = table_name
    table.insert(self.joins, { type = 'RIGHT JOIN', table = table_name, on = nil })
    return self
end

function QueryBuilder:on(left_field, right_field)
    if not left_field or not right_field then
        return self
    end
    if #self.joins == 0 then
        return self
    end
    local last_join = self.joins[#self.joins]
    last_join.on = {
        left = left_field,
        right = right_field,
        main_table = self.table,
        join_table = last_join.table
    }
    self._last_join_table = nil
    return self
end

function QueryBuilder:order_by(field, direction)
    -- 支持 table.field 格式
    table.insert(self.orders, {
        field = field,
        direction = direction or 'ASC'
    })
    return self
end

function QueryBuilder:limit(n)
    self.limit_val = tonumber(n)
    return self
end

function QueryBuilder:offset(n)
    self.offset_val = tonumber(n)
    return self
end

function QueryBuilder:where(key, operator, value)
    table.insert(self.wheres, {
        key = key,
        operator = operator or '=',
        value = value
    })
    return self
end

function QueryBuilder:to_sql()
    local prefix = self._prefix or ''

    -- 验证主表名
    local table_name = validate_identifier(self.table)
    if not table_name then
        return 'SELECT * FROM invalid_table'
    end

    -- 如果有 JOIN，自动为字段添加表名前缀
    if #self.joins > 0 then
        self:auto_prefix_fields()
    end

    local full_table_name = prefix .. table_name
    local sql = 'SELECT ' .. self.fields .. ' FROM ' .. full_table_name

    -- JOIN 子句
    if #self.joins > 0 then
        for _, join in ipairs(self.joins) do
            local join_table = prefix .. join.table
            local on_cond = join.on
            if on_cond then
                if type(on_cond) == 'table' then
                    -- 新格式: { left, right, main_table, join_table }
                    local left_field = on_cond.left
                    local right_field = on_cond.right
                    -- 添加表名前缀
                    local left_table = on_cond.main_table
                    local right_table = on_cond.join_table
                    left_field = left_field:find('.', 1, true) and left_field or prefix .. left_table .. '.' .. left_field
                    right_field = right_field:find('.', 1, true) and right_field or prefix .. right_table .. '.' .. right_field
                    on_cond = left_field .. ' = ' .. right_field
                else
                    -- 旧格式: 字符串
                    local equals_idx = on_cond:find(' = ', 1, true)
                    if equals_idx then
                        local left_part = trim(on_cond:sub(1, equals_idx - 1))
                        local right_part = trim(on_cond:sub(equals_idx + 3))
                        left_part = left_part:gsub('([^.]+)%.', prefix .. '%1.')
                        right_part = right_part:gsub('([^.]+)%.', prefix .. '%1.')
                        on_cond = left_part .. ' = ' .. right_part
                    end
                end
            end
            sql = sql .. ' ' .. join.type .. ' ' .. join_table .. ' ON ' .. (on_cond or '')
        end
    end

    -- WHERE 子句
    if #self.wheres > 0 then
        sql = sql .. ' WHERE '
        local conditions = {}
        for i, w in ipairs(self.wheres) do
            if w.raw then
                table.insert(conditions, w.raw)
            else
                -- 验证字段名（允许 table.field 格式）
                local field_name = validate_field_name(w.key)
                if not field_name then
                    field_name = 'invalid_field'
                end

                -- 使用转义函数处理值
                local escaped_value = escape_sql(w.value)

                local prefix = ''
                if i > 1 and w.is_or then
                    prefix = 'OR '
                elseif i > 1 then
                    prefix = 'AND '
                end
                table.insert(conditions, prefix .. field_name .. ' ' .. w.operator .. ' ' .. escaped_value)
            end
        end
        sql = sql .. table.concat(conditions, ' ')
    end

    -- ORDER BY 子句
    if #self.orders > 0 then
        local orders = {}
        for _, o in ipairs(self.orders) do
            table.insert(orders, o.field .. ' ' .. o.direction)
        end
        if #orders > 0 then
            sql = sql .. ' ORDER BY ' .. table.concat(orders, ', ')
        end
    end

    -- LIMIT 子句
    if self.limit_val then
        local limit = tonumber(self.limit_val)
        if limit and limit > 0 then
            sql = sql .. ' LIMIT ' .. limit
        end
    end

    -- OFFSET 子句
    if self.offset_val then
        local offset = tonumber(self.offset_val)
        if offset and offset >= 0 then
            sql = sql .. ' OFFSET ' .. offset
        end
    end

    return sql
end

function QueryBuilder:reset()
    self.fields = '*'
    self.wheres = {}
    self.joins = {}
    self.orders = {}
    self.limit_val = nil
    self.offset_val = nil
    self._last_join_table = nil
    return self
end

function QueryBuilder:table_prefix(tp)
    self._prefix = tp or ''
    return self
end

function QueryBuilder:clone()
    local clone = QueryBuilder:new(self.table, self._prefix)
    clone.fields = self.fields
    clone.wheres = {}
    clone.joins = {}
    for _, w in ipairs(self.wheres) do
        table.insert(clone.wheres, w)
    end
    for _, j in ipairs(self.joins) do
        table.insert(clone.joins, j)
    end
    for _, o in ipairs(self.orders) do
        table.insert(clone.orders, o)
    end
    clone.limit_val = self.limit_val
    clone.offset_val = self.offset_val
    return clone
end

return QueryBuilder
