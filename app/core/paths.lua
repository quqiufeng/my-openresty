-- 运行时根路径解析：优先 nginx 前缀（-p），其次环境变量，最后兼容旧绝对路径。
-- 使应用可自包含部署到任意目录。
local _M = {}

local function detect()
    -- OpenResty: ngx.config.prefix() 返回 -p 指定的前缀（通常以 / 结尾）
    local ok, ngx = pcall(function() return rawget(_G, "ngx") end)
    if ok and ngx and ngx.config and ngx.config.prefix then
        local p = ngx.config.prefix()
        if p and p ~= "" then
            if p:sub(-1) == "/" then p = p:sub(1, -2) end
            if p ~= "" then return p end
        end
    end
    return os.getenv("MYRESTY_ROOT") or "/var/www/web/my-openresty"
end

local ROOT = detect()

function _M.root()
    return ROOT
end

-- 拼接 root 下的相对路径（不自动加多余斜杠）
function _M.path(...)
    local parts = { ... }
    return ROOT .. "/" .. table.concat(parts, "/")
end

return _M
