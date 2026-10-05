-- RoleModel Model
local M = require("app.core.Model")
local QB = require("app.db.query")

local _M = setmetatable({}, { __index = M })
_M._TABLE = "role"

function _M.new()
    local o = M:new()
    o:set_table(_M._TABLE)
    return setmetatable(o, { __index = _M })
end

local SEARCH_FIELDS = { "name" }

-- /role/list - 列表查询
function _M:list(o)
    o = o or {}
    local page = tonumber(o.page) or 1
    local pageSize = tonumber(o.pageSize) or 10
    local b = QB:new("role")
    b:select("role.id, role.name")
    if o.keyword and o.keyword ~= "" then
        for i, f in ipairs(SEARCH_FIELDS) do
            if i == 1 then
                b:where("role." .. f, "LIKE", "%" .. o.keyword .. "%")
            else
                b:or_where("role." .. f, "LIKE", "%" .. o.keyword .. "%")
            end
        end
    end
    b:order_by("role.id", "DESC")
    b:limit(pageSize)
    b:offset((page - 1) * pageSize)
    return self:query(b:to_sql())
end

-- /role/detail - 详情查询
function _M:detail(o)
    local id = o and o.id
    if not id then return nil end
    local b = QB:new("role")
    b:select("role.id, role.name")
    b:where("role.id", "=", tonumber(id))
    b:limit(1)
    local r = self:query(b:to_sql())
    return r and r[1]
end

-- /role/create - 新建
function _M:create(o)
    local d = o or {}
    local t = ngx and ngx.time() or os.time()
    d.created_at = d.created_at or t
    d.updated_at = t
    return self:insert(d)
end

-- /role/update - 更新
function _M:update(a, b)
    local id, d
    if type(a) == "table" then d = a; id = a.id else id = a; d = b or {} end
    if not id then return false end
    d.updated_at = ngx and ngx.time() or os.time()
    return M.update(self, d, { id = tonumber(id) })
end

-- /role/delete - 删除
function _M:delete(a)
    local id = type(a) == "table" and a.id or a
    if not id then return false end
    return M.delete(self, { id = tonumber(id) })
end

-- /role/count - 统计
function _M:count(o)
    local b = QB:new("role")
    b:select("COUNT(*) as cnt")
    if o and o.keyword and o.keyword ~= "" then
        for i, f in ipairs(SEARCH_FIELDS) do
            if i == 1 then
                b:where("role." .. f, "LIKE", "%" .. o.keyword .. "%")
            else
                b:or_where("role." .. f, "LIKE", "%" .. o.keyword .. "%")
            end
        end
    end
    local r = self:query(b:to_sql())
    return r and r[1] and r[1].cnt or 0
end

return _M
