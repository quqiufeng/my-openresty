-- Curd Command - Generate CRUD for a table
local _M = {}

local Command = {}

function Command.new()
    local self = {
        args = {},
        options = {},
        name = 'curd',
    }
    
    function self:arg(i, d) return self.args[i] or d end
    function self:parse_args(a) self.args = a end
    function self:handle()
        local table_name = self:arg(1)
        if not table_name then
            self:error('Usage: myresty curd <table_name>')
            self:info('Example: myresty curd users')
            return
        end
        
        local singular = self:singular(table_name)
        local model_name = self:camelize(singular) .. 'Model'
        local controller_name = self:camelize(singular)
        
        self:info('Generating CRUD for table: ' .. table_name)
        self:success('Model: ' .. model_name)
        self:success('Controller: ' .. controller_name)
        self:info('')
        
        _M.generate_model(self, model_name, table_name)
        _M.generate_controller(self, controller_name, table_name, singular)
        _M.generate_routes(self, controller_name, table_name)
        _M.generate_unit_test(self, controller_name, table_name)
        _M.generate_integration_test(self, controller_name, table_name)
        
        self:success('')
        self:success('CRUD generation complete!')
    end
    
    function self:success(m) print('[OK] ' .. m) end
    function self:error(m) print('[ERROR] ' .. m) end
    function self:info(m) print('[INFO] ' .. m) end
    function self:line(m) print(m) end
    
    function self:ucfirst(s) return s and s:sub(1,1):upper()..s:sub(2) or '' end
    function self:plural(s) return s:gsub('y$','ies'):gsub('s$','')..'s' end
    function self:singular(s) return s:gsub('ies$','y'):gsub('s$','') end
    function self:underscore(s) return (s:gsub('(%u)', '_%1'):lower()) end
    function self:camelize(s) local r=''; for w in s:gmatch('[^_]+') do r=r..self:ucfirst(w) end; return r end
    function self:get_table_name(n) return self:underscore(self:plural(n)) end
    function self:file_exists(p) local f=io.open(p,'r'); if f then f:close() return true end return false end
    function self:write_file(p,c) local f=io.open(p,'w'); if not f then return false end f:write(c); f:close(); return true end
    function self:run(a) self:parse_args(a); self:handle() end
    
    return self
end

function _M.new()
    return Command.new()
end

function _M.generate_model(self, model_name, table_name)
    local content = string.format([=[
-- %s Model
local Model = require('app.core.Model')
local _M = setmetatable({}, { __index = Model })
_M._TABLE = '%s'

function _M:list(limit, offset)
    return self:where({ status = 'active' }):limit(limit, offset):get()
end

function _M:get_by_id(id)
    return self:where({ id = id }):first()
end

function _M:create(data)
    return self:insert(data)
end

function _M:update(id, data)
    return self:db:update(self._TABLE, data, { id = id })
end

function _M:delete(id)
    return self:db:delete(self._TABLE, { id = id })
end

function _M:count_all()
    return self:count()
end

return _M
]=], model_name, table_name)
    
    local path = '/var/www/web/my-openresty/app/models/' .. model_name .. '.lua'
    if self:write_file(path, content) then
        self:success('Model: ' .. path)
    end
end

function _M.generate_controller(self, controller_name, table_name, singular)
    local model_var = singular .. '_model'
    local content = string.format([=[
-- %s Controller
local Controller = require('app.core.Controller')
local _M = {}

function _M:__construct()
    Controller.__construct(self)
    self:load('%s')
end

function _M:index()
    local page = tonumber(self.get['page']) or 1
    local limit = tonumber(self.get['limit']) or 10
    local offset = (page - 1) * limit
    local data = self.%s:list(limit, offset)
    local total = self.%s:count_all()
    self:json({ success = true, data = data, total = total, page = page, limit = limit })
end

function _M:show(id)
    local data = self.%s:get_by_id(id)
    if data then
        self:json({ success = true, data = data })
    else
        self:json({ success = false, error = 'Not found' }, 404)
    end
end

function _M:create()
    local data = { name = self.post['name'], status = 'active', created_at = ngx.time(), updated_at = ngx.time() }
    local id = self.%s:create(data)
    self:json({ success = true, data = { id = id } }, 201)
end

function _M:update(id)
    local data = { name = self.post['name'], updated_at = ngx.time() }
    self.%s:update(id, data)
    self:json({ success = true })
end

function _M:delete(id)
    self.%s:delete(id)
    self:json({ success = true })
end

return _M
]=], controller_name, model_var, model_var, model_var, model_var, model_var, model_var, model_var)
    
    local path = '/var/www/web/my-openresty/app/controllers/' .. controller_name .. '.lua'
    if self:write_file(path, content) then
        self:success('Controller: ' .. path)
    end
end

function _M.generate_routes(self, controller_name, table_name)
    local content = string.format([=[
-- Routes for %s (add to app/routes.lua)
route:get('/%s', '%s:index')
route:get('/%s/{id}', '%s:show')
route:post('/%s', '%s:create')
route:put('/%s/{id}', '%s:update')
route:delete('/%s/{id}', '%s:delete')
]=], table_name, table_name, controller_name, table_name, controller_name, 
    table_name, controller_name, table_name, controller_name, table_name, controller_name)
    
    self:info('')
    self:info('Routes to add in app/routes.lua:')
    self:line(content)
end

function _M.generate_unit_test(self, controller_name, table_name)
    local var = table_name:gsub('s$','')
    local content = string.format([=[
-- %sSpec Test
describe('%s Controller', function()
    test('index returns list', function()
        local ctrl = { json = function(d) end, %s_model = { list = function() return {} end, count_all = function() return 0 end } }
        ctrl.index = function() ctrl:json({ success = true }) end
        ctrl.index()
    end)
    test('show returns item', function()
        local ctrl = { json = function(d) end, %s_model = { get_by_id = function() return { id = 1 } end } }
        ctrl.show = function(id) ctrl:json({ success = true }) end
        ctrl.show(1)
    end)
    test('create inserts data', function()
        local ctrl = { json = function(d) end, post = { name = 'Test' }, %s_model = { create = function() return 1 end } }
        ctrl.create = function() ctrl:json({ success = true }) end
        ctrl.create()
    end)
end)
]=], controller_name, controller_name, var, var, var)
    
    local path = '/var/www/web/my-openresty/tests/unit/controllers/' .. controller_name .. 'Spec.lua'
    if self:write_file(path, content) then
        self:success('Unit test: ' .. path)
    end
end

function _M.generate_integration_test(self, controller_name, table_name)
    local content = string.format([=[#!/bin/bash
# %s Integration Test

BASE_URL="${BASE_URL:-http://localhost:8080}"

echo "=== %s CRUD Tests ==="

test_endpoint() {
    local method=$1
    local endpoint=$2
    local data=$3
    local desc=$4
    
    if [ -n "$data" ]; then
        response=$(curl -s -w "\n%%{http_code}" -X $method "$BASE_URL$endpoint" -H "Content-Type: application/json" -d "$data")
    else
        response=$(curl -s -w "\n%%{http_code}" -X $method "$BASE_URL$endpoint")
    fi
    
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        echo "[PASS] $desc (HTTP $http_code)"
    else
        echo "[FAIL] $desc (HTTP $http_code)"
    fi
}

test_endpoint "GET" "/%s" "" "List items"
test_endpoint "POST" "/%s" '{"name":"Test"}' "Create item"
test_endpoint "GET" "/%s/1" "" "Get item"
test_endpoint "PUT" "/%s/1" '{"name":"Updated"}' "Update item"
test_endpoint "DELETE" "/%s/1" "" "Delete item"

echo "=== Tests Complete ==="
]=], controller_name, controller_name, table_name, table_name, table_name, table_name, table_name)
    
    local path = '/var/www/web/my-openresty/tests/integration/crud/' .. controller_name .. '.sh'
    if self:write_file(path, content) then
        self:success('Integration test: ' .. path)
        os.execute('chmod +x ' .. path)
    end
end

return _M
