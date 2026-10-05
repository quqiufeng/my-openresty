-- 框架入口：按规则名分派到 handler / proxy / echo
local config = require("framework.config")
local log = require("framework.log")
local _M = {}

local function dispatch(rule)
    local proto = rule.proto or "tcp"

    if rule.handler then
        local mod = require(rule.handler)
        if type(mod) == "table" and mod.run then
            return mod.run(rule)
        elseif type(mod) == "function" then
            return mod(rule)
        end
        error("handler " .. rule.handler .. " 缺少 run(rule)")
    end

    local transport = require("framework." .. proto)
    if rule.upstreams and #rule.upstreams > 0 then
        return transport.proxy(rule)
    end
    return transport.echo(rule)
end

function _M.handle(name)
    local rule = config.get(name)
    if not rule then
        log.err("未知转发规则: ", tostring(name))
        return
    end
    if rule.enabled == false then
        return
    end
    local ok, err = pcall(dispatch, rule)
    if not ok then
        log.err("规则 ", name, " 处理异常: ", err)
    end
end

return _M
