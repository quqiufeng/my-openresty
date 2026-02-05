# MyResty 数据访问层最佳实践

## 目录

- [1. Model vs QueryBuilder 核心区别](#1-model-vs-querybuilder-核心区别)
- [2. 搭配使用原则](#2-搭配使用原则)
- [3. Model 自带方法详解](#3-model-自带方法详解)
- [4. QueryBuilder 方法详解](#4-querybuilder-方法详解)
- [5. system_menu 表 CRUD 完整示例](#5-system_menu-表-crud-完整示例)

---

## 1. Model vs QueryBuilder 核心区别

### 1.1 本质区别

| 特性 | Model | QueryBuilder |
|------|-------|--------------|
| **定位** | 数据访问层 (执行 SQL) | SQL 构建器 (生成 SQL) |
| **职责** | 执行数据库操作 | 构建查询语句 |
| **返回值** | 查询结果 rows | SQL 字符串 |
| **连接管理** | 自动管理连接池 | 不管理连接 |
| **适用场景** | 简单 CRUD 操作 | 复杂查询条件 |

### 1.2 代码对比

```lua
-- Model: 直接执行，返回结果
local rows = self:get_all({status = 1})
-- 实际执行: SELECT * FROM system_menu WHERE status = 1

-- QueryBuilder: 生成 SQL 字符串
local builder = QueryBuilder:new('system_menu')
builder:where('status', '=', 1)
local sql = builder:to_sql()
-- 返回: "SELECT * FROM system_menu WHERE status = 1"
-- 需要手动执行: self:query(sql)
```

### 1.3 选择指南

```
简单操作 ──────→ Model 自带方法
    │
    │  简单等值条件
    │  单表查询
    │  标准 CRUD
    │  主键操作
    │
    ↓
复杂查询 ──────→ QueryBuilder
    │
    │  多条件组合
    │  LIKE 模糊查询
    │  WHERE IN 列表
    │  多字段排序
    │  分页查询
    │
    ↓
生成 SQL ──────→ QueryBuilder:to_sql()
```

---

## 2. 搭配使用原则

### 2.1 黄金法则

> **简单操作用 Model，复杂查询用 QueryBuilder**

### 2.2 场景对照表

| 场景 | 推荐方式 | 示例 |
|------|---------|------|
| 主键查询 | Model | `get_by_id(1)` |
| 简单插入 | Model | `insert({name = 'test'})` |
| 简单更新 | Model | `update({name = 'new'}, {id = 1})` |
| 简单删除 | Model | `delete({status = 0})` |
| 统计数量 | Model | `count({status = 1})` |
| 简单查询 | Model | `get_all({type = 'menu'})` |
| 多条件 AND | QueryBuilder | `where('a', '=', 1):where('b', '=', 2)` |
| OR 条件 | QueryBuilder | `where():or_where()` |
| 模糊搜索 | QueryBuilder | `like('name', '%admin%')` |
| IN 列表 | QueryBuilder | `where_in('id', {1,2,3})` |
| 多字段排序 | QueryBuilder | `order_by('a'):order_by('b')` |
| 分页查询 | QueryBuilder | `limit(10):offset(20)` |
| 自定义字段 | QueryBuilder | `select('id, name, title')` |

### 2.3 混合使用示例

```lua
-- 先用 QueryBuilder 构建复杂查询，再用 Model 执行
local builder = QueryBuilder:new('system_menu')
builder:select('id, path, name, title')
builder:where('status', '=', 1)
builder:like('path', '/system')
builder:order_by('sort', 'ASC')
builder:limit(10)

local sql = builder:to_sql()  -- 生成 SQL
local rows = self:query(sql)  -- Model 执行

-- 对比：简单查询直接用 Model
local rows = self:get_all({status = 1})  -- 自动生成简单 WHERE
```

---

## 3. Model 自带方法详解

### 3.1 方法速查

| 方法 | 用途 | 示例 | 生成的 SQL |
|------|------|------|-----------|
| `get_all(where, limit, offset)` | 查询多条 | `get_all({status=1}, 10, 0)` | `SELECT * WHERE status=1 LIMIT 10 OFFSET 0` |
| `get_by_id(id)` | 主键查询 | `get_by_id(5)` | `SELECT * WHERE id=5 LIMIT 1` |
| `insert(data)` | 插入记录 | `insert({name='test'})` | `INSERT INTO ...` |
| `update(data, where)` | 更新记录 | `update({name='new'}, {id=1})` | `UPDATE ... WHERE id=1` |
| `delete(where)` | 删除记录 | `delete({status=0})` | `DELETE FROM ... WHERE status=0` |
| `count(where)` | 统计数量 | `count({status=1})` | `SELECT COUNT(*) WHERE status=1` |
| `query(sql)` | 执行 SQL | `query("SELECT * ...")` | 传入什么执行什么 |
| `set_table(name)` | 设置表名 | `set_table('users')` | - |

### 3.2 get_all - 查询多条记录

```lua
-- 1. 查询所有记录
local rows = self:get_all()
-- SQL: SELECT * FROM system_menu

-- 2. 带 WHERE 条件 (简单等值)
local rows = self:get_all({status = 1})
-- SQL: SELECT * FROM system_menu WHERE status = 1

-- 3. 带分页
local rows = self:get_all({status = 1}, 10, 0)  -- limit=10, offset=0
-- SQL: SELECT * FROM system_menu WHERE status = 1 LIMIT 10 OFFSET 0

-- 4. 多条件 (自动用 AND 连接)
local rows = self:get_all({status = 1, keep_alive = 1})
-- SQL: SELECT * FROM system_menu WHERE status = 1 AND keep_alive = 1
```

### 3.3 get_by_id - 主键查询

```lua
-- 根据主键 ID 查询
local menu = self:get_by_id(1)
-- SQL: SELECT * FROM system_menu WHERE id = 1 LIMIT 1

-- 返回 nil 表示记录不存在
if menu then
    -- 找到记录
else
    -- 未找到
end
```

### 3.4 insert - 插入记录

```lua
-- 1. 插入单条记录
local id = self:insert({
    path = '/system/user',
    name = 'user',
    title = '用户管理',
    icon = 'user',
    sort = 1,
    status = 1
})
-- SQL: INSERT INTO system_menu (path, name, title, icon, sort, status) 
--      VALUES ('/system/user', 'user', '用户管理', 'user', 1, 1)

-- 返回插入的 ID，失败返回 false
if id then
    ngx.say('插入成功，ID:', id)
else
    ngx.say('插入失败')
end

-- 2. 插入时自动添加时间戳
local id = self:insert({
    path = '/system/role',
    name = 'role',
    title = '角色管理',
    created_at = ngx.time(),
    updated_at = ngx.time()
})
```

### 3.5 update - 更新记录

```lua
-- 1. 更新单条 (必须带 WHERE)
self:update({title = '用户列表'}, {id = 1})
-- SQL: UPDATE system_menu SET title = '用户列表' WHERE id = 1

-- 2. 更新多条 (带条件)
self:update({status = 0, updated_at = ngx.time()}, {parent_id = 5})
-- SQL: UPDATE system_menu SET status = 0, updated_at = 1739999999 WHERE parent_id = 5

-- 3. 批量更新
self:update({sort = 10}, {id = {1, 2, 3}})  -- 注意：Model 不直接支持 IN，需要用 QueryBuilder
```

### 3.6 delete - 删除记录

```lua
-- 1. 删除单条 (必须带 WHERE)
self:delete({id = 10})
-- SQL: DELETE FROM system_menu WHERE id = 10

-- 2. 批量删除
self:delete({status = -1})
-- SQL: DELETE FROM system_menu WHERE status = -1

-- 3. 删除并返回影响行数
-- Model 的 delete 返回 boolean，实际影响行数在数据库层面
```

### 3.7 count - 统计数量

```lua
-- 1. 统计全部
local total = self:count()
-- SQL: SELECT COUNT(*) as cnt FROM system_menu
-- 返回: 25

-- 2. 带条件统计
local total = self:count({status = 1})
-- SQL: SELECT COUNT(*) as cnt FROM system_menu WHERE status = 1
-- 返回: 18

-- 3. 复杂条件统计 (需要用 QueryBuilder)
local builder = QueryBuilder:new('system_menu')
builder.fields = 'COUNT(*) as total'
builder:where('status', '=', 1)
builder:where('parent_id', '=', 0)
local sql = builder:to_sql()
local rows = self:query(sql, 1)
local total = tonumber(rows[1].total)
-- SQL: SELECT COUNT(*) as total FROM system_menu WHERE status = 1 AND parent_id = 0
```

### 3.8 query - 执行原生 SQL

```lua
-- 1. 执行任意 SQL
local sql = "SELECT id, path, name FROM system_menu WHERE status = 1 ORDER BY sort ASC"
local rows, err, errno = self:query(sql)

-- 2. 带参数
-- 注意：直接拼接有 SQL 注入风险，建议用参数化
local user_input = ngx.var.arg_keyword
local sql = string.format("SELECT * FROM system_menu WHERE name LIKE '%%%s%%'", user_input)
-- 或使用 QueryBuilder 更安全
local builder = QueryBuilder:new('system_menu')
builder:like('name', '%' .. user_input .. '%')
local sql = builder:to_sql()
```

---

## 4. QueryBuilder 方法详解

### 4.1 方法速查

| 方法 | 用途 | 示例 | 生成 SQL |
|------|------|------|----------|
| `new(table)` | 创建实例 | `QueryBuilder.new('system_menu')` | - |
| `select(fields)` | 指定字段 | `select('id, name, title')` | `SELECT id, name, title` |
| `where(k, op, v)` | AND 条件 | `where('status', '=', 1)` | `WHERE status = 1` |
| `or_where()` | OR 条件 | `or_where('a', '=', 1)` | `OR a = 1` |
| `where_in(k, arr)` | IN 列表 | `where_in('id', {1,2,3})` | `WHERE id IN (1,2,3)` |
| `like(k, v)` | 模糊匹配 | `like('name', 'admin')` | `WHERE name LIKE '%admin%'` |
| `order_by(f, d)` | 排序 | `order_by('sort', 'DESC')` | `ORDER BY sort DESC` |
| `limit(n)` | 限制数量 | `limit(10)` | `LIMIT 10` |
| `offset(n)` | 偏移量 | `offset(20)` | `OFFSET 20` |
| `to_sql()` | 生成 SQL | `to_sql()` | 返回完整 SQL |

### 4.2 new - 创建实例

```lua
-- 引入 QueryBuilder
local QueryBuilder = require('app.db.query')

-- 创建查询构建器
local builder = QueryBuilder.new('system_menu')
-- 或在 Model 中
local builder = QueryBuilder:new('system_menu')
```

### 4.3 select - 指定查询字段

```lua
-- 1. 查询所有字段 (默认)
local builder = QueryBuilder:new('system_menu')
local sql = builder:to_sql()
-- SQL: SELECT * FROM system_menu

-- 2. 指定字段
local builder = QueryBuilder:new('system_menu')
builder:select('id, path, name, title')
local sql = builder:to_sql()
-- SQL: SELECT id, path, name, title FROM system_menu

-- 3. 使用别名
local builder = QueryBuilder:new('system_menu')
builder:select('id, name, title, FROM_UNIXTIME(created_at) as created_time')
local sql = builder:to_sql()
-- SQL: SELECT id, name, title, FROM_UNIXTIME(created_at) as created_time FROM system_menu
```

### 4.4 where - 条件过滤

```lua
-- 1. 等于 (=)
local builder = QueryBuilder:new('system_menu')
builder:where('status', '=', 1)
local sql = builder:to_sql()
-- SQL: SELECT * FROM system_menu WHERE status = 1

-- 2. 大于 (>)
local builder = QueryBuilder:new('system_menu')
builder:where('sort', '>', 5)
local sql = builder:to_sql()
-- SQL: SELECT * FROM system_menu WHERE sort > 5

-- 3. 小于 (<)
local builder = QueryBuilder:new('system_menu')
builder:where('sort', '<', 10)
local sql = builder:to_sql()
-- SQL: SELECT * FROM system_menu WHERE sort < 10

-- 4. 不等于 (!=)
local builder = QueryBuilder:new('system_menu')
builder:where('status', '!=', 0)
local sql = builder:to_sql()
-- SQL: SELECT * FROM system_menu WHERE status != 0

-- 5. 多条件 (自动 AND)
local builder = QueryBuilder:new('system_menu')
builder:where('status', '=', 1)
builder:where('parent_id', '=', 0)
builder:where('keep_alive', '=', 1)
local sql = builder:to_sql()
-- SQL: SELECT * FROM system_menu WHERE status = 1 AND parent_id = 0 AND keep_alive = 1

-- 6. 字符串值自动转义
local builder = QueryBuilder:new('system_menu')
builder:where('name', '=', "O'Reilly")  -- 包含单引号
local sql = builder:to_sql()
-- SQL: SELECT * FROM system_menu WHERE name = 'O''Reilly'  -- 自动转义
```

### 4.5 or_where - OR 条件

```lua
-- 1. OR 条件
local builder = QueryBuilder:new('system_menu')
builder:where('status', '=', 1)
builder:or_where('status', '=', 2)
local sql = builder:to_sql()
-- SQL: SELECT * FROM system_menu WHERE status = 1 OR status = 2

-- 2. 混合 AND/OR
local builder = QueryBuilder:new('system_menu')
builder:where('status', '=', 1)
builder:where('parent_id', '=', 0)
builder:or_where('parent_id', '=', 1)
local sql = builder:to_sql()
-- SQL: SELECT * FROM system_menu WHERE status = 1 AND parent_id = 0 OR parent_id = 1
-- 注意：OR 优先级较低，实际按括号分组可能不同

-- 3. 建议用清晰的方式
local builder = QueryBuilder:new('system_menu')
builder:where('parent_id', '=', 0)
builder:or_where(function()
    builder:where('status', '=', 1)
    builder:where('is_special', '=', 1)
end)
-- Lua 闭包方式实现复杂 OR
```

### 4.6 where_in - IN 列表

```lua
-- 1. ID 列表查询
local builder = QueryBuilder:new('system_menu')
builder:where_in('id', {1, 2, 3, 5, 8})
local sql = builder:to_sql()
-- SQL: SELECT * FROM system_menu WHERE id IN (1, 2, 3, 5, 8)

-- 2. 状态列表
local builder = QueryBuilder:new('system_menu')
builder:where_in('status', {1, 2})
local sql = builder:to_sql()
-- SQL: SELECT * FROM system_menu WHERE status IN (1, 2)

-- 3. 空数组处理
local builder = QueryBuilder:new('system_menu')
builder:where_in('id', {})  -- 空数组
local sql = builder:to_sql()
-- SQL: SELECT * FROM system_menu WHERE id IN ()  -- 无效 SQL，实际应处理
```

### 4.7 like - 模糊匹配

```lua
-- 1. 前后都匹配
local builder = QueryBuilder:new('system_menu')
builder:like('name', 'system')
local sql = builder:to_sql()
-- SQL: SELECT * FROM system_menu WHERE name LIKE '%system%'

-- 2. 前缀匹配
local builder = QueryBuilder:new('system_menu')
builder:like('path', '/system')
local sql = builder:to_sql()
-- SQL: SELECT * FROM system_menu WHERE path LIKE '%/system%'

-- 3. 组合使用
local builder = QueryBuilder:new('system_menu')
builder:where('status', '=', 1)
builder:like('name', '管理')
builder:order_by('sort', 'ASC')
local sql = builder:to_sql()
-- SQL: SELECT * FROM system_menu WHERE status = 1 AND name LIKE '%管理%' ORDER BY sort ASC
```

### 4.8 order_by - 排序

```lua
-- 1. 单字段升序
local builder = QueryBuilder:new('system_menu')
builder:order_by('sort', 'ASC')
local sql = builder:to_sql()
-- SQL: SELECT * FROM system_menu ORDER BY sort ASC

-- 2. 单字段降序
local builder = QueryBuilder:new('system_menu')
builder:order_by('sort', 'DESC')
local sql = builder:to_sql()
-- SQL: SELECT * FROM system_menu ORDER BY sort DESC

-- 3. 多字段排序
local builder = QueryBuilder:new('system_menu')
builder:order_by('parent_id', 'ASC')
builder:order_by('sort', 'ASC')
local sql = builder:to_sql()
-- SQL: SELECT * FROM system_menu ORDER BY parent_id ASC, sort ASC

-- 4. 默认排序 (不指定方向时用 ASC)
local builder = QueryBuilder:new('system_menu')
builder:order_by('id')
local sql = builder:to_sql()
-- SQL: SELECT * FROM system_menu ORDER BY id ASC
```

### 4.9 limit - 限制数量

```lua
-- 1. 基本使用
local builder = QueryBuilder:new('system_menu')
builder:limit(10)
local sql = builder:to_sql()
-- SQL: SELECT * FROM system_menu LIMIT 10

-- 2. 限制最大返回行数
local builder = QueryBuilder:new('system_menu')
builder:limit(100)  -- 最多返回 100 条
local sql = builder:to_sql()
-- SQL: SELECT * FROM system_menu LIMIT 100
```

### 4.10 offset - 偏移量

```lua
-- 1. 分页查询 (第一页)
local builder = QueryBuilder:new('system_menu')
builder:limit(10)
builder:offset(0)
local sql = builder:to_sql()
-- SQL: SELECT * FROM system_menu LIMIT 10 OFFSET 0

-- 2. 分页查询 (第二页)
local builder = QueryBuilder:new('system_menu')
builder:limit(10)
builder:offset(10)
local sql = builder:to_sql()
-- SQL: SELECT * FROM system_menu LIMIT 10 OFFSET 10

-- 3. 分页查询 (第 N 页)
local page = tonumber(ngx.var.arg_page) or 1
local pageSize = 10
local offset = (page - 1) * pageSize

local builder = QueryBuilder:new('system_menu')
builder:where('status', '=', 1)
builder:order_by('sort', 'ASC')
builder:limit(pageSize)
builder:offset(offset)
local sql = builder:to_sql()
-- 假设 page=3: SQL: SELECT * FROM system_menu WHERE status = 1 ORDER BY sort ASC LIMIT 10 OFFSET 20
```

### 4.11 完整查询示例

```lua
-- 构建复杂查询
local builder = QueryBuilder:new('system_menu')

-- 选择字段
builder:select('id, path, name, title, icon, sort, status, parent_id')

-- 条件过滤
builder:where('status', '=', 1)                      -- 状态启用
builder:where('parent_id', '=', 0)                   -- 一级菜单
builder:like('title', '系统')                         -- 标题包含"系统"

-- 排序分页
builder:order_by('sort', 'ASC')                      -- 按排序升序
builder:limit(10)                                    -- 每页 10 条
builder:offset(0)                                    -- 第一页

-- 生成 SQL
local sql = builder:to_sql()
-- 生成的 SQL:
-- SELECT id, path, name, title, icon, sort, status, parent_id 
-- FROM system_menu 
-- WHERE status = 1 
-- AND parent_id = 0 
-- AND title LIKE '%系统%' 
-- ORDER BY sort ASC 
-- LIMIT 10 OFFSET 0

-- 执行查询
local rows = self:query(sql)
```

---

## 5. system_menu 表 CRUD 完整示例

### 5.1 表结构假设

```sql
CREATE TABLE `system_menu` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `path` varchar(100) DEFAULT '' COMMENT '路由路径',
  `name` varchar(50) DEFAULT '' COMMENT '菜单名称',
  `title` varchar(100) DEFAULT '' COMMENT '显示标题',
  `icon` varchar(50) DEFAULT '' COMMENT '图标',
  `component` varchar(200) DEFAULT '' COMMENT '组件路径',
  `parent_id` int(11) DEFAULT 0 COMMENT '父级ID',
  `sort` int(11) DEFAULT 0 COMMENT '排序',
  `status` tinyint(1) DEFAULT 1 COMMENT '状态:0-禁用,1-启用',
  `keep_alive` tinyint(1) DEFAULT 0 COMMENT '是否缓存:0-否,1-是',
  `created_at` int(11) DEFAULT 0 COMMENT '创建时间',
  `updated_at` int(11) DEFAULT 0 COMMENT '更新时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='系统菜单表';
```

### 5.2 Model 层实现

```lua
-- app/models/MenuModel.lua
local Model = require('app.core.Model')
local QueryBuilder = require('app.db.query')

local _M = setmetatable({}, { __index = Model })
_M._TABLE = 'system_menu'

function _M.new()
    local model = Model:new()
    model:set_table(_M._TABLE)
    return model
end

-- ========== Model 自带方法 (简单操作) ==========

-- 1. 查询全部启用菜单 (Model:get_all)
function _M:get_enabled()
    return self:get_all({status = 1})
end
-- SQL: SELECT * FROM system_menu WHERE status = 1

-- 2. 根据 ID 查询 (Model:get_by_id)
function _M:get_by_id(id)
    return Model.get_by_id(self, id)
end
-- SQL: SELECT * FROM system_menu WHERE id = <id> LIMIT 1

-- 3. 插入新菜单 (Model:insert)
function _M:create(data)
    data.created_at = ngx.time()
    data.updated_at = ngx.time()
    return self:insert(data)
end
-- SQL: INSERT INTO system_menu (path, name, title, ..., created_at, updated_at) 
--      VALUES ('...', '...', '...', ..., <time>, <time>)

-- 4. 更新菜单 (Model:update)
function _M:update_menu(id, data)
    data.updated_at = ngx.time()
    return self:update(data, {id = tonumber(id)})
end
-- SQL: UPDATE system_menu SET title = '...', updated_at = <time> WHERE id = <id>

-- 5. 删除菜单 (Model:delete)
function _M:remove(id)
    return self:delete({id = tonumber(id)})
end
-- SQL: DELETE FROM system_menu WHERE id = <id>

-- 6. 统计菜单数量 (Model:count)
function _M:total()
    return self:count()
end
-- SQL: SELECT COUNT(*) as cnt FROM system_menu

-- 7. 统计启用数量 (Model:count)
function _M:enabled_count()
    return self:count({status = 1})
end
-- SQL: SELECT COUNT(*) as cnt FROM system_menu WHERE status = 1

-- ========== QueryBuilder (复杂查询) ==========

-- 8. 分页查询 (QueryBuilder)
function _M:get_list(options)
    options = options or {}
    local page = tonumber(options.page) or 1
    local pageSize = tonumber(options.pageSize) or 10
    local offset = (page - 1) * pageSize

    local builder = QueryBuilder:new('system_menu')
    builder:select('id, path, name, title, icon, sort, status, parent_id')

    -- 状态筛选
    if options.status and options.status ~= '' then
        builder:where('status', '=', tonumber(options.status))
    end

    -- 关键词搜索
    if options.keyword and options.keyword ~= '' then
        builder:like('name', options.keyword)
        builder:or_where('title', options.keyword)
    end

    -- 排序
    local sorter = options.sorter or 'sort'
    local order = options.order == 'ascend' and 'ASC' or 'DESC'
    builder:order_by(sorter, order)

    -- 分页
    builder:limit(pageSize)
    builder:offset(offset)

    local sql = builder:to_sql()
    -- 示例 SQL (page=1, pageSize=10, keyword='系统'):
    -- SELECT id, path, name, title, icon, sort, status, parent_id 
    -- FROM system_menu 
    -- WHERE (name LIKE '%系统%' OR title LIKE '%系统%') 
    -- ORDER BY sort ASC 
    -- LIMIT 10 OFFSET 0

    return self:query(sql)
end

-- 9. 获取菜单总数 (带查询条件)
function _M:search_count(options)
    options = options or {}

    local builder = QueryBuilder:new('system_menu')
    builder.fields = 'COUNT(*) as total'

    if options.status and options.status ~= '' then
        builder:where('status', '=', tonumber(options.status))
    end

    if options.keyword and options.keyword ~= '' then
        builder:like('name', options.keyword)
        builder:or_where('title', options.keyword)
    end

    local sql = builder:to_sql()
    -- 示例 SQL:
    -- SELECT COUNT(*) as total FROM system_menu 
    -- WHERE (name LIKE '%系统%' OR title LIKE '%系统%')

    local rows = self:query(sql, 1)
    return tonumber(rows and rows[1].total or 0)
end

-- 10. 获取子菜单 (QueryBuilder)
function _M:get_children(parent_id)
    local builder = QueryBuilder:new('system_menu')
    builder:select('id, path, name, title, icon, sort')
    builder:where('parent_id', '=', tonumber(parent_id))
    builder:where('status', '=', 1)
    builder:order_by('sort', 'ASC')
    local sql = builder:to_sql()
    -- SQL: SELECT id, path, name, title, icon, sort 
    --      FROM system_menu WHERE parent_id = <id> AND status = 1 ORDER BY sort ASC

    return self:query(sql)
end

-- 11. 批量获取菜单 (WHERE IN)
function _M:get_by_ids(ids)
    if not ids or #ids == 0 then
        return {}
    end

    local builder = QueryBuilder:new('system_menu')
    builder:where_in('id', ids)
    builder:order_by('sort', 'ASC')
    local sql = builder:to_sql()
    -- SQL: SELECT * FROM system_menu WHERE id IN (1,2,3,5,8) ORDER BY sort ASC

    return self:query(sql)
end

-- 12. 按路径查询 (QueryBuilder)
function _M:get_by_path(path)
    local builder = QueryBuilder:new('system_menu')
    builder:where('path', '=', path)
    builder:limit(1)
    local sql = builder:to_sql()
    -- SQL: SELECT * FROM system_menu WHERE path = '/system/user' LIMIT 1

    local rows = self:query(sql)
    return rows and rows[1] or nil
end

-- 13. 更新排序 (Model:update)
function _M:update_sort(id, sort)
    return self:update({sort = tonumber(sort)}, {id = tonumber(id)})
end
-- SQL: UPDATE system_menu SET sort = <sort> WHERE id = <id>

-- 14. 更新状态 (Model:update)
function _M:update_status(id, status)
    return self:update({status = tonumber(status), updated_at = ngx.time()}, {id = tonumber(id)})
end
-- SQL: UPDATE system_menu SET status = <status>, updated_at = <time> WHERE id = <id>

return _M
```

### 5.3 Controller 层实现

```lua
-- app/controllers/menu.lua
local Controller = require('app.core.Controller')

local _M = {}

function _M:__construct()
    Controller.__construct(self)
    self:load('menu_model')  -- 加载 MenuModel
end

-- ========== CREATE ==========
function _M:create()
    local data = {
        path = self:post('path'),
        name = self:post('name'),
        title = self:post('title'),
        icon = self:post('icon') or '',
        component = self:post('component') or '',
        parent_id = tonumber(self:post('parent_id')) or 0,
        sort = tonumber(self:post('sort')) or 0,
        status = tonumber(self:post('status')) or 1,
        keep_alive = tonumber(self:post('keep_alive')) or 0
    }

    -- 参数验证
    if not data.path or not data.name or not data.title then
        self:json({success = false, error = 'path, name, title 必填'}, 400)
        return
    end

    -- 使用 Model:insert
    local id = self.menu_model:create(data)

    if id then
        self:json({success = true, data = {id = id}, message = '创建成功'}, 201)
    else
        self:json({success = false, error = '创建失败'}, 500)
    end
end

-- ========== READ ==========
function _M:list()
    local options = {
        page = self:get('page'),
        pageSize = self:get('pageSize'),
        status = self:get('status'),
        keyword = self:get('keyword'),
        sorter = self:get('sorter'),
        order = self:get('order')
    }

    -- 使用 QueryBuilder 构建的 get_list
    local list = self.menu_model:get_list(options)
    local total = self.menu_model:search_count(options)

    self:json({
        success = true,
        data = list or {},
        total = total,
        page = tonumber(options.page) or 1,
        pageSize = tonumber(options.pageSize) or 10
    })
end

function _M:show(id)
    if not id then
        self:json({success = false, error = 'ID 必填'}, 400)
        return
    end

    -- 使用 Model:get_by_id
    local menu = self.menu_model:get_by_id(id)

    if menu then
        self:json({success = true, data = menu})
    else
        self:json({success = false, error = '菜单不存在'}, 404)
    end
end

function _M:children()
    local parent_id = tonumber(self:get('parent_id')) or 0

    -- 使用 QueryBuilder 构建的 get_children
    local children = self.menu_model:get_children(parent_id)

    self:json({
        success = true,
        data = children or {}
    })
end

-- ========== UPDATE ==========
function _M:update(id)
    if not id then
        self:json({success = false, error = 'ID 必填'}, 400)
        return
    end

    local data = {}
    local post = self.request.post or {}

    if post.path then data.path = post.path end
    if post.name then data.name = post.name end
    if post.title then data.title = post.title end
    if post.icon then data.icon = post.icon end
    if post.component then data.component = post.component end
    if post.parent_id then data.parent_id = tonumber(post.parent_id) end
    if post.sort then data.sort = tonumber(post.sort) end
    if post.status then data.status = tonumber(post.status) end
    if post.keep_alive then data.keep_alive = tonumber(post.keep_alive) end

    -- 使用 Model:update
    local success = self.menu_model:update_menu(id, data)

    if success then
        self:json({success = true, message = '更新成功'})
    else
        self:json({success = false, error = '更新失败'}, 500)
    end
end

function _M:update_sort(id)
    if not id then
        self:json({success = false, error = 'ID 必填'}, 400)
        return
    end

    local sort = tonumber(self:post('sort'))
    if not sort then
        self:json({success = false, error = 'sort 必填'}, 400)
        return
    end

    -- 使用 Model:update
    local success = self.menu_model:update_sort(id, sort)

    if success then
        self:json({success = true, message = '排序更新成功'})
    else
        self:json({success = false, error = '排序更新失败'}, 500)
    end
end

function _M:update_status(id)
    if not id then
        self:json({success = false, error = 'ID 必填'}, 400)
        return
    end

    local status = tonumber(self:post('status'))
    if not status then
        self:json({success = false, error = 'status 必填'}, 400)
        return
    end

    -- 使用 Model:update
    local success = self.menu_model:update_status(id, status)

    if success then
        self:json({success = true, message = '状态更新成功'})
    else
        self:json({success = false, error = '状态更新失败'}, 500)
    end
end

-- ========== DELETE ==========
function _M:delete(id)
    if not id then
        self:json({success = false, error = 'ID 必填'}, 400)
        return
    end

    -- 使用 Model:delete
    local success = self.menu_model:remove(id)

    if success then
        self:json({success = true, message = '删除成功'})
    else
        self:json({success = false, error = '删除失败'}, 500)
    end
end

-- ========== 特殊功能 ==========
function _M:tree()
    -- 获取树形结构
    local menu_tree = self.menu_model:get_menu_tree()
    local formatted = self.menu_model:format_menus_for_antd(menu_tree)

    self:json({
        success = true,
        data = formatted
    })
end

return _M
```

### 5.4 路由注册

```lua
-- app/routes.lua
function M(route)
    -- 菜单 CRUD
    route:get('/menu/list', 'menu:list')
    route:get('/menu/{id}', 'menu:show')
    route:post('/menu', 'menu:create')
    route:put('/menu/{id}', 'menu:update')
    route:delete('/menu/{id}', 'menu:delete')

    -- 菜单子项
    route:get('/menu/children', 'menu:children')

    -- 排序和状态
    route:put('/menu/{id}/sort', 'menu:update_sort')
    route:put('/menu/{id}/status', 'menu:update_status')

    -- 树形结构
    route:get('/menu/tree', 'menu:tree')
end
```

### 5.5 API 调用示例

```bash
# 创建菜单
POST /menu
Content-Type: application/json

{
    "path": "/system/user",
    "name": "user",
    "title": "用户管理",
    "icon": "user",
    "parent_id": 0,
    "sort": 1,
    "status": 1
}

# 查询列表 (带分页和搜索)
GET /menu/list?page=1&pageSize=10&keyword=系统&status=1

# 查询详情
GET /menu/1

# 更新菜单
PUT /menu/1
Content-Type: application/json

{
    "title": "用户列表",
    "sort": 5
}

# 更新排序
PUT /menu/1/sort
Content-Type: application/json

{
    "sort": 10
}

# 更新状态
PUT /menu/1/status
Content-Type: application/json

{
    "status": 0
}

# 删除菜单
DELETE /menu/1

# 获取子菜单
GET /menu/children?parent_id=0

# 获取树形结构
GET /menu/tree
```

---

## 6. 总结

### 6.1 快速选择

| 操作类型 | 推荐方式 | 示例 |
|---------|---------|------|
| 主键查询 | Model | `get_by_id(1)` |
| 简单 WHERE | Model | `get_all({status=1})` |
| 插入记录 | Model | `insert({name='test'})` |
| 更新记录 | Model | `update({name='new'}, {id=1})` |
| 删除记录 | Model | `delete({id=1})` |
| 统计数量 | Model | `count({status=1})` |
| 多条件查询 | QueryBuilder | `where():where():order_by()` |
| OR 条件 | QueryBuilder | `where():or_where()` |
| 模糊搜索 | QueryBuilder | `like('name', 'key')` |
| IN 列表 | QueryBuilder | `where_in('id', {1,2,3})` |
| 分页查询 | QueryBuilder | `limit():offset()` |

### 6.2 代码规范

```lua
-- ✅ 推荐：简单操作用 Model
function _M:get_active()
    return self:get_all({status = 1})  -- 简单 WHERE
end

function _M:create_menu(data)
    data.created_at = ngx.time()
    return self:insert(data)  -- 直接插入
end

-- ✅ 推荐：复杂查询用 QueryBuilder
function _M:search(options)
    local builder = QueryBuilder:new('system_menu')
    builder:select('id, name, title')
    builder:where('status', '=', 1)
    builder:like('title', options.keyword or '')
    builder:order_by('sort', 'ASC')
    builder:limit(10)
    builder:offset(0)
    return self:query(builder:to_sql())
end

-- ❌ 不推荐：重复造轮子
function _M:simple_search()
    local sql = "SELECT * FROM system_menu WHERE status = 1"  -- 应该用 Model
end
```
