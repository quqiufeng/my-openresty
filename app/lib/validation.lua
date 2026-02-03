local Validation = {}

Validation.RULES = {
    REQUIRED = 'required',
    OPTIONAL = 'optional',
    STRING = 'string',
    NUMBER = 'number',
    INTEGER = 'integer',
    BOOLEAN = 'boolean',
    EMAIL = 'email',
    URL = 'url',
    IP = 'ip',
    MIN = 'min',
    MAX = 'max',
    LENGTH_MIN = 'length_min',
    LENGTH_MAX = 'length_max',
    LENGTH = 'length',
    REGEX = 'regex',
    IN = 'in',
    NOT_IN = 'not_in',
    DATE = 'date',
    ALPHA = 'alpha',
    ALPHA_NUM = 'alpha_num',
    ALPHA_DASH = 'alpha_dash',
    NUMERIC = 'numeric',
    DIGITS = 'digits',
    MATCH = 'match',
    DIFFERENT = 'different',
    UNIQUE = 'unique',
    EXISTS = 'exists',
    ARRAY = 'array',
    FILE = 'file',
    IMAGE = 'image',
    MIME_TYPE = 'mime_type',
    SIZE_MAX = 'size_max'
}

Validation.MESSAGES = {
    required = 'The :field field is required.',
    optional = 'The :field field is optional.',
    string = 'The :field must be a string.',
    number = 'The :field must be a number.',
    integer = 'The :field must be an integer.',
    boolean = 'The :field must be a boolean.',
    email = 'The :field must be a valid email address.',
    url = 'The :field must be a valid URL.',
    ip = 'The :field must be a valid IP address.',
    min = 'The :field must be at least :param.',
    max = 'The :field must not exceed :param.',
    length_min = 'The :field must be at least :param characters.',
    length_max = 'The :field must not exceed :param characters.',
    length = 'The :field must be exactly :param characters.',
    regex = 'The :field format is invalid.',
    in = 'The :field must be one of: :param.',
    not_in = 'The :field must not be one of: :param.',
    date = 'The :field must be a valid date.',
    alpha = 'The :field may only contain letters.',
    alpha_num = 'The :field may only contain letters and numbers.',
    alpha_dash = 'The :field may only contain letters, numbers, and dashes.',
    numeric = 'The :field must be a numeric value.',
    digits = 'The :field must contain only digits.',
    match = 'The :field must match :param.',
    different = 'The :field must be different from :param.',
    unique = 'The :field has already been taken.',
    exists = 'The :field does not exist.',
    array = 'The :field must be an array.',
    file = 'The :field must be a file.',
    image = 'The :field must be an image.',
    mime_type = 'The :field must be one of the following types: :param.',
    size_max = 'The :field must not exceed :param size.'
}

function Validation:new(config)
    config = config or {}
    local instance = {
        data = {},
        rules = {},
        errors = {},
        custom_messages = {},
        labels = {},
        translations = {},
        config = config,
        bail = config.bail or false,
        throw_exception = config.throw_exception or false
    }

    if config.messages then
        for k, v in pairs(config.messages) do
            instance.custom_messages[k] = v
        end
    end

    if config.labels then
        for k, v in pairs(config.labels) do
            instance.labels[k] = v
        end
    end

    setmetatable(instance, { __index = Validation })
    return instance
end

function Validation:make(data, rules)
    self.data = data or {}
    self.rules = rules or {}
    self.errors = {}
    return self
end

function Validation:set_data(data)
    self.data = data
    return self
end

function Validation:add_rule(field, rule)
    if not self.rules[field] then
        self.rules[field] = {}
    end
    table.insert(self.rules[field], rule)
    return self
end

function Validation:set_rules(rules)
    self.rules = rules
    return self
end

function Validation:with_messages(messages)
    self.custom_messages = messages
    return self
end

function Validation:with_labels(labels)
    self.labels = labels
    return self
end

function Validation:bail_on_first_fail(bail)
    self.bail = bail
    return self
end

function Validation:validate()
    self.errors = {}

    for field, rules in pairs(self.rules) do
        if self:should_validate(field) then
            for _, rule in ipairs(rules) do
                local rule_name, rule_param = self:parse_rule(rule)

                if not self:validate_field(field, rule_name, rule_param) then
                    self:add_error(field, rule_name, rule_param)

                    if self.bail then
                        break
                    end
                end
            end
        end
    end

    return self:passes()
end

function Validation:should_validate(field)
    local value = self:get_value(field)

    for _, rule in ipairs(self.rules[field] or {}) do
        local rule_name = self:parse_rule(rule)
        if rule_name == self.RULES.REQUIRED then
            return true
        end
        if rule_name == self.RULES.OPTIONAL then
            return value ~= nil and value ~= ''
        end
    end

    return true
end

function Validation:parse_rule(rule)
    if type(rule) == "string" then
        local colon_pos = string.find(rule, ":")
        if colon_pos then
            local name = string.sub(rule, 1, colon_pos - 1)
            local param = string.sub(rule, colon_pos + 1)
            return name, param
        end
        return rule, nil
    elseif type(rule) == "table" then
        return rule[1], rule[2]
    end
    return rule, nil
end

function Validation:get_value(field)
    local value = self.data[field]

    if value == nil then
        for dot_field, dot_value in pairs(self.data) do
            if string.find(field, "%.") then
                local prefix = string.match(field, "^([^%.]+)")
                if prefix and string.find(dot_field, "^" .. prefix) then
                    return dot_value
                end
            end
        end
    end

    return value
end

function Validation:validate_field(field, rule_name, rule_param)
    local value = self:get_value(field)

    local validate_func = self["validate_" .. rule_name]
    if validate_func then
        return validate_func(self, field, value, rule_param)
    end

    return true
end

function Validation:validate_required(field, value, param)
    if value == nil or value == '' then
        return false
    end
    if type(value) == "table" and #value == 0 then
        return false
    end
    return true
end

function Validation:validate_optional(field, value, param)
    return value ~= nil and value ~= ''
end

function Validation:validate_string(field, value, param)
    if value == nil or value == '' then
        return true
    end
    return type(value) == "string"
end

function Validation:validate_number(field, value, param)
    if value == nil or value == '' then
        return true
    end
    if type(value) == "number" then
        return true
    end
    if tonumber(value) then
        return true
    end
    return false
end

function Validation:validate_integer(field, value, param)
    if value == nil or value == '' then
        return true
    end
    if tonumber(value) then
        local num = tonumber(value)
        return num == math.floor(num)
    end
    return false
end

function Validation:validate_boolean(field, value, param)
    if value == nil or value == '' then
        return true
    end
    return type(value) == "boolean" or value == true or value == false or value == "true" or value == "false" or value == 1 or value == 0
end

function Validation:validate_email(field, value, param)
    if value == nil or value == '' then
        return true
    end
    local pattern = "^[a-zA-Z0-9._%%+-]+@[a-zA-Z0-9.-]+%.[a-zA-Z]{2,}$"
    return string.match(value, pattern) ~= nil
end

function Validation:validate_url(field, value, param)
    if value == nil or value == '' then
        return true
    end
    local pattern = "^https?://[^%s]+$"
    return string.match(value, pattern) ~= nil
end

function Validation:validate_ip(field, value, param)
    if value == nil or value == '' then
        return true
    end
    local ipv4_pattern = "^%d%d?%d?%.%d%d?%d?%.%d%d?%d?%.%d%d?%d?$"
    local ipv6_pattern = "^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$"
    return string.match(value, ipv4_pattern) ~= nil or string.match(value, ipv6_pattern) ~= nil
end

function Validation:validate_min(field, value, param)
    if value == nil or value == '' then
        return true
    end
    local min_val = tonumber(param)
    local num = tonumber(value)
    if num then
        return num >= min_val
    end
    if type(value) == "string" then
        return #value >= min_val
    end
    return false
end

function Validation:validate_max(field, value, param)
    if value == nil or value == '' then
        return true
    end
    local max_val = tonumber(param)
    local num = tonumber(value)
    if num then
        return num <= max_val
    end
    if type(value) == "string" then
        return #value <= max_val
    end
    return false
end

function Validation:validate_length_min(field, value, param)
    if value == nil or value == '' then
        return true
    end
    if type(value) == "string" then
        return #value >= tonumber(param)
    end
    return false
end

function Validation:validate_length_max(field, value, param)
    if value == nil or value == '' then
        return true
    end
    if type(value) == "string" then
        return #value <= tonumber(param)
    end
    return false
end

function Validation:validate_length(field, value, param)
    if value == nil or value == '' then
        return true
    end
    if type(value) == "string" then
        return #value == tonumber(param)
    end
    return false
end

function Validation:validate_regex(field, value, param)
    if value == nil or value == '' then
        return true
    end
    local ok, result = pcall(function()
        return string.match(value, param)
    end)
    return ok and result ~= nil
end

function Validation:validate_in(field, value, param)
    if value == nil or value == '' then
        return true
    end
    local options = {}
    for option in string.gmatch(param, "[^,]+") do
        options[option] = true
    end
    return options[value] == true
end

function Validation:validate_not_in(field, value, param)
    if value == nil or value == '' then
        return true
    end
    local options = {}
    for option in string.gmatch(param, "[^,]+") do
        options[option] = true
    end
    return options[value] == nil
end

function Validation:validate_date(field, value, param)
    if value == nil or value == '' then
        return true
    end
    local pattern = "%d%d%d%d[-/]%d%d[-/]%d%d"
    return string.match(value, pattern) ~= nil
end

function Validation:validate_alpha(field, value, param)
    if value == nil or value == '' then
        return true
    end
    local pattern = "^[a-zA-Z]+$"
    return string.match(value, pattern) ~= nil
end

function Validation:validate_alpha_num(field, value, param)
    if value == nil or value == '' then
        return true
    end
    local pattern = "^[a-zA-Z0-9]+$"
    return string.match(value, pattern) ~= nil
end

function Validation:validate_alpha_dash(field, value, param)
    if value == nil or value == '' then
        return true
    end
    local pattern = "^[a-zA-Z0-9_-]+$"
    return string.match(value, pattern) ~= nil
end

function Validation:validate_numeric(field, value, param)
    if value == nil or value == '' then
        return true
    end
    return tonumber(value) ~= nil
end

function Validation:validate_digits(field, value, param)
    if value == nil or value == '' then
        return true
    end
    local pattern = "^%d+$"
    return string.match(value, pattern) ~= nil
end

function Validation:validate_match(field, value, param)
    local other_value = self:get_value(param)
    return value == other_value
end

function Validation:validate_different(field, value, param)
    local other_value = self:get_value(param)
    return value ~= other_value
end

function Validation:validate_unique(field, value, param)
    if value == nil or value == '' then
        return true
    end
    return true
end

function Validation:validate_exists(field, value, param)
    if value == nil or value == '' then
        return true
    end
    return true
end

function Validation:validate_array(field, value, param)
    if value == nil or value == '' then
        return true
    end
    return type(value) == "table"
end

function Validation:validate_file(field, value, param)
    if value == nil or value == '' then
        return true
    end
    if type(value) == "table" then
        return value.name ~= nil and value.path ~= nil
    end
    return false
end

function Validation:validate_image(field, value, param)
    if value == nil or value == '' then
        return true
    end
    if type(value) == "table" then
        local allowed_exts = {".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp"}
        local ext = string.lower(string.match(value.name, "%.[^.]+$") or "")
        for _, e in ipairs(allowed_exts) do
            if ext == e then
                return true
            end
        end
        return false
    end
    return false
end

function Validation:validate_mime_type(field, value, param)
    if value == nil or value == '' then
        return true
    end
    if type(value) == "table" then
        local allowed_types = {}
        for mime in string.gmatch(param, "[^,]+") do
            allowed_types[mime] = true
        end
        return allowed_types[value.content_type] == true
    end
    return false
end

function Validation:validate_size_max(field, value, param)
    if value == nil or value == '' then
        return true
    end
    if type(value) == "table" then
        local max_size = tonumber(param) * 1024 * 1024
        return value.size <= max_size
    end
    return false
end

function Validation:add_error(field, rule_name, rule_param)
    local message = self:get_error_message(field, rule_name, rule_param)

    if not self.errors[field] then
        self.errors[field] = {}
    end
    table.insert(self.errors[field], message)
end

function Validation:get_error_message(field, rule_name, rule_param)
    local custom_key = field .. "." .. rule_name
    if self.custom_messages[custom_key] then
        return self:replace_placeholders(self.custom_messages[custom_key], field, rule_param)
    end

    if self.custom_messages[rule_name] then
        return self:replace_placeholders(self.custom_messages[rule_name], field, rule_param)
    end

    local template = self.MESSAGES[rule_name] or "The :field field is invalid."
    return self:replace_placeholders(template, field, rule_param)
end

function Validation:replace_placeholders(message, field, param)
    local label = self.labels[field] or field

    message = string.gsub(message, ":field", label)

    if param then
        message = string.gsub(message, ":param", tostring(param))
    end

    return message
end

function Validation:errors()
    return self.errors
end

function Validation:first_error()
    for field, messages in pairs(self.errors) do
        if #messages > 0 then
            return messages[1]
        end
    end
    return nil
end

function Validation:has_errors()
    return next(self.errors) ~= nil
end

function Validation:has_error(field)
    return self.errors[field] ~= nil and #self.errors[field] > 0
end

function Validation:get_error(field)
    if self.errors[field] and #self.errors[field] > 0 then
        return self.errors[field][1]
    end
    return nil
end

function Validation:to_array()
    return self.errors
end

function Validation:to_json()
    local json = {}
    json.success = false
    json.message = "Validation failed"
    json.errors = self.errors
    json.error_count = 0

    for _, messages in pairs(self.errors) do
        json.error_count = json.error_count + #messages
    end

    return json
end

function Validation:response(status)
    status = status or 400
    local Response = require('app.core.Response')
    return Response:json(self:to_json(), status)
end

function Validation:passes()
    return not self:has_errors()
end

function Validation:fails()
    return self:has_errors()
end

function Validation:sometimes(field, condition, callback)
    local value = self:get_value(field)

    local should_apply = false
    if type(condition) == "function" then
        should_apply = condition(value, self.data)
    elseif type(condition) == "string" then
        local rule_name, rule_param = self:parse_rule(condition)
        should_apply = self:validate_field(field, rule_name, rule_param)
    end

    if should_apply then
        callback(self, field)
    end

    return self
end

function Validation:add_rule_after(field, after_field, rules)
    local after_value = self:get_value(after_field)
    if after_value then
        self:set_rules({
            [field] = rules
        })
    end
    return self
end

function Validation:extend(name, callback)
    self["validate_" .. name] = callback
    return self
end

function Validation:set_message(rule, message)
    self.MESSAGES[rule] = message
    return self
end

function Validation:get_data()
    return self.data
end

function Validation:only(...)
    local fields = {...}
    local result = {}
    for _, field in ipairs(fields) do
        result[field] = self.data[field]
    end
    return result
end

function Validation:except(...)
    local fields = {...}
    local result = {}
    for k, v in pairs(self.data) do
        local excluded = false
        for _, field in ipairs(fields) do
            if k == field then
                excluded = true
                break
            end
        end
        if not excluded then
            result[k] = v
        end
    end
    return result
end

return Validation
