--[[
    管理员控制器
    提供 /api/admin 接口
--]]

local Controller = require('app.core.Controller')
local AdminModel = require('app.models.AdminModel')

local _M = {}

function _M:__construct()
    Controller.__construct(self)
end

function _M:list()
    local admin_model = AdminModel:new()

    local page = tonumber(self.request.get and self.request.get['page']) or 1
    local pageSize = tonumber(self.request.get and self.request.get['pageSize']) or 10

    local sorter = self.request.get and self.request.get['sorter'] or 'id'
    local order = self.request.get and self.request.get['order'] or ''

    local username = self.request.get and self.request.get['username']
    local phone = self.request.get and self.request.get['phone']
    local role_id = self.request.get and self.request.get['role_id']

    local data, err = admin_model:list({
        page = page,
        pageSize = pageSize,
        sorter = sorter,
        order = order,
        username = username,
        phone = phone,
        role_id = role_id
    })

    if err then
        self:json({ success = false, message = '查询失败: ' .. tostring(err), data = nil, total = 0 }, 500)
        return
    end

    local total, count_err = admin_model:count({
        username = username,
        phone = phone,
        role_id = role_id
    })
    if count_err then
        total = 0
    end

    self:json({ success = true, message = 'success', data = data or {}, total = total })
end

function _M:get_one(id)
    if not id or id == '' then
        id = self.request.get and self.request.get['id']
    end
    if not id or id == '' then
        self:json({ success = false, message = '缺少ID', data = nil }, 400)
        return
    end

    local admin_model = AdminModel:new()
    local res, err = admin_model:get_by_id(tonumber(id))

    if err then
        self:json({ success = false, message = '查询失败: ' .. tostring(err), data = nil }, 500)
        return
    end

    if res then
        self:json({ success = true, message = 'success', data = res })
    else
        self:json({ success = false, message = '不存在', data = nil }, 404)
    end
end

function _M:create()
    local data = self.request.json or {}
    if not data or not next(data) then
        self:json({ success = false, message = '数据为空', data = nil }, 400)
        return
    end
    if not data.username or not data.password then
        self:json({ success = false, message = '用户名密码必填', data = nil }, 400)
        return
    end

    local admin_model = AdminModel:new()
    local id, err = admin_model:create(data)

    if err then
        self:json({ success = false, message = '创建失败: ' .. tostring(err), data = nil }, 500)
        return
    end

    self:json({ success = true, message = '创建成功', data = { id = id } })
end

function _M:update(id)
    if not id or id == '' then
        id = self.request.get and self.request.get['id']
    end
    local data = self.request.json or {}
    if not id or id == '' then
        self:json({ success = false, message = '缺少ID', data = nil }, 400)
        return
    end

    local admin_model = AdminModel:new()
    local success, err = admin_model:update(tonumber(id), data)

    if not success then
        self:json({ success = false, message = '更新失败: ' .. tostring(err), data = nil }, 500)
        return
    end

    self:json({ success = true, message = '更新成功', data = nil })
end

function _M:delete(id)
    if not id or id == '' then
        id = self.request.get and self.request.get['id']
    end
    if not id or id == '' then
        self:json({ success = false, message = '缺少ID', data = nil }, 400)
        return
    end

    local admin_model = AdminModel:new()
    local success, err = admin_model:delete(tonumber(id))

    if not success then
        self:json({ success = false, message = '删除失败: ' .. tostring(err), data = nil }, 500)
        return
    end

    self:json({ success = true, message = '删除成功', data = nil })
end

return _M
