-- MenuModel (canonical menu model)
-- CRUD over the `menu` table plus Ant Design Pro menu-tree helpers.
local M = require("app.core.Model")
local QB = require("app.db.query")

local _M = setmetatable({}, { __index = M })
_M._TABLE = "menu"

function _M.new()
    local o = M:new()
    o:set_table(_M._TABLE)
    return setmetatable(o, { __index = _M })
end

-- ========== CRUD ==========

-- /menu/list - 列表查询
function _M:list(o)
    o = o or {}
    local page = tonumber(o.page) or 1
    local pageSize = tonumber(o.pageSize) or 10
    local b = QB:new("menu")
    b:select("menu.id, menu.name, menu.path, menu.parent_id, menu.sort")
    local sf = { "name" }
    if o.keyword and o.keyword ~= "" then
        for i, f in ipairs(sf) do
            if i == 1 then
                b:where("menu." .. f, "LIKE", "%" .. o.keyword .. "%")
            else
                b:or_where("menu." .. f, "LIKE", "%" .. o.keyword .. "%")
            end
        end
    end
    b:order_by("menu.id", "DESC")
    b:limit(pageSize)
    b:offset((page - 1) * pageSize)
    return self:query(b:to_sql())
end

-- /menu/detail - 详情查询
function _M:detail(o)
    local id = o and o.id
    if not id then return nil end
    local b = QB:new("menu")
    b:select("menu.id, menu.name, menu.path, menu.parent_id, menu.sort")
    b:where("menu.id", "=", tonumber(id))
    b:limit(1)
    local r = self:query(b:to_sql())
    return r and r[1]
end

-- /menu/create - 新建
function _M:create(o)
    local d = o or {}
    local t = ngx and ngx.time() or os.time()
    d.created_at = d.created_at or t
    d.updated_at = t
    return self:insert(d)
end

-- /menu/update - 更新
function _M:update(a, b)
    local id, d
    if type(a) == "table" then d = a; id = a.id else id = a; d = b or {} end
    if not id then return false end
    d.updated_at = ngx and ngx.time() or os.time()
    return M.update(self, d, { id = tonumber(id) })
end

-- /menu/delete - 删除
function _M:delete(a)
    local id = type(a) == "table" and a.id or a
    if not id then return false end
    return M.delete(self, { id = tonumber(id) })
end

-- /menu/count - 统计
function _M:count(o)
    local b = QB:new("menu")
    b:select("COUNT(*) as cnt")
    local sf = { "name" }
    if o and o.keyword and o.keyword ~= "" then
        for i, f in ipairs(sf) do
            if i == 1 then
                b:where("menu." .. f, "LIKE", "%" .. o.keyword .. "%")
            else
                b:or_where("menu." .. f, "LIKE", "%" .. o.keyword .. "%")
            end
        end
    end
    local r = self:query(b:to_sql())
    return r and r[1] and r[1].cnt or 0
end

-- ========== Ant Design Pro menu tree ==========

-- Demo data: in production replace with a query against the menu table.
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
        {id = 12, parent_id = 9, path = '/list/basic-list', name = 'basic-list', title = '标准列表', icon = 'smile', component = './list/basic-list', keep_alive = 1, sort_order = 3},
        {id = 13, parent_id = 9, path = '/list/card-list', name = 'card-list', title = '卡片列表', icon = 'smile', component = './list/card-list', keep_alive = 1, sort_order = 4},

        {id = 14, parent_id = 0, path = '/profile', name = 'profile', title = '详情页', icon = 'profile', component = '', keep_alive = 1, sort_order = 4},
        {id = 15, parent_id = 14, path = '/profile/basic', name = 'basic', title = '基础详情页', icon = 'smile', component = './profile/basic', keep_alive = 1, sort_order = 1},
        {id = 16, parent_id = 14, path = '/profile/advanced', name = 'advanced', title = '高级详情页', icon = 'smile', component = './profile/advanced', keep_alive = 1, sort_order = 2},

        {id = 17, parent_id = 0, path = '/result', name = 'result', title = '结果页', icon = 'CheckCircleOutlined', component = '', keep_alive = 1, sort_order = 5},
        {id = 18, parent_id = 17, path = '/result/success', name = 'success', title = '成功页', icon = 'smile', component = './result/success', keep_alive = 1, sort_order = 1},
        {id = 19, parent_id = 17, path = '/result/fail', name = 'fail', title = '失败页', icon = 'smile', component = './result/fail', keep_alive = 1, sort_order = 2},

        {id = 20, parent_id = 0, path = '/exception', name = 'exception', title = '异常页', icon = 'warning', component = '', keep_alive = 1, sort_order = 6},
        {id = 21, parent_id = 20, path = '/exception/403', name = '403', title = '403', icon = 'smile', component = './exception/403', keep_alive = 1, sort_order = 1},
        {id = 22, parent_id = 20, path = '/exception/404', name = '404', title = '404', icon = 'smile', component = './exception/404', keep_alive = 1, sort_order = 2},
        {id = 23, parent_id = 20, path = '/exception/500', name = '500', title = '500', icon = 'smile', component = './exception/500', keep_alive = 1, sort_order = 3},

        {id = 24, parent_id = 0, path = '/account', name = 'account', title = '个人中心', icon = 'user', component = '', keep_alive = 1, sort_order = 7},
        {id = 25, parent_id = 24, path = '/account/center', name = 'account-center', title = '个人中心', icon = 'smile', component = './account/center', keep_alive = 1, sort_order = 1},
        {id = 26, parent_id = 24, path = '/account/settings', name = 'settings', title = '个人设置', icon = 'smile', component = './account/settings', keep_alive = 1, sort_order = 2},

        {id = 27, parent_id = 0, path = '/admin', name = 'admin', title = '管理员', icon = 'user', component = '', keep_alive = 1, sort_order = 8},
        {id = 28, parent_id = 27, path = '/admin/role', name = 'role', title = '角色管理', icon = 'team', component = './admin/role', keep_alive = 1, sort_order = 1},
        {id = 29, parent_id = 27, path = '/admin/admin-list', name = 'admin-list', title = '管理员列表', icon = 'solution', component = './admin/admin-list', keep_alive = 1, sort_order = 2},
    }

    for _, menu in ipairs(all_menus) do
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

-- Build a nested tree from a flat menu array.
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

-- Format a menu tree for Ant Design Pro front-end consumption.
function _M:format_menus_for_antd(menus)
    local result = {}
    for _, node in ipairs(menus or {}) do
        local item = {
            path = node.path,
            name = node.name,
            title = node.title,
            icon = node.icon,
            keep_alive = node.keep_alive,
        }
        if node.component and node.component ~= '' then
            item.component = node.component
        end
        if node.routes and #node.routes > 0 then
            item.routes = self:format_menus_for_antd(node.routes)
        end
        result[#result + 1] = item
    end
    return result
end

return _M
