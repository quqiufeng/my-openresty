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
    builder:select('admin.id, admin.username, admin.phone, admin.role_id, admin.status, ' ..
                   'role.name as role_name, role.description as role_description, ' ..
                   'FROM_UNIXTIME(admin.create_time) as create_time, ' ..
                   'FROM_UNIXTIME(admin.update_time) as update_time')

    -- LEFT JOIN role 表获取角色信息
    builder:left_join('role'):on('role_id', 'id')

    if options.username and options.username ~= '' then
        builder:where('admin.username', 'LIKE', '%' .. options.username .. '%')
    end
    if options.phone and options.phone ~= '' then
        builder:where('admin.phone', 'LIKE', '%' .. options.phone .. '%')
    end
    if options.role_id and options.role_id ~= '' then
        builder:where('admin.role_id', '=', tonumber(options.role_id))
    end
    if options.status and options.status ~= '' then
        builder:where('admin.status', '=', tonumber(options.status))
    end

    local sorter = options.sorter or 'admin.id'
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

    local builder = QueryBuilder:new('admin')
    builder:select('admin.id, admin.username, admin.phone, admin.role_id, admin.status, ' ..
                   'role.name as role_name, role.description as role_description, ' ..
                   'FROM_UNIXTIME(admin.create_time) as create_time, ' ..
                   'FROM_UNIXTIME(admin.update_time) as update_time')
    builder:left_join('role'):on('role_id', 'id')
    builder:where('admin.id', '=', tonumber(id))
    builder:limit(1)

    local sql = builder:to_sql()
    local rows = self:query(sql)
    return rows and rows[1] or nil
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
