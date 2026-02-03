-- User Controller
local Controller = require('app.core.Controller')
local _M = {}

function _M:__construct()
    Controller.__construct(self)
    self:load('user_model')
end

function _M:index()
    local page = tonumber(self.get['page']) or 1
    local limit = tonumber(self.get['limit']) or 10
    local offset = (page - 1) * limit
    local data = self.user_model:list(limit, offset)
    local total = self.user_model:count_all()
    self:json({ success = true, data = data, total = total, page = page, limit = limit })
end

function _M:show(id)
    local data = self.user_model:get_by_id(id)
    if data then
        self:json({ success = true, data = data })
    else
        self:json({ success = false, error = 'Not found' }, 404)
    end
end

function _M:create()
    local data = { name = self.post['name'], status = 'active', created_at = ngx.time(), updated_at = ngx.time() }
    local id = self.user_model:create(data)
    self:json({ success = true, data = { id = id } }, 201)
end

function _M:update(id)
    local data = { name = self.post['name'], updated_at = ngx.time() }
    self.user_model:update(id, data)
    self:json({ success = true })
end

function _M:delete(id)
    self.user_model:delete(id)
    self:json({ success = true })
end

return _M
