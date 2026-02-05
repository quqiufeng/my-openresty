--[[
    角色控制器
    提供 /api/role 接口
--]]

local Controller = require('app.core.Controller')
local RoleModel = require('app.models.RoleModel')

local _M = {}

function _M:__construct()
    Controller.__construct(self)
end

function _M:list()
    local role_model = RoleModel:new()

    local page = tonumber(self.request.get and self.request.get['page']) or 1
    local pageSize = tonumber(self.request.get and self.request.get['pageSize']) or 10

    local sorter = self.request.get and self.request.get['sorter'] or 'id'
    local order = self.request.get and self.request.get['order'] or ''

    local data, err = role_model:list({
        page = page,
        pageSize = pageSize,
        sorter = sorter,
        order = order
    })

    if err then
        self:json({ success = false, message = '查询失败: ' .. tostring(err), data = nil, total = 0 }, 500)
        return
    end

    local total, count_err = role_model:count()
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

    local role_model = RoleModel:new()
    local res, err = role_model:get_by_id(id)

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
    if not data.name or data.name == '' then
        self:json({ success = false, message = '角色名称必填', data = nil }, 400)
        return
    end

    local role_model = RoleModel:new()
    local id, err = role_model:create(data)

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

    local role_model = RoleModel:new()
    local success, err = role_model:update(tonumber(id), data)

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

    local role_model = RoleModel:new()
    local success, err = role_model:delete(tonumber(id))

    if not success then
        self:json({ success = false, message = '删除失败: ' .. tostring(err), data = nil }, 500)
        return
    end

    self:json({ success = true, message = '删除成功', data = nil })
end

return _M
