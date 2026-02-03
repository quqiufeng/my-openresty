-- ProductModel Model
local Model = require('app.core.Model')
local _M = setmetatable({}, { __index = Model })
_M._TABLE = '_products'
return _M
