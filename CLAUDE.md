# MyResty Framework - AI 开发指南

本文档用于指导 AI 大模型理解和开发本项目，涵盖项目架构、开发规范、历史教训、测试要求等关键信息。

---

## 1. 项目概述

### 基本信息

| 项目名称 | MyResty Framework |
|----------|------------------|
| 基于框架 | OpenResty (Nginx + Lua) |
| 语言 | Lua + LuaJIT 2.1 |
| 数据库 | MySQL 8.0 |
| 缓存 | Redis 6.x |
| 操作系统 | Ubuntu 24.04 LTS |

### 项目定位

基于 OpenResty 的 Web 框架，参考 PHP CodeIgniter 设计理念，提供 MVC 架构、ORM、路由、中间件等企业级功能。

### 核心特性

- MVC 架构分层清晰
- 统一 CRUD 代码生成器
- 自动 JOIN 支持
- Ant Design Pro 完美兼容
- 企业级会话管理（加密）
- 共享字典高性能缓存
- 验证码 + 图像处理
- HTTP 客户端
- 日志系统
- 限流中间件

---

## 2. 技术栈与环境

### 目录结构

```
/var/www/web/my-openresty/           # 项目根目录
├── nginx/
│   └── conf/
│       ├── nginx.conf               # 主 nginx 配置（模板）
│       └── myresty.conf             # MyResty 服务器配置
├── app/
│   ├── core/                        # 核心框架
│   │   ├── Config.lua               # 配置管理
│   │   ├── Router.lua               # 路由分发
│   │   ├── Request.lua              # 请求处理
│   │   ├── Response.lua             # 响应处理
│   │   ├── Controller.lua           # 控制器基类
│   │   ├── Model.lua                # 模型基类
│   │   └── QueryBuilder.lua         # 查询构建器
│   ├── controllers/                 # 控制器层
│   ├── models/                     # 数据模型层
│   ├── libraries/                  # 库文件
│   ├── middleware/                 # 中间件
│   └── utils/                      # 工具类
├── tests/
│   ├── unit/                       # 单元测试
│   └── integration/                 # 集成测试
├── docs/                           # 文档
└── myresty                        # CLI 工具
```

### 系统包安装命令

```bash
# 基础编译工具
apt-get update && apt-get install -y build-essential

# MySQL 客户端
apt-get install -y default-mysql-client

# Redis 客户端
apt-get install -y redis-tools

# Lua 和 OpenResty 依赖
apt-get install -y \
    libc6-dev \
    libgd-dev \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libwebp-dev \
    libfontconfig1-dev \
    libssl-dev \
    zlib1g-dev \
    libpcre3-dev

# 验证码字体
apt-get install -y fonts-wqy-microhei fonts-wqy-zenhei
```

### LuaJIT 安装

```bash
# 默认安装路径
/usr/local/web/luajit/bin/luajit

# 创建软链接（必须）
sudo ln -s /usr/local/web/luajit/bin/luajit /usr/local/bin/luajit

# 验证版本
luajit -v
# 输出: LuaJIT 2.1.ROLLING -- Copyright (C) 2005-2025 Mike Pall.
```

### Nginx 安装与配置

```bash
# 安装路径
/usr/local/web/nginx/

# 启动命令
/usr/local/web/nginx/sbin/nginx

# 重启命令
/usr/local/web/nginx/sbin/nginx -s reload

# 主配置文件
/usr/local/web/nginx/conf/nginx.conf

# 项目配置文件（会被主配置 include）
/var/www/web/my-openresty/nginx/conf/myresty.conf

# FastCGI 配置
/var/www/web/my-openresty/nginx/conf/fcgi.conf
```

### 关键 nginx 配置项

```nginx
# myresty.conf 关键配置
lua_package_path "/var/www/web/my-openresty/?.lua;;";
lua_package_cpath "/var/www/web/my-openresty/?.so;;";

set $root /var/www/web/my-openresty;

content_by_lua_file $root/bootstrap.lua;
```

### 服务启动顺序

```bash
# 1. 启动 Redis
redis-server /etc/redis/redis.conf

# 2. 启动 MySQL
systemctl start mysql

# 3. 启动 Nginx
/usr/local/web/nginx/sbin/nginx

# 验证服务
curl http://localhost:8080/
curl http://localhost:6379/info
mysql -u root -p -e "SHOW DATABASES"
```

---

## 3. 开发规范

### 命名约定

#### 文件命名

| 类型 | 规范 | 示例 |
|------|------|------|
| 控制器 | 小写，`.lua` 结尾 | `user.lua`, `admin.lua` |
| 模型 | PascalCase，`Model.lua` 结尾 | `UserModel.lua`, `RoleModel.lua` |
| 库文件 | 小写，`.lua` 结尾 | `mysql.lua`, `redis.lua` |
| 中间件 | 小写，`.lua` 结尾 | `auth.lua`, `cors.lua` |
| 测试文件 | `*_test.lua` | `query_builder_test.lua` |

#### 变量命名

| 类型 | 规范 | 示例 |
|------|------|------|
| 局部变量 | 小写下划线 | `local user_name`, `local page_size` |
| 模块变量 | 单一下划线前缀 | `local _M = {}` |
| 常量 | 全大写下划线 | `local MAX_SIZE = 100` |
| QueryBuilder 实例 | 统一用 `b` | `local b = QB:new("admin")` |
| Model 实例 | 统一用 `m` | `local m = UserModel:new()` |
| Controller `self` | 直接使用 | `function _M:index() self:json({}) end` |

#### 禁用模式（历史教训）

```lua
-- ❌ 禁止：MySQL 连接关闭
mysql:close()

-- ✅ 必须：连接池复用
mysql:set_keepalive(10000, 100)

-- ❌ 禁止：破坏单例
function _M:__construct()
    self.response = Response:new()  -- 覆盖了传入的实例
end

-- ✅ 必须：条件创建
function _M:__construct()
    if not self.response then
        self.response = Response:new()
    end
end

-- ❌ 禁止：相对路径
lua_package_path "./app/?.lua;;"

-- ✅ 必须：绝对路径
lua_package_path "/var/www/web/my-openresty/?.lua;;"

-- ❌ 禁止：未定义的变量
builder:left_join("role")  -- 'builder' 未定义

-- ✅ 必须：一致的变量名
local b = QB:new("admin")
b:left_join("role")
```

---

## 4. MVC 架构规范

### 架构层次

```
Controller (请求处理) → Model (数据访问) → MySQL/Redis
        ↑                   ↑
     继承                继承
app.core.Controller   app.core.Model
                           ↓
                     app.lib.mysql → resty.mysql
```

### Controller 规范

```lua
-- 基础控制器
local C = require("app.core.Controller")
local _M = {}

function _M:new()
    local instance = C:new()
    -- 必须使用 self. 注入的方式加载模型
    instance.user_model = self:load_model("user")
    return setmetatable(instance, { __index = _M })
end

-- 标准方法命名
function _M:index()      -- 列表
function _M:show()        -- 详情
function _M:create()     -- 新建
function _M:update()     -- 更新
function _M:delete()     -- 删除
```

### Model 规范

```lua
-- 基础模型
local M = require("app.core.Model")
local QB = require("app.db.query")
local _M = {}
_M._TABLE = "users"

function _M.new()
    local o = M:new()
    o:set_table(_M._TABLE)
    return o
end

-- 标准方法命名
function _M:get_list(o)      -- 列表查询
function _M:get_by_id(id)    -- 按ID查询
function _M:insert(data)     -- 插入
function _M:update(data, where) -- 更新
function _M:delete(where)     -- 删除
function _M:count(o)         -- 统计
```

### 数据访问原则

- **简单操作** → 使用 Model 自带方法 (`get_all`, `insert`, `update`, `delete`)
- **复杂查询** → 使用 QueryBuilder (`where`, `order_by`, `join`, `limit`, `offset`)
- **禁止** 在 Controller 中直接写原始 SQL
- **禁止** 在 Model 外部访问数据库

---

## 5. 历史 Bug 与解决方案

### Bug #1：MySQL 连接池问题

**问题**: 使用 `close()` 导致 "Got packets out of order" 错误

**解决方案**: 使用 `set_keepalive()` 替代 `close()`

```lua
-- 错误
local mysql = Mysql:new()
-- ... 操作 ...
mysql:close()  -- 断开连接

-- 正确
local mysql = Mysql:new()
-- ... 操作 ...
mysql:set_keepalive(10000, 100)  -- 10秒超时，100连接池
```

### Bug #2：Response 单例被破坏

**问题**: Controller `__construct()` 覆盖了 bootstrap 传递的 Response 实例

**症状**: `/menu/list` 接口返回 `{}` 空数据

**解决方案**: 条件创建

```lua
function _M:__construct()
    if not self.response then  -- 关键：检查是否已存在
        self.response = Response:new()
    end
end
```

### Bug #3：nginx 相对路径失效

**问题**: `$root` 变量引用相对路径导致配置失效

**解决方案**: 使用绝对路径

```nginx
# 错误
set $app_root ./nginx;

# 正确
set $root /var/www/web/my-openresty;
lua_package_path "/var/www/web/my-openresty/?.lua;;";
```

### Bug #4：代码生成器变量名错误

**问题**: 生成器使用未定义的变量名

```lua
-- 错误：变量名不一致
local b = QB:new("admin")
builder:left_join("role")  -- 'builder' 未定义

-- 正确：变量名一致
local b = QB:new("admin")
b:left_join("role")
```

**教训**: 代码生成器必须遵循统一命名规范，生成后必须验证

---

## 6. 测试规范

### 测试文件命名

| 类型 | 规范 | 示例 |
|------|------|------|
| 单元测试 | `tests/unit/models/*_spec.lua` | `admin_spec.lua` |
| 控制器测试 | `tests/unit/controllers/*Spec.lua` | `AdminSpec.lua` |
| 集成测试 | `tests/integration/crud/*.sh` | `Admin.sh` |

### 自动生成测试

代码生成器会自动生成以下测试文件：

```bash
# 生成 CRUD 后自动生成
luajit myresty curd /path/to/admin.json

# 生成文件列表
app/models/{Name}Model.lua       # 数据模型
app/controllers/{Name}.lua       # 统一接口控制器
tests/unit/models/{name}_spec.lua    # Model 单元测试
tests/unit/controllers/{Name}Spec.lua # Controller 单元测试
tests/integration/crud/{Name}.sh      # 集成测试
```

### 运行测试

```bash
# 1. 语法检查
luajit -c app/models/UserModel.lua

# 2. 运行单元测试
luajit tests/unit/models/admin_spec.lua        # Model 测试
luajit tests/unit/controllers/AdminSpec.lua    # Controller 测试

# 3. 运行 QueryBuilder 测试
luajit tests/unit/query_builder_test.lua
luajit tests/unit/model_join_test.lua
luajit tests/unit/model_prefix_test.lua

# 4. 运行集成测试
./tests/integration/crud/Admin.sh

# 5. API 接口测试
curl http://localhost:8080/admin/list
```

### 测试覆盖率要求

- **QueryBuilder**: 所有 public 方法必须有测试 (60+ tests)
- **Model**: CRUD 方法必须有测试 (7+ tests per model)
- **Controller**: 5 个接口必须有测试 (8+ tests per controller)

### 测试通过标准

```bash
# 单元测试
✓ PASS: test_name
✗ FAIL: test_name

# 集成测试
✓ PASS: API name
✗ FAIL: API name

# 退出码
0 = 全部通过
1 = 有失败
```

---

## 7. 代码生成器规范

### CLI 命令

```bash
# 创建软链接
sudo ln -s /usr/local/web/luajit/bin/luajit /usr/local/bin/luajit

# CRUD 生成（从 JSON 配置）
luajit myresty curd /path/to/admin.json
luajit myresty curd < /path/to/admin.json  # 支持输入重定向

# 代码生成
./myresty make:controller User
./myresty make:model Article
./myresty make:middleware Auth
./myresty make:library Payment
./myresty make:migration create_users
./myresty make:seeder Users
```

### JSON 配置格式

配置文件路径：`/home/quqiufeng/my-ant-design-pro/scripts/admin.json`

```json
{
  "path": "/admin/admin-list",
  "table": "admin",
  "search_field": [
    "username",
    "phone",
    {
      "field": "role_id",
      "type": "select",
      "api": "/api/role",
      "displayField": "name",
      "valueField": "id"
    }
  ],
  "list_field": [
    "id",
    "username",
    "phone",
    "role_id",
    "left join role on role_id=id display name as role_name"
  ],
  "create_field": ["username", "password", "phone", "role_id"],
  "update_field": ["username", "password", "phone", "role_id"]
}
```

### 生成的文件

| 文件 | 说明 |
|------|------|
| `app/models/{Name}Model.lua` | 数据模型 |
| `app/controllers/{Name}.lua` | 统一接口控制器 |
| `tests/unit/models/{name}_spec.lua` | Model 单元测试 |
| `tests/unit/controllers/{Name}Spec.lua` | Controller 单元测试 |
| `tests/integration/crud/{Name}.sh` | 集成测试 |

### 生成后必须执行

```bash
# 生成后运行测试验证
luajit tests/unit/models/{name}_spec.lua
luajit tests/unit/controllers/{Name}Spec.lua
./tests/integration/crud/{Name}.sh
```

### 生成器编码规则

1. **变量命名统一**: QueryBuilder 用 `b`，Model 用 `m`
2. **自动生成测试**: 生成器自动生成单元测试和集成测试
3. **目录自动创建**: 自动创建 tests/unit/models 目录

---

## 8. API 接口规范

### 响应格式

```json
{
  "success": true,
  "message": "success",
  "data": {},
  "total": 10,
  "page": 1,
  "pageSize": 10
}
```

### 错误响应

```json
{
  "success": false,
  "message": "id required",
  "data": null
}
```

### 状态码

| 状态码 | 说明 |
|--------|------|
| 200 | 成功 |
| 201 | 创建成功 |
| 400 | 缺少必要参数 |
| 404 | 记录不存在 |
| 500 | 服务器错误 |

### 统一 CRUD 接口

| 接口 | 方法 | 说明 |
|------|------|------|
| `/admin/list` | ANY | 列表查询（分页） |
| `/admin/detail` | ANY | 详情查询 |
| `/admin/create` | ANY | 新建 |
| `/admin/update` | ANY | 更新 |
| `/admin/delete` | ANY | 删除 |

### 请求参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `page` | number | 否 | 当前页码，默认 1 |
| `pageSize` | number | 否 | 每页数量，默认 10 |
| `keyword` | string | 否 | 关键词搜索 |
| `id` | number | 是 | 记录 ID |

---

## 9. 配置说明

### 数据库配置

```lua
-- app/config/mysql.lua
local config = {
    host = "127.0.0.1",
    port = 3306,
    database = "myresty",
    user = "root",
    password = "password",
    charset = "utf8mb4",
    max_pool_size = 100,
    keepalive_timeout = 10000,
    pool_size = 100
}
```

### Redis 配置

```lua
-- app/config/redis.lua
local config = {
    host = "127.0.0.1",
    port = 6379,
    password = "",
    database = 0,
    timeout = 2000,
    pool_size = 100
}
```

### 应用配置

```lua
-- app/config/config.lua
local config = {
    table_prefix = "",  -- 表前缀，区分不同项目
    default_page_size = 10,
    max_page_size = 100,
    session_secret = "your-session-secret",
    encryption_key = "your-encryption-key"
}
```

---

## 10. 常用命令速查

### 服务管理

```bash
# 启动服务
/usr/local/web/nginx/sbin/nginx           # Nginx
redis-server /etc/redis/redis.conf       # Redis
systemctl start mysql                    # MySQL

# 重启服务
/usr/local/web/nginx/sbin/nginx -s reload
redis-cli shutdown && redis-server /etc/redis/redis.conf
systemctl restart mysql

# 服务状态
redis-cli ping                           # Redis 连接测试
mysql -u root -p -e "SHOW STATUS"        # MySQL 状态
```

### 开发调试

```bash
# LuaJIT 语法检查
luajit -c app/models/UserModel.lua

# 运行单元测试
luajit tests/unit/query_builder_test.lua
luajit tests/unit/model_join_test.lua
luajit tests/unit/model_prefix_test.lua

# 运行集成测试
./tests/integration/crud/Admin.sh

# API 测试
curl http://localhost:8080/
curl "http://localhost:8080/admin/list?page=1&pageSize=10"
```

### 代码生成

```bash
# CRUD 生成
luajit myresty curd /home/quqiufeng/my-ant-design-pro/scripts/admin.json

# 组件生成
./myresty make:controller User
./myresty make:model Article
./myresty make:middleware Auth
./myresty make:library Payment
```

---

## 11. 开发检查清单

每次修改代码后必须检查：

- [ ] LuaJIT 语法检查通过 (`luajit -c`)
- [ ] 相关单元测试通过
- [ ] 集成测试通过
- [ ] API 接口响应正常
- [ ] 没有使用禁用模式
- [ ] 命名符合规范
- [ ] 文档已同步更新

---

## 12. 快速开始（AI 专用）

### 首次理解项目

```bash
# 1. 查看项目结构
ls -la /var/www/web/my-openresty/

# 2. 查看核心文件
cat /var/www/web/my-openresty/app/core/Controller.lua
cat /var/www/web/my-openresty/app/core/Model.lua

# 3. 查看配置文件
cat /var/www/web/my-openresty/app/config/config.lua

# 4. 运行基准测试
luajit tests/unit/query_builder_test.lua
```

### 添加新功能流程

1. **理解现有代码**: 查看同类功能的实现
2. **遵守命名规范**: 参考本文件的命名约定
3. **写测试**: 先写测试或同时写代码
4. **验证**: 运行测试确保通过
5. **更新文档**: 同步更新相关文档
6. **提交**: 遵循 commit message 规范

### 常见任务示例

**任务：添加用户头像上传功能**

```lua
-- 1. 参考现有上传功能
cat /var/www/web/my-openresty/app/controllers/upload.lua

-- 2. 参考图片处理
cat /var/www/web/my-openresty/app/utils/image.lua

-- 3. 遵守命名规范
-- Controller: user.lua → upload_avatar() 方法
-- Model: UserModel.lua → update_avatar(user_id, path)

-- 4. 添加路由
-- route:post('/user/avatar', 'user:upload_avatar')

-- 5. 运行测试验证
```

---

## 13. Commit Message 规范

```
<type>: <subject>

<body>

<footer>
```

### Type 类型

| Type | 说明 |
|------|------|
| feat | 新功能 |
| fix | Bug 修复 |
| docs | 文档更新 |
| style | 代码格式（不影响功能） |
| refactor | 重构 |
| test | 测试相关 |
| chore | 构建/辅助工具 |

### 示例

```
feat: 添加用户头像上传功能

- 新增 upload_avatar 方法
- 支持头像裁剪
- 集成 Image 工具类

Closes #123
```

---

## 14. 关键文件速查

| 文件 | 说明 | 关键信息 |
|------|------|----------|
| `bootstrap.lua` | 启动入口 | 配置加载、中间件初始化 |
| `app/core/Controller.lua` | 控制器基类 | 单例传递逻辑 |
| `app/core/Model.lua` | 模型基类 | CRUD 方法 |
| `app/core/QueryBuilder.lua` | 查询构建器 | JOIN、前缀支持 |
| `app/lib/mysql.lua` | MySQL 封装 | 连接池管理 |
| `app/lib/session.lua` | 会话管理 | 加密存储 |
| `app/lib/cache.lua` | 缓存封装 | 共享字典 |
| `app/console/commands/Curd.lua` | CRUD 生成器 | 生成规范 |
| `nginx/conf/myresty.conf` | 服务器配置 | 绝对路径 |

---

## 15. 已知局限与注意事项

1. **LuaJIT 版本**: 必须使用 LuaJIT 2.1，不支持 Lua 5.1+ 原生版本
2. **路径问题**: 所有路径必须使用绝对路径
3. **连接池**: 任何数据库操作必须使用 `set_keepalive()`
4. **单例破坏**: Controller/Model 构造函数必须检查依赖注入
5. **测试环境**: 单元测试不依赖外部服务，集成测试需要完整环境

---

**本文档版本**: 1.0  
**最后更新**: 2026-02-05  
**维护者**: AI Development Team
