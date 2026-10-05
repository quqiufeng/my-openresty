-- TCP 传输：echo 与反向代理（cosocket 双向中继）
local upstream = require("framework.upstream")
local log = require("framework.log")
local _M = {}

local RECV = 65536

local function relay(src, dst)
    while true do
        local data, err, partial = src:receiveany(RECV)
        if not data then data = partial end
        if not data or #data == 0 then
            return
        end
        local ok = dst:send(data)
        if not ok then
            return
        end
    end
end

-- 内置 echo
function _M.echo(rule)
    local down = ngx.req.socket()
    while true do
        local data, err, partial = down:receiveany(RECV)
        if not data then data = partial end
        if not data or #data == 0 then break end
        down:send(data)
    end
end

-- 反向代理：客户端 <-> 后端 双向中继
function _M.proxy(rule)
    local down = ngx.req.socket()

    local addr, err = upstream.pick(rule)
    if not addr then
        log.err("tcp_proxy[", rule.name, "] 选择后端失败: ", err)
        return
    end
    local host, port = upstream.split_addr(addr)
    if not host then
        log.err("tcp_proxy[", rule.name, "] ", port)
        return
    end
    log.info("tcp_proxy[", rule.name, "] -> ", addr)

    local us = ngx.socket.tcp()
    us:settimeouts(60000, 60000, 60000)

    local ok, cerr = us:connect(host, port)
    if not ok then
        upstream.mark_down(rule, addr)
        log.err("tcp_proxy[", rule.name, "] 连接 ", addr, " 失败: ", cerr)
        return
    end

    local t1 = ngx.thread.spawn(function() relay(down, us) end)
    local t2 = ngx.thread.spawn(function() relay(us, down) end)

    -- 任一方向结束即关闭双方，唤醒另一方向
    ngx.thread.wait(t1, t2)
    us:close()
    pcall(function() down:close() end)
    pcall(ngx.thread.wait, t1, t2)
end

return _M
