-- MenuModel Model
local M=require("app.core.Model")
local QB=require("app.db.query")
local _M=setmetatable({},{__index=M})
_M._TABLE="menu"

function _M.new()
  local o=M:new()o:set_table(_M._TABLE)return o
end

-- /menu/list - 列表查询
function _M.list(o)
  o=o or{}local page=tonumber(o.page)or 1
  local pageSize=tonumber(o.pageSize)or 10
  local b=QB:new("menu")
  b:select("menu.id, menu.name, menu.path, menu.parent_id, menu.sort")
  local sf={"name"}
  if o.keyword and o.keyword~="" then
    local c={}for _,f in ipairs(sf)do c[#c+1]="menu."..f.." LIKE \"%%"..o.keyword.."%%\"" end
    if #c>0 then b:wheres_raw("("..table.concat(c," OR ")..")",o.keyword)end
  end
    -- 无 JOIN
  b:order_by("menu.id","DESC")
  b:limit(pageSize)
  b:offset((page-1)*pageSize)
  return self:query(b:to_sql())
end

-- /menu/detail - 详情查询
function _M.detail(o)
  local id=o and o.id
  if not id then return nil end
  local b=QB:new("menu")
  b:select("menu.id, menu.name, menu.path, menu.parent_id, menu.sort")
  b:where("menu.id","=",tonumber(id))
  b:limit(1)
  local r=self:query(b:to_sql())
  return r and r[1]
end

-- /menu/create - 新建
function _M.create(o)
  local d=o or{}
  local t=ngx and ngx.time()or os.time()
  d.created_at=d.created_at or t
  d.updated_at=t
  return self:insert(d)
end

-- /menu/update - 更新
function _M.update(o)
  local id=o and o.id
  if not id then return false end
  local d=o or{}
  d.updated_at=ngx and ngx.time()or os.time()
  return self:update(d,{id=tonumber(id)})
end

-- /menu/delete - 删除
function _M.delete(o)
  local id=o and o.id
  if not id then return false end
  return self:delete({id=tonumber(id)})
end

-- /menu/count - 统计
function _M.count(o)
  local b=QB:new("menu")
  b:select("COUNT(*)as cnt")
  local sf={"name"}
  if o and o.keyword and o.keyword~="" then
    local c={}for _,f in ipairs(sf)do c[#c+1]="menu."..f.." LIKE \"%%"..o.keyword.."%%\"" end
    if #c>0 then b:wheres_raw("("..table.concat(c," OR ")..")",o.keyword)end
  end
  local r=self:query(b:to_sql())
  return r and r[1]and r[1].cnt or 0
end

return _M
