local Model = require('app.core.Model')

local _M = {}

function _M.new()
    local model = Model:new()
    model:set_table('users')
    return model
end

return _M
