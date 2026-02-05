# MyResty MVC 架构继承关系

## 1. 整体架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                      HTTP Request                                │
└─────────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────────┐
│                       Router (路由分发)                          │
│                    app/routes.lua → 路由匹配                      │
└─────────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────────┐
│                      Controller (控制器层)                        │
│                    app/controllers/*.lua                         │
│                           ↑                                      │
│                 继承: setmetatable                               │
│                           ↑                                      │
│              app.core.Controller (基类)                          │
└─────────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────────┐
│                        Model (模型层)                             │
│                   app/models/*Model.lua                          │
│                           ↑                                      │
│                 继承: setmetatable                               │
│                           ↑                                      │
│                app.core.Model (基类)                             │
│                           ↑                                      │
│            使用: ngx.socket.tcp() (原生 socket)                   │
│                           ↑                                      │
│              手动实现 MySQL 协议 (非 resty.mysql)                  │
└─────────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────────┐
│                      Database (MySQL)                            │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        Libraries (库)                            │
│                                                               │
│   app/lib/mysql.lua ──────────→ resty.mysql (系统内置)           │
│        ↑                             ↑                          │
│        │                             │                          │
│   封装便捷函数:                OpenResty 系统自带                 │
│   - new()                   MySQL 客户端库                       │
│   - connect()                                                    │
│   - query()                                                     │
│   - set_keepalive()                                             │
└─────────────────────────────────────────────────────────────────┘
```

## 2. Controller 层继承关系

### 2.1 类继承图

```
┌────────────────────────────────────────┐
│        自定义 Controller                 │
│     app/controllers/user.lua           │
│                                         │
│ function _M:show(id)                   │
│     self:json({data = user})           │
│ end                                     │
└──────────────────┬─────────────────────┘
                   │ setmetatable
                   │ __index = Controller
                   ↓
┌────────────────────────────────────────┐
│     app.core.Controller (基类)          │
│                                         │
│ function _M:json(data, status)         │
│ function _M:redirect(uri)              │
│ function _M:load_model(name)           │
│ function _M:post(key)                  │
│ function _M:get(key)                   │
│ ...                                     │
└──────────────────┬─────────────────────┘
                   │
                   │ require()
                   ↓
┌────────────────────────────────────────┐
│     app.core.Request (请求类)           │
│     app.core.Response (响应类)          │
│     app.core.Config (配置类)            │
│     app.core.Loader (加载器)            │
└────────────────────────────────────────┘
```

### 2.2 代码实现

```lua
-- ========== 1. 基类: app/core/Controller.lua ==========
local _M = { _VERSION = '1.0.0' }
local mt = { __index = _M }  -- 继承核心

function _M.new(self)
    local instance = {
        request = nil,
        response = nil,
        config = nil,
        load = nil,
        loaded = {}
    }
    instance.load = function(name, alias)
        return self:load_model(name, alias)
    end
    return setmetatable(instance, mt)
end

function _M.__construct(self)
    -- 初始化 Request, Response, Config
    self.request = Request:new()
    self.response = Response:new()
    self.config = Config
end

-- 响应方法
function _M.json(self, data, status)
    self.response:json(data, status)
end

-- 加载模型
function _M.load_model(self, name, alias)
    local Loader = require('app.core.Loader')
    return Loader:model(name)
end

-- 获取请求数据
function _M.post(self, key)
    return self.request:param(key)
end

function _M.get(self, key)
    return self.request.get[key]
end

return _M


-- ========== 2. 自定义 Controller: app/controllers/user.lua ==========
local Controller = require('app.core.Controller')  -- 引入基类

local _M = {}  -- 自定义控制器

-- 继承: 设置元表，__index 指向 Controller
setmetatable(_M, { __index = Controller })

-- 或使用构造函数方式
function _M:__construct()
    Controller.__construct(self)  -- 调用父类构造函数
    self:load('user_model')  -- 加载模型
end

-- 自己的方法
function _M:show(id)
    local user = self.user_model:get_by_id(id)
    self:json({success = true, data = user})  -- 调用父类方法
end

return _M
```

### 2.3 使用示例

```lua
-- 路由定义
route:get('/users/{id}', 'user:show')

-- 执行流程
1. Router 匹配 /users/{id} → user:show
2. 实例化 user Controller:
   local ctrl = user:new()  -- 继承自 Controller
3. 调用 show 方法:
   ctrl:show(123)  -- self.user_model 可用
```

## 3. Model 层继承关系

### 3.1 类继承图

```
┌────────────────────────────────────────┐
│        自定义 Model                      │
│     app/models/UserModel.lua            │
│                                         │
│ _M._TABLE = 'users'                     │
│                                         │
│ function _M:get_active()                │
│     return self:get_all({status=1})     │
│ end                                     │
└──────────────────┬─────────────────────┘
                   │ setmetatable
                   │ __index = Model
                   ↓
┌────────────────────────────────────────┐
│      app.core.Model (基类)              │
│                                         │
│ -- 基础方法                              │
│ function _M.new(self)                   │
│ function _M.connect(opts)               │
│ function _M.query(sql)                  │
│ function _M.get_all(where, limit, off)  │
│ function _M.get_by_id(id)               │
│ function _M.insert(data)                │
│ function _M.update(data, where)         │
│ function _M.delete(where)               │
│ function _M.count(where)                │
│                                         │
│ -- 底层实现 (手动 MySQL 协议)             │
│ local tcp = ngx.socket.tcp              │  ← 底层 socket
│ _send_query()                           │  ← 发送查询
│ _read_packet()                          │  ← 读取响应
│ _parse_ok_packet()                      │  ← 解析 OK 包
│ _parse_row_packet()                     │  ← 解析行数据
└──────────────────┬─────────────────────┘
                   │
                   │ ngx.socket.tcp()
                   ↓
┌────────────────────────────────────────┐
│       ngx.socket.tcp()                  │
│   (OpenResty 原生 TCP socket)           │
└──────────────────┬─────────────────────┘
                   │
                   │ MySQL 协议 (手动实现)
                   ↓
┌────────────────────────────────────────┐
│           MySQL Server                  │
└────────────────────────────────────────┘
```

### 3.2 代码实现

```lua
-- ========== 1. 基类: app/core/Model.lua ==========
local _M = { _VERSION = '1.0.0' }
local mt = { __index = _M }

-- 引入原生 TCP socket
local tcp = ngx.socket.tcp

-- 状态常量
local STATE_CONNECTED = 1

-- 创建 Model 实例
function _M.new(self)
    local sock, err = tcp()  -- 创建 TCP socket
    if not sock then return nil, err end
    
    return setmetatable({
        sock = sock,         -- 底层 socket
        state = nil,         -- 连接状态
        packet_no = nil,     -- 包序号
        compact = false      -- 紧凑模式
    }, mt)
end

-- 设置表名
function _M.set_table(self, name)
    self.table_name = name
    return self
end

-- 连接数据库
function _M.connect(self, opts)
    local sock = self.sock
    local host = opts.host or "127.0.0.1"
    local port = opts.port or 3306
    
    local ok, err = sock:connect(host, port, {
        pool_size = opts.pool_size or 100
    })
    
    if not ok then return nil, err end
    self.state = STATE_CONNECTED
    return 1
end

-- 执行查询 (底层 MySQL 协议)
function _M.query(self, query, est_nrows)
    local sock = self.sock
    self.packet_no = -1
    
    -- 发送查询包 (MySQL 协议: 0x03 + SQL)
    local packet = string.char(0x03) .. query
    sock:send(packet)
    
    -- 读取响应包并解析
    local data = sock:receive(4)  -- 包头
    -- ... 解析 MySQL 协议包 ...
    
    return rows  -- 返回结果
end

-- ========== 便捷方法 ==========

-- 查询多条
function _M.get_all(self, where, limit, offset)
    local sql = "SELECT * FROM " .. (self.table_name or "")
    sql = sql .. _build_where_clause(where)
    if limit then sql = sql .. " LIMIT " .. tonumber(limit) end
    if offset then sql = sql .. " OFFSET " .. tonumber(offset) end
    return self:query(sql)
end

-- 主键查询
function _M.get_by_id(self, id)
    local sql = "SELECT * FROM " .. (self.table_name or "") .. " WHERE id = " .. tonumber(id)
    local result = self:query(sql, 1)
    return result and result[1] or nil
end

-- 插入
function _M.insert(self, data)
    local fields = {}
    local values = {}
    for k, v in pairs(data) do
        table.insert(fields, k)
        table.insert(values, "'" .. _escape_str(v) .. "'")
    end
    local sql = "INSERT INTO " .. self.table_name .. 
                " (" .. table.concat(fields, ",") .. ")" ..
                " VALUES (" .. table.concat(values, ",") .. ")"
    local res = self:query(sql)
    return res and res.insert_id
end

-- 更新
function _M.update(self, data, where)
    local sets = {}
    for k, v in pairs(data) do
        table.insert(sets, k .. " = '" .. _escape_str(v) .. "'")
    end
    local sql = "UPDATE " .. self.table_name .. 
                " SET " .. table.concat(sets, ",") ..
                _build_where_clause(where)
    self:query(sql)
    return true
end

-- 删除
function _M.delete(self, where)
    local sql = "DELETE FROM " .. self.table_name .. _build_where_clause(where)
    self:query(sql)
    return true
end

-- 统计
function _M.count(self, where)
    local sql = "SELECT COUNT(*) as cnt FROM " .. self.table_name .. _build_where_clause(where)
    local result = self:query(sql, 1)
    return tonumber(result[1].cnt)
end

return _M


-- ========== 2. 自定义 Model: app/models/UserModel.lua ==========
local Model = require('app.core.Model')  -- 引入基类

local _M = setmetatable({}, { __index = Model })  -- 继承
_M._TABLE = 'users'  -- 指定表名

function _M.new()
    local model = Model:new()  -- 调用父类 new()
    model:set_table(_M._TABLE)  -- 设置表名
    return model
end

-- 封装业务方法
function _M:get_active()
    return self:get_all({status = 'active'})
end

function _M:get_by_email(email)
    local builder = QueryBuilder:new('users')
    builder:where('email', '=', email)
    builder:limit(1)
    local sql = builder:to_sql()
    local rows = self:query(sql)
    return rows and rows[1] or nil
end

return _M
```

### 3.3 使用示例

```lua
-- Controller 中使用 Model
function _M:show(id)
    -- 加载模型
    self:load('user_model')  -- 或 self.user_model = self:load_model('user_model')
    
    -- 调用模型方法
    local user = self.user_model:get_by_id(id)
    local active_users = self.user_model:get_active()
    
    -- 底层: self.user_model:get_all({status = 'active'})
    -- 实际调用: self.user_model:query("SELECT * FROM users WHERE status = 'active'")
end
```

## 4. lib/mysql 库 (封装 resty.mysql)

### 4.1 类关系图

```
┌────────────────────────────────────────┐
│      app/lib/mysql.lua (封装层)         │
│                                         │
│ -- 便捷函数                            │
│ _M.new()           → 创建连接           │
│ _M.connect()       → 连接数据库         │
│ _M.query()         → 执行查询           │
│ _M.set_keepalive() → 连接池复用         │
│ _M.close()         → 关闭连接           │
└──────────────────┬─────────────────────┘
                   │ require()
                   │ 封装/包装
                   ↓
┌────────────────────────────────────────┐
│          resty.mysql (系统内置)          │
│    OpenResty 自带 MySQL 客户端库         │
│                                         │
│ -- 核心方法                            │
│ :new()              创建实例            │
│ :connect(opts)      连接                │
│ :query(sql)         查询                │
│ :close()            关闭                │
│ :set_keepalive()    放入连接池          │
│ :send()             发送数据            │
│ :receive()          接收数据            │
└──────────────────┬─────────────────────┘
                   │ OpenResty 内置
                   ↓
┌────────────────────────────────────────┐
│           MySQL Server                  │
└────────────────────────────────────────┘
```

### 4.2 代码实现

```lua
-- ========== app/lib/mysql.lua ==========
-- 这是一个模块表，不是类
local _M = {}

-- 引入 OpenResty 系统自带的 MySQL 客户端
local resty_mysql = require('resty.mysql')

-- 引入配置
local Config = require('app.config.config')

-- 1. 创建 MySQL 实例
function _M.new()
    local config = Config.mysql or {}
    
    -- 使用 resty.mysql 创建实例
    local db = resty_mysql:new()
    db:set_timeout(config.timeout or 5000)
    
    return db, config
end

-- 2. 连接数据库
function _M.connect(db, db_name)
    local config = Config.mysql or {}
    local conn_config = Config.connections and Config.connections[db_name] or {}
    
    -- 合并配置
    local final_config = {}
    for k, v in pairs(config) do final_config[k] = v end
    for k, v in pairs(conn_config) do final_config[k] = v end
    
    -- 连接
    local ok, err = db:connect({
        host = final_config.host,
        port = final_config.port,
        user = final_config.user,
        password = final_config.password,
        database = final_config.database,
        charset = final_config.charset,
        pool = pool_name
    })
    
    if not ok then return nil, err end
    return true
end

-- 3. 执行查询
function _M.query(db, sql)
    return db:query(sql)  -- 直接调用 resty.mysql 的 query
end

-- 4. 关闭连接
function _M.close(db)
    if db then return db:close() end
end

-- 5. 放入连接池
function _M.set_keepalive(db)
    local config = Config.mysql or {}
    local pool_size = config.pool_size or 100
    local idle_timeout = config.idle_timeout or 10000
    return db:set_keepalive(idle_timeout, pool_size)
end

return _M
```

### 4.3 使用示例

```lua
-- 方式 1: 直接使用 lib/mysql
local mysql = require('app.lib.mysql')

local db, config = mysql.new()
local ok, err = mysql.connect(db)

if ok then
    local res, err, errno = mysql.query(db, "SELECT * FROM users")
    mysql.set_keepalive(db)
end


-- 方式 2: Controller 中使用 (不推荐，应该用 Model)
function _M:list()
    local mysql = require('app.lib.mysql')
    local db = mysql.new()
    mysql.connect(db)
    
    local res = mysql.query(db, "SELECT * FROM users")
    
    mysql.set_keepalive(db)
    self:json({data = res})
end
```

## 5. Model 与 lib/mysql 的关系

### 5.1 重要说明

```lua
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│   Model 基类 (app/core/Model.lua)                            │
│       ↓                                                      │
│   使用 ngx.socket.tcp() 创建原生 socket                       │
│       ↓                                                      │
│   手动实现 MySQL 协议 (二进制协议解析)                         │
│   - _send_query()    发送 MySQL 协议包                        │
│   - _read_packet()   读取 MySQL 协议包                        │
│   - _parse_ok_packet() 解析 OK 响应                          │
│   - _parse_row_packet() 解析数据行                           │
│       ↓                                                      │
│   直接连接 MySQL Server                                       │
│                                                              │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│                                                              │
│   lib/mysql (app/lib/mysql.lua)                              │
│       ↓                                                      │
│   封装 resty.mysql (OpenResty 系统库)                         │
│       ↓                                                      │
│   使用 resty.mysql 提供的 API                                 │
│   - db:connect()                                             │
│   - db:query()                                               │
│   - db:set_keepalive()                                       │
│       ↓                                                      │
│   resty.mysql 内部实现 MySQL 协议                              │
│       ↓                                                      │
│   连接 MySQL Server                                           │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### 5.2 对比

| 特性 | Model (app/core/Model) | lib/mysql (app/lib/mysql) |
|------|------------------------|---------------------------|
| **底层** | `ngx.socket.tcp()` 原生 socket | `resty.mysql` 系统库 |
| **MySQL 协议** | 手动实现 (约 300 行) | resty.mysql 内部实现 |
| **连接池** | 自动管理 | 自动管理 |
| **使用场景** | Model 层数据访问 | 通用 MySQL 操作 |
| **灵活性** | 高 (完全控制) | 中 (依赖 resty.mysql) |
| **代码量** | 多 (470 行) | 少 (70 行) |

### 5.3 选择建议

```lua
-- ✅ 推荐: 使用 Model (Model 层数据访问)
function _M:list()
    return self:get_all({status = 1})  -- Model 自动处理连接
end

-- ✅ 可选: 使用 lib/mysql (简单查询)
function some_helper()
    local mysql = require('app.lib.mysql')
    local db = mysql.new()
    mysql.connect(db)
    local res = mysql.query(db, "SELECT COUNT(*) as cnt FROM users")
    mysql.set_keepalive(db)
    return res
end

-- ❌ 不推荐: 在 Controller 中直接写 SQL
function _M:list()
    local mysql = require('app.lib.mysql')
    local db = mysql.new()
    mysql.connect(db)
    local res = mysql.query(db, "SELECT * FROM users")
    -- 应该用 Model
end
```

## 6. 完整继承关系汇总

### 6.1 Controller

```
用户 Controller (app/controllers/*.lua)
    ↑
    └── setmetatable(_, { __index = Controller })
        ↑
        └── app.core.Controller (基类)
            ├── app.core.Request
            ├── app.core.Response
            ├── app.core.Config
            └── app.core.Loader
```

### 6.2 Model

```
用户 Model (app/models/*Model.lua)
    ↑
    └── setmetatable(_, { __index = Model })
        ↑
        └── app.core.Model (基类)
            ├── ngx.socket.tcp()  ← 底层
            ├── 手动实现 MySQL 协议
            └── 便捷方法:
                ├── get_all()
                ├── get_by_id()
                ├── insert()
                ├── update()
                ├── delete()
                └── count()
```

### 6.3 lib/mysql

```
app.lib.mysql (便捷封装)
    ↑
    └── 封装 resty.mysql
        ↑
        └── require('resty.mysql')  ← OpenResty 系统内置
```

## 7. 快速参考表

| 文件路径 | 类型 | 继承/依赖 | 说明 |
|---------|------|----------|------|
| `app/controllers/user.lua` | Controller | 继承 `app.core.Controller` | 用户控制器 |
| `app/core/Controller.lua` | 基类 | 依赖 Request, Response, Config | Controller 基类 |
| `app/models/UserModel.lua` | Model | 继承 `app.core.Model` | 用户模型 |
| `app/core/Model.lua` | 基类 | 使用 `ngx.socket.tcp()` | Model 基类 (手写 MySQL 协议) |
| `app/lib/mysql.lua` | 库模块 | 封装 `resty.mysql` | MySQL 便捷封装 |
| `resty.mysql` | 系统库 | OpenResty 内置 | MySQL 客户端 |
