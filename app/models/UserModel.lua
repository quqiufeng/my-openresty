local M = require('app.core.Model')

local _M = setmetatable({}, { __index = M })
_M._TABLE = 'users'

function _M.new()
    local o = M:new()
    o:set_table(_M._TABLE)
    return setmetatable(o, { __index = _M })
end

return _M
