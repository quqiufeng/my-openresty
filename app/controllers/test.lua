local BaseController = require('app.core.Controller')
local Test = require('app.lib.test')

local TestController = {}

function TestController:index()
    return self:json({
        success = true,
        message = 'Test API',
        endpoints = {
            ['GET /test'] = 'Run all API tests',
            ['GET /test/users'] = 'Test user endpoints',
            ['GET /test/session'] = 'Test session endpoints',
            ['GET /test/cache'] = 'Test cache endpoints',
            ['GET /test/captcha'] = 'Test captcha endpoints',
        }
    })
end

function TestController:runAll()
    local test = Test:new({
        base_url = 'http://localhost:8080',
        timeout = 10000,
        verbose = false
    })

    local suite = test:describe('Full API Test Suite', {
        {
            name = 'API Root',
            fn = function(t)
                local res = t:get('/')
                t:assert(res, {status = 200, json_has = {message = true}})
            end
        },
        {
            name = 'User List',
            fn = function(t)
                local res = t:get('/users')
                t:assert(res, {status = 200})
            end
        },
        {
            name = 'Cache Set',
            fn = function(t)
                local res = t:post('/cache/set', {
                    key = 'test_key_' .. tostring(os.time()),
                    value = 'test_value'
                })
                t:assert(res, {status = 200, json_has = {success = true}})
            end
        },
        {
            name = 'Cache Get',
            fn = function(t)
                local res = t:post('/cache/get', {
                    key = 'test_key'
                })
                t:assert(res, {status = 200})
            end
        },
        {
            name = 'Session Set',
            fn = function(t)
                local res = t:post('/session/set', {
                    key = 'test_session',
                    value = 'session_value'
                })
                t:assert(res, {status = 200, json_has = {success = true}})
            end
        },
        {
            name = 'Session Get',
            fn = function(t)
                local res = t:post('/session/get', {
                    key = 'test_session'
                })
                t:assert(res, {status = 200})
            end
        },
        {
            name = 'Cache Increment',
            fn = function(t)
                local res = t:post('/cache/incr', {
                    key = 'test_incr_' .. tostring(os.time()),
                    step = 1
                })
                t:assert(res, {status = 200})
            end
        },
        {
            name = 'Captcha Image',
            fn = function(t)
                local res = t:get('/captcha', {width = 120, height = 80})
                t:assert(res, {status_range = {200, 300}})
            end
        }
    })

    local results = test:run_tests(suite)

    return self:json(results)
end

function TestController:users()
    local test = Test:new({
        base_url = 'http://localhost:8080',
        timeout = 10000,
        verbose = false
    })

    local suite = test:describe('User API Tests', {
        {
            name = 'GET /users',
            fn = function(t)
                local res = t:get('/users')
                t:assert(res, {status = 200})
            end
        },
        {
            name = 'GET /users/1',
            fn = function(t)
                local res = t:get('/users/1')
                t:assert(res, {status = 200})
            end
        }
    })

    local results = test:run_tests(suite)

    return self:json(results)
end

function TestController:session()
    local test = Test:new({
        base_url = 'http://localhost:8080',
        timeout = 10000,
        verbose = false
    })

    local suite = test:describe('Session API Tests', {
        {
            name = 'Set Session',
            fn = function(t)
                local res = t:post('/session/set', {
                    key = 'user_id',
                    value = '123'
                })
                t:assert(res, {status = 200, json_has = {success = true}})
            end
        },
        {
            name = 'Get Session',
            fn = function(t)
                local res = t:post('/session/get', {
                    key = 'user_id'
                })
                t:assert(res, {status = 200, json_has = {value = '123'}})
            end
        },
        {
            name = 'Remove Session',
            fn = function(t)
                local res = t:post('/session/remove', {
                    key = 'user_id'
                })
                t:assert(res, {status = 200})
            end
        }
    })

    local results = test:run_tests(suite)

    return self:json(results)
end

function TestController:cache()
    local test = Test:new({
        base_url = 'http://localhost:8080',
        timeout = 10000,
        verbose = false
    })

    local suite = test:describe('Cache API Tests', {
        {
            name = 'Set Cache',
            fn = function(t)
                local res = t:post('/cache/set', {
                    key = 'api_test_key',
                    value = 'test_value_' .. tostring(os.time()),
                    ttl = 60
                })
                t:assert(res, {status = 200, json_has = {success = true}})
            end
        },
        {
            name = 'Get Cache',
            fn = function(t)
                local res = t:post('/cache/get', {
                    key = 'api_test_key'
                })
                t:assert(res, {status = 200})
            end
        },
        {
            name = 'Increment',
            fn = function(t)
                local res = t:post('/cache/incr', {
                    key = 'api_test_counter_' .. tostring(os.time()),
                    step = 1
                })
                t:assert(res, {status = 200})
            end
        },
        {
            name = 'Get Keys',
            fn = function(t)
                local res = t:get('/cache/keys')
                t:assert(res, {status = 200, json_has = {count = true}})
            end
        },
        {
            name = 'Get Stats',
            fn = function(t)
                local res = t:get('/cache/stats')
                t:assert(res, {status = 200, json_has = {capacity = true}})
            end
        }
    })

    local results = test:run_tests(suite)

    return self:json(results)
end

function TestController:captcha()
    local test = Test:new({
        base_url = 'http://localhost:8080',
        timeout = 10000,
        verbose = false
    })

    local suite = test:describe('Captcha API Tests', {
        {
            name = 'Get Captcha Image',
            fn = function(t)
                local res = t:get('/captcha', {width = 120, height = 80})
                t:assert(res, {status_range = {200, 300}})
            end
        },
        {
            name = 'Get Captcha Code',
            fn = function(t)
                local res = t:get('/captcha/code')
                t:assert(res, {status = 200, json_has = {code = true}})
            end
        },
        {
            name = 'Get Info',
            fn = function(t)
                local res = t:get('/captcha', {width = 150, height = 60})
                t:assert(res, {status_range = {200, 300}})
            end
        }
    })

    local results = test:run_tests(suite)

    return self:json(results)
end

return TestController
