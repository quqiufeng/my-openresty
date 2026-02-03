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

## 14. 加密与安全 / Encryption & Security

### 14.1 AES-256-CBC 加密模式 / AES-256-CBC Encryption

MyResty 使用 OpenSSL FFI 实现 AES-256-CBC 加密：

```lua
-- crypto.lua 实现模式
local ffi = require("ffi")

ffi.cdef[[
    typedef struct evp_cipher_st EVP_CIPHER;
    typedef struct evp_cipher_ctx_st EVP_CIPHER_CTX;

    const EVP_CIPHER *EVP_aes_256_cbc(void);
    EVP_CIPHER_CTX *EVP_CIPHER_CTX_new(void);
    void EVP_CIPHER_CTX_free(EVP_CIPHER_CTX *ctx);

    int EVP_EncryptInit_ex(EVP_CIPHER_CTX *ctx, const EVP_CIPHER *type,
                           void *impl, const unsigned char *key,
                           const unsigned char *iv);
    int EVP_EncryptUpdate(EVP_CIPHER_CTX *ctx, unsigned char *out,
                          int *outl, const unsigned char *in, int inl);
    int EVP_EncryptFinal_ex(EVP_CIPHER_CTX *ctx, unsigned char *out, int *outl);

    int RAND_bytes(unsigned char *buf, int num);
]]

local libcrypto = ffi.load("crypto")
```

### 14.2 密钥管理 / Key Management

```lua
-- 密钥获取优先级
local function get_secret_key()
    -- 1. 环境变量 (最高优先级)
    local env_key = os.getenv('SESSION_SECRET') or os.getenv('MYRESTY_SESSION_SECRET')
    if env_key and #env_key >= 32 then
        return env_key
    end

    -- 2. 配置文件
    local config = load_config()
    if config and config.session and config.session.secret_key then
        return config.session.secret_key
    end

    -- 3. 默认密钥 (仅开发环境)
    return 'd07495d9623312cae328d13ca573e788'
end
```

### 14.3 安全的随机数生成 / Secure Random

```lua
function _M.random_bytes(length)
    local buf = ffi.new("unsigned char[?]", length)
    if libcrypto.RAND_bytes(buf, length) ~= 1 then
        return nil
    end
    return ffi.string(buf, length)
end
```

### 14.4 Base64 编解码 / Base64 Encode/Decode

```lua
function _M.base64_encode(data)
    local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    local result = {}

    local i = 1
    while i <= #data do
        local byte1 = string.byte(data, i)
        local byte2 = i + 1 <= #data and string.byte(data, i + 1) or 0
        local byte3 = i + 2 <= #data and string.byte(data, i + 2) or 0

        local triplet = byte1 * 65536 + byte2 * 256 + byte3

        table.insert(result, b64chars:sub(math.floor(triplet / 262144) % 64 + 1, math.floor(triplet / 262144) % 64 + 1))
        table.insert(result, b64chars:sub(math.floor(triplet / 4096) % 64 + 1, math.floor(triplet / 4096) % 64 + 1))

        if i + 1 <= #data then
            table.insert(result, b64chars:sub(math.floor(triplet / 64) % 64 + 1, math.floor(triplet / 64) % 64 + 1))
        else
            table.insert(result, '=')
        end

        if i + 2 <= #data then
            table.insert(result, b64chars:sub(triplet % 64 + 1, triplet % 64 + 1))
        else
            table.insert(result, '=')
        end

        i = i + 3
    end

    return table.concat(result)
end
```

---

## 15. HTTP 客户端实现 / HTTP Client Implementation

### 15.1 Cosocket HTTP 客户端 / Cosocket HTTP Client

```lua
-- http.lua 实现模式
local HttpClient = {}

function HttpClient:new(options)
    local self = setmetatable({}, HttpClient)
    self.options = options or {}
    self.default_timeout = options and options.timeout or 30000
    return self
end

function HttpClient:_parse_url(url)
    local protocol, host, port, path

    if url:match("^https://") then
        protocol = "https"
        port = 443
        url = url:gsub("^https://", "")
    elseif url:match("^http://") then
        protocol = "http"
        port = 80
        url = url:gsub("^http://", "")
    else
        protocol = "http"
        port = 80
    end

    local host_path = url:match("^([^/]+)(.*)$")
    if host_path then
        host = host_path:match("^([^:]+)")
        local port_match = host_path:match(":(%d+)")
        if port_match then
            port = tonumber(port_match)
        end
        path = url:match("^[^/]+(.*)$")
        if path == "" then path = "/" end
    else
        host = url
        path = "/"
    end

    return protocol, host, port, path
end
```

### 15.2 请求构建 / Request Building

```lua
function HttpClient:_build_query(params)
    if not params or type(params) ~= "table" then
        return nil
    end

    local query_parts = {}
    for key, value in pairs(params) do
        table.insert(query_parts, ngx.escape_uri(key) .. "=" .. ngx.escape_uri(tostring(value)))
    end

    if #query_parts > 0 then
        return table.concat(query_parts, "&")
    end
    return nil
end

function HttpClient:request(method, url, options)
    options = options or {}
    local timeout = options.timeout or self.default_timeout
    local body = options.body or options.data
    local headers = options.headers or {}
    local query = options.query

    local protocol, host, port, path = self:_parse_url(url)

    -- 构建查询字符串
    local query_str = self:_build_query(query)
    if query_str then
        if path:find("?") then
            path = path .. "&" .. query_str
        else
            path = path .. "?" .. query_str
        end
    end

    -- 创建 socket
    local sock = ngx.socket.tcp()
    sock:settimeout(timeout)

    local ok, err = sock:connect(host, port)
    if not ok then
        return nil, "Connection failed: " .. err
    end

    -- SSL 握手
    if protocol == "https" then
        local ok, err = sock:sslhandshake(nil, host, false)
        if not ok then
            sock:close()
            return nil, "SSL handshake failed: " .. err
        end
    end

    -- 发送请求
    local request_line = method .. " " .. path .. " HTTP/1.1\r\n"
    local request_headers = "Host: " .. host .. ":" .. port .. "\r\n"

    for key, value in pairs(headers) do
        request_headers = request_headers .. key .. ": " .. tostring(value) .. "\r\n"
    end

    if not headers["Content-Type"] and body then
        request_headers = request_headers .. "Content-Type: application/json\r\n"
    end

    if body then
        request_headers = request_headers .. "Content-Length: " .. #body .. "\r\n"
    end

    request_headers = request_headers .. "Connection: close\r\n\r\n"

    local bytes, err = sock:send(request_line .. request_headers)
    if not bytes then
        sock:close()
        return nil, "Send request failed: " .. err
    end

    if body then
        local bytes, err = sock:send(body)
        if not bytes then
            sock:close()
            return nil, "Send body failed: " .. err
        end
    end

    -- 接收响应
    local reader = sock:receiveuntil("\r\n\r\n")
    local headers_line, err = reader()
    if not headers_line then
        sock:close()
        return nil, "Receive headers failed: " .. err
    end

    local status_code = tonumber(headers_line:match("HTTP/%d%.%d (%d+)"))
    local response_headers = {}

    -- 解析响应头
    local line, err = reader()
    while line and line ~= "" do
        local key, value = line:match("^([^:]+):%s*(.+)$")
        if key and value then
            key = key:lower()
            response_headers[key] = value
        end
        line, err = reader()
    end

    -- 读取响应体
    local response_body
    if response_headers["transfer-encoding"] == "chunked" then
        -- Chunked 编码处理
        response_body = ""
        while true do
            local chunk_size_line = sock:receiveuntil("\r\n")
            local chunk_size, err = chunk_size_line()
            if not chunk_size then break end
            local size = tonumber(chunk_size, 16)
            if not size or size == 0 then break end
            local chunk = sock:receive(size + 2)
            if chunk then
                response_body = response_body .. chunk:sub(1, -3)
            end
        end
    else
        local content_length = tonumber(response_headers["content-length"]) or 0
        if content_length > 0 then
            response_body, err = sock:receive(content_length)
        else
            response_body, err = sock:receive("*a")
        end
    end

    sock:close()

    return {
        status = status_code or 500,
        body = response_body or "",
        headers = response_headers,
        success = (status_code or 500) >= 200 and (status_code or 500) < 300
    }, nil
end
```

---

## 16. 请求处理最佳实践 / Request Handling Best Practices

### 16.1 请求数据解析 / Request Data Parsing

```lua
-- request_helper.lua 模式
local function _get_request_data(req, fields, custom_rules, source)
    local result = {}
    local errors = {}

    if type(fields) == "string" then
        fields = { fields }
    end

    for _, field in ipairs(fields) do
        local rules = {}
        if custom_rules and type(custom_rules) == "table" then
            rules = custom_rules[field] or {}
        end

        local value
        if source == "get" then
            value = req:get[field]
        elseif source == "post" then
            value = req:post[field]
        elseif source == "json" then
            value = req.json and req.json[field]
        else
            value = req:input(field)
        end

        -- 类型转换
        local convert_type = rules.type
        if convert_type and type(value) == "string" then
            if convert_type == "number" then
                local num = tonumber(value)
                value = num or value
            elseif convert_type == "integer" then
                local num = tonumber(value)
                value = num and math.floor(num) or value
            elseif convert_type == "boolean" then
                if value == "true" or value == "1" or value == "yes" then
                    value = true
                elseif value == "false" or value == "0" or value == "no" then
                    value = false
                end
            elseif convert_type == "array" then
                value = { value }
            end
        end

        -- 验证必填
        if rules.required and (value == nil or value == "") then
            table.insert(errors, {
                field = field,
                message = rules.message or ("The " .. field .. " field is required.")
            })
        end

        result[field] = value
    end

    return result, errors
end
```

### 16.2 分页参数处理 / Pagination Parameters

```lua
function RequestHelper:get_pagination_params(default_per_page)
    default_per_page = default_per_page or 10

    local page = tonumber(self:get('page')) or 1
    local per_page = tonumber(self:get('per_page')) or default_per_page

    -- 边界检查
    if page < 1 then page = 1 end
    if per_page < 1 then per_page = default_per_page end
    if per_page > 100 then per_page = 100 end  -- 最大限制

    local sort_by = self:get('sort_by') or 'id'
    local sort_order = self:get('sort_order') or 'DESC'
    if sort_order ~= "ASC" and sort_order ~= "DESC" then
        sort_order = "DESC"
    end

    return {
        page = page,
        per_page = per_page,
        sort_by = sort_by,
        sort_order = sort_order,
        offset = (page - 1) * per_page,
        limit = per_page
    }
end
```

### 16.3 搜索参数处理 / Search Parameters

```lua
function RequestHelper:get_search_params(search_fields)
    local params = {}
    local keyword = self:get('keyword') or self:get('q') or ""

    if keyword ~= "" then
        for _, field in ipairs(search_fields or {}) do
            params[field] = keyword
        end
    end

    -- 支持 Base64 编码的过滤器
    local filters = self:get('filters')
    if type(filters) == "string" then
        local ok, decoded = pcall(function()
            return ngx.decode_base64(filters)
        end)
        if ok and decoded then
            local ok2, filter_tbl = pcall(function()
                return ngx.decode_json(decoded)
            end)
            if ok2 and type(filter_tbl) == "table" then
                filters = filter_tbl
            end
        end
    end

    if type(filters) == "table" then
        for k, v in pairs(filters) do
            params[k] = v
        end
    end

    return params, keyword
end
```

---

## 17. 文件处理安全 / File Handling Security

### 17.1 安全路径处理 / Safe Path Handling

```lua
-- file_helper.lua 模式
local function safe_path(base_path, filename)
    if not filename or filename == '' then
        return nil, 'Empty filename'
    end

    -- 移除危险字符
    local sanitized = filename:gsub('[\\:]', '_')

    -- 移除 .. 防止目录遍历
    while sanitized:find('%.%.') do
        sanitized = sanitized:gsub('%.%.', '.')
    end

    -- 防止绝对路径
    if sanitized:find('^/') or sanitized:find('^\\') then
        return nil, 'Absolute path not allowed'
    end

    -- 防止 NULL 字节
    if sanitized:find('%z') then
        return nil, 'Invalid characters in path'
    end

    local full_path = base_path .. '/' .. sanitized

    -- 确保路径在允许的目录内
    local resolved = full_path:gsub('/+', '/'):gsub('/%.$', ''):gsub('/%./', '/')
    local base_resolved = base_path:gsub('/+', '/'):gsub('/%.$', ''):gsub('/%./', '/')

    if not resolved:find('^' .. base_resolved) then
        return nil, 'Path outside allowed directory'
    end

    return resolved, nil
end
```

### 17.2 文件名净化 / Filename Sanitization

```lua
local function sanitize_filename(filename)
    if not filename or filename == '' then
        return 'file_' .. os.time()
    end

    local sanitized = filename:gsub('[^a-zA-Z0-9._-]', '_')
    sanitized = sanitized:gsub('_+', '_')

    -- 移除危险字符
    sanitized = sanitized:gsub('[\\/:]', '_')

    -- 移除 .. 防止目录遍历
    while sanitized:find('%.%.') do
        sanitized = sanitized:gsub('%.%.', '.')
    end

    -- 限制文件名长度
    if #sanitized > 255 then
        local ext = sanitized:match('%.(%w+)$') or ''
        local name = sanitized:match('(.+)%..+$') or sanitized
        if #name > 250 then
            name = name:sub(1, 250)
        end
        sanitized = name .. '.' .. ext
    end

    return sanitized
end
```

### 17.3 MIME 类型检查 / MIME Type Checking

```lua
local function is_image(mime)
    local image_mimes = {
        ['image/jpeg'] = true,
        ['image/png'] = true,
        ['image/gif'] = true,
        ['image/webp'] = true,
        ['image/svg+xml'] = true,
        ['image/bmp'] = true,
    }
    return image_mimes[mime] == true
end

local function is_document(mime)
    local doc_mimes = {
        ['application/pdf'] = true,
        ['application/msword'] = true,
        ['application/vnd.openxmlformats-officedocument.wordprocessingml.document'] = true,
        ['application/vnd.ms-excel'] = true,
        ['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'] = true,
        ['text/plain'] = true,
        ['text/csv'] = true,
    }
    return doc_mimes[mime] == true
end
```

---

## 18. 中间件模式 / Middleware Patterns

### 18.1 认证中间件 / Auth Middleware

```lua
-- auth.lua 模式
local Auth = {}

Auth.options = {
    mode = 'session',  -- session, token, both
    token_header = 'Authorization',
    token_prefix = 'Bearer',
    session_name = 'myresty_session',
    login_url = '/auth/login',
    unauthorized_msg = 'Unauthorized',
    allow_guest = false,
}

function Auth:setup(options)
    self.options = vim.tbl_deep_extend('force', self.options, options or {})
    return self
end

function Auth:handle(options)
    options = vim.tbl_deep_extend('force', self.options, options or {})

    local user_id, user_data, auth_type

    -- 1. 尝试 API Token 认证
    if options.mode == 'token' or options.mode == 'both' then
        user_id, user_data, auth_type = self:check_token(options)
    end

    -- 2. 尝试 Session 认证
    if not user_id and (options.mode == 'session' or options.mode == 'both') then
        user_id, user_data, auth_type = self:check_session(options)
    end

    -- 3. 游客模式
    if options.allow_guest then
        ngx.ctx.auth_user = user_id
        ngx.ctx.auth_data = user_data
        ngx.ctx.auth_type = auth_type or 'guest'
        return true
    end

    -- 4. 未登录处理
    if not user_id then
        ngx.status = 401
        ngx.header['Content-Type'] = 'application/json'
        ngx.say('{"success":false,"error":"' .. options.unauthorized_msg .. '","code":401}')
        ngx.exit(401)
        return false
    end

    -- 5. 角色检查
    if options.roles and #options.roles > 0 then
        local has_role = false
        local user_role = user_data and user_data.role or 'user'

        for _, role in ipairs(options.roles) do
            if user_role == role or user_role == 'admin' then
                has_role = true
                break
            end
        end

        if not has_role then
            ngx.status = 403
            ngx.header['Content-Type'] = 'application/json'
            ngx.say('{"success":false,"error":"Forbidden","code":403}')
            ngx.exit(403)
            return false
        end
    end

    -- 注入用户信息到请求上下文
    ngx.ctx.auth_user = user_id
    ngx.ctx.auth_data = user_data
    ngx.ctx.auth_type = auth_type or 'session'

    return true
end
```

### 18.2 限流中间件 / Rate Limit Middleware

```lua
-- rate_limit.lua 模式
local RateLimit = {}

RateLimit.options = {
    zones = {},
    default_limit = 60,
    default_window = 60,
    response_status = 429,
    response_message = 'Too Many Requests',
    headers = true,
    key_by_ip = true,
    key_by_user = false,
    log_blocked = true
}

RateLimit.zones = {
    api = { limit = 60, window = 60 },
    login = { limit = 5, window = 300 },
    upload = { limit = 10, window = 60 },
    default = { limit = 100, window = 60 }
}

function RateLimit:handle(options)
    options = vim.tbl_deep_extend('force', self.options, options or {})

    local zone_name = options.zone or 'default'
    local zone = options.zones and options.zones[zone_name] or self.options.zones[zone_name]

    if not zone then
        zone = {
            limit = options.default_limit,
            window = options.default_window
        }
    end

    local key = self:get_key(options, zone_name)

    local Limit = require('app.lib.limit')
    local limit = Limit:new({
        strategy = 'sliding_window',
        default_limit = zone.limit,
        default_window = zone.window,
        log_blocked = options.log_blocked
    })

    local success, info = limit:check(key, ngx.var.uri, zone.limit, zone.window, zone.burst or 0)

    if options.headers then
        self:set_headers(info)
    end

    if not success then
        if options.log_blocked then
            ngx.log(ngx.WARN, 'Rate limit exceeded: ' .. key .. ' (' .. info.current .. '/' .. info.limit .. ')')
        end

        ngx.status = options.response_status
        ngx.header['Content-Type'] = 'application/json'
        ngx.header['Retry-After'] = tostring(info.reset - ngx.now())
        ngx.say('{"success":false,"error":"' .. options.response_message .. '","code":' .. options.response_status .. ',"retry_after":' .. info.reset .. '}')
        ngx.exit(options.response_status)
        return false
    end

    return true
end

function RateLimit:get_key(options, zone_name)
    local key_parts = {}

    if options.key_by_ip ~= false then
        table.insert(key_parts, ngx.var.remote_addr or 'unknown')
    end

    if options.key_by_user then
        local Session = require('app.lib.session')
        local session = Session:new()
        local user_id = session:get('user_id')
        if user_id then
            table.insert(key_parts, 'user:' .. user_id)
        end
    end

    table.insert(key_parts, 'zone:' .. zone_name)

    return table.concat(key_parts, ':')
end

function RateLimit:set_headers(info)
    if not info then return end

    ngx.header['X-RateLimit-Limit'] = info.limit
    ngx.header['X-RateLimit-Remaining'] = info.remaining
    ngx.header['X-RateLimit-Reset'] = info.reset
    ngx.header['X-RateLimit-Window'] = info.window
end
```

---

## 19. 参考资源 / References

- [OpenResty 官方文档](http://openresty.org)
- [LuaJIT 官方文档](http://luajit.org)
- [lua-resty-mysql](https://github.com/openresty/lua-resty-mysql)
- [lua-resty-redis](https://github.com/openresty/lua-resty-redis)
- [lua-resty-lrucache](https://github.com/openresty/lua-resty-lrucache)
- [Nginx Lua 模块文档](https://github.com/openresty/lua-nginx-module)
- [OpenSSL EVP API](https://www.openssl.org/docs/man1.1.1/man3/EVP_EncryptInit.html)

---

## 20. 快速参考表 / Quick Reference

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
| 加密 | AES-256-CBC + RAND_bytes | 自定义加密 |
| HTTP 客户端 | Cosocket + SSL | 阻塞调用 |
| 文件路径 | safe_path + sanitize_filename | 直接拼接 |
| 认证 | 中间件模式 | 硬编码检查 |

---

*文档版本: 2.0.0*  
*最后更新: 2026-02-03*  
*新增章节: 加密与安全、HTTP 客户端实现、请求处理最佳实践、文件处理安全、中间件模式*
