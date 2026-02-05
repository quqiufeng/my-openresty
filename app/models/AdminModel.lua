-- AdminModel Model
-- 管理员模型

local Model = require('app.core.Model')
local QueryBuilder = require('app.db.query')

local _M = setmetatable({}, { __index = Model })
_M._TABLE = 'admin'

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

    local builder = QueryBuilder:new('admin')
    builder.fields = 'id, username, phone, role_id, FROM_UNIXTIME(create_time) as create_time, FROM_UNIXTIME(update_time) as update_time'

    if options.username and options.username ~= '' then
        builder:where('username', 'LIKE', '%' .. options.username .. '%')
    end
    if options.phone and options.phone ~= '' then
        builder:where('phone', 'LIKE', '%' .. options.phone .. '%')
    end
    if options.role_id and options.role_id ~= '' then
        builder:where('role_id', '=', tonumber(options.role_id))
    end

    local sorter = options.sorter or 'id'
    local sortOrder = options.order == 'ascend' and 'ASC' or 'DESC'
    builder:order_by(sorter, sortOrder)
    builder:limit(pageSize)
    builder:offset(offset)

    local sql = builder:to_sql()
    return self:query(sql)
end

function _M:count(options)
    options = options or {}

    local where = {}
    if options.username and options.username ~= '' then
        where.username = '%' .. options.username .. '%'
    end
    if options.phone and options.phone ~= '' then
        where.phone = '%' .. options.phone .. '%'
    end
    if options.role_id and options.role_id ~= '' then
        where.role_id = tonumber(options.role_id)
    end

    return self:count(where)
end

function _M:get_by_id(id)
    if not id then return nil end
    return Model.get_by_id(self, id)
end

function _M:get_by_username(username)
    if not username then return nil end

    local builder = QueryBuilder:new('admin')
    builder.fields = 'id, username, password, phone, role_id, salt'
    builder:where('username', '=', username)
    builder:limit(1)

    local sql = builder:to_sql()
    local rows = self:query(sql)
    return rows and rows[1] or nil
end

function _M:create(data)
    local insert_data = {
        username = data.username,
        password = data.password,
        phone = data.phone,
        role_id = tonumber(data.role_id) or 0,
        create_time = ngx.time(),
        update_time = ngx.time()
    }
    return self:insert(insert_data)
end

function _M:update(id, data)
    if not id then return false end

    local update_data = {}
    if data.username then update_data.username = data.username end
    if data.password and data.password ~= '' then update_data.password = data.password end
    if data.phone then update_data.phone = data.phone end
    if data.role_id then update_data.role_id = tonumber(data.role_id) end
    update_data.update_time = ngx.time()

    return self:update(update_data, { id = tonumber(id) })
end

function _M:delete(id)
    if not id then return false end
    return self:delete({ id = tonumber(id) })
end

return _M
