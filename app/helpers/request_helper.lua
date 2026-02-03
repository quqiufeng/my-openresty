local RequestHelper = {}

local function _get_value(req, key, default, rules)
    local value = req:input(key)

    if value == nil then
        return default
    end

    local rules = rules or {}

    if rules.trim ~= false and type(value) == "string" then
        value = string.gsub(value, "^%s+", "")
        value = string.gsub(value, "%s+$", "")
    end

    if rules.strip_tags then
        value = string.gsub(value, "<[^>]+>", "")
    end

    local convert_type = rules.type
    if convert_type then
        if convert_type == "number" then
            local num = tonumber(value)
            value = num or value
        elseif convert_type == "integer" then
            local num = tonumber(value)
            value = num and math.floor(num) or value
        elseif convert_type == "boolean" then
            if value == "true" or value == "1" or value == "yes" then
                value = true
            elseif value == "false" or value == "0" or value == "no" then
                value = false
            end
        elseif convert_type == "array" then
            if type(value) ~= "table" then
                value = { value }
            end
        end
    end

    if rules.lowercase then
        value = string.lower(value)
    elseif rules.uppercase then
        value = string.upper(value)
    end

    if rules.default ~= nil and (value == "" or value == nil) then
        value = rules.default
    end

    return value
end

local function _get_request_data(req, fields, custom_rules, source)
    local result = {}
    local errors = {}

    if type(fields) == "string" then
        fields = { fields }
    end

    for _, field in ipairs(fields) do
        local rules = {}
        if custom_rules and type(custom_rules) == "table" then
            rules = custom_rules[field] or {}
        end

        local default = rules.default or nil
        local required = rules.required

        local value
        if source == "get" then
            value = req:get[field]
        elseif source == "post" then
            value = req:post[field]
        elseif source == "json" then
            value = req.json and req.json[field]
        else
            value = req:input(field)
        end

        if value == nil then
            value = default
        end

        if rules.trim ~= false and type(value) == "string" then
            value = string.gsub(value, "^%s+", "")
            value = string.gsub(value, "%s+$", "")
        end

        if rules.strip_tags and type(value) == "string" then
            value = string.gsub(value, "<[^>]+>", "")
        end

        local convert_type = rules.type
        if convert_type and type(value) == "string" then
            if convert_type == "number" then
                local num = tonumber(value)
                value = num or value
            elseif convert_type == "integer" then
                local num = tonumber(value)
                value = num and math.floor(num) or value
            elseif convert_type == "boolean" then
                if value == "true" or value == "1" or value == "yes" then
                    value = true
                elseif value == "false" or value == "0" or value == "no" then
                    value = false
                end
            elseif convert_type == "array" then
                value = { value }
            end
        end

        if rules.lowercase and type(value) == "string" then
            value = string.lower(value)
        elseif rules.uppercase and type(value) == "string" then
            value = string.upper(value)
        end

        if rules.default ~= nil and (value == "" or value == nil) then
            value = rules.default
        end

        if required and (value == nil or value == "") then
            table.insert(errors, {
                field = field,
                message = rules.message or ("The " .. field .. " field is required.")
            })
        end

        result[field] = value
    end

    return result, errors
end

function RequestHelper:get(fields, custom_rules)
    local req = self
    if type(self) ~= "table" or not self.request then
        local Loader = require('app.core.Loader')
        req = Loader:controller('request_test')
    end

    return _get_request_data(req, fields, custom_rules, "all")
end

function RequestHelper:get_get(fields, custom_rules)
    local req = self
    if type(self) ~= "table" or not self.request then
        local Loader = require('app.core.Loader')
        req = Loader:controller('request_test')
    end

    return _get_request_data(req, fields, custom_rules, "get")
end

function RequestHelper:get_post(fields, custom_rules)
    local req = self
    if type(self) ~= "table" or not self.request then
        local Loader = require('app.core.Loader')
        req = Loader:controller('request_test')
    end

    return _get_request_data(req, fields, custom_rules, "post")
end

function RequestHelper:get_json(fields, custom_rules)
    local req = self
    if type(self) ~= "table" or not self.request then
        local Loader = require('app.core.Loader')
        req = Loader:controller('request_test')
    end

    return _get_request_data(req, fields, custom_rules, "json")
end

function RequestHelper:get_only(fields, rules, source)
    if type(fields) == "string" then
        fields = { fields }
    end

    local req = self
    if type(self) ~= "table" or not self.request then
        local Loader = require('app.core.Loader')
        req = Loader:controller('request_test')
    end

    local data, errors = _get_request_data(req, fields, rules, source or "all")

    if #errors > 0 then
        return nil, errors
    end

    return data
end

function RequestHelper:get_get_only(fields, rules)
    return self:get_only(fields, rules, "get")
end

function RequestHelper:get_post_only(fields, rules)
    return self:get_only(fields, rules, "post")
end

function RequestHelper:get_json_only(fields, rules)
    return self:get_only(fields, rules, "json")
end

function RequestHelper:get_except(fields, blacklist)
    local all_input = self:all_input()

    if type(fields) == "string" then
        fields = { fields }
    end
    if type(blacklist) == "string" then
        blacklist = { blacklist }
    end

    local result = {}

    for key, value in pairs(all_input) do
        local in_white = #fields == 0
        for _, f in ipairs(fields) do
            if f == key then
                in_white = true
                break
            end
        end

        local in_blacklist = false
        for _, b in ipairs(blacklist or {}) do
            if b == key then
                in_blacklist = true
                break
            end
        end

        if in_white and not in_blacklist then
            result[key] = value
        end
    end

    return result
end

function RequestHelper:only(...)
    local fields = {...}
    return self:get_only(fields)
end

function RequestHelper:except(...)
    local blacklist = {...}
    return self:get_except({}, blacklist)
end

function RequestHelper:merge(defaults)
    local all_input = self:all_input()

    if type(defaults) ~= "table" then
        return all_input
    end

    for key, value in pairs(defaults) do
        if all_input[key] == nil then
            all_input[key] = value
        end
    end

    return all_input
end

function RequestHelper:validate(fields, rules)
    if type(fields) == "string" then
        fields = { fields }
    end

    if type(rules) ~= "table" then
        rules = {}
    end

    local data, errors = self:get(fields, rules)

    if #errors > 0 then
        return false, data, errors
    end

    return true, data
end

function RequestHelper:get_pagination_params(default_per_page)
    default_per_page = default_per_page or 10

    local page = tonumber(self:get('page')) or 1
    local per_page = tonumber(self:get('per_page')) or default_per_page

    if page < 1 then page = 1 end
    if per_page < 1 then per_page = default_per_page end
    if per_page > 100 then per_page = 100 end

    local sort_by = self:get('sort_by') or 'id'
    local sort_order = self:get('sort_order') or 'DESC'
    if sort_order ~= "ASC" and sort_order ~= "DESC" then
        sort_order = "DESC"
    end

    return {
        page = page,
        per_page = per_page,
        sort_by = sort_by,
        sort_order = sort_order,
        offset = (page - 1) * per_page,
        limit = per_page
    }
end

function RequestHelper:get_search_params(search_fields)
    local params = {}
    local keyword = self:get('keyword') or self:get('q') or ""

    if keyword ~= "" then
        for _, field in ipairs(search_fields or {}) do
            params[field] = keyword
        end
    end

    local filters = self:get('filters')
    if type(filters) == "string" then
        local ok, decoded = pcall(function()
            return ngx.decode_base64(filters)
        end)
        if ok and decoded then
            local ok2, filter_tbl = pcall(function()
                return ngx.decode_json(decoded)
            end)
            if ok2 and type(filter_tbl) == "table" then
                filters = filter_tbl
            end
        end
    end

    if type(filters) == "table" then
        for k, v in pairs(filters) do
            params[k] = v
        end
    end

    return params, keyword
end

function RequestHelper:get_order_params(default_field, default_order)
    local sort_by = self:get('sort_by') or default_field or 'id'
    local sort_order = self:get('sort_order') or default_order or 'DESC'

    if sort_order ~= "ASC" and sort_order ~= "DESC" then
        sort_order = "DESC"
    end

    return {
        sort_by = sort_by,
        sort_order = sort_order,
        order_sql = sort_by .. " " .. sort_order
    }
end

function RequestHelper:get_date_range_params(field_prefix)
    field_prefix = field_prefix or ""

    local start_date = self:get(field_prefix .. 'start_date') or self:get(field_prefix .. 'start')
    local end_date = self:get(field_prefix .. 'end_date') or self:get(field_prefix .. 'end')

    return {
        start_date = start_date,
        end_date = end_date,
        has_range = start_date ~= nil or end_date ~= nil
    }
end

function RequestHelper:all()
    return self:all_input()
end

function RequestHelper:has(key)
    local value = self:input(key)
    return value ~= nil and value ~= ""
end

function RequestHelper:filled(key)
    local value = self:input(key)
    return value ~= nil and value ~= ""
end

function RequestHelper:string(key, default, source)
    local req = self
    if type(self) ~= "table" or not self.request then
        local Loader = require('app.core.Loader')
        req = Loader:controller('request_test')
    end

    local value
    if source == "get" then
        value = req:get[key]
    elseif source == "post" then
        value = req:post[key]
    elseif source == "json" then
        value = req.json and req.json[key]
    else
        value = req:input(key)
    end

    if value == nil or value == "" then
        return default
    end
    return tostring(value)
end

function RequestHelper:number(key, default, source)
    local req = self
    if type(self) ~= "table" or not self.request then
        local Loader = require('app.core.Loader')
        req = Loader:controller('request_test')
    end

    local value
    if source == "get" then
        value = req:get[key]
    elseif source == "post" then
        value = req:post[key]
    elseif source == "json" then
        value = req.json and req.json[key]
    else
        value = req:input(key)
    end

    local num = tonumber(value)
    return num or default
end

function RequestHelper:integer(key, default, source)
    local req = self
    if type(self) ~= "table" or not self.request then
        local Loader = require('app.core.Loader')
        req = Loader:controller('request_test')
    end

    local value
    if source == "get" then
        value = req:get[key]
    elseif source == "post" then
        value = req:post[key]
    elseif source == "json" then
        value = req.json and req.json[key]
    else
        value = req:input(key)
    end

    local num = tonumber(value)
    return num and math.floor(num) or default
end

function RequestHelper:boolean(key, default, source)
    local req = self
    if type(self) ~= "table" or not self.request then
        local Loader = require('app.core.Loader')
        req = Loader:controller('request_test')
    end

    local value
    if source == "get" then
        value = req:get[key]
    elseif source == "post" then
        value = req:post[key]
    elseif source == "json" then
        value = req.json and req.json[key]
    else
        value = req:input(key)
    end

    if value == "true" or value == "1" or value == "yes" then
        return true
    elseif value == "false" or value == "0" or value == "no" then
        return false
    end
    return default
end

function RequestHelper:array(key, source)
    local req = self
    if type(self) ~= "table" or not self.request then
        local Loader = require('app.core.Loader')
        req = Loader:controller('request_test')
    end

    local value
    if source == "get" then
        value = req:get[key]
    elseif source == "post" then
        value = req:post[key]
    elseif source == "json" then
        value = req.json and req.json[key]
    else
        value = req:input(key)
    end

    if type(value) == "table" then
        return value
    elseif value then
        return { value }
    end
    return {}
end

-- Shorthand methods for specific sources
function RequestHelper:get_string(key, default)
    return self:string(key, default, "get")
end

function RequestHelper:get_number(key, default)
    return self:number(key, default, "get")
end

function RequestHelper:get_integer(key, default)
    return self:integer(key, default, "get")
end

function RequestHelper:get_boolean(key, default)
    return self:boolean(key, default, "get")
end

function RequestHelper:get_array(key)
    return self:array(key, "get")
end

function RequestHelper:post_string(key, default)
    return self:string(key, default, "post")
end

function RequestHelper:post_number(key, default)
    return self:number(key, default, "post")
end

function RequestHelper:post_integer(key, default)
    return self:integer(key, default, "post")
end

function RequestHelper:post_boolean(key, default)
    return self:boolean(key, default, "post")
end

function RequestHelper:post_array(key)
    return self:array(key, "post")
end

function RequestHelper:json_string(key, default)
    return self:string(key, default, "json")
end

function RequestHelper:json_number(key, default)
    return self:number(key, default, "json")
end

function RequestHelper:json_integer(key, default)
    return self:integer(key, default, "json")
end

function RequestHelper:json_boolean(key, default)
    return self:boolean(key, default, "json")
end

function RequestHelper:json_array(key)
    return self:array(key, "json")
end

return RequestHelper
