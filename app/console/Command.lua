-- Console Command Base Class
local _M = { _VERSION = '1.0.0' }
local mt = { __index = _M }

function _M.new()
    local self = { args = {}, options = {} }
    return setmetatable(self, mt)
end

function _M:parse_args(raw_args) self.args = raw_args end
function _M:arg(i, d) return self.args[i] or d end
function _M:handle() print('Command not implemented') end
function _M:run(raw_args) self:parse_args(raw_args); self:handle() end
function _M:success(m) print('[OK] ' .. m) end
function _M:error(m) print('[ERROR] ' .. m) end
function _M:info(m) print('[INFO] ' .. m) end
function _M:ucfirst(s) return s and s:sub(1,1):upper()..s:sub(2) or '' end
function _M:plural(s) return s:gsub('y$','ies'):gsub('s$','')..'s' end
function _M:underscore(s) return (s:gsub('(%u)', '_%1'):lower()) end
function _M:get_table_name(n) return self:underscore(self:plural(n)) end
function _M:camelize(s) local r=''; for w in s:gmatch('[^_]+') do r=r..self:ucfirst(w) end; return r end
function _M:file_exists(p) local f=io.open(p,'r'); if f then f:close() return true end return false end
function _M:write_file(p,c) local f=io.open(p,'w'); if not f then return false end f:write(c); f:close(); return true end
return _M
