-- MenuModel Model
-- 菜单模型

local Model = require('app.core.Model')
local QueryBuilder = require('app.db.query')

local _M = setmetatable({}, { __index = Model })
_M._TABLE = 'system_menu'

function _M.new()
    local model = Model:new()
    model:set_table(_M._TABLE)
    return model
end

function _M:get_all_menus()
    return self:get_all({ status = 1 }, nil, nil)
end

function _M:get_menu_tree()
    local menus = self:get_all_menus()
    if not menus or #menus == 0 then
        return {}
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

    local function build_tree(menu_list)
        local menu_map = {}
        local roots = {}

        for _, menu in ipairs(menu_list) do
            menu.routes = {}
            menu_map[menu.path] = menu
        end

        for _, menu in ipairs(menu_list) do
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

    return build_tree(menus)
end

function _M:format_menus_for_antd(menu_tree)
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

    local function format_item(menu)
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
            item.routes = {}
            for _, child in ipairs(menu.routes) do
                table.insert(item.routes, format_item(child))
            end
        end

        return item
    end

    local result = {}
    for _, menu in ipairs(menu_tree) do
        table.insert(result, format_item(menu))
    end

    return result
end

return _M
