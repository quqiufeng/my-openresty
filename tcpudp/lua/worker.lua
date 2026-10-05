-- worker 初始化（每个 worker 一次）
local config = require("framework.config")
local n = #config.all()
ngx.log(ngx.INFO, "[tcpudp] worker started, rules=", n)
