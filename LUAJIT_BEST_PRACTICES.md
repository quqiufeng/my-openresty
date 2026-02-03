# LuaJIT Best Practices / LuaJIT 最佳实践规则

本指南基于对 OpenResty 源码分析，总结 LuaJIT 环境下的最佳实现方式。

This guide summarizes LuaJIT best practices based on OpenResty source code analysis.

---

## 1. 模块加载与代码缓存 / Module Loading & Code Caching

### 1.1 使用 package.path 和 package.cpath / Use Proper Package Paths

```lua
-- 在文件开头设置正确的路径
package.path = '/var/www/web/my-openresty/?.lua;/var/www/web/my-openresty/?/init.lua;/usr/local/web/?.lua;;'
package.cpath = '/var/www/web/my-openresty/?.so;/usr/local/web/lualib/?.so;;'

-- 优先加载本地模块
local mylib = require('app.lib.mylib')
```

### 1.2 延迟加载 / Lazy Loading

```lua
-- 不推荐：顶层 require 加载所有模块
-- 推荐：按需加载

-- 延迟加载示例
local function get_db()
    if not _db then
        _db = require('resty.mysql'):new()
        _db:connect(...)
    end
    return _db
end
```

### 1.3 OpenResty 模块预加载 / OpenResty Module Pre-loading

```lua
-- core.lua 预加载模式
require "resty.core.var"
require "resty.core.worker"
require "resty.core.regex"
require "resty.core.shdict"
require "resty.core.time"
require "resty.core.request"
```

**最佳实践**：在 `init_by_lua*` 阶段预加载核心模块，避免每个请求重复加载。

---

## 2. 连接池使用 / Connection Pool Usage

### 2.1 MySQL 连接池 / MySQL Connection Pool

```lua
-- resty/mysql.lua 实现模式
local mysql = require("resty.mysql")
local db, err = mysql:new()

-- 设置连接超时
db:set_timeout(1000) -- 1秒

-- 连接池配置
db:connect({
    host = "127.0.0.1",
    port = 3306,
    database = "test",
    user = "root",
    password = "password",
    pool_size = 100,  -- 连接池大小
    max_idle_timeout = 10000, -- 最大空闲时间(ms)
    backlog = 100,   -- 等待队列
})

-- 使用后放回连接池
db:set_keepalive(10000, 100)  -- 10秒超时, 100连接
-- 或显式关闭
-- db:close()
```

### 2.2 Redis 连接池 / Redis Connection Pool

```lua
-- resty/redis.lua 实现模式
local redis = require("resty.redis")
local red = redis:new()

-- 设置超时
red:set_timeout(1000)

-- 连接
red:connect("127.0.0.1", 6379)

-- 连接池参数
-- keepalive(空闲超时, 连接池大小)
red:set_keepalive(60000, 1000)  -- 60秒, 1000连接

-- Unix socket 连接
-- red:connect("unix:/tmp/redis.sock")
```

### 2.3 自定义连接池 / Custom Connection Pool

```lua
-- 基于 shared dict 的连接池
local _M = {}

function _M.new(pool_size)
    local self = {
        pool_size = pool_size or 100,
        pool = {},
    }
    return setmetatable(self, {__index = _M})
end

function _M.get(self)
    if #self.pool > 0 then
        return table.remove(self.pool)
    end
    return nil
end

function _M.put(self, conn)
    if #self.pool < self.pool_size then
        table.insert(self.pool, conn)
    else
        conn:close()
    end
end

return _M
```

### 2.4 连接池配置参数 / Pool Configuration Parameters

| 参数 | 说明 | 推荐值 |
|------|------|--------|
| `pool_size` | 连接池大小 | 100-1000 |
| `max_idle_timeout` | 空闲超时(ms) | 10000-60000 |
| `backlog` | 等待队列大小 | 100-500 |

---

## 3. Lua FFI 使用 / Lua FFI Usage

### 3.1 FFI 基本模式 / FFI Basic Pattern

```lua
-- 引用 FFI 库
local ffi = require "ffi"
local C = ffi.C

-- 定义 C 类型
ffi.cdef[[
    typedef struct {
        int fd;
        size_t size;
    } file_info_t;

    int access(const char *pathname, int mode);
    int stat(const char *pathname, void *buf);
]]

-- 使用 FFI 调用
local result = C.access("/path/to/file", 0)

-- 创建 C 数据
local file_info = ffi.new("file_info_t")
file_info.fd = 10
```

### 3.2 FFI 内存管理 / FFI Memory Management

```lua
-- 避免频繁分配，使用临时缓冲区
local ffi = require "ffi"
local ffi_new = ffi.new
local ffi_fill = ffi.fill
local ffi_sizeof = ffi.sizeof

-- 预分配缓冲区
local buf_size = 4096
local buffer = ffi_new("char[?]", buf_size)

-- 重用缓冲区
ffi_fill(buffer, buf_size, 0)
```

### 3.3 FFI 性能优化 / FFI Performance

```lua
-- 缓存 FFI 类型定义
local uintptr_t = ffi.typeof("uintptr_t")
local queue_type = ffi.typeof("lrucache_queue_t")
local queue_arr_type = ffi.typeof("lrucache_queue_t[?]")

-- 使用 ffi.cast 避免重复类型转换
local const_rec_ptr_type = ffi.typeof("const struct lua_resty_limit_req_rec*")

-- 预创建 cdata 实例（复用）
local rec_cdata = ffi.new("struct lua_resty_limit_req_rec")
```

### 3.4 FFI 类型转换 / FFI Type Casting

```lua
local ffi = require "ffi"
local ffi_cast = ffi.cast
local tonumber = tonumber

-- 安全转换
local v = dict:get(key)
if v then
    local rec = ffi_cast(const_rec_ptr_type, v)
    local value = tonumber(rec.excess)
end
```

### 3.5 错误处理 / FFI Error Handling

```lua
local ok, err = pcall(function()
    -- FFI 调用可能失败
    return C.some_function()
end)

if not ok then
    ngx.log(ngx.ERR, "FFI error: ", err)
end
```

---

## 4. Lua Cosocket 使用 / Lua Cosocket Usage

### 4.1 Cosocket API / Cosocket API

```lua
-- 创建 TCP socket
local sock = ngx.socket.tcp()

-- 设置超时
sock:settimeout(1000)  -- 1秒
sock:settimeouts(connect_timeout, send_timeout, read_timeout)

-- 连接
local ok, err = sock:connect(host, port)
-- 或 Unix socket
-- local ok, err = sock:connect("unix:/tmp/socket")

-- 发送数据
local ok, err = sock:send("GET / HTTP/1.1\r\nHost: example.com\r\n\r\n")
if not ok then
    ngx.log(ngx.ERR, "send failed: ", err)
end

-- 接收响应
local line, err = sock:receive()
-- 或接收指定字节数
-- local data, err = sock:receive(1024)

-- 关闭连接
sock:close()

-- 放回连接池
sock:set_keepalive(60000, 100)
```

### 4.2 UDP Socket / UDP Socket

```lua
local sock = ngx.socket.udp()
sock:setpeername("8.8.8.8", 53)

-- 发送
sock:send(query_data)

-- 接收
local data, err = sock:receive()
```

### 4.3 Cosocket 限制 / Cosocket Limitations

```lua
-- Cosocket 只在以下阶段可用：
-- * rewrite
-- * access
-- * content
-- * log
-- * balancer_by_lua*

-- Cosocket 在以下阶段不可用：
-- * header_filter
-- * body_filter
```

### 4.4 错误处理模式 / Error Handling Pattern

```lua
local sock = ngx.socket.tcp()
local ok, err = sock:connect(host, port)
if not ok then
    ngx.log(ngx.ERR, "connect failed: ", err)
    return nil, err
end

local ok, err = sock:send(request)
if not ok then
    sock:close()  -- 失败时关闭连接
    return nil, err
end

local response, err = sock:receive()
if not response then
    sock:close()
    return nil, err
end

-- 成功：放回连接池
sock:set_keepalive(10000, 100)
```

---

## 5. Table 性能优化 / Table Performance

### 5.1 table.new / Pre-allocate Tables

```lua
-- 推荐：使用 table.new 预分配内存
local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function(narr, nrec) return {} end
end

-- 预分配数组部分和记录部分
local tab = new_tab(100, 50)  -- 100 数组, 50 记录

-- 在热点代码中使用
for i = 1, 1000 do
    local item = new_tab(0, 8)  -- 只分配记录部分
    item.name = "item" .. i
    item.value = i
end
```

### 5.2 table.clear / Clear Tables for Reuse

```lua
local ok, tb_clear = pcall(require, "table.clear")
if not ok then
    tb_clear = function(tab)
        for k, _ in pairs(tab) do
            tab[k] = nil
        end
    end
end

-- 表池模式
local tab_pool = {}
local tab_pool_len = 0

local function get_tab()
    if tab_pool_len > 0 then
        tab_pool_len = tab_pool_len - 1
        return tab_pool[tab_pool_len + 1]
    end
    return new_tab(16, 0)
end

local function put_tab(tab)
    if tab_pool_len >= 32 then return end
    tb_clear(tab)
    tab_pool_len = tab_pool_len + 1
    tab_pool[tab_pool_len] = tab
end
```

### 5.3 tablepool / OpenResty Table Pool

```lua
-- 使用 OpenResty 提供的 tablepool
local newtab = require "table.new"
local cleartab = require "table.clear"
local fetch = require "tablepool".fetch
local release = require "tablepool".release

-- 获取表
local tab = fetch("my_tag", 16, 0)

-- 使用完成后释放
release("my_tag", tab, false)  -- false: 不清空表
-- 或
release("my_tag", tab, true)   -- true: 清空表
```

---

## 6. Shared Dictionary / 共享字典

### 6.1 基本使用 / Basic Usage

```lua
local dict = ngx.shared.my_dict

-- 设置
dict:set("key", "value", 60)  -- 60秒过期

-- 获取
local value = dict:get("key")

-- 原子增/减
dict:incr("counter", 1)

-- 删除
dict:delete("key")

-- 检查存在
local exists, value = dict:get("key")
```

### 6.2 限流使用 / Rate Limiting

```lua
-- 基于 shared dict 的限流
local limit_req = require "resty.limit.req"

local lim, err = limit_req.new("limit_req_dict", 100, 10)  -- 100 req/s, 10 burst

-- 检查限流
local delay, err = lim:incoming("127.0.0.1", true)
if not delay then
    if err == "rejected" then
        ngx.exit(429)
    end
    ngx.exit(500)
end
```

### 6.3 缓存使用 / Caching

```lua
local lrucache = require "resty.lrucache"

-- 创建 LRU 缓存
local cache, err = lrucache.new(1000)  -- 1000 项

-- 设置缓存
cache:set("user:1", {name = "John"}, 3600)  -- 1小时过期

-- 获取缓存
local user, err = cache:get("user:1")
```

---

## 7. 代码组织模式 / Code Organization Patterns

### 7.1 模块模式 / Module Pattern

```lua
-- mymodule.lua
local _M = {
    _VERSION = '1.0.0'
}

-- 私有函数
local function private_func()
    -- ...
end

-- 公共函数
function _M.public_func()
    -- ...
end

return _M
```

### 7.2 Metatable 模式 / Metatable Pattern

```lua
local _M = {}
local mt = { __index = _M }

function _M.new()
    local self = {
        data = {},
    }
    return setmetatable(self, mt)
end

function _M:process()
    -- ...
end

return _M
```

### 7.3 惰性初始化 / Lazy Initialization

```lua
local _M = {}
local _instance = nil

function _M.get_instance()
    if not _instance then
        _instance = {
            config = load_config(),
            cache = init_cache(),
        }
    end
    return _instance
end

return _M
```

### 7.4 单例模式 / Singleton Pattern

```lua
local _M = {}

local instance = nil

function _M.singleton()
    if instance == nil then
        instance = {
            connection = create_connection(),
        }
    end
    return instance
end

return _M
```

---

## 8. 性能最佳实践 / Performance Best Practices

### 8.1 避免全局变量 / Avoid Global Variables

```lua
-- 不推荐
function process()
    global_data = get_data()  -- 全局变量
end

-- 推荐
function process(self)
    local data = self.data  -- 局部变量
end
```

### 8.2 使用局部变量 / Use Local Variables

```lua
-- 缓存查找结果到局部变量
local ngx_log = ngx.log
local ngx_ERR = ngx.ERR
local ngx_DEBUG = ngx.DEBUG

-- 在循环中使用
for i = 1, 1000 do
    local item = items[i]
    ngx_log(ngx_DEBUG, "item: ", item)
end
```

### 8.3 字符串拼接 / String Concatenation

```lua
-- 推荐：使用 table.concat
local parts = {}
parts[1] = "Hello"
parts[2] = " "
parts[3] = "World"
local str = table.concat(parts)

-- 不推荐：使用 ..
local str = "Hello" .. " " .. "World"  -- 多次内存分配
```

### 8.4 避免热点代码中的 pcall / Avoid pcall in Hot Paths

```lua
-- 初始化时检查
local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function(narr, nrec) return {} end
end

-- 热点代码中使用局部引用
local my_func = expensive_func
for i = 1, 10000 do
    my_func(i)  -- 避免每次查找
end
```

### 8.5 使用 JIT 可热身的代码 / JIT-Friendly Code

```lua
-- JIT 可以优化的代码
local function fast_loop(n)
    local s = 0
    for i = 1, n do
        s = s + i
    end
    return s
end

-- JIT 难以优化的代码
local function slow_loop(n)
    local s = 0
    for i = 1, n do
        -- 动态类型导致 JIT 无法优化
        local val = math.random()
        if val > 0.5 then
            s = s + i
        else
            s = s - i
        end
    end
    return s
end
```

---

## 9. 错误处理模式 / Error Handling Patterns

### 9.1 防御性编程 / Defensive Programming

```lua
function _M.process(data)
    -- 参数检查
    if not data then
        return nil, "data is required"
    end

    if type(data) ~= "table" then
        return nil, "data must be a table"
    end

    -- 业务逻辑
    -- ...
end
```

### 9.2 使用 pcall / Use pcall for Protected Calls

```lua
local ok, result = pcall(function()
    -- 可能出错的代码
    return risky_operation()
end)

if not ok then
    ngx.log(ngx.ERR, "operation failed: ", result)
    return nil, result
end

return result
```

### 9.3 资源清理 / Resource Cleanup

```lua
local sock = ngx.socket.tcp()
local ok, err = sock:connect(host, port)
if not ok then
    return nil, err
end

local ok, err = sock:send(data)
if not ok then
    sock:close()  -- 确保清理
    return nil, err
end

local response, err = sock:receive()
if not response then
    sock:close()  -- 确保清理
    return nil, err
end

-- 成功：放回连接池
sock:set_keepalive(10000, 100)
```

---

## 10. 安全实践 / Security Practices

### 10.1 输入验证 / Input Validation

```lua
function _M.validate_input(input)
    if not input then
        return nil, "input is required"
    end

    -- 类型检查
    if type(input.user_id) ~= "number" then
        return nil, "user_id must be a number"
    end

    -- SQL 注入防护：使用参数化查询
    -- NEVER: db:query("SELECT * FROM users WHERE id = " .. input.user_id)

    -- 推荐：使用预处理语句
    local stmt, err = db:prepare("SELECT * FROM users WHERE id = ?")
    local res, err = stmt:execute(input.user_id)

    return true
end
```

### 10.2 敏感数据处理 / Sensitive Data Handling

```lua
-- 不记录敏感信息
function _M.login(username, password)
    ngx.log(ngx.INFO, "login attempt for user: ", username)
    -- NEVER: ngx.log(ngx.INFO, "password: ", password)
end

-- 加密存储
local crypto = require "resty.string"
local hashed = crypto.sha1(password)  -- 或使用 scrypt/argon2
```

---

## 11. 完整示例 / Complete Example

```lua
-- mymodule.lua
local ngx_log = ngx.log
local ngx_ERR = ngx.ERR
local ngx_DEBUG = ngx.DEBUG

local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function(narr, nrec) return {} end
end

local _M = {
    _VERSION = '1.0.0'
}
local mt = { __index = _M }

function _M.new(opts)
    opts = opts or {}
    local self = {
        host = opts.host or "127.0.0.1",
        port = opts.port or 3306,
        pool_size = opts.pool_size or 100,
        timeout = opts.timeout or 1000,
    }

    -- 延迟初始化
    self.sock = nil

    return setmetatable(self, mt)
end

function _M.connect(self)
    if self.sock then
        return self.sock
    end

    local mysql = require "resty.mysql"
    local sock, err = mysql:new()
    if not sock then
        return nil, err
    end

    sock:set_timeout(self.timeout)

    local ok, err = sock:connect({
        host = self.host,
        port = self.port,
        pool_size = self.pool_size,
    })

    if not ok then
        sock:close()
        return nil, err
    end

    self.sock = sock
    return sock
end

function _M.query(self, sql)
    local sock, err = self:connect()
    if not sock then
        return nil, err
    end

    local res, err = sock:query(sql)
    if not res then
        return nil, err
    end

    return res
end

function _M.close(self)
    if self.sock then
        self.sock:close()
        self.sock = nil
    end
end

function _M.set_keepalive(self)
    if self.sock then
        self.sock:set_keepalive(10000, self.pool_size)
        self.sock = nil
    end
end

return _M
```

---

## 12. 性能监控 / Performance Monitoring

### 12.1 使用 ngx.now() / Use ngx.now()

```lua
local ngx_now = ngx.now

function _M.process()
    local start = ngx_now()

    -- 业务逻辑
    local result = do_something()

    local elapsed = ngx_now() - start
    ngx.log(ngx.INFO, "processed in: ", elapsed, "s")

    return result
end
```

### 12.2 指标收集 / Metrics Collection

```lua
local dict = ngx.shared.metrics

function _M.record_metric(key, value)
    local ok, err = dict:incr(key, value)
    if not ok then
        ngx.log(ngx.ERR, "failed to record metric: ", err)
    end
end
```

---

## 13. 常见问题 / FAQ

### Q1: 为什么连接池没有生效？

```lua
-- 错误：每次都创建新连接
local function bad_example()
    local db = mysql:new()  -- 新对象
    db:connect(...)
    db:close()  -- 关闭而不是放回池
end

-- 正确：复用连接
local db = nil
local function good_example()
    if not db then
        db = mysql:new()
        db:connect(...)
    end
    db:set_keepalive(10000, 100)  -- 放回池
end
```

### Q2: 为什么 FFI 调用慢？

```lua
-- 错误：频繁创建 cdata
function bad_perf()
    for i = 1, 10000 do
        local cdata = ffi.new("struct my_struct")  -- 慢！
        -- 使用 cdata
    end
end

-- 正确：复用 cdata
local cdata = ffi.new("struct my_struct")
function good_perf()
    for i = 1, 10000 do
        -- 复用 cdata，设置字段值
        cdata.field = i
        -- 使用 cdata
    end
end
```

### Q3: 为什么 table.concat 比 .. 慢？

```lua
-- 少量字符串拼接使用 ..
local s = "a" .. "b" .. "c"  -- 少量时更快

-- 大量字符串使用 table.concat
local parts = {}
for i = 1, 1000 do
    parts[i] = "item" .. i
end
local s = table.concat(parts, ", ")  -- 大量时更快
```

---

## 14. 参考资源 / References

- [OpenResty 官方文档](http://openresty.org)
- [LuaJIT 官方文档](http://luajit.org)
- [lua-resty-mysql](https://github.com/openresty/lua-resty-mysql)
- [lua-resty-redis](https://github.com/openresty/lua-resty-redis)
- [lua-resty-lrucache](https://github.com/openresty/lua-resty-lrucache)
- [Nginx Lua 模块文档](https://github.com/openresty/lua-nginx-module)

---

## 15. 快速参考表 / Quick Reference

| 场景 | 推荐做法 | 避免 |
|------|----------|------|
| 模块加载 | `require` | `dofile` |
| 表创建 | `table.new` | `{}` (大表) |
| 表清空 | `table.clear` | 循环 `nil` |
| 字符串拼接 | `table.concat` (多) / `..` (少) | 多次 `..` |
| 全局变量 | 局部缓存 | 直接使用 |
| 连接池 | `set_keepalive` | `close` |
| 热点代码 | 局部变量 | 全局查找 |
| 错误处理 | `pcall` / `xpcall` | 无防护 |
| 性能监控 | `ngx.now()` | `os.time()` |

---

*文档版本: 1.0.0*  
*最后更新: 2026-02-03*
