--[[
    菜单控制器
    提供 /menu/list 接口，返回 Ant Design Pro 格式的菜单数据
    通过分析 path 字段来确定父子节点关系
--]]

local Controller = require('app.core.Controller')
local MenuModel = require('app.models.MenuModel')

local _M = {}

function _M:__construct()
    Controller.__construct(self)
end

function _M:list()
    local menu_model = MenuModel:new()

    local menu_tree, err = menu_model:get_menu_tree()
    if err then
        self:json({
            success = false,
            status = 500,
            message = '查询失败: ' .. tostring(err),
            data = nil
        }, 500)
        return
    end

    if not menu_tree or #menu_tree == 0 then
        self:json({
            success = true,
            status = 200,
            message = 'success',
            data = {}
        })
        return
    end

    local formatted_menus = menu_model:format_menus_for_antd(menu_tree)

    self:json({
        success = true,
        status = 200,
        message = 'success',
        data = formatted_menus
    })
end

return _M
