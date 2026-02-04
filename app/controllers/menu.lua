local Controller = require('app.core.Controller')
local MenuModel = require('app.models.menu_model')

local _M = {}

function _M:__construct()
    Controller.__construct(self)
end

function _M:list()
    local menu_model = MenuModel:new()
    local menu_tree, err = menu_model:get_menu_tree()

    if err then
        ngx.log(ngx.ERR, 'Failed to get menu list: ', err)
        self:json({
            success = false,
            status = 500,
            message = 'Failed to get menu list',
            data = nil
        }, 500)
        return
    end

    local formatted_menus = self:format_menus(menu_tree)

    self:json({
        success = true,
        status = 200,
        message = 'success',
        data = formatted_menus
    })
end

function _M:format_menus(menus)
    if not menus then
        return {}
    end

    local result = {}
    for _, menu in ipairs(menus) do
        local item = {
            path = menu.path or '',
            name = menu.name or '',
            title = menu.title or '',
            icon = menu.icon or '',
            keepAlive = menu.keep_alive == 1 or menu.keepAlive == true
        }

        if menu.routes and #menu.routes > 0 then
            item.routes = self:format_menus(menu.routes)
        end

        table.insert(result, item)
    end

    return result
end

return _M
