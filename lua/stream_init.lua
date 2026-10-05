-- stream(子)系统初始化：设置 package.path/cpath 并预热转发配置。
-- 由 stream{} 的 init_by_lua_file 调用（相对 nginx 前缀）。
local root = ngx.config.prefix()
if root:sub(-1) ~= "/" then root = root .. "/" end

package.path = table.concat({
    root .. "lua/?.lua",
    root .. "lua/?/init.lua",
    root .. "lib/?.lua",
    root .. "lib/?/init.lua",
    root .. "?.lua",
    root .. "?/init.lua",
    package.path,
}, ";")
package.cpath = root .. "lib/?.so;" .. package.cpath

-- 预热转发规则（出错在启动期暴露）
require("framework.config").all()
