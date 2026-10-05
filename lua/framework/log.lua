-- 统一日志前缀
local _M = {}

local P = "[tcpudp] "

function _M.info(...) ngx.log(ngx.INFO, P, ...) end
function _M.warn(...) ngx.log(ngx.WARN, P, ...) end
function _M.err(...)  ngx.log(ngx.ERR,  P, ...) end

return _M
