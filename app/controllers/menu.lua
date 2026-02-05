--[[
    菜单控制器
    提供 /menu/list 接口，返回 Ant Design Pro 格式的菜单数据
    通过分析 path 字段来确定父子节点关系
--]]

local Controller = require('app.core.Controller')
local _M = {}

function _M:__construct()
    Controller.__construct(self)
end

function _M:list()
    local mysql = require('app.lib.mysql')
    local db = mysql.new()
    mysql.connect(db)

    if not db then
        self:json({
            success = false,
            status = 500,
            message = '连接数据库失败',
            data = nil
        }, 500)
        return
    end

    local sql = "SELECT id, path, name, title, icon, component, keep_alive, sort FROM system_menu WHERE status = 1 ORDER BY sort ASC, path ASC"
    local res, err = mysql.query(db, sql)

    mysql.set_keepalive(db)

    if not res then
        self:json({
            success = false,
            status = 500,
            message = '查询失败: ' .. tostring(err),
            data = nil
        }, 500)
        return
    end

    if not res or #res == 0 then
        self:json({
            success = true,
            status = 200,
            message = 'success',
            data = {}
        })
        return
    end

    local function get_parent_path(path)
        local last_slash = path:match('/([^/]+)$')
        if not last_slash then
            return nil
        end
        local parent = path:sub(1, #path - #last_slash - 1)
        if parent == '' then
            return nil
        end
        return parent
    end

    local function build_tree(menus)
        local menu_map = {}
        local roots = {}

        for _, menu in ipairs(menus) do
            menu.routes = {}
            menu_map[menu.path] = menu
        end

        for _, menu in ipairs(menus) do
            local parent_path = get_parent_path(menu.path)

            if not parent_path then
                table.insert(roots, menu)
            else
                local parent = menu_map[parent_path]
                if parent then
                    table.insert(parent.routes, menu)
                else
                    table.insert(roots, menu)
                end
            end
        end

        return roots
    end

    local function format_menus(menus)
        local result = {}
        for _, menu in ipairs(menus) do
            local is_leaf = get_parent_path(menu.path) ~= nil

            local component = ''
            if is_leaf then
                component = '.' .. menu.path
            end

            local item = {
                path = menu.path,
                name = menu.name or '',
                title = menu.title or '',
                icon = menu.icon or '',
                keepAlive = menu.keep_alive == 1,
                component = component
            }

            if menu.routes and #menu.routes > 0 then
                item.routes = format_menus(menu.routes)
            end

            table.insert(result, item)
        end
        return result
    end

    local menu_tree = build_tree(res)
    local formatted_menus = format_menus(menu_tree)

    self:json({
        success = true,
        status = 200,
        message = 'success',
        data = formatted_menus
    })
end

return _M
