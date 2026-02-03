local Validator = {}

local loaded_rules = {}
local loaded_common = nil

local function load_file(path)
    local file = io.open(path, 'r')
    if not file then
        return nil, 'File not found: ' .. path
    end
    local content = file:read('*a')
    file:close()

    local func, err = loadstring('return ' .. content)
    if not func then
        return nil, 'Parse error: ' .. tostring(err)
    end

    local ok, result = pcall(func)
    if not ok then
        return nil, 'Execution error: ' .. tostring(result)
    end

    return result, nil
end

function Validator:load_table_rules(table_name)
    if loaded_rules[table_name] then
        return loaded_rules[table_name]
    end

    local base_path = '/var/www/web/my-openresty/config/validation'
    local file_path = base_path .. '/' .. table_name .. '.lua'

    local rules, err = load_file(file_path)
    if err then
        return nil, err
    end

    loaded_rules[table_name] = rules
    return rules, nil
end

function Validator:load_common_rules()
    if loaded_common then
        return loaded_common
    end

    local base_path = '/var/www/web/my-openresty/config/validation'
    local file_path = base_path .. '/common.lua'

    local rules, err = load_file(file_path)
    if err then
        return nil, err
    end

    loaded_common = rules
    return rules, nil
end

function Validator:get_table_fields(table_name)
    local rules, err = self:load_table_rules(table_name)
    if err then
        return nil, err
    end
    return rules.fields or {}
end

function Validator:get_table_scenarios(table_name)
    local rules, err = self:load_table_rules(table_name)
    if err then
        return nil, err
    end
    return rules.scenarios or {}
end

function Validator:get_field_rules(table_name, field_name)
    local fields = self:get_table_fields(table_name)
    if not fields then
        return nil, 'Table not found: ' .. table_name
    end

    local field = fields[field_name]
    if not field then
        return nil, 'Field not found: ' .. field_name
    end

    return field.rules or {}
end

function Validator:get_field_label(table_name, field_name)
    local fields = self:get_table_fields(table_name)
    if not fields then
        return nil
    end

    local field = fields[field_name]
    if not field then
        return nil
    end

    return field.label or field_name
end

function Validator:get_scenario_fields(table_name, scenario_name)
    local scenarios = self:get_table_scenarios(table_name)
    if not scenarios then
        return nil, 'Table not found: ' .. table_name
    end

    return scenarios[scenario_name] or {}
end

function Validator:get_common_field(field_name)
    local common = self:load_common_rules()
    if not common then
        return nil
    end

    return common.fields[field_name] or {}
end

function Validator:get_common_type(type_name)
    local common = self:load_common_rules()
    if not common then
        return nil
    end

    return common.types[type_name] or {}
end

function Validator:build_rules_from_config(table_name, fields_or_scenario)
    local rules = {}
    local fields = self:get_table_fields(table_name)

    if not fields then
        return nil, 'Table not found: ' .. table_name
    end

    local field_list = fields_or_scenario
    if type(fields_or_scenario) == 'string' then
        field_list = self:get_scenario_fields(table_name, fields_or_scenario)
    end

    for _, field_name in ipairs(field_list) do
        local field_config = fields[field_name]
        if field_config then
            local field_rules = field_config.rules or {}
            if #field_rules > 0 then
                rules[field_name] = field_rules
            end
        end
    end

    return rules
end

function Validator:build_labels_from_config(table_name)
    local labels = {}
    local fields = self:get_table_fields(table_name)

    if not fields then
        return nil, 'Table not found: ' .. table_name
    end

    for field_name, field_config in pairs(fields) do
        if field_config.label then
            labels[field_name] = field_config.label
        end
    end

    return labels
end

function Validator:validate(table_name, data, fields_or_scenario, custom_rules)
    local Validation = require('app.lib.validation')

    local rules = custom_rules or {}
    if not custom_rules then
        rules = self:build_rules_from_config(table_name, fields_or_scenario)
    end

    if not rules or next(rules) == nil then
        return nil, 'No rules found'
    end

    local labels = self:build_labels_from_config(table_name)

    local validation = Validation:new({
        bail = true
    })
    validation:make(data, rules)
    validation:with_labels(labels)

    if validation:fails() then
        return false, validation:to_json()
    end

    return true, data
end

function Validator:validate_scenario(table_name, scenario_name, data)
    return self:validate(table_name, data, scenario_name)
end

function Validator:get_table_info(table_name)
    local rules, err = self:load_table_rules(table_name)
    if err then
        return nil, err
    end

    return {
        table_name = rules.table_name,
        description = rules.description,
        field_count = rules.fields and #rules.fields or 0,
        scenario_count = rules.scenarios and #rules.scenarios or 0
    }
end

function Validator:list_tables()
    local base_path = '/var/www/web/my-openresty/config/validation'
    local tables = {}

    local ok, files = pcall(function()
        local result = {}
        for file in io.popen('ls -1 "' .. base_path .. '"'):lines() do
            if string.match(file, '%.lua$') and file ~= 'common.lua' then
                table.insert(result, string.gsub(file, '%.lua$', ''))
            end
        end
        return result
    end)

    if not ok then
        return {}
    end

    return files
end

function Validator:get_all_fields_info(table_name)
    local fields = self:get_table_fields(table_name)
    if not fields then
        return nil
    end

    local result = {}
    for field_name, field_config in pairs(fields) do
        table.insert(result, {
            name = field_name,
            type = field_config.type or 'string',
            label = field_config.label or field_name,
            rules = field_config.rules or {},
            description = field_config.description or '',
            optional = field_config.optional or false,
            default = field_config.default
        })
    end

    return result
end

function Validator:get_all_scenarios(table_name)
    local scenarios = self:get_table_scenarios(table_name)
    if not scenarios then
        return nil
    end

    local result = {}
    for name, fields in pairs(scenarios) do
        table.insert(result, {
            name = name,
            fields = fields
        })
    end

    return result
end

function Validator:clear_cache(table_name)
    if table_name then
        loaded_rules[table_name] = nil
    else
        loaded_rules = {}
        loaded_common = nil
    end
end

return Validator
