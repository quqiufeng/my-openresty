-- Admin Controller (统一接口)
-- 支持 GET/POST/PUT/DELETE 方式
-- 接口:
--   /admin/list - 列表查询(分页)
--   /admin/detail - 详情查询
--   /admin/create - 新建
--   /admin/update - 更新
--   /admin/delete - 删除

local C=require("app.core.Controller")
local M=require("app.models.AdminModel")
local _M={}

function _M.__construct()
  C.__construct(self)
  self.admin_model=M:new()
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

-- /admin/list - 列表查询(分页)
function _M.list()
  local p=self:get_params()
  local page=tonumber(p.page)or 1
  local pageSize=tonumber(p.pageSize)or 10
  local data=self.admin_model:list({
    page=page,
    pageSize=pageSize,
    keyword=p.keyword
  })
  local total=self.admin_model:count({keyword=p.keyword})
  self:json({success=true,data=data or{},total=total,page=page,pageSize=pageSize})
end

-- /admin/detail - 详情查询
function _M.detail()
  local p=self:get_params()
  if not p.id then self:json({success=false,message="id required"},400)return end
  local data=self.admin_model:detail(p)
  if data then self:json({success=true,data=data})else self:json({success=false,message="Not Found"},404)end
end

-- /admin/create - 新建
function _M.create()
  local p=self:get_params()
  local id=self.admin_model:create(p)
  self:json({success=true,message="Created",data={id=id}},201)
end

-- /admin/update - 更新
function _M.update()
  local p=self:get_params()
  if not p.id then self:json({success=false,message="id required"},400)return end
  self.admin_model:update(p)
  self:json({success=true,message="Updated"})
end

-- /admin/delete - 删除
function _M.delete()
  local p=self:get_params()
  if not p.id then self:json({success=false,message="id required"},400)return end
  self.admin_model:delete(p)
  self:json({success=true,message="Deleted"})
end

return _M
