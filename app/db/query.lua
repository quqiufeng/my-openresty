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

-- 处理字段名，支持 table.field 和 table.field as alias 格式
local function parse_field(field)
    if not field or type(field) ~= 'string' then
        return field
    end

    -- 检查是否包含 AS 别名 (不区分大小写)
    local alias_start = field:upper():find('%s+AS%s+', 1, true)
    if alias_start then
        local field_part = field:sub(1, alias_start - 1):trim()
        local alias = field:sub(alias_start + 4):trim()
        return field_part, alias
    end

    return field, nil
end

-- 清理字符串首尾空白
local function trim(str)
    if not str then return nil end
    return str:gsub('^%s+', ''):gsub('%s+$', '')
end

function QueryBuilder:new(table_name)
    local self = setmetatable({}, QueryBuilder)
    self.table = table_name or ''
    self.fields = '*'
    self.wheres = {}
    self.joins = {}
    self.orders = {}
    self.limit_val = nil
    self.offset_val = nil
    return self
end

function QueryBuilder:select(fields)
    if type(fields) == 'table' then
        -- 支持 table 格式: {'id', 'name', 'users.email as user_email'}
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

function QueryBuilder:join(table_name, first_key, operator, second_key)
    if not table_name or not first_key or not second_key then
        return self
    end
    local cond = validate_identifier(first_key) .. ' ' .. (operator or '=') .. ' ' .. validate_identifier(second_key)
    table.insert(self.joins, { type = 'JOIN', table = table_name, on = cond })
    return self
end

function QueryBuilder:left_join(table_name, first_key, operator, second_key)
    if not table_name or not first_key or not second_key then
        return self
    end
    local cond = validate_identifier(first_key) .. ' ' .. (operator or '=') .. ' ' .. validate_identifier(second_key)
    table.insert(self.joins, { type = 'LEFT JOIN', table = table_name, on = cond })
    return self
end

function QueryBuilder:right_join(table_name, first_key, operator, second_key)
    if not table_name or not first_key or not second_key then
        return self
    end
    local cond = validate_identifier(first_key) .. ' ' .. (operator or '=') .. ' ' .. validate_identifier(second_key)
    table.insert(self.joins, { type = 'RIGHT JOIN', table = table_name, on = cond })
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

function QueryBuilder:to_sql()
    -- 验证表名
    local table_name = validate_identifier(self.table)
    if not table_name then
        ngx.log(ngx.ERR, 'Invalid table name: ' .. tostring(self.table))
        return 'SELECT * FROM invalid_table'
    end

    local sql = 'SELECT ' .. self.fields .. ' FROM ' .. table_name

    -- JOIN 子句
    if #self.joins > 0 then
        for _, join in ipairs(self.joins) do
            sql = sql .. ' ' .. join.type .. ' ' .. join.table .. ' ON ' .. join.on
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
                -- 验证字段名
                local field_name = validate_identifier(w.key)
                if not field_name then
                    ngx.log(ngx.WARN, 'Invalid field name in where: ' .. tostring(w.key))
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
    return self
end

function QueryBuilder:clone()
    local clone = QueryBuilder:new(self.table)
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
