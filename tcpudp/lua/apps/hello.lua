-- 示例应用：自定义 TCP 协议处理
-- 在 conf/forward.lua 中用 handler = "apps.hello" 引用。
local _M = {}

function _M.run(rule)
    local sock = ngx.req.socket()
    sock:send("hello from MyResty tcpudp [" .. rule.name .. "]\r\n")
    while true do
        local data, err, partial = sock:receiveany(65536)
        if not data then data = partial end
        if not data or #data == 0 then break end
        sock:send(data)
    end
end

return _M
