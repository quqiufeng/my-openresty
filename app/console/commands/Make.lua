-- Make Command
local _M = {}

local Command = {}

function Command.new()
    local self = {
        args = {},
        options = {},
        name = 'make',
    }
    
    function self:arg(i, d) return self.args[i] or d end
    function self:parse_args(a) self.args = a end
    function self:handle()
        local subcommand = self:arg(1)
        local name = self:arg(2)
        
        if not subcommand or not name then
            self:error('Usage: myresty make:<type> <name>')
            return
        end
        
        local generators = {
            controller = 'generate_controller',
            model = 'generate_model',
            middleware = 'generate_middleware',
            library = 'generate_library',
            command = 'generate_command',
            migration = 'generate_migration',
            seeder = 'generate_seeder',
        }
        
        local generator = generators[subcommand]
        if not generator then
            self:error('Unknown type: ' .. subcommand)
            return
        end
        
        _M[generator](self, name)
    end
    
    function self:success(m) print('[OK] ' .. m) end
    function self:error(m) print('[ERROR] ' .. m) end
    function self:info(m) print('[INFO] ' .. m) end
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

function _M.generate_controller(self, name)
    local cname = self:camelize(name)
    local table = self:get_table_name(name)
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
    local data = self.%s:get_all(nil, limit, (page - 1) * limit)
    local total = self.%s:count()
    self:json({ success = true, data = data, total = total, page = page, limit = limit })
end

function _M:show(id)
    local data = self.%s:get_by_id(id)
    if data then self:json({ success = true, data = data })
    else self:json({ success = false, error = 'Not found' }, 404) end
end

function _M:create()
    local id = self.%s:insert({ name = self.post['name'] })
    self:json({ success = true, data = { id = id } }, 201)
end

function _M:update(id)
    self.%s:update(id, { name = self.post['name'] })
    self:json({ success = true })
end

function _M:delete(id)
    self.%s:delete(id)
    self:json({ success = true })
end

return _M
]=], cname, table, table, table, table, table, table, table)
    
    local path = '/var/www/web/my-openresty/app/controllers/' .. cname .. '.lua'
    if self:write_file(path, content) then
        self:success('Controller: ' .. path)
    end
end

function _M.generate_model(self, name)
    local model_name = self:camelize(name) .. 'Model'
    local content = string.format([=[
-- %s Model
local Model = require('app.core.Model')
local _M = setmetatable({}, { __index = Model })
_M._TABLE = '%s'
return _M
]=], model_name, self:get_table_name(name))
    
    local path = '/var/www/web/my-openresty/app/models/' .. model_name .. '.lua'
    if self:write_file(path, content) then
        self:success('Model: ' .. path)
    end
end

function _M.generate_middleware(self, name)
    local content = string.format([=[
-- %s Middleware
local _M = {}
function _M:new() return setmetatable({}, { __index = _M }) end
function _M:handle(options) return true end
return _M
]=], self:camelize(name))
    
    local path = '/var/www/web/my-openresty/app/middleware/' .. self:camelize(name) .. '.lua'
    if self:write_file(path, content) then
        self:success('Middleware: ' .. path)
    end
end

function _M.generate_library(self, name)
    local content = string.format([=[
-- %s Library
local _M = {}
function _M:new() return setmetatable({}, { __index = _M }) end
return _M
]=], self:camelize(name))
    
    local path = '/var/www/web/my-openresty/app/lib/' .. self:camelize(name) .. '.lua'
    if self:write_file(path, content) then
        self:success('Library: ' .. path)
    end
end

function _M.generate_command(self, name)
    local content = string.format([=[
-- %s Command
local Command = require('app.console.Command')
local _M = setmetatable({}, { __index = Command })
function _M.new()
    local self = Command.new()
    self.name = '%s'
    return self
end
function _M:handle() self:info('%s command') end
return _M
]=], self:camelize(name), name, name)
    
    local path = '/var/www/web/my-openresty/app/console/commands/' .. self:camelize(name) .. '.lua'
    if self:write_file(path, content) then
        self:success('Command: ' .. path)
    end
end

function _M.generate_migration(self, name)
    local ts = os.date('%Y%m%d%H%M%S')
    local table = self:get_table_name(name)
    local content = string.format([=[
-- Migration: %s
local Migration = require('app.database.Migration')
local _M = {}
function _M:up()
    self:create_table('%s', function(t)
        t.id('integer'):primary_key()
        t.string('name'):not_null()
        t.timestamps()
    end)
end
function _M:down() self:drop_table('%s') end
return _M
]=], self:camelize(name), table, table)
    
    local path = '/var/www/web/my-openresty/app/database/migrations/' .. ts .. '_' .. name .. '.lua'
    if self:write_file(path, content) then
        self:success('Migration: ' .. path)
    end
end

function _M.generate_seeder(self, name)
    local content = string.format([=[
-- Seeder: %s
local Seeder = require('app.database.Seeder')
local _M = {}
function _M:run() self:table('%s'):insert({ name = 'Example' }) end
return _M
]=], self:camelize(name), self:get_table_name(name))
    
    local path = '/var/www/web/my-openresty/app/database/seeds/' .. self:camelize(name) .. '.lua'
    if self:write_file(path, content) then
        self:success('Seeder: ' .. path)
    end
end

return _M
