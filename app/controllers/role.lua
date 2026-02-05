--[[
    角色控制器
    提供 /api/role 接口
--]]

local Controller = require('app.core.Controller')
local _M = {}

function _M:__construct()
    Controller.__construct(self)
end

function _M:list()
    local mysql = require('app.lib.mysql')
    local db = mysql.new()
    mysql.connect(db)

    if not db then
        self:json({ success = false, message = '连接失败', data = nil, total = 0 }, 500)
        return
    end

    local page = tonumber(self.request.get and self.request.get['page']) or 1
    local pageSize = tonumber(self.request.get and self.request.get['pageSize']) or 10
    local offset = (page - 1) * pageSize

    local sorter = self.request.get and self.request.get['sorter'] or 'id'
    local order = self.request.get and self.request.get['order'] or ''
    local sort_order = order == 'ascend' and 'ASC' or 'DESC'

    local sql = "SELECT id, name, description, status, FROM_UNIXTIME(create_time) as create_time, FROM_UNIXTIME(update_time) as update_time FROM role ORDER BY " .. sorter .. " " .. sort_order .. " LIMIT " .. pageSize .. " OFFSET " .. offset
    local data, err = mysql.query(db, sql)

    local count_sql = "SELECT COUNT(*) as total FROM role"
    local count_res = mysql.query(db, count_sql)
    local total = count_res and count_res[1] and tonumber(count_res[1].total) or 0

    mysql.set_keepalive(db)

    if err then
        self:json({ success = false, message = '查询失败: ' .. tostring(err), data = nil, total = 0 }, 500)
        return
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

    local mysql = require('app.lib.mysql')
    local db = mysql.new()
    mysql.connect(db)

    if not db then
        self:json({ success = false, message = '连接失败', data = nil }, 500)
        return
    end

    local sql = "SELECT id, name, description, status, FROM_UNIXTIME(create_time) as create_time, FROM_UNIXTIME(update_time) as update_time FROM role WHERE id = " .. tonumber(id)
    local res, err = mysql.query(db, sql)
    mysql.set_keepalive(db)

    if res and res[1] then
        self:json({ success = true, message = 'success', data = res[1] })
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

    local mysql = require('app.lib.mysql')
    local db = mysql.new()
    mysql.connect(db)

    if not db then
        self:json({ success = false, message = '连接失败', data = nil }, 500)
        return
    end

    local name = "'" .. string.gsub(tostring(data.name), "'", "''") .. "'"
    local description = data.description and "'" .. string.gsub(tostring(data.description), "'", "''") .. "'" or "''"
    local status = tonumber(data.status) or 1

    local sql = "INSERT INTO role (name, description, status, create_time, update_time) VALUES (" .. name .. ", " .. description .. ", " .. status .. ", UNIX_TIMESTAMP(), UNIX_TIMESTAMP())"
    mysql.query(db, sql)
    mysql.set_keepalive(db)

    self:json({ success = true, message = '创建成功', data = nil })
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

    local mysql = require('app.lib.mysql')
    local db = mysql.new()
    mysql.connect(db)

    if not db then
        self:json({ success = false, message = '连接失败', data = nil }, 500)
        return
    end

    local updates = {}
    if data.name then table.insert(updates, "name = '" .. string.gsub(tostring(data.name), "'", "''") .. "'") end
    if data.description ~= nil then table.insert(updates, "description = '" .. string.gsub(tostring(data.description or ''), "'", "''") .. "'") end
    if data.status ~= nil then table.insert(updates, "status = " .. tonumber(data.status)) end

    if #updates > 0 then
        table.insert(updates, "update_time = UNIX_TIMESTAMP()")
        local sql = "UPDATE role SET " .. table.concat(updates, ", ") .. " WHERE id = " .. tonumber(id)
        mysql.query(db, sql)
    end

    mysql.set_keepalive(db)
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

    local mysql = require('app.lib.mysql')
    local db = mysql.new()
    mysql.connect(db)

    if not db then
        self:json({ success = false, message = '连接失败', data = nil }, 500)
        return
    end

    local sql = "DELETE FROM role WHERE id = " .. tonumber(id)
    mysql.query(db, sql)
    mysql.set_keepalive(db)

    self:json({ success = true, message = '删除成功', data = nil })
end

return _M
