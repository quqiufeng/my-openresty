#!/usr/bin/env lua
--[[
MyResty Unit Test Runner

Usage:
    lua tests/unit/run.lua                    -- Run all tests
    lua tests/unit/run.lua --spec calculator  -- Run specific spec
    lua tests/unit/run.lua --format json      -- JSON output
    lua tests/unit/run.lua --help             -- Show help
]]

package.path = '/var/www/web/my-resty/?.lua;/var/www/web/my-resty/?/init.lua;/usr/local/web/?.lua;;'
package.cpath = '/var/www/web/my-resty/?.so;/usr/local/web/lualib/?.so;;'

local Test = require('app.utils.test')
local args = {...}

-- Parse arguments
local options = {
    spec = nil,
    format = 'plain',
    help = false
}

for i, arg in ipairs(args) do
    if arg == '--help' or arg == '-h' then
        options.help = true
    elseif (arg == '--spec' or arg == '-s') and args[i + 1] then
        options.spec = args[i + 1]
    elseif (arg == '--format' or arg == '-f') and args[i + 1] then
        options.format = args[i + 1]
    elseif arg == '--quiet' or arg == '-q' then
        options.format = 'quiet'
    end
end

if options.help then
    print([[
MyResty Unit Test Runner

Usage:
    lua tests/unit/run.lua [options]

Options:
    --spec NAME      Run specific spec file (without _spec.lua)
    --format FORMAT  Output format: plain, json, quiet (default: plain)
    --help, -h       Show this help message

Examples:
    lua tests/unit/run.lua
    lua tests/unit/run.lua --spec calculator
    lua tests/unit/run.lua --format json
    lua tests/unit/run.lua --spec config --format json

Specs:
    calculator  - Calculator and string utility tests
    config      - Config module tests
]])
    os.exit(0)
end

-- Find and load spec files
local function find_specs()
    local specs = {}
    local spec_dir = '/var/www/web/my-resty/tests/unit'

    -- Check if spec directory exists
    local ok, err = io.open(spec_dir)
    if not ok then
        print('Error: Spec directory not found: ' .. spec_dir)
        os.exit(1)
    end
    ok:close()

    -- Find all spec files
    for file in io.lines(io.popen('ls ' .. spec_dir)) do
        if file:match('_spec%.lua$') then
            table.insert(specs, file:gsub('_spec%.lua$', ''))
        end
    end

    return specs
end

-- Filter specs if specified
local function filter_specs(all_specs, filter)
    if not filter then
        return all_specs
    end

    local filtered = {}
    for _, spec in ipairs(all_specs) do
        if spec == filter or spec:find(filter, 1, true) then
            table.insert(filtered, spec)
        end
    end

    if #filtered == 0 then
        print('Error: Spec "' .. filter .. '" not found')
        print('Available specs: ' .. table.concat(all_specs, ', '))
        os.exit(1)
    end

    return filtered
end

-- Load a spec file
local function load_spec(name)
    local spec_file = '/var/www/web/my-resty/tests/unit/' .. name .. '_spec.lua'

    local ok, err = io.open(spec_file)
    if not ok then
        print('Error: Spec file not found: ' .. spec_file)
        os.exit(1)
    end
    ok:close()

    -- Clear test state
    Test.reset()

    -- Expose Test module functions globally for the spec
    _G.describe = Test.describe
    _G.it = Test.it
    _G.pending = Test.pending
    _G.before_each = Test.before_each
    _G.after_each = Test.after_each
    _G.assert = Test.assert

    -- Load and run the spec
    dofile(spec_file)
end

-- Main
print('MyResty Unit Test Runner')
print('========================')
print('')

local all_specs = find_specs()
local specs_to_run = filter_specs(all_specs, options.spec)

print('Running ' .. #specs_to_run .. ' test suite(s)...')
print('')

for _, spec in ipairs(specs_to_run) do
    print('Loading: ' .. spec .. '_spec.lua')
    load_spec(spec)
end

print('')

-- Run all tests
Test.run({ format = options.format })
