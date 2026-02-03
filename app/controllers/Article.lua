-- Article Controller
local Controller = require('app.core.Controller')
local _M = {}

function _M:__construct()
    Controller.__construct(self)
    self:load('_articles')
end

function _M:index()
    local page = tonumber(self.get['page']) or 1
    local limit = tonumber(self.get['limit']) or 10
    local data = self._articles:get_all(nil, limit, (page - 1) * limit)
    local total = self._articles:count()
    self:json({ success = true, data = data, total = total, page = page, limit = limit })
end

function _M:show(id)
    local data = self._articles:get_by_id(id)
    if data then self:json({ success = true, data = data })
    else self:json({ success = false, error = 'Not found' }, 404) end
end

function _M:create()
    local id = self._articles:insert({ name = self.post['name'] })
    self:json({ success = true, data = { id = id } }, 201)
end

function _M:update(id)
    self._articles:update(id, { name = self.post['name'] })
    self:json({ success = true })
end

function _M:delete(id)
    self._articles:delete(id)
    self:json({ success = true })
end

return _M
