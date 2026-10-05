#!/usr/bin/env lua
--[[
MyResty Unit Test Runner

Usage:
    luajit tests/unit/run.lua                    -- Run all tests
    luajit tests/unit/run.lua --spec router      -- Run specs matching "router"
    luajit tests/unit/run.lua --format json      -- JSON output
    luajit tests/unit/run.lua --help             -- Show help

Discovers every *_spec.lua under tests/unit (recursively) that uses the
app.utils.test framework. Standalone generated specs (self-executing) are
skipped here and can be run directly, e.g. luajit tests/unit/controllers/AdminSpec.lua
]]

package.path = '/var/www/web/my-openresty/?.lua;/var/www/web/my-openresty/?/init.lua;/usr/local/lualib/?.lua;;'
package.cpath = '/var/www/web/my-openresty/?.so;/usr/local/lualib/?.so;;'

-- Provide a minimal `ngx` mock so modules can load under plain LuaJIT.
pcall(dofile, '/var/www/web/my-openresty/tests/unit/ngx_mock.lua')

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
    luajit tests/unit/run.lua [options]

Options:
    --spec NAME      Run specs whose path contains NAME
    --format FORMAT  Output format: plain, json (default: plain)
    --help, -h       Show this help message

Examples:
    luajit tests/unit/run.lua
    luajit tests/unit/run.lua --spec router
    luajit tests/unit/run.lua --format json
]])
    os.exit(0)
end

local SPEC_DIR = '/var/www/web/my-openresty/tests/unit'

-- Find recursively every *_spec.lua that uses the app.utils.test framework.
local function find_specs()
    local specs = {}

    local dir = io.open(SPEC_DIR)
    if not dir then
        print('Error: Spec directory not found: ' .. SPEC_DIR)
        os.exit(1)
    end
    dir:close()

    local pipe = io.popen and io.popen('find ' .. SPEC_DIR .. ' -type f -name "*_spec.lua" 2>/dev/null')
    if not pipe then
        print('Error: cannot enumerate spec files (io.popen unavailable)')
        os.exit(1)
    end

    for file in pipe:lines() do
        local f = io.open(file, 'r')
        if f then
            local content = f:read('*a')
            f:close()
            -- Only Test-framework specs can be aggregated into one run.
            if content and content:find('app.utils.test', 1, true) then
                specs[#specs + 1] = file
            end
        end
    end
    pipe:close()

    table.sort(specs)
    return specs
end

local function filter_specs(all_specs, filter)
    if not filter then
        return all_specs
    end

    local filtered = {}
    for _, spec in ipairs(all_specs) do
        if spec:find(filter, 1, true) then
            filtered[#filtered + 1] = spec
        end
    end

    if #filtered == 0 then
        print('Error: no spec matching "' .. filter .. '"')
        print('Available specs:')
        for _, spec in ipairs(all_specs) do print('  ' .. spec) end
        os.exit(1)
    end

    return filtered
end

-- Expose Test module functions globally for the specs
_G.describe = Test.describe
_G.it = Test.it
_G.pending = Test.pending
_G.before_each = Test.before_each
_G.after_each = Test.after_each
_G.assert = Test.assert

print('MyResty Unit Test Runner')
print('========================')
print('')

local all_specs = find_specs()
local specs_to_run = filter_specs(all_specs, options.spec)

print('Running ' .. #specs_to_run .. ' test suite(s)...')
print('')

local load_errors = 0
for _, spec in ipairs(specs_to_run) do
    print('Loading: ' .. spec)
    local ok, err = pcall(dofile, spec)
    if not ok then
        load_errors = load_errors + 1
        print('  [LOAD ERROR] ' .. tostring(err))
    end
end

print('')
Test.run({ format = options.format })
