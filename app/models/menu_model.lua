--[[
    菜单数据模型
    用于构建 Ant Design Pro 左侧菜单数据
    支持无限级嵌套的树形结构

    数据结构说明：
    - id: 菜单唯一标识
    - parent_id: 父菜单ID（0表示一级菜单）
    - path: 路由路径
    - name: 菜单名称（用于权限标识）
    - title: 菜单标题（显示名称）
    - icon: 图标类型（对应 Ant Design 图标）
    - component: 前端组件路径
    - keep_alive: 是否缓存页面（1=是，0=否）
    - sort_order: 排序权重（越小越靠前）
    - status: 状态（1=启用，0=禁用）
--]]

local _M = {}

--[[
    创建模型实例
    @return table 模型实例
--]]
function _M:new()
    return setmetatable({}, {__index = _M})
end

--[[
    获取所有菜单数据
    这里使用硬编码数据模拟数据库返回
    生产环境应该从数据库读取 system_menu 表

    数据层级说明：
    - parent_id = 0: 一级菜单（顶级菜单）
    - parent_id > 0: 二级或三级菜单（子菜单）

    @return table 扁平化的菜单数组
--]]
function _M:get_all_menus()
    local rows = {}

    -- =====================================================
    -- 一级菜单：仪表盘（Dashboard）
    -- 二级菜单：分析页、监控页、工作台
    -- =====================================================
    local all_menus = {
        -- ---------- 仪表盘（一级） ----------
        {id = 1, parent_id = 0, path = '/dashboard', name = 'dashboard', title = '仪表盘', icon = 'dashboard', component = '', keep_alive = 1, sort_order = 1},
        {id = 2, parent_id = 1, path = '/dashboard/analysis', name = 'analysis', title = '分析页', icon = 'smile', component = './dashboard/analysis', keep_alive = 1, sort_order = 1},
        {id = 3, parent_id = 1, path = '/dashboard/monitor', name = 'monitor', title = '监控页', icon = 'smile', component = './dashboard/monitor', keep_alive = 1, sort_order = 2},
        {id = 4, parent_id = 1, path = '/dashboard/workplace', name = 'workplace', title = '工作台', icon = 'smile', component = './dashboard/workplace', keep_alive = 1, sort_order = 3},

        -- ---------- 表单页（一级） ----------
        {id = 5, parent_id = 0, path = '/form', name = 'form', title = '表单页', icon = 'form', component = '', keep_alive = 1, sort_order = 2},
        {id = 6, parent_id = 5, path = '/form/basic-form', name = 'basic-form', title = '基础表单', icon = 'smile', component = './form/basic-form', keep_alive = 1, sort_order = 1},
        {id = 7, parent_id = 5, path = '/form/step-form', name = 'step-form', title = '分步表单', icon = 'smile', component = './form/step-form', keep_alive = 1, sort_order = 2},
        {id = 8, parent_id = 5, path = '/form/advanced-form', name = 'advanced-form', title = '高级表单', icon = 'smile', component = './form/advanced-form', keep_alive = 1, sort_order = 3},

        -- ---------- 列表页（一级） ----------
        {id = 9, parent_id = 0, path = '/list', name = 'list', title = '列表页', icon = 'table', component = '', keep_alive = 1, sort_order = 3},
        {id = 10, parent_id = 9, path = '/list/search', name = 'search-list', title = '搜索列表', icon = 'smile', component = './list/search', keep_alive = 1, sort_order = 1},
        {id = 11, parent_id = 9, path = '/list/table-list', name = 'table-list', title = '查询表格', icon = 'smile', component = './list/table-list', keep_alive = 1, sort_order = 2},
        {id = 12, parent_id = 9, path = '/list/basic-list', name = 'basic-list', title = '标准列表', icon = 'smile', component = './list/basic-list', keep_alive = 1, sort_order = 3},
        {id = 13, parent_id = 9, path = '/list/card-list', name = 'card-list', title = '卡片列表', icon = 'smile', component = './list/card-list', keep_alive = 1, sort_order = 4},

        -- ---------- 详情页（一级） ----------
        {id = 14, parent_id = 0, path = '/profile', name = 'profile', title = '详情页', icon = 'profile', component = '', keep_alive = 1, sort_order = 4},
        {id = 15, parent_id = 14, path = '/profile/basic', name = 'basic', title = '基础详情页', icon = 'smile', component = './profile/basic', keep_alive = 1, sort_order = 1},
        {id = 16, parent_id = 14, path = '/profile/advanced', name = 'advanced', title = '高级详情页', icon = 'smile', component = './profile/advanced', keep_alive = 1, sort_order = 2},

        -- ---------- 结果页（一级） ----------
        {id = 17, parent_id = 0, path = '/result', name = 'result', title = '结果页', icon = 'CheckCircleOutlined', component = '', keep_alive = 1, sort_order = 5},
        {id = 18, parent_id = 17, path = '/result/success', name = 'success', title = '成功页', icon = 'smile', component = './result/success', keep_alive = 1, sort_order = 1},
        {id = 19, parent_id = 17, path = '/result/fail', name = 'fail', title = '失败页', icon = 'smile', component = './result/fail', keep_alive = 1, sort_order = 2},

        -- ---------- 异常页（一级） ----------
        {id = 20, parent_id = 0, path = '/exception', name = 'exception', title = '异常页', icon = 'warning', component = '', keep_alive = 1, sort_order = 6},
        {id = 21, parent_id = 20, path = '/exception/403', name = '403', title = '403', icon = 'smile', component = './exception/403', keep_alive = 1, sort_order = 1},
        {id = 22, parent_id = 20, path = '/exception/404', name = '404', title = '404', icon = 'smile', component = './exception/404', keep_alive = 1, sort_order = 2},
        {id = 23, parent_id = 20, path = '/exception/500', name = '500', title = '500', icon = 'smile', component = './exception/500', keep_alive = 1, sort_order = 3},

        -- ---------- 个人中心（一级） ----------
        {id = 24, parent_id = 0, path = '/account', name = 'account', title = '个人中心', icon = 'user', component = '', keep_alive = 1, sort_order = 7},
        {id = 25, parent_id = 24, path = '/account/center', name = 'account-center', title = '个人中心', icon = 'smile', component = './account/center', keep_alive = 1, sort_order = 1},
        {id = 26, parent_id = 24, path = '/account/settings', name = 'settings', title = '个人设置', icon = 'smile', component = './account/settings', keep_alive = 1, sort_order = 2},

        -- ---------- 管理员（一级）- 系统管理 ----------
        {id = 27, parent_id = 0, path = '/admin', name = 'admin', title = '管理员', icon = 'user', component = '', keep_alive = 1, sort_order = 8},
        {id = 28, parent_id = 27, path = '/admin/role', name = 'role', title = '角色管理', icon = 'team', component = './admin/role', keep_alive = 1, sort_order = 1},
        {id = 29, parent_id = 27, path = '/admin/admin-list', name = 'admin-list', title = '管理员列表', icon = 'solution', component = './admin/admin-list', keep_alive = 1, sort_order = 2},
    }

    -- 将数据转换为标准格式
    for i, menu in ipairs(all_menus) do
        table.insert(rows, {
            id = menu.id,                    -- 菜单唯一ID
            parent_id = menu.parent_id,      -- 父菜单ID（0=一级菜单）
            path = menu.path,                -- 路由路径，如 /dashboard/analysis
            name = menu.name,                -- 菜单标识，如 dashboard
            title = menu.title,              -- 显示标题，如 仪表盘
            icon = menu.icon,                -- 图标，如 dashboard、smile
            component = menu.component,       -- 前端组件路径
            keep_alive = menu.keep_alive,    -- 是否缓存（1=是）
            sort_order = menu.sort_order,     -- 排序（越小越靠前）
            status = 1                       -- 状态（1=启用）
        })
    end

    return rows
end

--[[
    构建树形菜单结构
    将扁平化的菜单数组转换为嵌套的树形结构

    算法说明：
    1. 先把所有菜单放到 map 中，建立 id -> menu 的映射
    2. 遍历所有菜单，根据 parent_id 构建父子关系
    3. 一级菜单（parent_id=0）放入 roots 数组
    4. 子菜单放入父菜单的 routes 数组中

    @param menus table 扁平化的菜单数组（从数据库读取的原始数据）
    @return table 树形结构的菜单数组（用于前端渲染）
--]]
function _M:build_menu_tree(menus)
    -- 空数据检查
    if not menus or #menus == 0 then
        return {}
    end

    local menu_map = {}   -- 用于 O(1) 快速查找的映射表：id -> menu
    local roots = {}      -- 根节点数组（一级菜单）

    -- 第一步：初始化所有菜单，为每个菜单创建空的 routes 数组
    for _, menu in ipairs(menus) do
        menu.routes = {}  -- 初始化子菜单容器
        menu_map[menu.id] = menu  -- 建立 ID 到菜单对象的映射
    end

    -- 第二步：遍历所有菜单，构建父子关系
    for _, menu in ipairs(menus) do
        if menu.parent_id == 0 or menu.parent_id == nil then
            -- parent_id 为 0 或空的是一级菜单，直接放入 roots
            table.insert(roots, menu)
        else
            -- parent_id > 0 的是子菜单
            -- 从 map 中找到父菜单，添加到父菜单的 routes 中
            local parent = menu_map[menu.parent_id]
            if parent then
                table.insert(parent.routes, menu)
            end
        end
    end

    return roots
end

--[[
    获取完整的树形菜单
    整合 get_all_menus 和 build_menu_tree 两个方法

    @return table 树形菜单数组
    @return string|nil 错误信息（如果有）
--]]
function _M:get_menu_tree()
    -- 1. 获取扁平化的菜单数据
    local menus, err = self:get_all_menus()
    if err then
        return nil, err
    end

    -- 2. 构建树形结构
    return self:build_menu_tree(menus)
end

return _M
