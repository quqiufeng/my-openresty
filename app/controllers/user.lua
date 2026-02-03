local Controller = require('app.core.Controller')

local _M = {}

function _M:__construct()
    Controller.__construct(self)
    self:load('user_model')
end

function _M:get_list()
    local Request = require('app.core.Request')
    local limit = tonumber(Request.get['limit']) or 10
    local offset = tonumber(Request.get['offset']) or 0

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
    local user = self.user_model:get_by_id(id)
    if user then
        self:json({success = true, data = user})
    else
        self:json({success = false, error = 'User not found'}, 404)
    end
end

function _M:create()
    local Request = require('app.core.Request')
    local data = Request.post

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
    local Request = require('app.core.Request')
    local data = Request.post

    local success = self.user_model:update(data, 'id = ' .. tonumber(id))
    if success then
        self:json({success = true})
    else
        self:json({success = false, error = 'Failed to update user'}, 500)
    end
end

function _M:delete(id)
    local success = self.user_model:delete('id = ' .. tonumber(id))
    if success then
        self:json({success = true})
    else
        self:json({success = false, error = 'Failed to delete user'}, 500)
    end
end

return _M
