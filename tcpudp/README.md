# MyResty TCP/UDP 开发框架

基于 **OpenResty（nginx `stream` + `ngx_stream_lua`）** 封装的 L4 开发框架：
用 **Lua** 编写 TCP/UDP 应用与转发逻辑，通过 **conf 文件配置网络转发**，
可打包为 **自包含部署目录（二进制 + lib + conf + lua）**。

- LuaJIT 与框架一起**编译打包**（`bin/build.sh`）
- 把已安装的 OpenResty nginx 二进制当依赖汇聚进来
- Lua 库（`.lua`）与 `.so` 统一放入 `lib/`
- 功能全部由 Lua 实现，无需写 C

---

## 目录结构

```
tcpudp/
├── bin/
│   ├── nginx            # 运行时二进制（构建时从 OpenResty 复制）
│   ├── luajit           # 构建的 LuaJIT 解释器
│   ├── build.sh         # 编译 LuaJIT + 汇集二进制/库 + 生成 conf + 组 dist
│   ├── start.sh         # 启动
│   ├── stop.sh          # 停止
│   ├── reload.sh        # 重载（含重新生成转发配置）
│   ├── status.sh        # 状态
│   ├── sync-conf.sh     # 由 conf/forward.lua 生成 stream 配置
│   └── gen-conf.lua     # 配置生成器（Lua）
├── lib/                 # Lua 库(.lua) 与 .so（构建时填充）
├── conf/
│   ├── nginx.conf       # 主配置（stream + lua_package + 引入转发配置）
│   ├── forward.lua      # ★ 用户配置：转发规则
│   └── stream.d/
│       └── forward.conf # 由 sync-conf.sh 生成，勿手改
├── lua/
│   ├── worker.lua       # init_worker_by_lua
│   ├── framework/       # 框架：config / upstream / tcp / udp / log / init
│   └── apps/            # 用户应用（示例 apps/hello.lua）
├── logs/  run/          # 运行目录
└── dist/                # 部署包（bin + lib + conf + lua）
```

---

## 快速开始

```bash
# 1) 构建（编译 LuaJIT、汇集 nginx 二进制与 Lua 库、生成配置、组装 dist）
bin/build.sh

# 2) 启动 / 停止 / 重载 / 状态
bin/start.sh
bin/status.sh
bin/reload.sh
bin/stop.sh
```

测试（默认规则见下）：

```bash
printf 'hello\n' | nc 127.0.0.1 19001     # TCP echo
nc 127.0.0.1 19005                         # 自定义 handler（先返回问候语）
python3 -c 'import socket;s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);s.settimeout(3);s.sendto(b"hi",("127.0.0.1",19003));print(s.recvfrom(100)[0])'  # UDP echo
```

---

## 配置转发（`conf/forward.lua`）

框架只认这个文件；`bin/sync-conf.sh` 会把它翻译成 nginx `stream` 的 `server` 块。

| 字段 | 必填 | 说明 |
|------|------|------|
| `name` | 是 | 规则唯一名 |
| `proto` | 否 | `"tcp"`（默认）或 `"udp"` |
| `listen` | 是 | 监听地址，如 `"0.0.0.0:19001"` |
| `upstreams` | 否 | 后端列表 `{"host:port", ...}`；配置后走负载均衡转发 |
| `handler` | 否 | 自定义 Lua 处理器模块名（优先于 upstreams） |
| `enabled` | 否 | `false` 临时停用 |

**分派优先级**：`handler` → `upstreams`（代理）→ 内置 `echo`。

示例：

```lua
return {
    { name = "tcp_echo",  proto = "tcp", listen = "0.0.0.0:19001" },
    { name = "tcp_proxy", proto = "tcp", listen = "0.0.0.0:19002",
      upstreams = { "127.0.0.1:19011", "127.0.0.1:19012" } },
    { name = "udp_echo",  proto = "udp", listen = "0.0.0.0:19003" },
    { name = "udp_proxy", proto = "udp", listen = "0.0.0.0:19004",
      upstreams = { "127.0.0.1:19014" } },
    { name = "tcp_hello", proto = "tcp", listen = "0.0.0.0:19005",
      handler = "apps.hello" },
}
```

改完执行 `bin/reload.sh` 生效。

---

## 编写自定义 Lua 应用

在 `lua/apps/` 下新建模块，提供 `run(rule)`：

```lua
-- lua/apps/myapp.lua
local _M = {}
function _M.run(rule)
    local sock = ngx.req.socket()      -- 下游连接
    sock:send("welcome\n")
    while true do
        local data, err, partial = sock:receiveany(65536)
        if not data then data = partial end
        if not data or #data == 0 then break end
        sock:send(data)
    end
end
return _M
```

在 `conf/forward.lua` 中：`handler = "apps.myapp"`。

框架内可用的能力（`ngx_stream_lua` 提供）：
- `ngx.req.socket()`：下游 TCP/UDP 套接字
- `ngx.socket.tcp()` / `ngx.socket.udp()`：上游 cosocket（支持连接池 `setkeepalive`）
- `ngx.thread.spawn/wait`：协程
- `ngx.shared.tcpudp_stats`：共享字典（框架已声明）
- `ngx.timer.at/every`、`ngx.log`、`ngx.var` 等

框架模块：
- `framework.config`：`all()` / `get(name)` / `reload()`
- `framework.upstream`：`pick(rule)`（round-robin + 失败冷却）、`split_addr`
- `framework.tcp` / `framework.udp`：`proxy(rule)` / `echo(rule)`
- `framework.log`：`info/warn/err`

---

## 构建与部署

`bin/build.sh` 做五件事：

1. **编译 LuaJIT**（默认源码 `$OPENRESTY_SRC/bundle/LuaJIT-2.1-20260415`），产出 `bin/luajit` 与 `lib/libluajit-5.1.so.2`
2. 复制 OpenResty 的 nginx 二进制到 `bin/nginx`
3. 汇集 Lua 库：`/usr/local/lualib` 的 `resty/ ngx/ rds/ redis/` 目录与 `*.lua`、`*.so` → `lib/`
4. 由 `conf/forward.lua` 生成 `conf/stream.d/forward.conf`
5. 组装 `dist/ = bin + lib + conf + lua`

可用环境变量覆盖：

```bash
OPENRESTY_HOME=/usr/local/nginx \
NGINX_BIN=/usr/local/nginx/sbin/nginx \
OPENRESTY_SRC=/opt/openresty-1.31.1.1 \
LUAJIT_SRC=/opt/openresty-1.31.1.1/bundle/LuaJIT-2.1-20260415 \
LUALIB=/usr/local/lualib \
JOBS=8 bin/build.sh

SKIP_LUAJIT=1 bin/build.sh   # 跳过编译，改为复制系统 luajit
```

**部署**：把 `dist/` 整体拷到目标机，执行 `dist/bin/start.sh`。
启动脚本会设置 `LD_LIBRARY_PATH=$ROOT/lib`，优先使用自带的 `libluajit`。

> 目标机需具备系统库：`libssl3 / libcrypto3 / libpcre2-8 / zlib / libcrypt`（nginx 的 `NEEDED`）。
> nginx 与 LuaJIT 均为 x86_64 构建，跨平台需在目标架构上重新 `build.sh`。

---

## 运行原理

```
conf/forward.lua ──(bin/sync-conf.sh)──▶ conf/stream.d/forward.conf
                                                │ include
                                                ▼
                                        conf/nginx.conf (stream)
                                                │ content_by_lua_block
                                                ▼
                        framework.handle(name) ──▶ handler / proxy / echo
```

- `init_by_lua_block` 用 `ngx.config.prefix()` 设置 `package.path/cpath`，使框架与用户代码从本目录 `lua/`、`lib/` 加载，实现自包含部署。
- 转发规则在 master 启动时预热（`framework.config`），worker 通过 fork 继承缓存。
- TCP 代理使用 `ngx.socket.tcp` cosocket + 双向中继（`ngx.thread`）；UDP 为单包请求/响应模型。

---

## 已知限制

- UDP 为**单数据报**请求/响应（`ngx_stream_lua` 的 UDP 下游每次读取一个报文）；多包会话需在 Lua 里自行处理。
- 转发规则以 `conf/forward.lua` 为唯一来源，`conf/stream.d/forward.conf` 自动生成，勿手改。
- 动态增删监听端口需改 `forward.lua` 后 `reload`（nginx 不支持运行时新增 `listen`）。
- 当前 `lua_code_cache` 默认开启，改 Lua 代码后需 `reload`。
