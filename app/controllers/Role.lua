-- Role Controller (统一接口)
-- 支持 GET/POST/PUT/DELETE 方式
-- 接口:
--   /role/list - 列表查询(分页)
--   /role/detail - 详情查询
--   /role/create - 新建
--   /role/update - 更新
--   /role/delete - 删除

local C=require("app.core.Controller")
local M=require("app.models.RoleModel")
local _M={}

function _M.__construct()
  C.__construct(self)
  self.role_model=M:new()
end

-- 获取请求参数(支持GET/POST/JSON)
function _M.get_params()
  local p=self.get or{}
  local post=self.post or{}
  for k,v in pairs(post)do p[k]=v end
  local input=self:input()
  if input and type(input)=="table"then for k,v in pairs(input)do p[k]=v end end
  return p
end

-- /role/list - 列表查询(分页)
function _M.list()
  local p=self:get_params()
  local page=tonumber(p.page)or 1
  local pageSize=tonumber(p.pageSize)or 10
  local data=self.role_model:list({
    page=page,
    pageSize=pageSize,
    keyword=p.keyword
  })
  local total=self.role_model:count({keyword=p.keyword})
  self:json({success=true,data=data or{},total=total,page=page,pageSize=pageSize})
end

-- /role/detail - 详情查询
function _M.detail()
  local p=self:get_params()
  if not p.id then self:json({success=false,message="id required"},400)return end
  local data=self.role_model:detail(p)
  if data then self:json({success=true,data=data})else self:json({success=false,message="Not Found"},404)end
end

-- /role/create - 新建
function _M.create()
  local p=self:get_params()
  local id=self.role_model:create(p)
  self:json({success=true,message="Created",data={id=id}},201)
end

-- /role/update - 更新
function _M.update()
  local p=self:get_params()
  if not p.id then self:json({success=false,message="id required"},400)return end
  self.role_model:update(p)
  self:json({success=true,message="Updated"})
end

-- /role/delete - 删除
function _M.delete()
  local p=self:get_params()
  if not p.id then self:json({success=false,message="id required"},400)return end
  self.role_model:delete(p)
  self:json({success=true,message="Deleted"})
end

return _M
