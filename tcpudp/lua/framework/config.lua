-- 转发规则加载器：读取并缓存 conf/forward.lua
-- 在 init_by_lua（master）阶段预热，worker 通过 fork 继承缓存。
local _M = {}

local rules   -- 数组
local by_name -- name -> rule

local function forward_path()
    local root = ngx.config.prefix()
    if root:sub(-1) ~= "/" then root = root .. "/" end
    return root .. "conf/forward.lua"
end

local function load()
    if by_name then return end
    local path = forward_path()
    local chunk, err = loadfile(path)
    if not chunk then
        error("加载转发配置失败 " .. path .. ": " .. tostring(err))
    end
    local ok, data = pcall(chunk)
    if not ok then
        error("执行转发配置失败 " .. path .. ": " .. tostring(data))
    end
    if type(data) ~= "table" then
        error("conf/forward.lua 必须返回 table")
    end

    rules = data
    by_name = {}
    for i, r in ipairs(rules) do
        if type(r) ~= "table" or not r.name then
            error("forward.lua 第 " .. i .. " 项缺少 name 字段")
        end
        by_name[r.name] = r
    end
end

function _M.all()
    load()
    return rules
end

function _M.get(name)
    load()
    return by_name[name]
end

function _M.reload()
    by_name = nil
    rules = nil
    load()
end

return _M
