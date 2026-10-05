-- MyResty TCP/UDP 转发规则（用户配置）
-- 修改后执行：bin/sync-conf.sh && bin/reload.sh
--
-- 字段说明：
--   name      规则唯一名（必填，生成内容里作为 handle 参数）
--   proto     "tcp" | "udp"（默认 tcp）
--   listen    监听地址，形如 "0.0.0.0:19001"
--   upstreams 后端列表 {"host:port", ...}；配置后走内置负载均衡转发
--   handler   自定义 Lua 处理器模块名（优先于 upstreams），模块需提供 run(rule)
--   enabled   置 false 可临时停用该规则（默认 true）
--
-- 内置行为：
--   - 有 upstreams → TCP/UDP 反向代理（round-robin）
--   - 无 upstreams 且无 handler → TCP/UDP 回显（echo）
--   - 有 handler → 调用 handler.run(rule)
return {
    -- TCP 回显（内置 echo），telnet/nc 直连验证
    { name = "tcp_echo", proto = "tcp", listen = "0.0.0.0:19001" },

    -- TCP 反向代理：轮询转发到两个后端
    { name = "tcp_proxy", proto = "tcp", listen = "0.0.0.0:19002",
      upstreams = { "127.0.0.1:19011", "127.0.0.1:19012" } },

    -- UDP 回显（内置 udp echo）
    { name = "udp_echo", proto = "udp", listen = "0.0.0.0:19003" },

    -- UDP 反向代理
    { name = "udp_proxy", proto = "udp", listen = "0.0.0.0:19004",
      upstreams = { "127.0.0.1:19014" } },

    -- 自定义 Lua 应用示例（见 lua/apps/hello.lua）
    { name = "tcp_hello", proto = "tcp", listen = "0.0.0.0:19005",
      handler = "apps.hello" },
}
