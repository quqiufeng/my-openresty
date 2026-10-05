# OpenResty 源码级架构报告

> 基于源码与语义检索（MyResty code search）对 OpenResty 1.31.1.1 的架构梳理。
> 源码路径：`/opt/openresty-1.31.1.1`　检索缓存：`/opt/code_caches/openresty_cache`（35483 chunks）
> 生成日期：2026-10-05

---

## 1. 项目概览

OpenResty 不是单一程序，而是一个**打包发行版**：把打了补丁的 nginx、LuaJIT、`ngx_lua` 及一系列开源 nginx/Lua 模块组合成一个可直接构建的源码树。

| 组件 | 版本 | 说明 |
|------|------|------|
| OpenResty | 1.31.1.1 | 发行版自身版本 |
| nginx | **1.31.1**（`nginx_version 1031001`） | `bundle/nginx-1.31.1`，含补丁 |
| LuaJIT | 2.1-20260415 | `bundle/LuaJIT-2.1-20260415` |
| ngx_lua (lua-nginx-module) | 0.10.31rc5 | `bundle/ngx_lua-0.10.31rc5`，67 个 `.c`、约 6.0 万行 C |
| ngx_stream_lua | 0.0.19rc4 | `bundle/ngx_stream_lua-0.0.19rc4`，约 4.2 万行 C（L4 TCP/UDP） |
| lua-resty-core | 0.1.34rc3 | 用 FFI 重写核心 API（性能） |
| lua-resty-* | 16 个库 | redis/mysql/dns/lock/lrucache/websocket… |
| lua-cjson | 2.1.0.17 | JSON 编解码 |
| ngx_devel_kit (NDK) | 0.3.4 | 众多第三方模块的依赖 |

顶层目录：

```
/opt/openresty-1.31.1.1
├── configure        # OpenResty 构建入口（包装 nginx 的 configure）
├── Makefile         # 构建/安装编排
├── bundle/          # 各组件源码（nginx、LuaJIT、ngx_lua、lua-resty-*…）
├── build/           # configure 展开后的构建目录（47 个组件）
├── patches/         # 对 nginx 等打的补丁
└── util/            # 杂项脚本
```

---

## 2. 整体分层架构

```
┌───────────────────────────────────────────────────────────────────────┐
│ L7 应用层        my-openresty / OpenResty 应用（Lua 业务）              │
├───────────────────────────────────────────────────────────────────────┤
│ L6 Lua 库层      lua-resty-core / -redis / -mysql / -lock / -dns …     │
├───────────────────────────────────────────────────────────────────────┤
│ L5 Lua 运行时    ngx_lua(HTTP) / ngx_stream_lua(L4)  ←→  LuaJIT 2.1     │
├───────────────────────────────────────────────────────────────────────┤
│ L4 第三方模块    echo / headers-more / set-misc / srcache / xss / …    │
├───────────────────────────────────────────────────────────────────────┤
│ L3 子系统        HTTP(含 v2/v3) │ STREAM │ MAIL                          │
├───────────────────────────────────────────────────────────────────────┤
│ L2 事件层        event 抽象 + 模块(epoll/kqueue/select/poll/iocp)       │
├───────────────────────────────────────────────────────────────────────┤
│ L1 核心层        core：模块系统 / cycle / 配置 / 内存池 / slab / 容器    │
├───────────────────────────────────────────────────────────────────────┤
│ L0 系统层        os/unix（linux/自由 BSD/macos…）· os/win32              │
└───────────────────────────────────────────────────────────────────────┘
```

nginx 源码规模（`.c`+`.h` 行数）印证了分层：

| 目录 | 文件 | 行数 | 职责 |
|------|------|------|------|
| `src/core` | 76 | 32,703 | 模块系统、cycle、配置、内存池、slab、容器、日志、字符串 |
| `src/event` | 60 | 16,991 | 事件抽象、定时器、连接、accept、epoll/kqueue 无关层 |
| `src/event/modules` | 10 | 5,078 | epoll / kqueue / select / poll / iocp 具体实现 |
| `src/http` | 110 | 40,470 | HTTP 核心、phase 引擎、upstream、proxy、cache |
| `src/http/modules` | 64 | 68,477 | 内置 HTTP 模块（gzip、rewrite、proxy、fastcgi…共 59 个 `.c`） |
| `src/http/v2` / `v3` | 7 / 13 | 8,228 / 7,351 | HTTP/2、HTTP/3 |
| `src/stream` | 33 | 24,798 | L4 流处理（TCP/UDP 代理、balancer） |
| `src/os/unix` / `win32` | 65 / 34 | 10,845 / 6,149 | 平台适配 |

---

## 3. nginx 模块系统（L1 核心）

nginx 的一切都是模块。核心数据结构 `ngx_module_t`（`src/core/ngx_module.h:227`）：

```c
struct ngx_module_s {
    ngx_uint_t   ctx_index, index;
    char        *name;
    ngx_uint_t   version;
    const char  *signature;   // 编译期 ABI 签名，防模块二进制不兼容
    void        *ctx;         // 指向模块类型专属 context
    ngx_command_t *commands;  // 配置指令表
    ngx_uint_t   type;        // NGX_CORE_MODULE / NGX_HTTP_MODULE / NGX_STREAM_MODULE …

    ngx_int_t (*init_master)(ngx_log_t *);
    ngx_int_t (*init_module)(ngx_cycle_t *);
    ngx_int_t (*init_process)(ngx_cycle_t *);
    ngx_int_t (*init_thread)(ngx_cycle_t *);
    void      (*exit_thread)(ngx_cycle_t *);
    void      (*exit_process)(ngx_cycle_t *);
    void      (*exit_master)(ngx_cycle_t *);
    uintptr_t  spare_hook0..7; // 保留位，向后兼容
};
```

- 每个模块用 `NGX_MODULE_V1` 初始化公共头部（`ngx_module.h:220`），末尾 `NGX_MODULE_V1_PADDING`。
- `NGX_MODULE_SIGNATURE_*`（`ngx_module.h:21-217`）把 35 个编译期特性编码成字符串，`nginx -V` 会显示 `--build=`；动态模块加载时校验，避免 ABI 错配。
- 核心模块 context 为 `ngx_core_module_t`（`ngx_module.h:265`），只有 `create_conf` / `init_conf` 两个回调——这是 nginx “声明式配置”的入口。

模块生命周期钩子按阶段调用：
`init_master` →（fork 前）→ `init_module`（每个 cycle，含 reload）→ `init_process`（每个 worker）→ `exit_process` → `exit_master`。

---

## 4. 启动与配置生命周期

核心函数 `ngx_init_cycle()`（`src/core/ngx_cycle.c:39`）在启动和每次 reload 时执行，产出 `ngx_cycle_t`（`src/core/ngx_cycle.h`）：

```c
struct ngx_cycle_s {
    void         ****conf_ctx;     // 配置上下文：module_index → (http|stream|core)-module_index → conf
    ngx_pool_t    *pool;
    ngx_log_t     *log;
    ngx_connection_t **files;
    ngx_connection_t  *free_connections;   // 连接池空闲链表
    ngx_uint_t         free_connection_n;
    ngx_module_t **modules; ngx_uint_t modules_n;
    ngx_array_t    listening;
    ngx_list_t     open_files;
    ngx_list_t     shared_memory;          // lua_shared_dict 等共享内存段
    ngx_cycle_t   *old_cycle;              // reload 时指向旧 cycle（平滑升级）
    ...
};
```

流程要点：
1. **解析配置**：`conf_ctx` 是四层指针数组，按 “模块类型 → 模块序号” 定位各模块解析出的配置。
2. **共享内存**：`lua_shared_dict` / `upstream zone` 等在 `shared_memory` 列表中统一创建；reload 时若 tag 相同可复用（`ngx_shm_zone_t`，`ngx_cycle.h:38`）。
3. **平滑升级**：新 cycle 建好后，worker 逐个切换，`old_cycle` 保证旧连接不断。
4. **每 worker 初始化**：`ngx_worker_process_init()`（`src/os/unix/ngx_process_cycle.c:825`）创建连接池、初始化事件模块、调用模块 `init_process`。

---

## 5. 事件与进程模型（L2 事件层）

### 5.1 事件抽象

事件层通过一组函数指针屏蔽 epoll/kqueue/select 差异（`src/event/ngx_event.h:169`）：

```c
typedef struct {
    ngx_int_t (*add)(ngx_event_t *ev, ngx_int_t event, ngx_uint_t flags);
    ngx_int_t (*del)(ngx_event_t *ev, ngx_int_t event, ngx_uint_t flags);
    ngx_int_t (*enable)(ngx_event_t *ev, ngx_int_t event, ngx_uint_t flags);
    ngx_int_t (*disable)(ngx_event_t *ev, ngx_int_t event, ngx_uint_t flags);
    ngx_int_t (*add_conn)(ngx_connection_t *c);
    ngx_int_t (*del_conn)(ngx_connection_t *c, ngx_uint_t flags);
    ngx_int_t (*notify)(ngx_event_handler_pt handler);
    ngx_int_t (*process_events)(ngx_cycle_t *, ngx_msec_t timer, ngx_uint_t flags);
    ngx_int_t (*init)(ngx_cycle_t *, ngx_msec_t timer);
    void      (*done)(ngx_cycle_t *);
} ngx_event_actions_t;
```

- 具体实现：`ngx_epoll_module.c` / `ngx_kqueue_module.c` / `ngx_select_module.c` / `ngx_poll_module.c` / `ngx_iocp_module.c`（`src/event/modules`）。
- 事件模型标志：`NGX_USE_LEVEL_EVENT` / `NGX_USE_ONESHOT_EVENT` / `NGX_USE_CLEAR_EVENT` / `NGX_USE_KQUEUE_EVENT`（`ngx_event.h:190+`）。
- **定时器**用红黑树实现：`ngx_event_timer_init` / `ngx_event_add_timer` / `ngx_event_del_timer`（`src/event/ngx_event_timer.{c,h}`），`ngx_event_find_timer` 取最近超时。
- **连接建立**：`ngx_event_accept`（`src/event/ngx_event_accept.c:21`）被 epoll/kqueue 分发共同调用；每次 accept 限量（防惊群/饥饿），失败走 accept mutex 或延迟。

### 5.2 进程模型

- **Master/Worker**：master 负责监听、fork worker、处理信号；worker 跑事件循环。`ngx_signal_worker_processes`（`src/os/unix/ngx_process_cycle.c:499`）分发信号给 worker。
- **连接池**：`ngx_cycle_t.free_connections` 预分配 `worker_connections` 数量；`ngx_get_connection` 领取、`ngx_free_connection` 归还。
- **Cache Manager / Loader**：proxy cache 由独立进程管理。
- **accept mutex**：多 worker 下用共享内存原子/文件锁避免惊群。

---

## 6. HTTP 子系统（L3）

### 6.1 Phase 引擎（请求管线）

nginx 把请求处理拆成**固定 11 个阶段**（`src/http/ngx_http_core_module.h:111`）：

| # | 阶段 | 说明 |
|---|------|------|
| 0 | `NGX_HTTP_POST_READ_PHASE` | 读完请求头后 |
| 1 | `NGX_HTTP_SERVER_REWRITE_PHASE` | server 级 rewrite |
| 2 | `NGX_HTTP_FIND_CONFIG_PHASE` | 按 URI 选 location（特殊，不可挂 handler） |
| 3 | `NGX_HTTP_REWRITE_PHASE` | location 级 rewrite |
| 4 | `NGX_HTTP_POST_REWRITE_PHASE` | rewrite 后（特殊，可能内部跳转） |
| 5 | `NGX_HTTP_PREACCESS_PHASE` | 访问前（limit_conn/limit_req） |
| 6 | `NGX_HTTP_ACCESS_PHASE` | 访问控制（access/auth） |
| 7 | `NGX_HTTP_POST_ACCESS_PHASE` | 访问后（特殊） |
| 8 | `NGX_HTTP_PRECONTENT_PHASE` | content 前（try_files/mirror） |
| 9 | `NGX_HTTP_CONTENT_PHASE` | 生成响应（index/autoindex/proxy/ngx_lua content） |
| 10 | `NGX_HTTP_LOG_PHASE` | 日志 |

阶段表在配置期被“编译”成线性 handler 数组：

```c
/* ngx_http_core_module.h:136 */
struct ngx_http_phase_handler_s {
    ngx_http_phase_handler_pt  checker;   // 阶段调度器
    ngx_http_handler_pt        handler;   // 实际 handler（可空）
    ngx_uint_t                 next;      // 下一阶段索引
};
typedef struct {               /* ngx_http_core_module.h:143 */
    ngx_http_phase_handler_t  *handlers;
    ngx_uint_t  server_rewrite_index;
    ngx_uint_t  location_rewrite_index;
} ngx_http_phase_engine_t;
```

- 装配：`ngx_http_init_phase_handlers()`（`src/http/ngx_http.c:455`）把所有模块注册到各阶段的 handler 拉平为数组。
- 执行：`ngx_http_core_run_phases()`（`src/http/ngx_http_core_module.c:894`）：

```c
ph = cmcf->phase_engine.handlers;
while (ph[r->phase_handler].checker) {
    rc = ph[r->phase_handler].checker(r, &ph[r->phase_handler]);
    if (rc == NGX_OK) return;   // 交给异步，稍后从断点继续
}
```

这是 nginx “**同步写法、异步执行**”的关键：handler 返回 `NGX_AGAIN` 时会挂起，事件就绪后由 `r->write_event_handler`（`ngx_http_request_handler`，`ngx_http_request.c:2577`）重新驱动管线。

### 6.2 请求入口

- `ngx_http_wait_request_handler`（`src/http/ngx_http_request.c:376`）：连接可读，解析请求行/头。
- `ngx_http_process_request` → 初始化 `ngx_http_request_t` 并进入 `ngx_http_core_run_phases`。
- `ngx_http_request_t` 携带：`pool`、`connection`、`headers_in/out`、`phase_handler`、`write_event_handler`、`subrequests`、`count`、`main`（子请求指向父）等。

### 6.3 Upstream 与负载均衡

- 抽象：`ngx_http_upstream_t` + peer 接口。
- Round-robin 是所有算法基础：`ngx_http_upstream_init_round_robin_peer`（`src/http/ngx_http_upstream_round_robin.c:539`）、`ngx_http_upstream_create_round_robin_peer`（:602）。
- Stream 侧对应：`ngx_stream_upstream_get_round_robin_peer`（`src/stream/ngx_stream_upstream_round_robin.c:608`）。
- 动态后端（`server` 指令 + resolver）与 zone 共享内存、健康检查（`lua-resty-upstream-healthcheck`）配合。

### 6.4 输出过滤链

- `ngx_http_output_header_filter_pt` / `body_filter_pt`（`src/http/ngx_http_core_module.h:530`）形成链表；各模块（gzip、chunked、headers-more、ngx_lua）用 `ngx_http_next_header_filter` 串联。
- 缓冲区用 **chain（`ngx_chain_t`）+ buffer（`ngx_buf_t`）** 组织，零拷贝发送。

---

## 7. Stream 子系统（L4 网关）

`src/stream` 让 nginx 直接处理 TCP/UDP，是 OpenResty 做网关/四层代理的基础。

- 阶段：`post_accept` → `preread` →（`ssl`）→ `balancer` → `content`，与 HTTP 类似但更短。
- 运行时用 Lua：`ngx_stream_lua` 提供
  - `preread_by_lua_file` / `preread_by_lua_block`（`ngx_stream_lua_module.c:243/252`）——协议嗅探/预读分流
  - `content_by_lua` / `_block` / `_file`（`:261/269/277`）——自定义 L4 处理/转发
  - `balancer_by_lua_block` / `_file`（`:310/317`）——动态负载均衡
- 实现：`ngx_stream_lua_balancer_handler_file/inline`（`ngx_stream_lua_balancer.c:77/97`）、`ngx_stream_lua_balancer_get_peer`（`:297`）。
- 与 HTTP 侧共享：LuaJIT VM、cosocket、shared dict、timer。

---

## 8. 内存管理

OpenResty/nginx 有两条独立内存路径：

### 8.1 请求级内存池 `ngx_pool_t`

```c
/* src/core/ngx_palloc.h */
struct ngx_pool_s {
    ngx_pool_data_t     d;        // 当前块的头（last/end/failed）
    size_t              max;      // 小分配阈值
    ngx_pool_t         *current;  // 当前块（链表）
    ngx_chain_t        *chain;    // 池上分配的 chain 空闲链
    ngx_pool_large_t   *large;    // 大块分配（> max）
    ngx_pool_cleanup_t *cleanup;  // 清理回调（释放 fd、句柄…）
    ngx_log_t          *log;
};
```

- 接口：`ngx_palloc` / `ngx_pnalloc` / `ngx_pcalloc` / `ngx_pfree`（`ngx_palloc.c:278`）；大块走 `ngx_palloc_large`（:214）。
- 生命周期：请求结束 `ngx_destroy_pool` 一次性释放；`ngx_reset_pool` 复用。
- `ngx_pool_cleanup_add`（:312）注册析构（如关闭连接、释放 lua 线程）。

### 8.2 共享内存 slab `ngx_slab_pool_t`

```c
/* src/core/ngx_slab.h */
typedef struct {
    ngx_shmtx_sh_t    lock;
    size_t            min_size, min_shift;
    ngx_slab_page_t  *pages, *last, free;
    ngx_slab_stat_t  *stats;
    ngx_uint_t        pfree;
    u_char           *start, *end;
    ngx_shmtx_t       mutex;
    ...
} ngx_slab_pool_t;
```

- `ngx_slab_init`（`ngx_slab.c:99`）、`ngx_slab_alloc`（:169）、`ngx_slab_calloc`（:421）。
- 用途：`lua_shared_dict`、upstream zone、SSL session cache、limit_req/conn 状态等跨 worker 共享数据。

---

## 9. Lua 集成架构（ngx_lua）—— 本报告重点

### 9.1 模块注册与钩子

`ngx_http_lua_module`（`ngx_lua/src/ngx_http_lua_module.c:823`）是一个标准 `NGX_HTTP_MODULE`：

```c
static ngx_http_module_t ngx_http_lua_module_ctx = {
    NULL,                           /* preconfiguration */
    ngx_http_lua_init,              /* postconfiguration —— 注册各阶段 handler */
    ngx_http_lua_create_main_conf,  ngx_http_lua_init_main_conf,
    ngx_http_lua_create_srv_conf,   ngx_http_lua_merge_srv_conf,
    ngx_http_lua_create_loc_conf,   ngx_http_lua_merge_loc_conf
};
ngx_module_t ngx_http_lua_module = {
    NGX_MODULE_V1, &ngx_http_lua_module_ctx, ngx_http_lua_cmds,
    NGX_HTTP_MODULE,
    NULL, NULL,
    ngx_http_lua_init_worker,       /* init process */
    NULL, NULL,
    ngx_http_lua_exit_worker,       /* exit process */
    NULL, NGX_MODULE_V1_PADDING
};
```

- **指令数**：`ngx_http_lua_cmds` 约 **95** 条 `ngx_string(...)`（如 `content_by_lua*`、`rewrite_by_lua*`、`access_by_lua*`、`header_filter_by_lua*`、`body_filter_by_lua*`、`log_by_lua*`、`init_by_lua*`、`init_worker_by_lua*`、`balancer_by_lua*`、`ssl_*_by_lua*` 等）。
- **阶段注册**（`ngx_http_lua_init`，`ngx_http_lua_module.c:894-932`）：把 Lua handler 塞进
  `SERVER_REWRITE` / `REWRITE` / `ACCESS` / `PRECONTENT` / `LOG` 阶段的 `cmcf->phases[...] .handlers` 数组；
  `content_by_lua` 走 `CONTENT` 阶段（`ngx_http_lua_contentby.c`），`header/body_filter_by_lua` 走输出过滤链。
- **每请求/每 worker/每进程**：
  - `init_by_lua*` → master 启动时在 `ngx_http_lua_init` 里预建 Lua VM（配置只读阶段）
  - `init_worker_by_lua*` → worker `init_process`（`ngx_http_lua_init_worker`）
  - 请求级：`content/rewrite/access/..._by_lua` 各自 `*by.c`

### 9.2 请求上下文与协程模型

`ngx_http_lua_ctx_t`（`ngx_lua/src/ngx_http_lua_common.h`）挂在请求上，核心字段：

```c
typedef struct ngx_http_lua_ctx_s {
    ngx_http_request_t      *request;
    ngx_http_handler_pt      resume_handler;   // 协程让出后由谁恢复
    ngx_http_lua_co_ctx_t   *cur_co_ctx;       // 当前协程上下文
    ngx_list_t              *user_co_ctx;      // 用户协程（ngx.thread）
    ngx_http_lua_co_ctx_t    entry_co_ctx;     // 入口协程
    ngx_chain_t             *out;              // HTTP/1.0 缓冲输出链
    ngx_chain_t             *filter_in_bufs, *filter_busy_bufs; // body filter
    ngx_http_cleanup_t      *free_cleanup;
    ngx_int_t                exit_code;
    void                    *downstream;       // socket upstream 或 co_ctx
    ngx_http_lua_posted_thread_t *posted_threads;
    int                      uthreads;         // 活跃用户线程数（ngx.thread）
    uint32_t                 context;          // 当前运行阶段/指令上下文
    unsigned                 waiting_more_body:1;
    unsigned                 exited:1, eof:1, capture:1, ...;
} ngx_http_lua_ctx_t;
```

协程让出/恢复：
- `ngx_http_lua_coroutine_yield`（`ngx_lua/src/ngx_http_lua_coroutine.c:245`）——Lua 代码里遇到阻塞 I/O 时 `yield`；
- nginx 事件就绪后，通过 `resume_handler` 把协程 `resume` 回来继续执行。
这样 Lua 里可以写“同步阻塞”风格代码，底层却是非阻塞的。

### 9.3 Cosocket（核心机制）

cosocket = coroutine + socket，是 Lua 侧访问网络/MySQL/Redis 的基石：

- 实现文件 `ngx_http_lua_socket_tcp.c`，关键函数：
  - `ngx_http_lua_socket_tcp_connect`（:24）——异步连接/域名解析
  - `ngx_http_lua_socket_tcp_receive` / `receiveany`（:30/31）——异步收
  - `..._resolve_handler`——DNS 解析回调
  - `..._setkeepalive`（:5612）——**连接池**：把连接放回 pool，供后续请求复用（对应 `lua-resty-mysql/redis` 的 `set_keepalive`）
- 数据结构 `ngx_http_lua_socket_tcp_upstream_t` 描述一次“upstream 连接状态机”。
- stream 侧同构实现：`ngx_stream_lua_socket_tcp_setkeepalive`（`ngx_stream_lua-0.0.19rc4/.../ngx_stream_lua_socket_tcp.c:6033`）。
- 与 nginx 事件层直接对接：内部使用 `ngx_event_t` 读写事件 + 定时器做超时。

### 9.4 Shared Dict

- `ngx_http_lua_shared_dict_get`（`ngx_lua/src/ngx_http_lua_shdict.c:586`）等在 slab 共享内存上实现 `ngx.shared.DICT`。
- 提供 `get/set/add/replace/incr/ttl/flush_all` 等，跨 worker 共享；配合 `lua-resty-lock` 做分布式锁。

### 9.5 子请求 / 定时器 / 输出过滤

- **子请求**：`ngx_http_lua_subrequest`（`ngx_lua/src/ngx_http_lua_subrequest.c:1372`）、`ngx_http_lua_inject_subrequest_api`（:1357）——`ngx.location.capture` 实现，用于内部接口聚合。
- **定时器**：`ngx.timer.at/every` → stream 侧 `ngx_stream_lua_ngx_timer_at/every`（`ngx_stream_lua_timer.c:124/135`）；HTTP 侧通过 `posted_threads` 在 event loop 外跑“用户线程”。
- **输出过滤**：`header_filter_by_lua` / `body_filter_by_lua`（`ngx_http_lua_headerfilterby.c` / `ngx_http_lua_bodyfilterby.c`）接入 nginx 输出过滤链。
- **SSL**：`ssl_certificate_by_lua` / `ssl_session_*_by_lua` 等（`ngx_http_lua_ssl_*.c`）。

---

## 10. 第三方 nginx 模块与 Lua 库清单

### 10.1 第三方 nginx 模块（bundle）

| 模块 | 作用 |
|------|------|
| `ngx_devel_kit` (NDK) | 通用开发工具集，多数扩展模块依赖 |
| `echo-nginx-module` | 调试/赋值/`echo` 类指令 |
| `headers-more-nginx-module` | 精细操作请求/响应头 |
| `set-misc-nginx-module` | `set_*` 变量（md5/sha1/escape…） |
| `encrypted-session-nginx-module` | 加密会话 |
| `form-input-nginx-module` | 表单解析 |
| `srcache-nginx-module` | 子请求缓存层 |
| `memc-nginx-module` / `redis2` / `redis` / `drizzle` / `postgres` | 外部数据源接入 |
| `rds-csv` / `rds-json` | 结构化输出 |
| `xss-nginx-module` | XSS 防护 |
| `iconv-nginx-module` | 编码转换 |
| `array-var-nginx-module` / `ngx_coolkit` | 辅助 |
| `ngx_lua_upstream` | Lua 访问 upstream 信息 |
| `ngx_postgres` | Lua/Postgres 桥接 |

### 10.2 lua-resty-* 库

| 库 | 作用 |
|----|------|
| `lua-resty-core` | 用 FFI 重写核心 API（性能关键） |
| `lua-resty-lrucache` | LRU 缓存（供 core 等使用） |
| `lua-resty-lock` | 基于 shared dict 的锁 |
| `lua-resty-dns` | 异步 DNS 解析 |
| `lua-resty-mysql` / `-redis` / `-memcached` | 数据库/缓存客户端（cosocket） |
| `lua-resty-websocket` | WebSocket |
| `lua-resty-upload` | multipart 上传解析 |
| `lua-resty-string` | 字符串/哈希/AES |
| `lua-resty-openssl` / `-rsa` | 加密/证书 |
| `lua-resty-shell` / `-signal` | 子进程/信号 |
| `lua-resty-limit-traffic` | 限流（req/conn/count） |
| `lua-resty-upstream-healthcheck` | upstream 健康检查 |
| `lua-tablepool` | table 对象池（LuaJIT 性能） |
| `lua-cjson` | JSON |

---

## 11. 关键源码索引（file:line）

| 主题 | 位置 |
|------|------|
| 模块结构体 | `nginx/src/core/ngx_module.h:227` |
| 模块 ABI 签名 | `nginx/src/core/ngx_module.h:21` |
| core 模块 context | `nginx/src/core/ngx_module.h:265` |
| cycle 结构 | `nginx/src/core/ngx_cycle.h:47` |
| cycle 初始化 | `nginx/src/core/ngx_cycle.c:39` |
| worker 初始化 | `nginx/src/os/unix/ngx_process_cycle.c:825` |
| 事件抽象 | `nginx/src/event/ngx_event.h:169` |
| 定时器 | `nginx/src/event/ngx_event_timer.{c,h}` |
| accept | `nginx/src/event/ngx_event_accept.c:21` |
| 阶段枚举 | `nginx/src/http/ngx_http_core_module.h:111` |
| 阶段 handler 结构 | `nginx/src/http/ngx_http_core_module.h:136` |
| 阶段装配 | `nginx/src/http/ngx_http.c:455` |
| 阶段执行 | `nginx/src/http/ngx_http_core_module.c:894` |
| 请求读处理 | `nginx/src/http/ngx_http_request.c:376` |
| 请求事件驱动 | `nginx/src/http/ngx_http_request.c:2577` |
| upstream round-robin | `nginx/src/http/ngx_http_upstream_round_robin.c:539` |
| 输出过滤指针 | `nginx/src/http/ngx_http_core_module.h:530` |
| stream round-robin | `nginx/src/stream/ngx_stream_upstream_round_robin.c:608` |
| 内存池 | `nginx/src/core/ngx_palloc.h` / `.c:214,278,312` |
| slab 共享内存 | `nginx/src/core/ngx_slab.c:99,169,421` |
| ngx_lua 模块定义 | `ngx_lua/src/ngx_http_lua_module.c:823` |
| ngx_lua 阶段注册 | `ngx_lua/src/ngx_http_lua_module.c:894-932` |
| ngx_lua 请求 ctx | `ngx_lua/src/ngx_http_lua_common.h`（`ngx_http_lua_ctx_t`） |
| 协程 yield | `ngx_lua/src/ngx_http_lua_coroutine.c:245` |
| cosocket connect | `ngx_lua/src/ngx_http_lua_socket_tcp.c:24` |
| cosocket keepalive | `ngx_lua/src/ngx_http_lua_socket_tcp.c:5612` |
| shared dict | `ngx_lua/src/ngx_http_lua_shdict.c:586` |
| 子请求 capture | `ngx_lua/src/ngx_http_lua_subrequest.c:1372` |
| stream_lua 指令 | `ngx_stream_lua/src/ngx_stream_lua_module.c:110` |
| stream_lua balancer | `ngx_stream_lua/src/ngx_stream_lua_balancer.c:77,297` |
| stream_lua timer | `ngx_stream_lua/src/ngx_stream_lua_timer.c:124,135` |

---

## 12. 语义检索证据（code search）

命令：`./ai_code_search.sh search /opt/code_caches/openresty_cache "<query>" 2`

| 查询 | Top 命中 | 分数 |
|------|----------|------|
| HTTP request processing phases handler | `ngx_http_request_handler` | 0.85 |
| http phase engine checker handler array | `ngx_http_init_phase_handlers` | 0.99 |
| master worker process fork signal | `ngx_signal_worker_processes` | 0.94 |
| event module add event del event | `ngx_del_event` | 1.00 |
| memory pool palloc pfree large | `ngx_pfree` | 0.95 |
| shared dictionary slab allocator | `ngx_slab_alloc` | 0.79 |
| upstream load balancing round robin peer | `ngx_http_upstream_init_round_robin_peer` | 1.00 |
| lua cosocket connection pool keepalive | `ngx_stream_lua_socket_tcp_setkeepalive` | 0.94 |
| lua coroutine yield resume request ctx | `ngx_http_lua_coroutine_yield` | 0.97 |
| lua shared dict set get | `ngx_http_lua_shared_dict_get` | 0.96 |
| lua subrequest internal request capture | `ngx_http_lua_subrequest` | 0.92 |
| stream lua preread balancer content handler | `ngx_stream_lua_balancer_handler_file` | 0.95 |
| worker process init module | `ngx_worker_process_init` | 0.98 |

---

## 13. 与本项目（my-openresty）的映射

| OpenResty 源码机制 | MyResty 对应 | 说明 |
|--------------------|-------------|------|
| `content_by_lua_file`（`ngx_http_lua_contentby.c`） | `bootstrap.lua`（`content_by_lua_file`） | 我们的 MVC 入口即运行在 CONTENT 阶段 |
| 11 阶段 phase 引擎 | `middleware/{rewrite,access,header_filter,body_filter,log}.lua` | 我们手动模拟阶段；nginx 原生阶段由 `*_by_lua*` 指令挂载 |
| `phase_engine.handlers` 线性数组 | `bootstrap.lua` 的 Router 匹配 | 我们实现了静态 hash + 动态前缀的简化版 |
| cosocket `set_keepalive`（`...:5612`） | `app/lib/mysql.lua` / `redis.lua` 的 `set_keepalive` | **必须放回连接池**，对应我们修复的 Bug#1 |
| `ngx_slab_alloc` + shdict | `lua_shared_dict my_resty_cache` / `app/lib/cache.lua` | 共享字典基于 slab |
| `init_by_lua*` / `init_worker_by_lua*` | `init.lua` / `init_worker.lua`（`init_by_lua_file`） | 我们都是“一次性注册”的定位 |
| `ngx_stream_lua`（preread/balancer/content） | 暂未使用 | 若做 TCP/UDP 网关可直接复用 |
| upstream round-robin | — | 若做负载均衡/网关可参考 peer 接口 |
| `ngx_http_lua_ctx_t` | `ngx.ctx`（我们用于请求级 Request 缓存） | 我们已把 Request 缓存迁到 `ngx.ctx` |

---

## 14. 结论

- **架构本质**：OpenResty = nginx 的“模块化 + 阶段化 + 事件驱动”内核，叠加 LuaJIT 运行时与 ngx_lua/ngx_stream_lua 两个适配层，再用 lua-resty-* 补齐协议客户端能力。
- **三层可扩展点**：C 模块（`ngx_module_t`）、Lua 指令（`*_by_lua*`）、Lua 库（lua-resty-*）。
- **两条内存线**：请求级 `ngx_pool_t`（一次性释放）与跨进程 `ngx_slab_pool_t`（shared dict）。
- **异步之所以能写同步**：phase handler 的 `NGX_AGAIN` + 协程 `yield/resume` + cosocket，把回调地狱封装成线性代码。
- **对 MyResty 的启示**：优先借鉴 `init_by_lua` 一次性注册、cosocket 连接池、`ngx.ctx` 请求上下文、以及 stream 模块做 L4 网关；路由/阶段可用 nginx 原生 phase 机制替代手写模拟，以获得更好的性能与可维护性。
