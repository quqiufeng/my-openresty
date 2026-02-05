-- Menu Controller (统一接口)
-- 支持 GET/POST/PUT/DELETE 方式
-- 接口:
--   /menu/list - 列表查询(分页)
--   /menu/detail - 详情查询
--   /menu/create - 新建
--   /menu/update - 更新
--   /menu/delete - 删除

local C=require("app.core.Controller")
local M=require("app.models.MenuModel")
local _M={}

function _M.__construct()
  C.__construct(self)
  self.menu_model=M:new()
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

-- /menu/list - 列表查询(分页)
function _M.list()
  local p=self:get_params()
  local page=tonumber(p.page)or 1
  local pageSize=tonumber(p.pageSize)or 10
  local data=self.menu_model:list({
    page=page,
    pageSize=pageSize,
    keyword=p.keyword
  })
  local total=self.menu_model:count({keyword=p.keyword})
  self:json({success=true,data=data or{},total=total,page=page,pageSize=pageSize})
end

-- /menu/detail - 详情查询
function _M.detail()
  local p=self:get_params()
  if not p.id then self:json({success=false,message="id required"},400)return end
  local data=self.menu_model:detail(p)
  if data then self:json({success=true,data=data})else self:json({success=false,message="Not Found"},404)end
end

-- /menu/create - 新建
function _M.create()
  local p=self:get_params()
  local id=self.menu_model:create(p)
  self:json({success=true,message="Created",data={id=id}},201)
end

-- /menu/update - 更新
function _M.update()
  local p=self:get_params()
  if not p.id then self:json({success=false,message="id required"},400)return end
  self.menu_model:update(p)
  self:json({success=true,message="Updated"})
end

-- /menu/delete - 删除
function _M.delete()
  local p=self:get_params()
  if not p.id then self:json({success=false,message="id required"},400)return end
  self.menu_model:delete(p)
  self:json({success=true,message="Deleted"})
end

return _M
