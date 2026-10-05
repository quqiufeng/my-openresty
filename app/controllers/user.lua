local Controller = require('app.core.Controller')

local _M = {}

function _M:__construct()
    Controller.__construct(self)
    self:load('UserModel', 'user_model')
end

function _M:get_list()
    local get = self.request.get or {}
    local limit = tonumber(get['limit']) or 10
    local offset = tonumber(get['offset']) or 0

    local users = self.user_model:get_all(nil, limit, offset)
    self:json({
        success = true,
        data = users,
        pagination = {
            limit = limit,
            offset = offset
        }
    })
end

function _M:get_one(id)
    if id == nil or id == '' then
        id = self.request.get and self.request.get['id']
    end
    local user = self.user_model:get_by_id(tonumber(id))
    if user then
        self:json({success = true, data = user})
    else
        self:json({success = false, error = 'User not found'}, 404)
    end
end

function _M:create()
    local data = self.request.json or {}
    if not next(data) then
        data = self.request.post or {}
    end

    if not data.username or not data.email then
        self:json({success = false, error = 'Missing required fields'}, 400)
        return
    end

    local id = self.user_model:insert(data)
    if id then
        self:json({success = true, id = id}, 201)
    else
        self:json({success = false, error = 'Failed to create user'}, 500)
    end
end

function _M:update(id)
    if id == nil or id == '' then
        id = self.request.get and self.request.get['id']
    end
    if id == nil or id == '' or tonumber(id) == nil then
        self:json({success = false, error = 'ID required'}, 400)
        return
    end

    local data = self.request.json or {}
    if not next(data) then
        data = self.request.post or {}
    end

    local success = self.user_model:update(data, { id = tonumber(id) })
    if success then
        self:json({success = true})
    else
        self:json({success = false, error = 'Failed to update user'}, 500)
    end
end

function _M:delete(id)
    if id == nil or id == '' then
        id = self.request.get and self.request.get['id']
    end
    if id == nil or id == '' or tonumber(id) == nil then
        self:json({success = false, error = 'ID required'}, 400)
        return
    end

    local success = self.user_model:delete({ id = tonumber(id) })
    if success then
        self:json({success = true})
    else
        self:json({success = false, error = 'Failed to delete user'}, 500)
    end
end

return _M
