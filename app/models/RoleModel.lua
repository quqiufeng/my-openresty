-- RoleModel Model
-- 角色模型

local Model = require('app.core.Model')
local QueryBuilder = require('app.db.query')

local _M = setmetatable({}, { __index = Model })
_M._TABLE = 'role'

function _M.new()
    local model = Model:new()
    model:set_table(_M._TABLE)
    return model
end

function _M:list(options)
    options = options or {}
    local page = tonumber(options.page) or 1
    local pageSize = tonumber(options.pageSize) or 10
    local offset = (page - 1) * pageSize

    local builder = QueryBuilder:new('role')
    builder.fields = 'id, name, description, status, FROM_UNIXTIME(create_time) as create_time, FROM_UNIXTIME(update_time) as update_time'

    local sorter = options.sorter or 'id'
    local sortOrder = options.order == 'ascend' and 'ASC' or 'DESC'
    builder:order_by(sorter, sortOrder)
    builder:limit(pageSize)
    builder:offset(offset)

    local sql = builder:to_sql()
    return self:query(sql)
end

function _M:count()
    return self:count(nil)
end

function _M:get_by_id(id)
    if not id then return nil end

    local builder = QueryBuilder:new('role')
    builder.fields = 'id, name, description, status, FROM_UNIXTIME(create_time) as create_time, FROM_UNIXTIME(update_time) as update_time'
    builder:where('id', '=', tonumber(id))
    builder:limit(1)

    local sql = builder:to_sql()
    local rows = self:query(sql)
    return rows and rows[1] or nil
end

function _M:create(data)
    local insert_data = {
        name = data.name,
        description = data.description,
        status = tonumber(data.status) or 1,
        create_time = ngx.time(),
        update_time = ngx.time()
    }
    return self:insert(insert_data)
end

function _M:update(id, data)
    if not id then return false end

    local update_data = {}
    if data.name then update_data.name = data.name end
    if data.description ~= nil then update_data.description = data.description end
    if data.status ~= nil then update_data.status = tonumber(data.status) end
    update_data.update_time = ngx.time()

    return self:update(update_data, { id = tonumber(id) })
end

function _M:delete(id)
    if not id then return false end
    return self:delete({ id = tonumber(id) })
end

return _M
