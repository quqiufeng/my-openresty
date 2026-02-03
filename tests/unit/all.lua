#!/usr/bin/env lua
--[[
MyResty All Unit Tests Runner

Usage:
    lua tests/unit/all.lua              -- Run all tests
    lua tests/unit/all.lua --quiet      -- Quiet mode
    lua tests/unit/all.lua --json       -- JSON output
]]

package.path = '/var/www/web/my-openresty/?.lua;/var/www/web/my-openresty/?/init.lua;/usr/local/web/?.lua;;'
package.cpath = '/var/www/web/my-openresty/?.so;/usr/local/web/lualib/?.so;;'

local Test = require('app.utils.test')

local args = {...}
local options = {
    format = 'plain'
}

for i, arg in ipairs(args) do
    if arg == '--quiet' or arg == '-q' then
        options.format = 'quiet'
    elseif arg == '--json' or arg == '-j' then
        options.format = 'json'
    elseif arg == '--help' or arg == '-h' then
        print([[
MyResty All Unit Tests

Usage:
    lua tests/unit/all.lua [options]

Options:
    --quiet, -q    Minimal output
    --json, -j     JSON output format
    --help, -h     Show this help

Test Suites:
    - config_spec.lua
    - router_spec.lua
    - helper_spec.lua
    - request_spec.lua
    - response_spec.lua
    - query_builder_spec.lua
    - cache_spec.lua
    - session_spec.lua
    - http_spec.lua
]])
        os.exit(0)
    end
end

-- Define all test specs
local test_specs = {
    'config_spec.lua',
    'router_spec.lua',
    'helper_spec.lua',
    'request_spec.lua',
    'response_spec.lua',
    'query_builder_spec.lua',
    'cache_spec.lua',
    'session_spec.lua',
    'http_spec.lua'
}

local function load_spec(filename)
    local spec_file = '/var/www/web/my-openresty/tests/unit/' .. filename

    local ok, err = io.open(spec_file)
    if not ok then
        print('Error: Spec file not found: ' .. spec_file)
        return false
    end
    ok:close()

    -- Reset test state and load spec
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

    return true
end

-- Main
print('MyResty Unit Tests - All Suites')
print('================================')
print('')
print('Running ' .. #test_specs .. ' test suite(s)...')
print('')

local total_passed = 0
local total_failed = 0
local total_tests = 0

for _, spec in ipairs(test_specs) do
    print('Loading: ' .. spec)

    local ok = load_spec(spec)
    if ok then
        -- Spec loaded successfully
    end
    print('')
end

-- Run all tests in a single call
Test.run({ format = options.format })
