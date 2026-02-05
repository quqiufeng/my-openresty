-- RoleModel Model
-- 角色模型

local Model = require('app.core.Model')
local QueryBuilder = require('app.db.query')
local Mysql = require('app.lib.mysql')

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
    local db = Mysql:new()
    local ok, err = db:connect()
    if not ok then
        return nil, err
    end
    local rows, query_err, errno = db:query(sql)
    db:set_keepalive()

    if query_err then
        return nil, query_err, errno
    end

    return rows
end

function _M:count()
    local builder = QueryBuilder:new('role')
    builder.fields = 'COUNT(*) as total'
    local sql = builder:to_sql()

    local db = Mysql:new()
    local ok, err = db:connect()
    if not ok then
        return 0, err
    end
    local rows, query_err, errno = db:query(sql)
    db:set_keepalive()

    if query_err then
        return 0, query_err, errno
    end

    return rows and rows[1] and tonumber(rows[1].total) or 0
end

function _M:get_by_id(id)
    if not id then return nil end

    local builder = QueryBuilder:new('role')
    builder.fields = 'id, name, description, status, FROM_UNIXTIME(create_time) as create_time, FROM_UNIXTIME(update_time) as update_time'
    builder:where('id', '=', tonumber(id))
    builder:limit(1)

    local sql = builder:to_sql()
    local db = Mysql:new()
    local ok, err = db:connect()
    if not ok then
        return nil, err
    end
    local rows, query_err, errno = db:query(sql)
    db:set_keepalive()

    if query_err then
        return nil, query_err, errno
    end

    return rows and rows[1] or nil
end

function _M:create(data)
    local builder = QueryBuilder:new('role')
    local insert_data = {
        name = data.name,
        description = data.description,
        status = tonumber(data.status) or 1,
        create_time = ngx.time(),
        update_time = ngx.time()
    }

    local sql = builder:insert(insert_data)
    local db = Mysql:new()
    local ok, err = db:connect()
    if not ok then
        return nil, err
    end
    local res, query_err, errno = db:query(sql)
    db:set_keepalive()

    if query_err then
        return nil, query_err, errno
    end

    return res and res.insert_id
end

function _M:update(id, data)
    if not id then return false end

    local builder = QueryBuilder:new('role')
    local update_data = {}
    if data.name then update_data.name = data.name end
    if data.description ~= nil then update_data.description = data.description end
    if data.status ~= nil then update_data.status = tonumber(data.status) end
    update_data.update_time = ngx.time()

    builder:where('id', '=', tonumber(id))
    local sql = builder:update(update_data)

    local db = Mysql:new()
    local ok, err = db:connect()
    if not ok then
        return false, err
    end
    local _, query_err, errno = db:query(sql)
    db:set_keepalive()

    if query_err then
        return false, query_err, errno
    end

    return true
end

function _M:delete(id)
    if not id then return false end

    local builder = QueryBuilder:new('role')
    builder:where('id', '=', tonumber(id))
    local sql = builder:delete()

    local db = Mysql:new()
    local ok, err = db:connect()
    if not ok then
        return false, err
    end
    local _, query_err, errno = db:query(sql)
    db:set_keepalive()

    if query_err then
        return false, query_err, errno
    end

    return true
end

return _M
