# MyResty Integration Tests

## 简介

本目录包含MyResty框架的集成测试脚本，通过curl命令测试完整的HTTP请求-响应流程。

## 文件说明

- `test.sh` - 集成测试主脚本
- `nginx_test.conf` - 测试用的Nginx配置文件（包含所有测试路由）

## 快速开始

### 1. 启动Nginx

```bash
# 复制测试配置到Nginx配置目录
sudo cp nginx_test.conf /etc/nginx/conf.d/myresty_test.conf

# 测试配置语法
sudo nginx -t

# 重启Nginx
sudo systemctl restart nginx

# 或者开发模式下启动
openresty -c /etc/nginx/conf.d/myresty_test.conf
```

### 2. 运行测试

```bash
# 运行所有测试
./test.sh

# 详细模式运行
./test.sh -v

# 只测试路由器和会话
./test.sh router session

# 指定测试URL
BASE_URL=http://localhost:8080 ./test.sh
```

### 3. 测试选项

```bash
./test.sh -h  # 显示帮助

# 可用的测试类型:
# - all       所有测试 (默认)
# - router    路由器测试
# - session   会话测试
# - helper    帮助器测试
# - cache     缓存测试
# - query     查询构建器测试
# - response  响应测试
# - middleware 中间件测试
# - upload    文件上传测试
```

## 测试内容

### 路由器测试 (Router)
- GET/POST/PUT/DELETE 路由注册
- 路由参数提取
- 查询参数处理
- 404错误处理

### 会话测试 (Session)
- 用户登录/登出
- Session创建和读取
- 购物车功能
- 认证保护

### 帮助器测试 (Helper)
- 日期格式化
- UUID/随机字符串生成
- 邮箱/URL/手机号验证
- XSS过滤和HTML转义
- Base64编码解码
- MD5哈希
- 数组分页

### 缓存测试 (Cache)
- 缓存读取和写入
- 缓存失效

### 查询构建器测试 (QueryBuilder)
- 基础查询
- 条件过滤
- 排序和分页

### 响应测试 (Response)
- JSON/HTML/Text/XML响应
- 重定向
- 自定义状态码和响应头

### 中间件测试 (Middleware)
- 请求日志
- CORS跨域
- 速率限制
- 认证中间件

### 文件上传测试 (Upload)
- 文件上传

## 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| BASE_URL | 测试基础URL | http://localhost:8080 |

示例:
```bash
BASE_URL=http://api.example.com:9000 ./test.sh router
```

## 输出说明

测试输出使用颜色标识:
- 🟢 `[PASS]` - 测试通过
- 🔴 `[FAIL]` - 测试失败
- 🟡 `[SKIP]` - 测试跳过
- 🔵 `[INFO]` - 信息提示

## 报告

测试完成后会生成详细报告，包括:
- 测试总数
- 通过/失败数量
- 通过率

报告保存位置: `/tmp/myresty_test_report.txt`

## 故障排除

### Nginx无法启动
```bash
# 检查配置语法
sudo nginx -t

# 查看错误日志
sudo tail -f /var/log/nginx/error.log
```

### 连接被拒绝
```bash
# 确保Nginx已启动
sudo systemctl status nginx

# 检查端口是否正确
netstat -tlnp | grep nginx
```

### 测试失败
```bash
# 使用详细模式查看具体错误
./test.sh -v

# 检查单个测试
curl -v http://localhost:8080/api/users
```

## 添加新测试

### 1. 在nginx_test.conf中添加路由

```nginx
location /test/my-feature {
    content_by_lua_block {
        local Response = require('app.core.Response')
        -- 测试逻辑
        Response:json({result = "success"})
    end}
}
```

### 2. 在test.sh中添加测试函数

```bash
test_my_feature() {
    echo ""
    echo "=== 我的功能测试 ==="
    curl_get "/test/my-feature" "测试我的功能"
}
```

### 3. 在main()中调用

```bash
if [ "$run_all" = true ] || [ "$run_my_feature" = true ]; then
    test_my_feature
fi
```
