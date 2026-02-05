# MyResty Framework 最佳实践指南

## 目录

- [1. 项目架构概览](#1-项目架构概览)
- [2. 路由注册](#2-路由注册)
- [3. Controller 实现](#3-controller-实现)
- [4. Model 实现](#4-model-实现)
- [5. QueryBuilder 使用](#5-querybuilder-使用)
- [6. Model 常用数据库操作方法](#6-model-常用数据库操作方法)
- [7. 完整示例](#7-完整示例)

---

## 1. 项目架构概览

```
my-openresty/
├── app/
│   ├── core/           # 核心类 (Controller, Model, Router, Request, Response)
│   ├── controllers/    # 控制器层
│   ├── models/         # 数据模型层
│   ├── db/             # 数据库工具 (QueryBuilder)
│   ├── lib/            # 库 (mysql, redis, session, cache, validation)
│   ├── middleware/     # 中间件
│   ├── config/         # 配置文件
│   ├── helpers/        # 辅助函数
│   └── routes.lua      # 路由定义
├── nginx/conf/         # Nginx 配置
└── tests/              # 测试用例
```

**请求生命周期**：

```
HTTP 请求
    ↓
rewrite_by_lua (URL 重写)
    ↓
access_by_lua (访问控制)
    ↓
content_by_lua → bootstrap.lua → Router → Controller → Model
    ↓
响应返回
```

---

## 2. 路由注册

### 2.1 基本路由语法

路由定义在 `app/routes.lua` 中，使用闭包或字符串格式：

```lua
-- 闭包形式 (简单路由)
route:get('/', function(req, res)
    res:json({message = 'Welcome'})
end)

-- 字符串形式 (控制器:动作)
route:get('/users', 'user:get_list')
route:post('/users', 'user:create')
```

### 2.2 HTTP 方法

| 方法 | 用途 | 示例 |
|------|------|------|
| `route:get()` | GET 请求 | `route:get('/users')` |
| `route:post()` | POST 请求 | `route:post('/users')` |
| `route:put()` | PUT 更新 | `route:put('/users/{id}')` |
| `route:delete()` | DELETE 删除 | `route:delete('/users/{id}')` |
| `route:patch()` | PATCH 部分更新 | `route:patch('/users/{id}')` |
| `route:any()` | 任意方法 | `route:any('/api/status')` |

### 2.3 路径参数

```lua
-- 命名参数 {id}
route:get('/users/{id}', 'user:get_one')
route:put('/users/{id}', 'user:update')
route:delete('/users/{id}', 'user:delete')

-- 匿名参数 :param
route:get('/posts/:category/:year', 'archive:show')
```

### 2.4 RESTful 资源路由

```lua
-- 自动生成 7 个标准 RESTful 路由
route:resource('users', 'user')

-- 生成路由：
-- GET    /users          -> user:index
-- GET    /users/{id}     -> user:show
-- POST   /users          -> user:create
-- PUT    /users/{id}     -> user:update
-- DELETE /users/{id}     -> user:delete
-- GET    /users/new     -> user:new
-- GET    /users/edit    -> user:edit
```

### 2.5 路由组和前缀

```lua
-- 路由前缀在 nginx.conf 中通过 location 定义
location /api/ {
    content_by_lua_file 'bootstrap.lua';
}
-- 所有路由自动带有 /api 前缀
```

### 2.6 完整路由注册示例

```lua
-- app/routes.lua
local M = {}

function M(route)
    -- 根路由
    route:get('/', function(req, res)
        res:json({message = 'Welcome to MyResty API', version = '1.0.0'})
    end)

    -- 动态路由参数
    route:get('/hello/{name}', {controller = 'welcome', action = 'hello'})

    -- 用户 CRUD 路由
    route:get('/users', 'user:get_list')
    route:get('/users/{id}', 'user:get_one')
    route:post('/users', 'user:create')
    route:put('/users/{id}', 'user:update')
    route:delete('/users/{id}', 'user:delete')

    -- 带参数验证的路由
    route:get('/products/{category}/{id}', 'product:detail')

    -- 嵌套资源
    route:resource('posts.comments', 'comment')
end

return M
```

---

## 3. Controller 实现

### 3.1 基本结构

```lua
-- app/controllers/user.lua
local Controller = require('app.core.Controller')

local _M = {}

function _M:__construct()
    Controller.__construct(self)
    -- 加载模型
    self:load('user_model')
    -- 或使用 Loader 加载
    -- self:load_model('user_model')
end

return _M
```

### 3.2 获取请求数据

```lua
-- GET 参数
local page = self:get('page') or 1
local limit = self:get('limit') or 10

-- POST 参数
local name = self:post('name')
local email = self:post('email')

-- 路由参数
local id = self:segment(1)  -- 获取第一个路由参数

-- JSON 请求体
local json_data = self.request.json

-- 所有输入
local all_input = self:input()  -- 或 self.request.all_input
```

### 3.3 响应方法

```lua
-- JSON 响应 (最常用)
self:json({success = true, data = data})
self:json({error = 'not found'}, 404)

-- 分页响应
self:paginate(users, total, page, limit)

-- 重定向
self:redirect('/login')
self:redirect_back()

-- 成功/失败响应
self:success(data, '操作成功')
self:fail('操作失败', nil, 400)

-- 其他响应
self:html('<h1>Hello</h1>')
self:text('Plain text')
self:xml(xml_data)
```

### 3.4 完整 Controller 示例

```lua
-- app/controllers/user.lua
local Controller = require('app.core.Controller')

local _M = {}

function _M:__construct()
    Controller.__construct(self)
    self:load('user_model')
end

-- 列表
function _M:get_list()
    local page = tonumber(self:get('page')) or 1
    local limit = tonumber(self.get['limit']) or 10
    local offset = (page - 1) * limit

    local users = self.user_model:get_all(nil, limit, offset)
    local total = self.user_model:count()

    self:json({
        success = true,
        data = users,
        total = total,
        page = page,
        limit = limit
    })
end

-- 详情
function _M:get_one(id)
    if not id then
        self:json({success = false, error = 'ID required'}, 400)
        return
    end

    local user = self.user_model:get_by_id(id)
    if user then
        self:json({success = true, data = user})
    else
        self:json({success = false, error = 'User not found'}, 404)
    end
end

-- 创建
function _M:create()
    local data = {
        username = self:post('username'),
        email = self:post('email'),
        status = 'active'
    }

    if not data.username or not data.email then
        self:json({success = false, error = 'Username and email required'}, 400)
        return
    end

    local id = self.user_model:insert(data)
    if id then
        self:json({success = true, data = {id = id}}, 201)
    else
        self:json({success = false, error = 'Failed to create'}, 500)
    end
end

-- 更新
function _M:update(id)
    if not id then
        self:json({success = false, error = 'ID required'}, 400)
        return
    end

    local data = {
        username = self:post('username'),
        email = self:post('email')
    }

    self.user_model:update(data, {id = tonumber(id)})
    self:json({success = true})
end

-- 删除
function _M:delete(id)
    if not id then
        self:json({success = false, error = 'ID required'}, 400)
        return
    end

    self.user_model:delete({id = tonumber(id)})
    self:json({success = true})
end

return _M
```

### 3.5 Controller 最佳实践

```lua
-- ✅ 正确做法
function _M:show(id)
    -- 1. 参数验证
    if not id or tonumber(id) == 0 then
        self:json({error = 'Invalid ID'}, 400)
        return
    end

    -- 2. 调用 Model 获取数据
    local user = self.user_model:get_by_id(id)

    -- 3. 业务逻辑判断
    if not user then
        self:json({error = 'Not found'}, 404)
        return
    end

    -- 4. 返回响应
    self:json({success = true, data = user})
end

-- ❌ 错误做法：不要在 Controller 中直接写 SQL
function _M:show(id)
    local mysql = require('app.lib.mysql')
    local db = mysql.new()
    mysql.connect(db)
    local res = mysql.query(db, "SELECT * FROM users WHERE id = " .. id)
    -- 应该使用 Model 层
end
```

---

## 4. Model 实现

### 4.1 基本结构

```lua
-- app/models/UserModel.lua
local Model = require('app.core.Model')

local _M = setmetatable({}, { __index = Model })
_M._TABLE = 'users'  -- 指定表名

function _M.new()
    local model = Model:new()
    model:set_table(_M._TABLE)
    return model
end

-- 可选：封装业务方法
function _M:get_by_username(username)
    local builder = QueryBuilder:new('users')
    builder:where('username', '=', username)
    builder:limit(1)
    local sql = builder:to_sql()
    local rows = self:query(sql)
    return rows and rows[1] or nil
end

return _M
```

### 4.2 业务方法封装

```lua
-- app/models/UserModel.lua
local Model = require('app.core.Model')

local _M = setmetatable({}, { __index = Model })
_M._TABLE = 'users'

function _M.new()
    local model = Model:new()
    model:set_table(_M._TABLE)
    return model
end

-- 列表 (带分页)
function _M:list(options)
    options = options or {}
    local page = tonumber(options.page) or 1
    local pageSize = tonumber(options.pageSize) or 10
    local offset = (page - 1) * pageSize

    return self:get_all(nil, pageSize, offset)
end

-- 按状态查询
function _M:get_by_status(status)
    return self:get_all({status = status})
end

-- 统计活跃用户
function _M:count_active()
    return self:count({status = 'active'})
end

return _M
```

### 4.3 Model 最佳实践

```lua
-- ✅ 正确做法：封装业务逻辑
function _M:active_users()
    return self:get_all({status = 'active'})
end

function _M:deactivate_user(id)
    return self:update({status = 'inactive'}, {id = id})
end

-- ✅ 使用 Model 内置方法
local id = self:insert({name = 'John'})           -- 插入
self:update({name = 'Tom'}, {id = 1})            -- 更新
self:delete({status = 'deleted'})                -- 删除
local user = self:get_by_id(1)                   -- 主键查询
local count = self:count({status = 'active'})    -- 统计

-- ❌ 错误做法：重复造轮子
function _M:create_user(data)
    local sql = "INSERT INTO users ..."
    -- 应该直接使用 self:insert(data)
end
```

---

## 5. QueryBuilder 使用

### 5.1 什么时候使用 QueryBuilder

**使用 Model 内置方法**：
- 主键查询 `get_by_id()`
- 简单插入 `insert()`
- 简单更新 `update()`
- 简单删除 `delete()`
- 简单统计 `count()`

**使用 QueryBuilder**：
- 复杂 WHERE 条件
- 多字段排序
- 分页查询
- LIKE 查询
- WHERE IN 查询

### 5.2 基本用法

```lua
local QueryBuilder = require('app.db.query')

-- 创建查询构建器
local builder = QueryBuilder.new('users')

-- 指定查询字段
builder:select('id, username, email')

-- WHERE 条件
builder:where('status', '=', 'active')
builder:where('age', '>', 18)
builder:or_where('role', '=', 'admin')

-- LIKE 查询
builder:like('username', 'john')

-- WHERE IN
builder:where_in('status', {'active', 'pending'})

-- 排序
builder:order_by('created_at', 'DESC')
builder:order_by('name', 'ASC')

-- 分页
builder:limit(10)
builder:offset(20)

-- 生成 SQL
local sql = builder:to_sql()
-- SELECT id, username, email FROM users WHERE status = 'active' ...

-- 执行查询
local rows = self:query(sql)
```

### 5.3 完整查询示例

```lua
-- 带复杂条件的分页查询
function _M:search(options)
    local builder = QueryBuilder:new('users')
    builder.fields = 'id, username, email, status, created_at'

    -- 搜索条件
    if options.keyword and options.keyword ~= '' then
        builder:where('username', 'LIKE', '%' .. options.keyword .. '%')
        builder:or_where('email', 'LIKE', '%' .. options.keyword .. '%')
    end

    if options.status and options.status ~= '' then
        builder:where('status', '=', options.status)
    end

    if options.role_id then
        builder:where('role_id', '=', tonumber(options.role_id))
    end

    -- 排序
    local sorter = options.sorter or 'id'
    local order = options.order == 'ascend' and 'ASC' or 'DESC'
    builder:order_by(sorter, order)

    -- 分页
    local page = tonumber(options.page) or 1
    local pageSize = tonumber(options.pageSize) or 10
    builder:limit(pageSize)
    builder:offset((page - 1) * pageSize)

    -- 执行
    local sql = builder:to_sql()
    return self:query(sql)
end
```

### 5.4 QueryBuilder 方法速查

| 方法 | 用途 | 示例 |
|------|------|------|
| `new(table)` | 创建实例 | `QueryBuilder.new('users')` |
| `select(fields)` | 指定字段 | `builder:select('id, name')` |
| `where(k, op, v)` | 条件 | `builder:where('age', '>', 18)` |
| `or_where()` | 或条件 | `builder:or_where('vip', '=', true)` |
| `where_in()` | IN 条件 | `builder:where_in('id', {1,2,3})` |
| `like()` | LIKE 模糊查询 | `builder:like('name', 'john')` |
| `order_by()` | 排序 | `builder:order_by('id', 'DESC')` |
| `limit()` | 限制数量 | `builder:limit(10)` |
| `offset()` | 偏移量 | `builder:offset(20)` |
| `to_sql()` | 生成 SQL | `builder:to_sql()` |

---

## 6. Model 常用数据库操作方法

### 6.1 连接数据库

```lua
-- Model 自动处理连接，调用方法即可
local model = Model:new()
model:set_table('users')
```

### 6.2 查询方法

#### get_all - 查询多条记录

```lua
-- 简单查询
local users = self:get_all()

-- 带 WHERE 条件
local users = self:get_all({status = 'active'})

-- 带分页
local users = self:get_all({status = 'active'}, 10, 0)  -- limit, offset
```

#### get_by_id - 主键查询

```lua
local user = self:get_by_id(1)
-- 等价于: SELECT * FROM users WHERE id = 1 LIMIT 1
```

#### query - 执行原生 SQL

```lua
local sql = "SELECT * FROM users WHERE status = 'active'"
local rows, err, errno = self:query(sql)
```

#### query_one - 查询单条

```lua
local user = self:query_one("SELECT * FROM users WHERE id = 1")
```

### 6.3 插入方法

#### insert - 插入记录

```lua
-- 插入单条
local id = self:insert({
    username = 'john',
    email = 'john@example.com',
    status = 'active'
})
-- 返回 insert_id

-- 失败返回 false
local ok = self:insert({name = 'test'})
if not ok then
    -- 插入失败
end
```

### 6.4 更新方法

#### update - 更新记录

```lua
-- 更新 (必须带 WHERE 条件)
self:update({status = 'inactive'}, {id = 1})
self:update({name = 'new_name'}, {status = 'active'})
self:update({views = views + 1}, {id = id})  -- 注意：不会自动递增
```

### 6.5 删除方法

#### delete - 删除记录

```lua
-- 删除 (必须带 WHERE 条件)
self:delete({id = 1})
self:delete({status = 'deleted'})
```

### 6.6 统计方法

#### count - 统计数量

```lua
-- 统计全部
local total = self:count()

-- 带条件统计
local active_count = self:count({status = 'active'})
local admin_count = self:count({role = 'admin'})
```

### 6.7 方法速查表

| 方法 | 用途 | 参数 | 返回值 |
|------|------|------|--------|
| `get_all(where, limit, offset)` | 查询多条 | table, num, num | rows table |
| `get_by_id(id)` | 主键查询 | num | row or nil |
| `insert(data)` | 插入数据 | table | insert_id or false |
| `update(data, where)` | 更新数据 | table, table | boolean |
| `delete(where)` | 删除数据 | table | boolean |
| `count(where)` | 统计数量 | table | num |
| `query(sql)` | 原生查询 | string | rows, err, errno |
| `query_one(sql)` | 查询单条 | string | row or nil |

### 6.8 WHERE 条件格式

```lua
-- 简单等值
{status = 'active'}           -- WHERE status = 'active'

-- 数字
{age = 25}                    -- WHERE age = 25

-- 多条件 (AND)
{status = 'active', type = 1} -- WHERE status = 'active' AND type = 1

-- 原生字符串
"status = 'active'"           -- WHERE status = 'active'
```

---

## 7. 完整示例

### 7.1 新增一个功能模块

假设要开发「文章管理」模块：

#### Step 1: 创建 Model

```lua
-- app/models/ArticleModel.lua
local Model = require('app.core.Model')

local _M = setmetatable({}, { __index = Model })
_M._TABLE = 'articles'

function _M.new()
    local model = Model:new()
    model:set_table(_M._TABLE)
    return model
end

-- 业务方法：获取已发布文章
function _M:published()
    return self:get_all({status = 'published'})
end

-- 业务方法：按分类查询
function _M:get_by_category(category_id, limit, offset)
    return self:get_all({category_id = category_id, status = 'published'}, limit, offset)
end

-- 业务方法：统计分类文章数
function _M:count_by_category(category_id)
    return self:count({category_id = category_id})
end

return _M
```

#### Step 2: 创建 Controller

```lua
-- app/controllers/article.lua
local Controller = require('app.core.Controller')

local _M = {}

function _M:__construct()
    Controller.__construct(self)
    self:load('article_model')
end

function _M:index()
    local page = tonumber(self:get('page')) or 1
    local limit = tonumber(self.get['limit']) or 10
    local offset = (page - 1) * limit

    local articles = self.article_model:published()
    local total = self.article_model:count({status = 'published'})

    self:json({
        success = true,
        data = articles,
        total = total,
        page = page,
        limit = limit
    })
end

function _M:show(id)
    if not id then
        self:json({success = false, error = 'ID required'}, 400)
        return
    end

    local article = self.article_model:get_by_id(id)
    if article then
        self:json({success = true, data = article})
    else
        self:json({success = false, error = 'Article not found'}, 404)
    end
end

function _M:create()
    local data = {
        title = self:post('title'),
        content = self:post('content'),
        category_id = tonumber(self:post('category_id')),
        status = 'draft'
    }

    if not data.title then
        self:json({success = false, error = 'Title required'}, 400)
        return
    end

    local id = self.article_model:insert(data)
    self:json({success = true, data = {id = id}}, 201)
end

function _M:update(id)
    if not id then
        self:json({success = false, error = 'ID required'}, 400)
        return
    end

    local data = {
        title = self:post('title'),
        content = self:post('content')
    }

    self.article_model:update(data, {id = tonumber(id)})
    self:json({success = true})
end

function _M:delete(id)
    if not id then
        self:json({success = false, error = 'ID required'}, 400)
        return
    end

    self.article_model:delete({id = tonumber(id)})
    self:json({success = true})
end

return _M
```

#### Step 3: 注册路由

```lua
-- app/routes.lua
function M(route)
    -- 简单路由
    route:get('/articles', 'article:index')
    route:get('/articles/{id}', 'article:show')
    route:post('/articles', 'article:create')
    route:put('/articles/{id}', 'article:update')
    route:delete('/articles/{id}', 'article:delete')
end
```

### 7.2 使用 QueryBuilder 处理复杂查询

```lua
-- app/models/ArticleModel.lua
local Model = require('app.core.Model')
local QueryBuilder = require('app.db.query')

local _M = setmetatable({}, { __index = Model })
_M._TABLE = 'articles'

function _M.new()
    local model = Model:new()
    model:set_table(_M._TABLE)
    return model
end

-- 复杂搜索 (使用 QueryBuilder)
function _M:search(options)
    local builder = QueryBuilder:new('articles')
    builder.fields = 'id, title, summary, author, created_at, view_count'

    -- 关键词搜索
    if options.keyword and options.keyword ~= '' then
        builder:where('title', 'LIKE', '%' .. options.keyword .. '%')
        builder:or_where('content', 'LIKE', '%' .. options.keyword .. '%')
    end

    -- 分类筛选
    if options.category_id then
        builder:where('category_id', '=', tonumber(options.category_id))
    end

    -- 状态筛选
    if options.status and options.status ~= '' then
        builder:where('status', '=', options.status)
    end

    -- 日期范围
    if options.start_date then
        builder:where('created_at', '>=', options.start_date)
    end
    if options.end_date then
        builder:where('created_at', '<=', options.end_date)
    end

    -- 排序
    local sorter = options.sorter or 'created_at'
    local order = options.order == 'ascend' and 'ASC' or 'DESC'
    builder:order_by(sorter, order)

    -- 分页
    local page = tonumber(options.page) or 1
    local pageSize = tonumber(options.pageSize) or 10
    builder:limit(pageSize)
    builder:offset((page - 1) * pageSize)

    -- 执行查询
    local sql = builder:to_sql()
    return self:query(sql)
end

-- 统计搜索结果
function _M:search_count(options)
    local builder = QueryBuilder:new('articles')
    builder.fields = 'COUNT(*) as total'

    if options.keyword and options.keyword ~= '' then
        builder:where('title', 'LIKE', '%' .. options.keyword .. '%')
    end

    if options.category_id then
        builder:where('category_id', '=', tonumber(options.category_id))
    end

    local sql = builder:to_sql()
    local rows = self:query(sql, 1)
    return rows and tonumber(rows[1].total) or 0
end

return _M
```

---

## 8. 常见问题

### Q1: 什么时候用 Model，什么时候用 QueryBuilder？

```lua
-- ✅ 用 Model 内置方法 (简单操作)
self:get_all({status = 'active'})
self:get_by_id(1)
self:insert({name = 'John'})
self:update({name = 'New'}, {id = 1})
self:delete({status = 'deleted'})
self:count({type = 'vip'})

-- ✅ 用 QueryBuilder (复杂查询)
local builder = QueryBuilder:new('users')
builder:select('id, name, email')
builder:where('status', '=', 'active')
builder:where('age', '>', 18)
builder:or_where('role', '=', 'admin')
builder:like('name', 'john')
builder:order_by('created_at', 'DESC')
builder:limit(10)
builder:offset(20)
local sql = builder:to_sql()
```

### Q2: 如何防止 SQL 注入？

```lua
-- ✅ 安全：使用参数化查询
self:insert({username = user_input})  -- 自动转义
self:get_all({status = user_input})

-- ✅ 安全：QueryBuilder 自动转义
builder:where('name', '=', user_input)  -- 自动转义

-- ❌ 危险：拼接字符串
local sql = "SELECT * FROM users WHERE name = '" .. user_input .. "'"  -- SQL 注入风险！
```

### Q3: 如何处理事务？

```lua
-- 使用 query_helper
local db = require('app.helpers.query_helper')

local ok, err = db.transaction(function()
    -- 业务操作
    db.insert('users', {username = 'user1'})
    db.update('users', {email = 'new@email.com'}, {username = 'user1'})
end)

if ok then
    -- 事务成功
else
    -- 事务回滚
end
```

### Q4: 如何使用连接池？

Model 自动管理连接池，无需手动处理：

```lua
-- Model 自动处理
local model = Model:new()
model:set_table('users')
model:get_all()  -- 自动从连接池获取连接
model:set_keepalive()  -- 自动放回连接池
```

---

## 9. 总结

| 层级 | 职责 | 最佳实践 |
|------|------|---------|
| **Router** | URL 映射 | 保持简洁，复杂逻辑在 Controller |
| **Controller** | 请求/响应 | 不写 SQL，只调用 Model |
| **Model** | 数据操作 | 使用内置方法，封装业务逻辑 |
| **QueryBuilder** | 复杂查询 | 仅用于 WHERE/ORDER/LIMIT 组合 |

**核心原则**：
1. Controller 负责接收请求、返回响应
2. Model 负责所有数据库操作
3. QueryBuilder 用于复杂查询条件
4. 永远不要在 Controller 中写原生 SQL
