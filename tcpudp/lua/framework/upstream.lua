-- 后端选择：round-robin + 失败冷却（基于 lua_shared_dict tcpudp_stats）
local shd = ngx.shared.tcpudp_stats
local _M = {}

-- "host:port" -> host, port
function _M.split_addr(addr)
    local host, port = tostring(addr):match("^(.-):(%d+)$")
    if not host then
        return nil, "非法地址: " .. tostring(addr)
    end
    return host, tonumber(port)
end

-- 轮询选择后端；跳过处于冷却期的后端
function _M.pick(rule)
    local ups = rule.upstreams
    if not ups or #ups == 0 then
        return nil, "该规则未配置 upstreams"
    end
    local n = #ups
    local now = ngx.now()

    for _ = 1, n do
        local c = shd:incr("rr:" .. rule.name, 1, 0)
        local idx = ((c - 1) % n) + 1
        local addr = ups[idx]
        local until_ts = shd:get("down:" .. rule.name .. ":" .. addr)
        if not until_ts or until_ts <= now then
            return addr, idx
        end
    end
    -- 全部冷却中，兜底返回第一个
    return ups[1], 1
end

function _M.mark_down(rule, addr, ttl)
    ttl = ttl or 5
    shd:set("down:" .. rule.name .. ":" .. addr, ngx.now() + ttl, ttl + 1)
end

function _M.mark_up(rule, addr)
    shd:delete("down:" .. rule.name .. ":" .. addr)
end

return _M
