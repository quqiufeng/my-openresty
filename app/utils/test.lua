--[[
MyResty Unit Test Framework

Usage:
```lua
local Test = require('app.utils.test')

describe('Calculator', function()
    before_each(function()
        -- 每个测试前执行
    end)

    after_each(function()
        -- 每个测试后执行
    end)

    it('should add two numbers', function()
        assert.equals(3, add(1, 2))
    end)

    it('should handle zero', function()
        assert.is_true(add(0, 0) == 0)
    end)
end)
```

Run tests:
```bash
lua tests/unit/run.lua
```
]]

local _M = {}

-- Color codes for terminal output
local COLORS = {
    RESET = '\27[0m',
    GREEN = '\27[32m',
    RED = '\27[31m',
    YELLOW = '\27[33m',
    BLUE = '\27[34m',
    CYAN = '\27[36m'
}

-- Track test state
local test_state = {
    suites = {},
    current_suite = nil,
    current_test = nil,
    passed = 0,
    failed = 0,
    errors = 0,
    start_time = nil,
    output_format = 'plain'  -- 'plain' or 'json'
}

-- Assertion functions
local assertions = {}

function assertions.equals(expected, actual, msg)
    if expected ~= actual then
        msg = msg or string.format('Expected %s, got %s', tostring(expected), tostring(actual))
        error(msg, 2)
    end
end

function assertions.not_equals(expected, actual, msg)
    if expected == actual then
        msg = msg or string.format('Expected values to be different')
        error(msg, 2)
    end
end

function assertions.is_true(value, msg)
    if value ~= true then
        msg = msg or 'Expected true, got ' .. tostring(value)
        error(msg, 2)
    end
end

function assertions.is_false(value, msg)
    if value ~= false then
        msg = msg or 'Expected false, got ' .. tostring(value)
        error(msg, 2)
    end
end

function assertions.is_nil(value, msg)
    if value ~= nil then
        msg = msg or 'Expected nil, got ' .. tostring(value)
        error(msg, 2)
    end
end

function assertions.not_nil(value, msg)
    if value == nil then
        msg = msg or 'Expected non-nil value'
        error(msg, 2)
    end
end

function assertions.is_not_nil(value, msg)
    if value == nil then
        msg = msg or 'Expected non-nil value'
        error(msg, 2)
    end
end

function assertions.is_function(value, msg)
    if type(value) ~= 'function' then
        msg = msg or 'Expected function, got ' .. type(value)
        error(msg, 2)
    end
end

function assertions.is_table(value, msg)
    if type(value) ~= 'table' then
        msg = msg or 'Expected table, got ' .. type(value)
        error(msg, 2)
    end
end

function assertions.is_string(value, msg)
    if type(value) ~= 'string' then
        msg = msg or 'Expected string, got ' .. type(value)
        error(msg, 2)
    end
end

function assertions.has_key(key, table, msg)
    if type(table) ~= 'table' or table[key] == nil then
        msg = msg or 'Table should have key: ' .. tostring(key)
        error(msg, 2)
    end
end

function assertions.error(fn, msg, expected_err)
    local ok, err = pcall(fn)
    if ok then
        msg = msg or 'Expected function to throw error'
        error(msg, 2)
    end
    if expected_err and not string.find(tostring(err), expected_err, 1, true) then
        error('Expected error containing "' .. expected_err .. '", got: ' .. tostring(err), 2)
    end
end

function assertions.no_error(fn, msg)
    local ok, err = pcall(fn)
    if not ok then
        msg = msg or 'Unexpected error: ' .. tostring(err)
        error(msg, 2)
    end
end

function assertions.matches(pattern, value, msg)
    if not string.find(value or '', pattern, 1) then
        msg = msg or 'Value should match pattern: ' .. tostring(pattern)
        error(msg, 2)
    end
end

function assertions.approx(actual, expected, tolerance, msg)
    tolerance = tolerance or 0.001
    if math.abs(actual - expected) > tolerance then
        msg = msg or string.format('Expected ~%f, got %f (tolerance: %f)',
            expected, actual, tolerance)
        error(msg, 2)
    end
end

-- Make assertions available globally in tests
local assert = setmetatable({}, {
    __index = function(_, key)
        if assertions[key] then
            return function(...)
                return assertions[key](...)
            end
        end
        error('Unknown assertion: ' .. tostring(key), 2)
    end
})

-- Test suite builder
local function describe(name, fn)
    local suite = {
        name = name,
        tests = {},
        before_each = nil,
        after_each = nil
    }

    local prev_suite = test_state.current_suite
    test_state.current_suite = suite

    -- Run suite definition
    fn()

    table.insert(test_state.suites, suite)
    test_state.current_suite = prev_suite
end

-- Test case builder
local function it(name, fn)
    if not test_state.current_suite then
        error('it() must be called inside describe()', 2)
    end

    table.insert(test_state.current_suite.tests, {
        name = name,
        fn = fn
    })
end

-- Pending test (not yet implemented)
local function pending(name, reason)
    reason = reason or 'Not implemented'
    if not test_state.current_suite then
        error('pending() must be called inside describe()', 2)
    end

    table.insert(test_state.current_suite.tests, {
        name = name,
        pending = true,
        reason = reason
    })
end

-- Setup/teardown
local function before_each(fn)
    if not test_state.current_suite then
        error('before_each() must be called inside describe()', 2)
    end
    test_state.current_suite.before_each = fn
end

local function after_each(fn)
    if not test_state.current_suite then
        error('after_each() must be called inside describe()', 2)
    end
    test_state.current_suite.after_each = fn
end

-- Run a single test
local function run_test(suite, test)
    local start_time = os.time()

    -- Run before_each
    if suite.before_each then
        suite.before_each()
    end

    local success, err = pcall(test.fn)

    -- Run after_each
    if suite.after_each then
        suite.after_each()
    end

    return success, err, os.time() - start_time
end

-- Run all tests
local function run_all(options)
    options = options or {}
    test_state.output_format = options.format or 'plain'
    test_state.start_time = os.time()
    test_state.passed = 0
    test_state.failed = 0
    test_state.errors = {}

    if test_state.output_format == 'plain' then
        print('')
        print(COLORS.CYAN .. '========================================' .. COLORS.RESET)
        print(COLORS.CYAN .. '  MyResty Unit Tests' .. COLORS.RESET)
        print(COLORS.CYAN .. '========================================' .. COLORS.RESET)
        print('')
    end

    for _, suite in ipairs(test_state.suites) do
        if test_state.output_format == 'plain' then
            print(COLORS.BLUE .. '  ' .. suite.name .. COLORS.RESET)
            print('  ' .. string.rep('-', #suite.name))
        end

        for _, test in ipairs(suite.tests) do
            if test.pending then
                if test_state.output_format == 'plain' then
                    print(COLORS.YELLOW .. '  [PENDING] ' .. test.name .. COLORS.RESET)
                    if test.reason ~= 'Not implemented' then
                        print('           ' .. test.reason)
                    end
                end
            else
                local success, err, duration = run_test(suite, test)

                if success then
                    test_state.passed = test_state.passed + 1
                    if test_state.output_format == 'plain' then
                        print(COLORS.GREEN .. '  [PASS] ' .. test.name .. COLORS.RESET)
                    end
                else
                    test_state.failed = test_state.failed + 1
                    if test_state.output_format == 'plain' then
                        print(COLORS.RED .. '  [FAIL] ' .. test.name .. COLORS.RESET)
                        print('         ' .. tostring(err))
                    else
                        table.insert(test_state.errors, {
                            suite = suite.name,
                            test = test.name,
                            error = tostring(err)
                        })
                    end
                end
            end
        end

        if test_state.output_format == 'plain' then
            print('')
        end
    end

    local duration = os.time() - test_state.start_time

    -- Output results
    if test_state.output_format == 'json' then
        local result = {
            framework = 'MyResty Test',
            version = '1.0.0',
            timestamp = os.date('%Y-%m-%d %H:%M:%S'),
            duration = duration .. 's',
            suites = #test_state.suites,
            tests = {
                total = test_state.passed + test_state.failed,
                passed = test_state.passed,
                failed = test_state.failed,
                pending = 0  -- Could add pending count
            },
            failures = test_state.errors
        }
        local cjson = require('cjson')
        local json_str = cjson.encode(result)
        -- Pretty print by decoding and re-encoding
        local ok, pretty = pcall(function()
            local decoded = cjson.decode(json_str)
            return cjson.encode(decoded)
        end)
        print(ok and pretty or json_str)
    else
        print(COLORS.CYAN .. '========================================' .. COLORS.RESET)
        print(COLORS.CYAN .. '  Results' .. COLORS.RESET)
        print(COLORS.CYAN .. '========================================' .. COLORS.RESET)
        print('')
        print('  Total:   ' .. tostring(test_state.passed + test_state.failed))
        print('  Passed:  ' .. COLORS.GREEN .. tostring(test_state.passed) .. COLORS.RESET)
        print('  Failed:  ' .. COLORS.RED .. tostring(test_state.failed) .. COLORS.RESET)
        print('  Duration: ' .. tostring(duration) .. 's')
        print('')

        if test_state.failed > 0 then
            print(COLORS.RED .. '  TESTS FAILED' .. COLORS.RESET)
            os.exit(1)
        else
            print(COLORS.GREEN .. '  ALL TESTS PASSED' .. COLORS.RESET)
            os.exit(0)
        end
    end
end

-- Reset state
local function reset()
    test_state.suites = {}
    test_state.current_suite = nil
    test_state.current_test = nil
    test_state.passed = 0
    test_state.failed = 0
    test_state.errors = 0
end

-- Expose API
_M.describe = describe
_M.it = it
_M.pending = pending
_M.before_each = before_each
_M.after_each = after_each
_M.run = run_all
_M.reset = reset
_M.assert = assert
_M.colors = COLORS

return _M
