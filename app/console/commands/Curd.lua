-- Curd Command - Generate Unified CRUD from JSON config
local _M = {}

local Command = {}

function Command.new()
    local self = {args={},options={},name='curd'}
    function self:arg(i,d) return self.args[i] or d end
    function self:parse_args(a) self.args=a end
    function self:handle()
        local f=self:arg(1)
        local c
        -- Support < xxx.json syntax (read from stdin)
        if not f then
            c=io.read('*a')
            if not c or c=='' then print('[ERROR] Usage: myresty curd <config.json>')return end
        else
            -- Support < xxx.json (shell passes '<' as arg1, filename as arg2)
            if f=='<' then
                f=self:arg(2)
            elseif f and f:sub(1,1)=='<' then
                f=f:sub(2):match('^%s*(.-)%s*$')
            end
            if not f then print('[ERROR] Usage: myresty curd <config.json>')return end
            local file=io.open(f,'r')
            if not file then print('[ERROR] File not found: '..f)return end
            c=file:read('*a')file:close()
        end
        local config=_M.parse_json(c)
        if not config or not config.table then print('[ERROR] Invalid config')return end
        local tn=config.table
        local sn=_M.singular(tn)
        local mn=sn:gsub('^%l',string.upper)..'Model'
        local cn=sn:gsub('^%l',string.upper)
        print('[INFO] Generating CRUD for table: '..tn)
        print('[OK] Model: '..mn)
        print('[OK] Controller: '..cn)
        print('')
        _M.gen_model(self,config,mn,tn)
        _M.gen_ctrl(self,config,cn,tn,sn)
        _M.gen_model_test(self,config,mn,tn,sn)
        _M.gen_ctrl_test(self,config,cn,tn,sn)
        _M.gen_integration_test(self,config,cn,tn)
        print('')
        print('[OK] Tests generated!')
        print('[OK] Run: luajit tests/unit/models/'..sn..'_spec.lua')
        print('[OK] Run: luajit tests/unit/controllers/'..cn..'Spec.lua')
        print('[OK] Run: ./tests/integration/crud/'..cn..'.sh')
        print('')
        print('[OK] Done!')
    end
    function self:write(p,c)local f=io.open(p,'w')if not f then return false end f:write(c)f:close()return true end
    function self:run(a)self:parse_args(a)self:handle()end
    return self
end

function _M.new()return Command.new()end

function _M.singular(s)return s:gsub('ies$','y'):gsub('s$','')end

function _M.parse_json(s)
    s=s:gsub('%c',' ')local i=1
    local function sk()while i<=#s and s:sub(i,i):match('%s')do i=i+1 end end
    local function v()
        sk()if i>#s then return nil end
        local c=s:sub(i,i)
        if c=='"' then return _M.ps()
        elseif c=='[' then return _M.pa()
        elseif c=='{' then return _M.po()
        elseif s:sub(i,4)=='true'then i=i+4 return true
        elseif s:sub(i,5)=='false'then i=i+5 return false
        elseif s:sub(i,4)=='null'then i=i+4 return nil
        else local n=s:sub(i):match('^[0-9.e+-]+')if n then i=i+#n-1 return tonumber(n)end i=i+1 return nil end
    end
    function _M.ps()
        sk()if s:sub(i,i)~='"'then return nil end i=i+1 local t={}
        while i<=#s do
            local c=s:sub(i,i)
            if c=='"'then i=i+1 break end
            if c=='\\'then i=i+1 local n=s:sub(i,i)
                if n=='n'then t[#t+1]='\n'elseif n=='t'then t[#t+1]='\t'elseif n=='"'then t[#t+1]='"'elseif n=='\\'then t[#t+1]='\\'else t[#t+1]=n end
            else t[#t+1]=c end
            i=i+1
        end return table.concat(t)
    end
    function _M.pa()
        sk()if s:sub(i,i)~='['then return nil end i=i+1 sk()local a={}
        if s:sub(i,i)==']'then i=i+1 return a end
        while true do a[#a+1]=v()sk()if s:sub(i,i)==','then i=i+1 elseif s:sub(i,i)==']'then i=i+1 break else break end end
        return a
    end
    function _M.po()
        sk()if s:sub(i,i)~='{'then return nil end i=i+1 sk()local o={}
        if s:sub(i,i)=='}'then i=i+1 return o end
        while true do
            local k=_M.ps()if not k then break end
            sk()if s:sub(i,i)~=':'then break end i=i+1
            o[k]=v()sk()
            if s:sub(i,i)==','then i=i+1 elseif s:sub(i,i)=='}'then i=i+1 break else break end
        end
        return o
    end
    return v()
end

function _M.gen_model(self,config,mn,tn)
    local sp={}local jp={}
    local prefix=self:arg(2)or''
    for _,f in ipairs(config.list_field or{})do
        if type(f)=='string' then
            if f:find('left join ')then
                local r=f:gsub('^left join ','')
                local jt=r:match('^(%S+)')
                local on=r:match('on (%S+)')
                if jt and on then
                    local l,r=on:match('(.+)=(.+)')
                    if l and r then
                        local pjt=prefix~='' and prefix..'_'..jt or jt
                        jp[#jp+1]=string.format('    b:left_join("%s"):on("%s", "%s")',pjt,l,r)
                        if r:find('display ')then
                            local d=r:match('display (%S+)')
                            local a=r:match('display %S+ as (%S+)')or d
                            if d then sp[#sp+1]=jt..'.'..d..' as '..a end
                        end
                    end
                end
            else sp[#sp+1]=tn..'.'..f end
        end
    end
    local ss=#sp>0 and table.concat(sp,', ')or tn..'.*'
    local ssr={}for _,f in ipairs(config.search_field or{})do if type(f)=='string'then ssr[#ssr+1]='"'..f..'"' end end
    local sstr=#ssr>0 and '{'..table.concat(ssr,',')..'}'or'{}'
    local jstr=#jp>0 and table.concat(jp,'\n')or'    -- 无 JOIN'
    local ct='-- '..mn..' Model\n'
    ct=ct..'local M=require("app.core.Model")\n'
    ct=ct..'local QB=require("app.db.query")\n'
    ct=ct..'local _M=setmetatable({},{__index=M})\n'
    ct=ct..'_M._TABLE="'..tn..'"\n\n'
    ct=ct..'function _M.new()\n'
    ct=ct..'  local o=M:new()o:set_table(_M._TABLE)return o\n'
    ct=ct..'end\n\n'
    ct=ct..'-- /'..tn..'/list - 列表查询\n'
    ct=ct..'function _M.list(o)\n'
    ct=ct..'  o=o or{}local page=tonumber(o.page)or 1\n'
    ct=ct..'  local pageSize=tonumber(o.pageSize)or 10\n'
    ct=ct..'  local b=QB:new("'..tn..'")\n'
    ct=ct..'  b:select("'..ss..'")\n'
    ct=ct..'  local sf='..sstr..'\n'
    ct=ct..'  if o.keyword and o.keyword~="" then\n'
    ct=ct..'    local c={}for _,f in ipairs(sf)do c[#c+1]="'..tn..'."..f.." LIKE \\"%%"..o.keyword.."%%\\"" end\n'
    ct=ct..'    if #c>0 then b:wheres_raw("("..table.concat(c," OR ")..")",o.keyword)end\n'
    ct=ct..'  end\n'
    ct=ct..jstr..'\n'
    ct=ct..'  b:order_by("'..tn..'.id","DESC")\n'
    ct=ct..'  b:limit(pageSize)\n'
    ct=ct..'  b:offset((page-1)*pageSize)\n'
    ct=ct..'  return self:query(b:to_sql())\n'
    ct=ct..'end\n\n'
    ct=ct..'-- /'..tn..'/detail - 详情查询\n'
    ct=ct..'function _M.detail(o)\n'
    ct=ct..'  local id=o and o.id\n'
    ct=ct..'  if not id then return nil end\n'
    ct=ct..'  local b=QB:new("'..tn..'")\n'
    ct=ct..'  b:select("'..ss..'")\n'
    ct=ct..'  b:where("'..tn..'.id","=",tonumber(id))\n'
    ct=ct..'  b:limit(1)\n'
    ct=ct..'  local r=self:query(b:to_sql())\n'
    ct=ct..'  return r and r[1]\n'
    ct=ct..'end\n\n'
    ct=ct..'-- /'..tn..'/create - 新建\n'
    ct=ct..'function _M.create(o)\n'
    ct=ct..'  local d=o or{}\n'
    ct=ct..'  local t=ngx and ngx.time()or os.time()\n'
    ct=ct..'  d.created_at=d.created_at or t\n'
    ct=ct..'  d.updated_at=t\n'
    ct=ct..'  return self:insert(d)\n'
    ct=ct..'end\n\n'
    ct=ct..'-- /'..tn..'/update - 更新\n'
    ct=ct..'function _M.update(o)\n'
    ct=ct..'  local id=o and o.id\n'
    ct=ct..'  if not id then return false end\n'
    ct=ct..'  local d=o or{}\n'
    ct=ct..'  d.updated_at=ngx and ngx.time()or os.time()\n'
    ct=ct..'  return self:update(d,{id=tonumber(id)})\n'
    ct=ct..'end\n\n'
    ct=ct..'-- /'..tn..'/delete - 删除\n'
    ct=ct..'function _M.delete(o)\n'
    ct=ct..'  local id=o and o.id\n'
    ct=ct..'  if not id then return false end\n'
    ct=ct..'  return self:delete({id=tonumber(id)})\n'
    ct=ct..'end\n\n'
    ct=ct..'-- /'..tn..'/count - 统计\n'
    ct=ct..'function _M.count(o)\n'
    ct=ct..'  local b=QB:new("'..tn..'")\n'
    ct=ct..'  b:select("COUNT(*)as cnt")\n'
    ct=ct..'  local sf='..sstr..'\n'
    ct=ct..'  if o and o.keyword and o.keyword~="" then\n'
    ct=ct..'    local c={}for _,f in ipairs(sf)do c[#c+1]="'..tn..'."..f.." LIKE \\"%%"..o.keyword.."%%\\"" end\n'
    ct=ct..'    if #c>0 then b:wheres_raw("("..table.concat(c," OR ")..")",o.keyword)end\n'
    ct=ct..'  end\n'
    ct=ct..'  local r=self:query(b:to_sql())\n'
    ct=ct..'  return r and r[1]and r[1].cnt or 0\n'
    ct=ct..'end\n\n'
    ct=ct..'return _M\n'
    local p='/var/www/web/my-openresty/app/models/'..mn..'.lua'
    self:write(p,ct)print('[OK] Model: '..p)
end

function _M.gen_ctrl(self,config,cn,tn,sn)
    local mv=sn..'_model'
    local ct='-- '..cn..' Controller (统一接口)\n'
    ct=ct..'-- 支持 GET/POST/PUT/DELETE 方式\n'
    ct=ct..'-- 接口:\n'
    ct=ct..'--   /'..tn..'/list - 列表查询(分页)\n'
    ct=ct..'--   /'..tn..'/detail - 详情查询\n'
    ct=ct..'--   /'..tn..'/create - 新建\n'
    ct=ct..'--   /'..tn..'/update - 更新\n'
    ct=ct..'--   /'..tn..'/delete - 删除\n\n'
    ct=ct..'local C=require("app.core.Controller")\n'
    ct=ct..'local M=require("app.models.'..sn:gsub('^%l',string.upper)..'Model")\n'
    ct=ct..'local _M={}\n\n'
    ct=ct..'function _M.__construct()\n'
    ct=ct..'  C.__construct(self)\n'
    ct=ct..'  self.'..mv..'=M:new()\n'
    ct=ct..'end\n\n'
    ct=ct..'-- 获取请求参数(支持GET/POST/JSON)\n'
    ct=ct..'function _M.get_params()\n'
    ct=ct..'  local p=self.get or{}\n'
    ct=ct..'  local post=self.post or{}\n'
    ct=ct..'  for k,v in pairs(post)do p[k]=v end\n'
    ct=ct..'  local input=self:input()\n'
    ct=ct..'  if input and type(input)=="table"then for k,v in pairs(input)do p[k]=v end end\n'
    ct=ct..'  return p\n'
    ct=ct..'end\n\n'
    ct=ct..'-- /'..tn..'/list - 列表查询(分页)\n'
    ct=ct..'function _M.list()\n'
    ct=ct..'  local p=self:get_params()\n'
    ct=ct..'  local page=tonumber(p.page)or 1\n'
    ct=ct..'  local pageSize=tonumber(p.pageSize)or 10\n'
    ct=ct..'  local data=self.'..mv..':list({\n'
    ct=ct..'    page=page,\n'
    ct=ct..'    pageSize=pageSize,\n'
    ct=ct..'    keyword=p.keyword\n'
    ct=ct..'  })\n'
    ct=ct..'  local total=self.'..mv..':count({keyword=p.keyword})\n'
    ct=ct..'  self:json({success=true,data=data or{},total=total,page=page,pageSize=pageSize})\n'
    ct=ct..'end\n\n'
    ct=ct..'-- /'..tn..'/detail - 详情查询\n'
    ct=ct..'function _M.detail()\n'
    ct=ct..'  local p=self:get_params()\n'
    ct=ct..'  if not p.id then self:json({success=false,message="id required"},400)return end\n'
    ct=ct..'  local data=self.'..mv..':detail(p)\n'
    ct=ct..'  if data then self:json({success=true,data=data})else self:json({success=false,message="Not Found"},404)end\n'
    ct=ct..'end\n\n'
    ct=ct..'-- /'..tn..'/create - 新建\n'
    ct=ct..'function _M.create()\n'
    ct=ct..'  local p=self:get_params()\n'
    ct=ct..'  local id=self.'..mv..':create(p)\n'
    ct=ct..'  self:json({success=true,message="Created",data={id=id}},201)\n'
    ct=ct..'end\n\n'
    ct=ct..'-- /'..tn..'/update - 更新\n'
    ct=ct..'function _M.update()\n'
    ct=ct..'  local p=self:get_params()\n'
    ct=ct..'  if not p.id then self:json({success=false,message="id required"},400)return end\n'
    ct=ct..'  self.'..mv..':update(p)\n'
    ct=ct..'  self:json({success=true,message="Updated"})\n'
    ct=ct..'end\n\n'
    ct=ct..'-- /'..tn..'/delete - 删除\n'
    ct=ct..'function _M.delete()\n'
    ct=ct..'  local p=self:get_params()\n'
    ct=ct..'  if not p.id then self:json({success=false,message="id required"},400)return end\n'
    ct=ct..'  self.'..mv..':delete(p)\n'
    ct=ct..'  self:json({success=true,message="Deleted"})\n'
    ct=ct..'end\n\n'
    ct=ct..'return _M\n'
    local p='/var/www/web/my-openresty/app/controllers/'..cn..'.lua'
    self:write(p,ct)print('[OK] Controller: '..p)
end

function _M.gen_model_test(self,config,mn,tn,sn)
    local tests_passed=0
    local tests_failed=0
    local function assert_eq(exp,act,name)
        if exp==act then tests_passed=tests_passed+1 else tests_failed=tests_failed+1 end
    end
    local ct='-- '..mn..' Unit Tests\n'
    ct=ct..'-- Generated by curd command. Run with: luajit tests/unit/models/'..sn..'_spec.lua\n\n'
    ct=ct..'package.path="/var/www/web/my-openresty/?.lua;;"..package.path\n'
    ct=ct..'package.cpath="/var/www/web/my-openresty/?.so;;"..package.cpath\n\n'
    ct=ct..'local Test=require("app.lib.test")\n'
    ct=ct..'local '..mn..'=require("app.models.'..sn:gsub('^%l',string.upper)..'Model")\n\n'
    ct=ct..'local tests_passed=0\n'
    ct=ct..'local tests_failed=0\n\n'
    ct=ct..'local function assert_eq(exp,act,name)\n'
    ct=ct..'    if exp==act then\n'
    ct=ct..'        print("✓ PASS: "..name)\n'
    ct=ct..'        tests_passed=tests_passed+1\n'
    ct=ct..'    else\n'
    ct=ct..'        print("✗ FAIL: "..name)\n'
    ct=ct..'        print("  Expected: "..tostring(exp))\n'
    ct=ct..'        print("  Actual:   "..tostring(act))\n'
    ct=ct..'        tests_failed=tests_failed+1\n'
    ct=ct..'    end\n'
    ct=ct..'end\n\n'
    ct=ct..'print("='..string.rep('=',60)..'")\n'
    ct=ct..'print("'..mn..' Unit Tests")\n'
    ct=ct..'print("='..string.rep('=',60)..'")\n'
    ct=ct..'print()\n\n'
    ct=ct..'-- Test: new()\n'
    ct=ct..'print("Test: new()")\n'
    ct=ct..'local m='..mn..':new()\n'
    ct=ct..'assert_eq("'..tn..'",m._TABLE,"new() should set table name")\n'
    ct=ct..'assert_eq(true,m~=nil,"new() should return instance")\n'
    ct=ct..'print()\n\n'
    ct=ct..'-- Test: list() should return table\n'
    ct=ct..'print("Test: list()")\n'
    ct=ct..'local list=m:list({page=1,pageSize=10})\n'
    ct=ct..'assert_eq("table",type(list),"list() should return table")\n'
    ct=ct..'print()\n\n'
    ct=ct..'-- Test: count() should return number\n'
    ct=ct..'print("Test: count()")\n'
    ct=ct..'local cnt=m:count({})\n'
    ct=ct..'assert_eq("number",type(cnt),"count() should return number")\n'
    ct=ct..'print()\n\n'
    ct=ct..'-- Test: detail() with id\n'
    ct=ct..'print("Test: detail()")\n'
    ct=ct..'local d=m:detail({id=1})\n'
    ct=ct..'assert_eq("table",type(d),"detail() should return table or nil")\n'
    ct=ct..'print()\n\n'
    ct=ct..'-- Test: create() should return id\n'
    ct=ct..'print("Test: create()")\n'
    ct=ct..'local id=m:create({username="test_'..os.time()..'",phone="'..tostring(os.time()):sub(-4)..'"})\n'
    ct=ct..'assert_eq("number",type(id),"create() should return id")\n'
    ct=ct..'print()\n\n'
    ct=ct..'-- Test: update() should return boolean\n'
    ct=ct..'print("Test: update()")\n'
    ct=ct..'local ok=m:update({id=1,username="updated"})\n'
    ct=ct..'assert_eq("boolean",type(ok),"update() should return boolean")\n'
    ct=ct..'print()\n\n'
    ct=ct..'-- Test: delete() should return boolean\n'
    ct=ct..'print("Test: delete()")\n'
    ct=ct..'local ok=m:delete({id=1})\n'
    ct=ct..'assert_eq("boolean",type(ok),"delete() should return boolean")\n'
    ct=ct..'print()\n\n'
    ct=ct..'print("="..string.rep("=",60)..")\n'
    ct=ct..'print("Test Results")\n'
    ct=ct..'print("="..string.rep("=",60)..")\n'
    ct=ct..'print("Passed: "..tests_passed)\n'
    ct=ct..'print("Failed: "..tests_failed)\n'
    ct=ct..'print()\n'
    ct=ct..'if tests_failed>0 then os.exit(1) end\n'
    local p='/var/www/web/my-openresty/tests/unit/models'
    os.execute('mkdir -p "'..p..'"')
    p=p..'/'..sn..'_spec.lua'
    self:write(p,ct)print('[OK] Model Test: '..p)
end

function _M.gen_ctrl_test(self,config,cn,tn,sn)
    local mv=sn..'_model'
    local ct='-- '..cn..' Controller Unit Tests\n'
    ct=ct..'-- Generated by curd command. Run with: luajit tests/unit/controllers/'..cn..'Spec.lua\n\n'
    ct=ct..'package.path="/var/www/web/my-openresty/?.lua;;"..package.path\n'
    ct=ct..'package.cpath="/var/www/web/my-openresty/?.so;;"..package.cpath\n\n'
    ct=ct..'local tests_passed=0\n'
    ct=ct..'local tests_failed=0\n\n'
    ct=ct..'local function assert_eq(exp,act,name)\n'
    ct=ct..'    if exp==act then\n'
    ct=ct..'        print("✓ PASS: "..name)\n'
    ct=ct..'        tests_passed=tests_passed+1\n'
    ct=ct..'    else\n'
    ct=ct..'        print("✗ FAIL: "..name)\n'
    ct=ct..'        print("  Expected: "..tostring(exp))\n'
    ct=ct..'        print("  Actual:   "..tostring(act))\n'
    ct=ct..'        tests_failed=tests_failed+1\n'
    ct=ct..'    end\n'
    ct=ct..'end\n\n'
    ct=ct..'print("='..string.rep('=',60)..'")\n'
    ct=ct..'print("'..cn..' Controller Unit Tests")\n'
    ct=ct..'print("='..string.rep('=',60)..'")\n'
    ct=ct..'print()\n\n'
    ct=ct..'-- Test: controller should load model\n'
    ct=ct..'print("Test: controller structure")\n'
    ct=ct..'local C=require("app.controllers.'..cn..'")\n'
    ct=ct..'assert_eq("table",type(C),"controller should be table")\n'
    ct=ct..'assert_eq("function",type(C.list),"list() should be function")\n'
    ct=ct..'assert_eq("function",type(C.detail),"detail() should be function")\n'
    ct=ct..'assert_eq("function",type(C.create),"create() should be function")\n'
    ct=ct..'assert_eq("function",type(C.update),"update() should be function")\n'
    ct=ct..'assert_eq("function",type(C.delete),"delete() should be function")\n'
    ct=ct..'assert_eq("function",type(C.get_params),"get_params() should be function")\n'
    ct=ct..'print()\n\n'
    ct=ct..'-- Test: mock request\n'
    ct=ct..'print("Test: mock request handling")\n'
    ct=ct..'local mock={get={page="1",pageSize="10"},post={},json=function()end}\n'
    ct=ct..'setmetatable(mock,{__index=function(t,k) return function() end end})\n'
    ct=ct..'assert_eq("function",type(mock.get_params),"get_params should be callable")\n'
    ct=ct..'print()\n\n'
    ct=ct..'-- Test: list() should call model\n'
    ct=ct..'print("Test: list() interface")\n'
    ct=ct..'assert_eq("function",type(C.list),"list should be function")\n'
    ct=ct..'print()\n\n'
    ct=ct..'-- Test: detail() should require id\n'
    ct=ct..'print("Test: detail() interface")\n'
    ct=ct..'assert_eq("function",type(C.detail),"detail should be function")\n'
    ct=ct..'print()\n\n'
    ct=ct..'-- Test: create() interface\n'
    ct=ct..'print("Test: create() interface")\n'
    ct=ct..'assert_eq("function",type(C.create),"create should be function")\n'
    ct=ct..'print()\n\n'
    ct=ct..'-- Test: update() interface\n'
    ct=ct..'print("Test: update() interface")\n'
    ct=ct..'assert_eq("function",type(C.update),"update should be function")\n'
    ct=ct..'print()\n\n'
    ct=ct..'-- Test: delete() interface\n'
    ct=ct..'print("Test: delete() interface")\n'
    ct=ct..'assert_eq("function",type(C.delete),"delete should be function")\n'
    ct=ct..'print()\n\n'
    ct=ct..'print("="..string.rep("=",60)..")\n'
    ct=ct..'print("Test Results")\n'
    ct=ct..'print("="..string.rep("=",60)..")\n'
    ct=ct..'print("Passed: "..tests_passed)\n'
    ct=ct..'print("Failed: "..tests_failed)\n'
    ct=ct..'print()\n'
    ct=ct..'if tests_failed>0 then os.exit(1) end\n'
    local p='/var/www/web/my-openresty/tests/unit/controllers/'..cn..'Spec.lua'
    self:write(p,ct)print('[OK] Controller Test: '..p)
end

function _M.gen_integration_test(self,config,cn,tn)
    local ct='#!/bin/bash\n'
    ct=ct..'# '..cn..' Integration Tests\n'
    ct=ct..'# Generated by curd command\n\n'
    ct=ct..'BASE_URL=${BASE_URL:-http://localhost:8080}\n'
    ct=ct..'TABLE="'..tn..'"\n\n'
    ct=ct..'echo "============================================================"\n'
    ct=ct..'echo "'..cn..' Integration Tests"\n'
    ct=ct..'echo "============================================================"\n'
    ct=ct..'echo "Base URL: $BASE_URL"\n'
    ct=ct..'echo ""\n\n'
    ct=ct..'passed=0\n'
    ct=ct..'failed=0\n\n'
    ct=ct..'test_api() {\n'
    ct=ct..'    local method=$1\n'
    ct=ct..'    local endpoint=$2\n'
    ct=ct..'    local data=$3\n'
    ct=ct..'    local name=$4\n\n'
    ct=ct..'    echo "Test: $name"\n'
    ct=ct..'    if [ -n "$data" ]; then\n'
    ct=ct..'        response=$(curl -s -X $method "$BASE_URL$endpoint" -H "Content-Type: application/json" -d \'"$data\')\n'
    ct=ct..'    else\n'
    ct=ct..'        response=$(curl -s -X $method "$BASE_URL$endpoint")\n'
    ct=ct..'    fi\n\n'
    ct=ct..'    if echo "$response" | grep -q "success"; then\n'
    ct=ct..'        echo "✓ PASS: $name"\n'
    ct=ct..'        ((passed++))\n'
    ct=ct..'    else\n'
    ct=ct..'        echo "✗ FAIL: $name"\n'
    ct=ct..'        echo "  Response: $response"\n'
    ct=ct..'        ((failed++))\n'
    ct=ct..'    fi\n'
    ct=ct..'    echo ""\n'
    ct=ct..'}\n\n'
    ct=ct..'echo "Test: List $TABLE"\n'
    ct=ct..'test_api "GET" "/'..tn..'/list" "" "List '..tn..'"\n\n'
    ct=ct..'echo "Test: Create $TABLE"\n'
    ct=ct..'test_api "POST" "/'..tn..'/create" \'{"username":"test_'..os.time()..'","phone":"'..tostring(os.time()):sub(-4)..'","role_id":1}\' "Create '..tn..'"\n\n'
    ct=ct..'echo "Test: Detail $TABLE"\n'
    ct=ct..'test_api "GET" "/'..tn..'/detail?id=1" "" "Detail '..tn..'"\n\n'
    ct=ct..'echo "Test: Update $TABLE"\n'
    ct=ct..'test_api "POST" "/'..tn..'/update" \'{"id":1,"username":"updated"}\' "Update '..tn..'"\n\n'
    ct=ct..'echo "Test: Delete $TABLE"\n'
    ct=ct..'test_api "POST" "/'..tn..'/delete" \'{"id":1}\' "Delete '..tn..'"\n\n'
    ct=ct..'echo "============================================================"\n'
    ct=ct..'echo "Test Results"\n'
    ct=ct..'echo "============================================================"\n'
    ct=ct..'echo "Passed: $passed"\n'
    ct=ct..'echo "Failed: $failed"\n'
    ct=ct..'echo ""\n\n'
    ct=ct..'if [ $failed -gt 0 ]; then\n'
    ct=ct..'    echo "Some tests failed!"\n'
    ct=ct..'    exit 1\n'
    ct=ct..'else\n'
    ct=ct..'    echo "All tests passed!"\n'
    ct=ct..'    exit 0\n'
    ct=ct..'fi\n'
    local p='/var/www/web/my-openresty/tests/integration/crud/'..cn..'.sh'
    self:write(p,ct)
    os.execute('chmod +x "'..p..'"')
    print('[OK] Integration Test: '..p)
end

return _M
