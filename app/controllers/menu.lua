--[[
    菜单控制器
    提供 /menu/list 接口，返回 Ant Design Pro 格式的菜单数据

    接口返回格式：
    {
        "success": true,
        "status": 200,
        "message": "success",
        "data": [
            {
                "path": "/dashboard",
                "name": "dashboard",
                "title": "仪表盘",
                "icon": "dashboard",
                "keepAlive": true,
                "component": "",
                "routes": [
                    {
                        "path": "/dashboard/analysis",
                        "name": "analysis",
                        "title": "分析页",
                        "icon": "smile",
                        "keepAlive": true,
                        "component": "./dashboard/analysis"
                    }
                ]
            }
        ]
    }
--]]

local Controller = require('app.core.Controller')
local MenuModel = require('app.models.menu_model')

local _M = {}

--[[
    构造函数
    调用父类 Controller 的初始化方法
--]]
function _M:__construct()
    Controller.__construct(self)
end

--[[
    获取菜单列表接口
    GET /menu/list

    处理流程：
    1. 创建 MenuModel 实例
    2. 调用 get_menu_tree() 获取树形菜单数据
    3. 调用 format_menus() 格式化输出字段
    4. 返回 JSON 响应
--]]
function _M:list()
    -- 1. 创建模型实例
    local menu_model = MenuModel:new()

    -- 2. 获取树形菜单数据
    local menu_tree, err = menu_model:get_menu_tree()

    -- 3. 错误处理
    if err then
        self:json({
            success = false,
            status = 500,
            message = '获取菜单列表失败: ' .. tostring(err),
            data = nil
        }, 500)
        return
    end

    -- 4. 格式化菜单数据（字段转换、类型处理）
    local formatted_menus = self:format_menus(menu_tree)

    -- 5. 返回成功响应
    self:json({
        success = true,
        status = 200,
        message = 'success',
        data = formatted_menus
    })
end

--[[
    格式化菜单数据
    将模型数据转换为前端所需的格式

    字段映射：
    - keep_alive (数据库) -> keepAlive (前端)
    - 驼峰命名转换
    - 空值处理

    @param menus table 树形菜单数组
    @return table 格式化后的菜单数组
--]]
function _M:format_menus(menus)
    -- 空数据检查
    if not menus then
        return {}
    end

    local result = {}

    -- 遍历每个菜单项
    for _, menu in ipairs(menus) do
        -- 构建菜单项
        local item = {
            path = menu.path or '',           -- 路由路径
            name = menu.name or '',            -- 菜单名称
            title = menu.title or '',          -- 显示标题
            icon = menu.icon or '',            -- 图标
            -- 数据库字段 keep_alive (0/1) 转换为前端 keepAlive (boolean)
            keepAlive = menu.keep_alive == 1 or menu.keepAlive == true,
            component = menu.component or ''   -- 组件路径
        }

        -- 递归处理子菜单
        if menu.routes and #menu.routes > 0 then
            item.routes = self:format_menus(menu.routes)
        end

        -- 添加到结果数组
        table.insert(result, item)
    end

    return result
end

return _M
