-- UDP 传输：单包 echo 与单包反向代理
local upstream = require("framework.upstream")
local log = require("framework.log")
local _M = {}

-- 内置 echo：读一个数据报并回给客户端
function _M.echo(rule)
    local down = ngx.req.socket()
    local data = down:receive()
    if not data then return end
    down:send(data)
end

-- 反向代理：客户端数据报 -> 后端 -> 回给客户端
function _M.proxy(rule)
    local down = ngx.req.socket()
    local data = down:receive()
    if not data then return end

    local addr, err = upstream.pick(rule)
    if not addr then
        log.err("udp_proxy[", rule.name, "] 选择后端失败: ", err)
        return
    end
    local host, port = upstream.split_addr(addr)
    if not host then
        log.err("udp_proxy[", rule.name, "] ", port)
        return
    end

    local us = ngx.socket.udp()
    us:settimeout(5000)
    local ok, e = us:setpeername(host, port)
    if not ok then
        log.err("udp_proxy[", rule.name, "] setpeername ", addr, " 失败: ", e)
        return
    end

    us:send(data)
    local reply = us:receive()
    if reply then
        down:send(reply)
    end
    us:close()
end

return _M
