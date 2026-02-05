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
    self.fields = fields or '*'
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

function QueryBuilder:select(fields)
    self.fields = fields or '*'
    return self
end

function QueryBuilder:where(key, operator, value)
    table.insert(self.wheres, {
        key = key,
        operator = operator,
        value = value
    })
    return self
end

function QueryBuilder:or_where(key, operator, value)
    table.insert(self.wheres, {
        key = key,
        operator = operator,
        value = value,
        is_or = true
    })
    return self
end

function QueryBuilder:where_in(key, values)
    if not validate_identifier(key) then
        ngx.log(ngx.WARN, 'Invalid identifier in where_in: ' .. tostring(key))
        return self
    end
    local condition = key .. ' IN ('
    local escaped_values = {}
    for i, v in ipairs(values) do
        table.insert(escaped_values, escape_sql(v))
    end
    condition = condition .. table.concat(escaped_values, ', ') .. ')'
    table.insert(self.wheres, { raw = condition })
    return self
end

function QueryBuilder:like(key, value)
    if type(value) ~= 'string' then
        value = tostring(value or '')
    end
    table.insert(self.wheres, {
        key = key,
        operator = 'LIKE',
        value = value
    })
    return self
end

function QueryBuilder:join(table_name, cond)
    -- Simple join (for demo purposes)
    return self
end

function QueryBuilder:left_join(table_name, cond)
    return self
end

function QueryBuilder:order_by(field, direction)
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
            local field_name = validate_identifier(o.field)
            if field_name then
                table.insert(orders, field_name .. ' ' .. o.direction)
            end
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
