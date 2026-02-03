local Controller = require('app.core.Controller')

local _M = {}

function _M:index()
    self:json({
        message = 'Welcome to MyResty Framework',
        version = '1.0.0',
        controllers = {
            name = 'welcome',
            methods = {'index', 'hello'}
        }
    })
end

function _M:hello(name)
    self:json({
        message = 'Hello, ' .. tostring(name) .. '!',
        controller = 'welcome',
        action = 'hello'
    })
end

return _M
