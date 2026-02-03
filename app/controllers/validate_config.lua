local BaseController = require('app.core.Controller')
local Validator = require('app.lib.validator')

local ValidateConfig = {}
setmetatable(ValidateConfig, { __index = BaseController })

function ValidateConfig:index()
    local tables = Validator:list_tables()

    self:json({
        success = true,
        message = 'Config-based Validation API',
        description = 'Validate using rules from config/validation/*.lua files',
        endpoints = {
            'GET /validate-config - This info',
            'GET /validate-config/tables - List all tables',
            'GET /validate-config/table/{name} - Get table rules',
            'POST /validate-config/users/{scenario} - Validate users table',
            'POST /validate-config/products/{scenario} - Validate products table',
            'POST /validate-config/orders/{scenario} - Validate orders table',
            'POST /validate-config/custom - Custom validation'
        },
        available_tables = tables,
        usage = {
            example = 'POST /validate-config/users/create',
            body = {
                username = 'john123',
                email = 'john@example.com',
                password = 'password123',
                password_confirmation = 'password123'
            }
        }
    })
end

function ValidateConfig:tables()
    local tables = Validator:list_tables()
    local table_info = {}

    for _, name in ipairs(tables) do
        local info = Validator:get_table_info(name)
        if info then
            table.insert(table_info, info)
        end
    end

    self:json({
        success = true,
        tables = table_info
    })
end

function ValidateConfig:table_info()
    local table_name = self:get('table') or self:segment(2)

    if not table_name then
        return self:json({
            success = false,
            error = 'Table name required'
        }, 400)
    end

    local fields = Validator:get_all_fields_info(table_name)
    if not fields then
        return self:json({
            success = false,
            error = 'Table not found: ' .. table_name
        }, 404)
    end

    local scenarios = Validator:get_all_scenarios(table_name)

    self:json({
        success = true,
        table = table_name,
        fields = fields,
        scenarios = scenarios
    })
end

function ValidateConfig:users()
    local scenario = self:get('scenario') or self:segment(2) or 'create'
    local data = {
        username = self:post('username'),
        email = self:post('email'),
        password = self:post('password'),
        password_confirmation = self:post('password_confirmation'),
        real_name = self:post('real_name'),
        phone = self:post('phone'),
        age = self:post('age'),
        status = self:post('status'),
        role = self:post('role')
    }

    local success, result = Validator:validate_scenario('users', scenario, data)

    if not success then
        return self:json(result, 400)
    end

    self:json({
        success = true,
        message = 'Users validation passed (' .. scenario .. ')',
        scenario = scenario,
        data = result
    })
end

function ValidateConfig:products()
    local scenario = self:get('scenario') or self:segment(2) or 'create'
    local data = {
        name = self:post('name'),
        sku = self:post('sku'),
        description = self:post('description'),
        price = self:post('price'),
        cost_price = self:post('cost_price'),
        stock = self:post('stock'),
        category_id = self:post('category_id'),
        status = self:post('status'),
        is_featured = self:post('is_featured')
    }

    local success, result = Validator:validate_scenario('products', scenario, data)

    if not success then
        return self:json(result, 400)
    end

    self:json({
        success = true,
        message = 'Products validation passed (' .. scenario .. ')',
        scenario = scenario,
        data = result
    })
end

function ValidateConfig:orders()
    local scenario = self:get('scenario') or self:segment(2) or 'create'
    local data = {
        order_no = self:post('order_no'),
        user_id = self:post('user_id'),
        status = self:post('status'),
        total_amount = self:post('total_amount'),
        receiver_name = self:post('receiver_name'),
        receiver_phone = self:post('receiver_phone'),
        receiver_address = self:post('receiver_address'),
        payment_method = self:post('payment_method')
    }

    local success, result = Validator:validate_scenario('orders', scenario, data)

    if not success then
        return self:json(result, 400)
    end

    self:json({
        success = true,
        message = 'Orders validation passed (' .. scenario .. ')',
        scenario = scenario,
        data = result
    })
end

function ValidateConfig:custom()
    local data = {
        product_code = self:post('product_code'),
        quantity = self:post('quantity'),
        discount = self:post('discount'),
        coupon_code = self:post('coupon_code')
    }

    local rules = {
        product_code = { 'regex:^[A-Z]{3}%d{4}$' },
        quantity = { 'integer', { 'min', 1 }, { 'max', 100 } },
        discount = { 'numeric', { 'min', 0 }, { 'max', 100 } },
        coupon_code = { 'alpha_dash', { 'length_min', 4 }, { 'length_max', 20 } }
    }

    local Validation = require('app.lib.validation')
    local validation = Validation:new({ bail = true })
    validation:make(data, rules)

    if validation:fails() then
        return self:json(validation:to_json(), 400)
    end

    self:json({
        success = true,
        message = 'Custom validation passed',
        data = data
    })
end

function ValidateConfig:users_create()
    local data = {
        username = self:post('username'),
        email = self:post('email'),
        password = self:post('password'),
        password_confirmation = self:post('password_confirmation')
    }

    local success, result = Validator:validate_scenario('users', 'create', data)

    if not success then
        return self:json(result, 400)
    end

    self:json({
        success = true,
        message = 'User registration validation passed',
        validated_data = {
            username = result.username,
            email = result.email
        }
    })
end

function ValidateConfig:users_login()
    local data = {
        email = self:post('email'),
        password = self:post('password')
    }

    local success, result = Validator:validate_scenario('users', 'login', data)

    if not success then
        return self:json(result, 400)
    end

    self:json({
        success = true,
        message = 'User login validation passed'
    })
end

function ValidateConfig:users_profile()
    local data = {
        real_name = self:post('real_name'),
        phone = self:post('phone'),
        age = self:post('age'),
        gender = self:post('gender'),
        bio = self:post('bio'),
        website = self:post('website'),
        wechat = self:post('wechat'),
        qq = self:post('qq')
    }

    local success, result = Validator:validate_scenario('users', 'profile', data)

    if not success then
        return self:json(result, 400)
    end

    self:json({
        success = true,
        message = 'User profile validation passed',
        data = result
    })
end

function ValidateConfig:products_create()
    local data = {
        name = self:post('name'),
        sku = self:post('sku'),
        price = self:post('price'),
        category_id = self:post('category_id')
    }

    local success, result = Validator:validate_scenario('products', 'create', data)

    if not success then
        return self:json(result, 400)
    end

    self:json({
        success = true,
        message = 'Product creation validation passed',
        data = {
            name = result.name,
            sku = result.sku,
            price = result.price
        }
    })
end

function ValidateConfig:products_update()
    local data = {
        name = self:post('name'),
        price = self:post('price'),
        description = self:post('description'),
        stock = self:post('stock'),
        status = self:post('status')
    }

    local success, result = Validator:validate_scenario('products', 'update', data)

    if not success then
        return self:json(result, 400)
    end

    self:json({
        success = true,
        message = 'Product update validation passed',
        data = result
    })
end

function ValidateConfig:orders_create()
    local data = {
        user_id = self:post('user_id'),
        receiver_name = self:post('receiver_name'),
        receiver_phone = self:post('receiver_phone'),
        receiver_address = self:post('receiver_address'),
        payment_method = self:post('payment_method')
    }

    local success, result = Validator:validate_scenario('orders', 'create', data)

    if not success then
        return self:json(result, 400)
    end

    self:json({
        success = true,
        message = 'Order creation validation passed',
        data = {
            user_id = result.user_id,
            payment_method = result.payment_method
        }
    })
end

function ValidateConfig:orders_ship()
    local data = {
        shipping_method = self:post('shipping_method'),
        shipping_no = self:post('shipping_no')
    }

    local success, result = Validator:validate_scenario('orders', 'ship', data)

    if not success then
        return self:json(result, 400)
    end

    self:json({
        success = true,
        message = 'Order shipping validation passed',
        data = result
    })
end

return ValidateConfig
