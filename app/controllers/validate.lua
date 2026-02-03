local BaseController = require('app.core.Controller')
local Validation = require('app.lib.validation')

local Validate = {}
setmetatable(Validate, { __index = BaseController })

function Validate:index()
    local Loader = require('app.core.Loader')
    local config = Loader:config('validation')

    self:json({
        success = true,
        message = 'Validation API',
        description = 'JSON-based form validation library',
        endpoints = {
            'POST /validate/basic - Basic validation',
            'POST /validate/login - Login form validation',
            'POST /validate/register - Registration validation',
            'POST /validate/update - Update with conditional',
            'POST /validate/custom - Custom rules',
            'POST /validate/messages - Custom error messages',
            'POST /validate/array - Array validation',
            'POST /validate/all - All rules demo'
        },
        available_rules = {
            'required', 'optional', 'string', 'number', 'integer', 'boolean',
            'email', 'url', 'ip', 'min', 'max', 'length_min', 'length_max', 'length',
            'regex', 'in', 'not_in', 'date', 'alpha', 'alpha_num', 'alpha_dash',
            'numeric', 'digits', 'match', 'different', 'array', 'file', 'image'
        }
    })
end

function Validate:basic()
    local data = {
        name = self:post('name'),
        email = self:post('email'),
        age = self:post('age'),
        website = self:post('website')
    }

    local rules = {
        name = { 'required', 'length_min:2', 'length_max:50' },
        email = { 'required', 'email' },
        age = { 'required', 'number', 'min:18', 'max:120' },
        website = { 'url' }
    }

    local validation = Validation:new()
    validation:make(data, rules)

    if validation:fails() then
        return self:json(validation:to_json(), 400)
    end

    self:json({
        success = true,
        message = 'Validation passed',
        data = data
    })
end

function Validate:login()
    local data = {
        email = self:post('email'),
        password = self:post('password')
    }

    local rules = {
        email = { 'required', 'email', 'max:100' },
        password = { 'required', 'min:6', 'max:50' }
    }

    local validation = Validation:new()
    validation:make(data, rules)

    if validation:fails() then
        return self:json(validation:to_json(), 400)
    end

    self:json({
        success = true,
        message = 'Login validation passed',
        data = {
            email = data.email,
            password_length = #data.password
        }
    })
end

function Validate:register()
    local data = {
        username = self:post('username'),
        email = self:post('email'),
        password = self:post('password'),
        password_confirmation = self:post('password_confirmation'),
        age = self:post('age'),
        phone = self:post('phone')
    }

    local rules = {
        username = { 'required', 'alpha_num', 'length_min:3', 'length_max:20' },
        email = { 'required', 'email', 'max:100' },
        password = { 'required', 'min:8', 'max:50' },
        password_confirmation = { 'required', { 'match', 'password' } },
        age = { 'number', 'min:13', 'max:150' },
        phone = { 'regex:^%d{10,11}$' }
    }

    local custom_messages = {
        ['password_confirmation.match'] = 'Password confirmation does not match.',
        ['username.alpha_num'] = 'Username may only contain letters and numbers.'
    }

    local validation = Validation:new({
        messages = custom_messages,
        bail = true
    })
    validation:make(data, rules)

    if validation:fails() then
        return self:json(validation:to_json(), 400)
    end

    self:json({
        success = true,
        message = 'Registration validation passed',
        data = {
            username = data.username,
            email = data.email,
            age = tonumber(data.age)
        }
    })
end

function Validate:update()
    local data = {
        title = self:post('title'),
        content = self:post('content'),
        status = self:post('status'),
        category = self:post('category')
    }

    local rules = {
        title = { 'required', 'length_min:3', 'length_max:200' },
        content = { 'required', 'length_min:10' },
        status = { 'in:draft,published,archived' },
        category = { 'in:news,tech,lifestyle,other' }
    }

    local validation = Validation:new()
    validation:make(data, rules)

    if validation:fails() then
        return self:json(validation:to_json(), 400)
    end

    self:json({
        success = true,
        message = 'Update validation passed',
        data = data
    })
end

function Validate:custom()
    local data = {
        product_code = self:post('product_code'),
        price = self:post('price'),
        discount = self:post('discount')
    }

    local rules = {
        product_code = { 'regex:^[A-Z]{3}%d{4}$' },
        price = { 'required', 'number', 'min:0.01' },
        discount = { 'numeric', 'max:100' }
    }

    local custom_messages = {
        ['product_code.regex'] = 'Product code must be in format ABC1234 (3 letters + 4 digits).',
        ['discount.max'] = 'Discount cannot exceed 100%.'
    }

    local validation = Validation:new({
        messages = custom_messages,
        bail = true
    })
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

function Validate:messages()
    local data = {
        username = self:post('username'),
        email = self:post('email'),
        password = self:post('password')
    }

    local rules = {
        username = { 'required', 'alpha_num', 'length_min:3' },
        email = { 'required', 'email' },
        password = { 'required', 'min:8' }
    }

    local custom_messages = {
        ['username.required'] = 'Please enter your username.',
        ['username.alpha_num'] = 'Username can only contain letters and numbers.',
        ['username.length_min'] = 'Username must be at least :param characters long.',
        ['email.required'] = 'Email address is required.',
        ['email.email'] = 'Please enter a valid email address.',
        ['password.required'] = 'Password is required.',
        ['password.min'] = 'Password must be at least :param characters.'
    }

    local labels = {
        username = 'Username',
        email = 'Email Address',
        password = 'Password'
    }

    local validation = Validation:new({
        messages = custom_messages,
        bail = true
    })
    validation:make(data, rules)
    validation:with_labels(labels)

    if validation:fails() then
        return self:json(validation:to_json(), 400)
    end

    self:json({
        success = true,
        message = 'Custom messages validation passed',
        data = data
    })
end

function Validate:array()
    local data = {
        tags = self:post('tags'),
        prices = self:post('prices'),
        emails = self:post('emails')
    }

    local function validate_array_items(items, rules)
        if type(items) ~= "table" then
            return false, "Must be an array"
        end
        for i, item in ipairs(items) do
            for field, rule_list in pairs(rules) do
                local validation = Validation:new()
                validation:make({ [field] = item[field] }, { [field] = rule_list })
                if validation:fails() then
                    return false, "Item " .. i .. " has invalid " .. field
                end
            end
        end
        return true
    end

    local validation = Validation:new()
    validation:make(data, {
        tags = { 'array' },
        prices = { 'array' },
        emails = { 'array' }
    })

    if validation:fails() then
        return self:json(validation:to_json(), 400)
    end

    if type(data.tags) == "table" then
        for i, tag in ipairs(data.tags) do
            local tag_validation = Validation:new()
            tag_validation:make({ tag = tag }, { tag = { 'required', 'string', 'length_max:30' } })
            if tag_validation:fails() then
                return self:json({
                    success = false,
                    message = 'Array validation failed',
                    errors = {
                        tags = { "Tag at position " .. i .. " is invalid: " .. tag_validation:first_error() }
                    }
                }, 400)
            end
        end
    end

    self:json({
        success = true,
        message = 'Array validation passed',
        data = data
    })
end

function Validate:all()
    local data = {
        name = self:post('name'),
        email = self:post('email'),
        password = self:post('password'),
        age = self:post('age'),
        phone = self:post('phone'),
        website = self:post('website'),
        status = self:post('status'),
        amount = self:post('amount'),
        code = self:post('code'),
        category = self:post('category')
    }

    local rules = {
        name = { 'required', 'alpha', 'length_min:2', 'length_max:50' },
        email = { 'required', 'email' },
        password = { 'required', 'min:8', 'max:50' },
        age = { 'number', 'min:1', 'max:150' },
        phone = { 'regex:^%d{10,11}$' },
        website = { 'url' },
        status = { 'in:active,inactive,pending' },
        amount = { 'numeric', 'min:0' },
        code = { 'alpha_dash', 'length:8' },
        category = { 'in:news,tech,lifestyle,other' }
    }

    local validation = Validation:new({ bail = true })
    validation:make(data, rules)

    if validation:fails() then
        return self:json(validation:to_json(), 400)
    end

    self:json({
        success = true,
        message = 'All rules validation passed',
        data = {
            name = data.name,
            email = data.email,
            age = tonumber(data.age),
            status = data.status
        }
    })
end

function Validate:login_with_session()
    local data = {
        email = self:post('email'),
        password = self:post('password'),
        captcha = self:post('captcha')
    }

    local rules = {
        email = { 'required', 'email' },
        password = { 'required', 'min:6' },
        captcha = { 'required', { 'length', 5 } }
    }

    local custom_messages = {
        ['captcha.length'] = 'Captcha must be exactly 5 characters.'
    }

    local validation = Validation:new({
        messages = custom_messages,
        bail = true
    })
    validation:make(data, rules)

    if validation:fails() then
        return self:json(validation:to_json(), 400)
    end

    local Loader = require('app.core.Loader')
    local Session = Loader:library('session')
    local CaptchaHelper = Loader:helper('captcha')

    local captcha_valid, captcha_msg = CaptchaHelper:validate(data.captcha, ngx)
    if not captcha_valid then
        return self:json({
            success = false,
            message = 'Validation failed',
            errors = {
                captcha = { captcha_msg }
            }
        }, 400)
    end

    self:json({
        success = true,
        message = 'Login with captcha validation passed'
    })
end

function Validate:api_key()
    local data = {
        api_key = self:post('api_key'),
        action = self:post('action')
    }

    local rules = {
        api_key = { 'required', 'regex:^[a-f0-9]{32}$' },
        action = { 'required', 'in:read,write,delete' }
    }

    local custom_messages = {
        ['api_key.regex'] = 'Invalid API key format. Must be 32-character hex string.',
        ['action.in'] = 'Action must be one of: read, write, delete.'
    }

    local validation = Validation:new({
        messages = custom_messages,
        bail = true
    })
    validation:make(data, rules)

    if validation:fails() then
        return self:json(validation:to_json(), 401)
    end

    self:json({
        success = true,
        message = 'API key validation passed',
        action = data.action
    })
end

return Validate
