#!/usr/bin/env lua

--[[
MyResty Test Runner

Usage:
    lua tests/run.lua [--url http://localhost:8080] [--output json]

Options:
    --url     Base URL for API testing (default: http://localhost:8080)
    --output  Output format: json or plain (default: plain)
]]

local http = require('socket.http')
local ltn12 = require('ltn12')
local json = require('cjson')

local args = {...}
local base_url = 'http://localhost:8080'
local output_format = 'plain'

for i, arg in ipairs(args) do
    if arg == '--url' and args[i+1] then
        base_url = args[i+1]
    elseif arg == '--output' and args[i+1] then
        output_format = args[i+1]
    elseif arg == '--help' or arg == '-h' then
        print([[
MyResty Test Runner

Usage:
    lua tests/run.lua [--url URL] [--output FORMAT]

Options:
    --url     Base URL for API testing (default: http://localhost:8080)
    --output  Output format: json or plain (default: plain)

Examples:
    lua tests/run.lua
    lua tests/run.lua --url http://127.0.0.1:8080 --output json
]])
        os.exit(0)
    end
end

local function request(method, path, data)
    local url = base_url .. path
    local body = nil
    local headers = {}

    if data then
        if type(data) == 'table' then
            local parts = {}
            for k, v in pairs(data) do
                table.insert(parts, k .. '=' .. tostring(v))
            end
            body = table.concat(parts, '&')
            headers['Content-Type'] = 'application/x-www-form-urlencoded'
        else
            body = data
        end
    end

    local resp_body = {}
    local resp, code, resp_headers = http.request {
        url = url,
        method = method,
        headers = headers,
        body = body,
        sink = ltn12.sink.table(resp_body)
    }

    if not resp then
        return nil, code
    end

    local resp_str = table.concat(resp_body)
    local resp_json = nil

    pcall(function()
        resp_json = json.decode(resp_str)
    end)

    return {
        status = code,
        body = resp_str,
        json = resp_json,
        headers = resp_headers
    }
end

local function assert(response, conditions)
    local failures = {}

    if conditions.status and response.status ~= conditions.status then
        table.insert(failures, string.format('Expected status %d, got %d', conditions.status, response.status))
    end

    if conditions.json_has then
        if not response.json then
            table.insert(failures, 'Expected JSON response')
        else
            for k, v in pairs(conditions.json_has) do
                if response.json[k] == nil then
                    table.insert(failures, 'Expected json.' .. k)
                elseif v ~= nil and response.json[k] ~= v then
                    table.insert(failures, string.format('Expected json.%s=%s, got %s', k, tostring(v), tostring(response.json[k])))
                end
            end
        end
    end

    return #failures == 0, failures
end

local tests = {
    {
        name = 'GET / (API Root)',
        test = function()
            local res = request('GET', '/')
            assert(res, {status = 200, json_has = {message = true}})
        end
    },
    {
        name = 'GET /users (User List)',
        test = function()
            local res = request('GET', '/users')
            assert(res, {status = 200})
        end
    },
    {
        name = 'POST /cache/set (Set Cache)',
        test = function()
            local res = request('POST', '/cache/set', {
                key = 'test_key_' .. tostring(os.time()),
                value = 'test_value',
                ttl = 60
            })
            assert(res, {status = 200, json_has = {success = true}})
        end
    },
    {
        name = 'POST /cache/get (Get Cache)',
        test = function()
            local res = request('POST', '/cache/get', {key = 'test_key'})
            assert(res, {status = 200})
        end
    },
    {
        name = 'POST /session/set (Set Session)',
        test = function()
            local res = request('POST', '/session/set', {
                key = 'test_session',
                value = 'test_value'
            })
            assert(res, {status = 200, json_has = {success = true}})
        end
    },
    {
        name = 'POST /session/get (Get Session)',
        test = function()
            local res = request('POST', '/session/get', {key = 'test_session'})
            assert(res, {status = 200})
        end
    },
    {
        name = 'POST /cache/incr (Increment)',
        test = function()
            local res = request('POST', '/cache/incr', {
                key = 'test_counter_' .. tostring(os.time()),
                step = 1
            })
            assert(res, {status = 200})
        end
    },
    {
        name = 'GET /captcha (Captcha Image)',
        test = function()
            local res = request('GET', '/captcha?width=120&height=80')
            assert(res, {status = 200})
        end
    },
    {
        name = 'GET /cache/stats (Cache Stats)',
        test = function()
            local res = request('GET', '/cache/stats')
            assert(res, {status = 200, json_has = {capacity = true}})
        end
    },
    {
        name = 'GET /cache/keys (Cache Keys)',
        test = function()
            local res = request('GET', '/cache/keys')
            assert(res, {status = 200, json_has = {count = true}})
        end
    }
}

local function run_tests()
    local passed = 0
    local failed = 0
    local start_time = os.time()

    for _, test in ipairs(tests)
    do
        local status, err = pcall(test.test)

        if status then
            passed = passed + 1
            if output_format == 'plain' then
                print('[PASS] ' .. test.name)
            end
        else
            failed = failed + 1
            if output_format == 'plain' then
                print('[FAIL] ' .. test.name)
                print('       Error: ' .. tostring(err))
            end
        end
    end

    local duration = os.time() - start_time

    if output_format == 'json' then
        local result = {
            suite = 'MyResty API Tests',
            total = #tests,
            passed = passed,
            failed = failed,
            duration = duration .. 's',
            timestamp = os.date('%Y-%m-%d %H:%M:%S')
        }
        print(json.encode(result, pretty = true))
    else
        print('')
        print('========================================')
        print('Test Suite: MyResty API Tests')
        print('Total: ' .. #tests)
        print('Passed: ' .. passed)
        print('Failed: ' .. failed)
        print('Duration: ' .. duration .. 's')
        print('========================================')
    end
end

print('Running MyResty API Tests...')
print('Base URL: ' .. base_url)
print('')

run_tests()
