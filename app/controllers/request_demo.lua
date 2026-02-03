local BaseController = require('app.core.Controller')
local RequestHelper = require('app.helpers.request_helper')

local RequestDemo = {}
setmetatable(RequestDemo, { __index = BaseController })

function RequestDemo:index()
    self:json({
        success = true,
        message = 'Request Helper Demo',
        description = 'Auto-process request data with validation and type conversion',
        endpoints = {
            'POST /request-demo/basic - Basic field extraction',
            'POST /request-demo/typed - Type conversion',
            'POST /request-demo/validate - Validation with errors',
            'POST /request-demo/pagination - Pagination params',
            'POST /request-demo/search - Search params',
            'POST /request-demo/filter - Filter params',
            'POST /request-demo/only - Get only specific fields',
            'POST /request-demo/except - Exclude fields',
            'POST /request-demo/complete - Complete example'
        }
    })
end

function RequestDemo:basic()
    local fields = { 'name', 'email', 'age', 'city' }

    local data = RequestHelper:get(self, fields)

    self:json({
        success = true,
        message = 'Basic field extraction',
        data = data
    })
end

function RequestDemo:typed()
    local rules = {
        name = { type = "string", default = "" },
        age = { type = "number", default = 0 },
        score = { type = "number", default = 0 },
        is_active = { type = "boolean", default = false },
        tags = { type = "array", default = {} }
    }

    local data = RequestHelper:get(self, { 'name', 'age', 'score', 'is_active', 'tags' }, rules)

    self:json({
        success = true,
        message = 'Type conversion',
        data = {
            name = data.name,
            age = data.age,
            age_type = type(data.age),
            score = data.score,
            score_type = type(data.score),
            is_active = data.is_active,
            is_active_type = type(data.is_active),
            tags = data.tags,
            tags_type = type(data.tags)
        }
    })
end

function RequestDemo:validate()
    local rules = {
        username = { required = true, message = 'Username is required' },
        email = { required = true, type = "email", message = 'Valid email required' },
        password = { required = true, min = 6, message = 'Password must be at least 6 characters' },
        age = { type = "integer", default = 0 }
    }

    local data, errors = RequestHelper:get_only(self, {
        'username', 'email', 'password', 'age'
    }, rules)

    if #errors > 0 then
        return self:json({
            success = false,
            message = 'Validation failed',
            errors = errors
        }, 400)
    end

    self:json({
        success = true,
        message = 'Validation passed',
        data = data
    })
end

function RequestDemo:pagination()
    local params = RequestHelper:get_pagination_params(self, 20)

    self:json({
        success = true,
        message = 'Pagination parameters',
        params = params,
        example_sql = string.format(
            "SELECT * FROM users LIMIT %d OFFSET %d",
            params.limit,
            params.offset
        )
    })
end

function RequestDemo:search()
    local search_fields = { 'username', 'email', 'title', 'content' }
    local params, keyword = RequestHelper:get_search_params(self, search_fields)

    self:json({
        success = true,
        message = 'Search parameters',
        keyword = keyword,
        search_fields = search_fields,
        params = params
    })
end

function RequestDemo:filter()
    local data = self:all_input()

    local filtered = RequestHelper:get_only(self, {
        'status', 'category', 'is_featured', 'date_from', 'date_to'
    })

    self:json({
        success = true,
        message = 'Filter parameters',
        original_data = data,
        filtered = filtered
    })
end

function RequestDemo:only()
    local all_data = self:all_input()

    local data = RequestHelper:only(self, 'username', 'email', 'age')

    self:json({
        success = true,
        message = 'Get only specific fields',
        original_keys = self:keys(all_data),
        only_fields = { 'username', 'email', 'age' },
        data = data
    })
end

function RequestDemo:except()
    local all_data = self:all_input()

    local data = RequestHelper:except(self, 'password', 'secret_token', 'api_key')

    self:json({
        success = true,
        message = 'Exclude sensitive fields',
        excluded_fields = { 'password', 'secret_token', 'api_key' },
        data = data
    })
end

function RequestDemo:complete()
    local rules = {
        username = { required = true, type = "string" },
        email = { required = true, type = "email" },
        password = { required = true, min = 6 },
        age = { type = "integer", default = 0 },
        status = { type = "string", default = "active" }
    }

    local valid, data, errors = RequestHelper:validate(self, {
        'username', 'email', 'password', 'age', 'status'
    }, rules)

    if not valid then
        return self:json({
            success = false,
            message = 'Validation failed',
            errors = errors
        }, 400)
    end

    local pagination = RequestHelper:get_pagination_params(self, 20)
    local search_params, keyword = RequestHelper:get_search_params(self, { 'username', 'email' })

    self:json({
        success = true,
        message = 'Complete request processing',
        validated_data = data,
        pagination = pagination,
        search = {
            keyword = keyword,
            params = search_params
        },
        ready_for_db = {
            insert_users = {
                username = data.username,
                email = data.email,
                password = data.password,
                age = data.age,
                status = data.status
            },
            query_conditions = search_params
        }
    })
end

function RequestDemo:direct_types()
    local data = {
        string_val = self:request():string('text_field'),
        number_val = self:request():number('num_field'),
        integer_val = self:request():integer('int_field'),
        boolean_val = self:request():boolean('bool_field'),
        array_val = self:request():array('arr_field')
    }

    self:json({
        success = true,
        message = 'Direct type methods',
        data = data,
        types = {
            string_val = type(data.string_val),
            number_val = type(data.number_val),
            integer_val = type(data.integer_val),
            boolean_val = type(data.boolean_val),
            array_val = type(data.array_val)
        }
    })
end

function RequestDemo:get_post()
    local get_fields = { 'page', 'sort_by', 'sort_order' }
    local post_fields = { 'username', 'email', 'password' }
    local json_fields = { 'config', 'settings' }

    local get_data = RequestHelper:get_get(self, get_fields)
    local post_data = RequestHelper:get_post(self, post_fields)
    local json_data = RequestHelper:get_json(self, json_fields)

    self:json({
        success = true,
        message = 'GET vs POST vs JSON separation',
        source = {
            get = {
                description = 'Query parameters (?page=1)',
                data = get_data
            },
            post = {
                description = 'Form data (POST body)',
                data = post_data
            },
            json = {
                description = 'JSON body',
                data = json_data
            }
        }
    })
end

function RequestDemo:get_post_only_demo()
    local rules = {
        username = { required = true },
        email = { required = true, type = "email" }
    }

    local post_data, errors = RequestHelper:get_post_only(self, {
        'username', 'email', 'password'
    }, rules)

    if #errors > 0 then
        return self:json({
            success = false,
            message = 'POST validation failed',
            errors = errors
        }, 400)
    end

    self:json({
        success = true,
        message = 'POST only validation passed',
        data = post_data
    })
end

function RequestDemo:shorthand_types()
    local data = {
        get_string = RequestHelper:get_string(self, 'default', 'get'),
        get_number = RequestHelper:get_number(self, 0, 'get'),
        post_string = RequestHelper:post_string(self, 'default', 'post'),
        post_number = RequestHelper:post_number(self, 0, 'post'),
        json_string = RequestHelper:json_string(self, 'default', 'json'),
        json_number = RequestHelper:json_number(self, 0, 'json')
    }

    self:json({
        success = true,
        message = 'Shorthand type methods by source',
        data = data
    })
end

function RequestDemo:keys(tbl)
    local keys = {}
    for k, _ in pairs(tbl or {}) do
        table.insert(keys, k)
    end
    return keys
end

return RequestDemo
