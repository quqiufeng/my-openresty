-- RoleModel Model
local M=require("app.core.Model")
local QB=require("app.db.query")
local _M=setmetatable({},{__index=M})
_M._TABLE="role"

function _M.new()
  local o=M:new()o:set_table(_M._TABLE)return o
end

function _M.list(o)
  o=o or{}local p=tonumber(o.page)or 1
  local sz=tonumber(o.pageSize)or 10
  local b=QB:new("role")
  b:select("role.id, role.name")
  local sf={"name"}
  if o.keyword and o.keyword~="" then
    local c={}for _,f in ipairs(sf)do c[#c+1]="role."..f.." LIKE \"%%"..o.keyword.."%%\"" end
    if #c>0 then b:wheres_raw("("..table.concat(c," OR ")..")",o.keyword)end
  end
    -- 无 JOIN
  b:order_by("role.id","DESC")
  b:limit(sz)
  b:offset((p-1)*sz)
  return self:query(b:to_sql())
end

function _M.count_all(o)
  local b=QB:new("role")b:select("COUNT(*)as cnt")
  local sf={"name"}
  if o and o.keyword and o.keyword~="" then
    local c={}for _,f in ipairs(sf)do c[#c+1]="role."..f.." LIKE \"%%"..o.keyword.."%%\"" end
    if #c>0 then b:wheres_raw("("..table.concat(c," OR ")..")",o.keyword)end
  end
  local r=self:query(b:to_sql())
  return r and r[1]and r[1].cnt or 0
end

function _M.get_by_id(id)
  if not id then return nil end
  local b=QB:new("role")
  b:select("role.id, role.name")
  b:where("role.id","=",tonumber(id))
  b:limit(1)
  local r=self:query(b:to_sql())
  return r and r[1]
end

function _M.create(d)
  local t=ngx and ngx.time()or os.time()
  d.created_at=d.created_at or t
  d.updated_at=t
  return self:insert(d)
end

function _M.update_data(id,d)
  d.updated_at=ngx and ngx.time()or os.time()
  return self:update(d,{id=id})
end

function _M.delete_data(id)return self:delete({id=id})end

return _M
