local _M = {}

function _M:new()
    return setmetatable({}, {__index = _M})
end

function _M:get_all_menus()
    local rows = {}

    local all_menus = {
        {id = 1, parent_id = 0, path = '/dashboard', name = 'dashboard', title = '仪表盘', icon = 'dashboard', component = '', keep_alive = 1, sort_order = 1},
        {id = 2, parent_id = 1, path = '/dashboard/analysis', name = 'analysis', title = '分析页', icon = 'smile', component = './dashboard/analysis', keep_alive = 1, sort_order = 1},
        {id = 3, parent_id = 1, path = '/dashboard/monitor', name = 'monitor', title = '监控页', icon = 'smile', component = './dashboard/monitor', keep_alive = 1, sort_order = 2},
        {id = 4, parent_id = 1, path = '/dashboard/workplace', name = 'workplace', title = '工作台', icon = 'smile', component = './dashboard/workplace', keep_alive = 1, sort_order = 3},
        {id = 5, parent_id = 0, path = '/form', name = 'form', title = '表单页', icon = 'form', component = '', keep_alive = 1, sort_order = 2},
        {id = 6, parent_id = 5, path = '/form/basic-form', name = 'basic-form', title = '基础表单', icon = 'smile', component = './form/basic-form', keep_alive = 1, sort_order = 1},
        {id = 7, parent_id = 5, path = '/form/step-form', name = 'step-form', title = '分步表单', icon = 'smile', component = './form/step-form', keep_alive = 1, sort_order = 2},
        {id = 8, parent_id = 5, path = '/form/advanced-form', name = 'advanced-form', title = '高级表单', icon = 'smile', component = './form/advanced-form', keep_alive = 1, sort_order = 3},
        {id = 9, parent_id = 0, path = '/list', name = 'list', title = '列表页', icon = 'table', component = '', keep_alive = 1, sort_order = 3},
        {id = 10, parent_id = 9, path = '/list/search', name = 'search-list', title = '搜索列表', icon = 'smile', component = './list/search', keep_alive = 1, sort_order = 1},
        {id = 11, parent_id = 9, path = '/list/table-list', name = 'table-list', title = '查询表格', icon = 'smile', component = './list/table-list', keep_alive = 1, sort_order = 2},
        {id = 12, parent_id = 0, path = '/admin', name = 'admin', title = '管理员', icon = 'user', component = '', keep_alive = 1, sort_order = 4},
        {id = 13, parent_id = 12, path = '/admin/role', name = 'role', title = '角色管理', icon = 'team', component = './admin/role', keep_alive = 1, sort_order = 1},
        {id = 14, parent_id = 12, path = '/admin/admin-list', name = 'admin-list', title = '管理员列表', icon = 'solution', component = './admin/admin-list', keep_alive = 1, sort_order = 2},
    }

    for i, menu in ipairs(all_menus) do
        table.insert(rows, {
            id = menu.id,
            parent_id = menu.parent_id,
            path = menu.path,
            name = menu.name,
            title = menu.title,
            icon = menu.icon,
            component = menu.component,
            keep_alive = menu.keep_alive,
            sort_order = menu.sort_order,
            status = 1
        })
    end

    return rows
end

function _M:build_menu_tree(menus)
    if not menus or #menus == 0 then
        return {}
    end

    local menu_map = {}
    local roots = {}

    for _, menu in ipairs(menus) do
        menu.routes = {}
        menu_map[menu.id] = menu
    end

    for _, menu in ipairs(menus) do
        if menu.parent_id == 0 or menu.parent_id == nil then
            table.insert(roots, menu)
        else
            local parent = menu_map[menu.parent_id]
            if parent then
                table.insert(parent.routes, menu)
            end
        end
    end

    return roots
end

function _M:get_menu_tree()
    local menus, err = self:get_all_menus()
    if err then
        return nil, err
    end

    return self:build_menu_tree(menus)
end

return _M
