-- UserModel Model
local Model = require('app.core.Model')
local _M = setmetatable({}, { __index = Model })
_M._TABLE = 'users'

function _M:list(limit, offset)
    return self:where({ status = 'active' }):limit(limit, offset):get()
end

function _M:get_by_id(id)
    return self:where({ id = id }):first()
end

function _M:create(data)
    return self:insert(data)
end

function _M:update(id, data)
    return self:db:update(self._TABLE, data, { id = id })
end

function _M:delete(id)
    return self:db:delete(self._TABLE, { id = id })
end

function _M:count_all()
    return self:count()
end

return _M
