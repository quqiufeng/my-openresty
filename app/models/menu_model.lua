local mysql = require('app.lib.mysql')

local _M = {}

function _M:new()
    return setmetatable({}, {__index = _M})
end

function _M:get_all_menus()
    local db = mysql:new()
    local ok, err = db:connect({
        host = '127.0.0.1',
        port = 3306,
        user = 'root',
        password = '123456',
        database = 'project',
        pool_size = 10
    })
    if not ok then
        ngx.log(ngx.ERR, 'Failed to connect to database: ', err)
        return nil, err
    end

    local sql = "SELECT id, parent_id, path, name, title, icon, component, keep_alive, sort_order, status FROM system_menu WHERE status = 1 ORDER BY parent_id ASC, sort_order ASC"

    local rows, err = db:query(sql)
    db:close()

    if err then
        return nil, err
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
