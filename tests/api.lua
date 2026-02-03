local Test = require('app.libraries.test')

local function run_api_tests()
    local test = Test:new({
        base_url = 'http://localhost:8080',
        timeout = 10000,
        verbose = true
    })

    local suite = test:describe('MyResty API Tests', {
        {
            name = 'GET / should return welcome message',
            fn = function(t)
                local res = t:get('/')
                local ok, err = t:assert(res, {
                    status = 200,
                    json_has = {message = true}
                })
                if not ok then
                    error('Test failed: ' .. table.concat(err, ', '))
                end
            end
        },
        {
            name = 'GET /users should return user list',
            fn = function(t)
                local res = t:get('/users')
                local ok, err = t:assert(res, {
                    status = 200
                })
                if not ok then
                    error('Test failed: ' .. table.concat(err, ', '))
                end
            end
        },
        {
            name = 'POST /session/set should set session value',
            fn = function(t)
                local res = t:post('/session/set', {
                    key = 'test_key',
                    value = 'test_value'
                })
                local ok, err = t:assert(res, {
                    status = 200,
                    json_has = {success = true}
                })
                if not ok then
                    error('Test failed: ' .. table.concat(err, ', '))
                end
            end
        },
        {
            name = 'POST /session/get should get session value',
            fn = function(t)
                local res = t:post('/session/get', {
                    key = 'test_key'
                })
                local ok, err = t:assert(res, {
                    status = 200,
                    json_has = {value = 'test_value'}
                })
                if not ok then
                    error('Test failed: ' .. table.concat(err, ', '))
                end
            end
        },
        {
            name = 'POST /cache/set should set cache value',
            fn = function(t)
                local res = t:post('/cache/set', {
                    key = 'test_cache_key',
                    value = 'test_cache_value',
                    ttl = 3600
                })
                local ok, err = t:assert(res, {
                    status = 200,
                    json_has = {success = true}
                })
                if not ok then
                    error('Test failed: ' .. table.concat(err, ', '))
                end
            end
        },
        {
            name = 'POST /cache/get should get cache value',
            fn = function(t)
                local res = t:post('/cache/get', {
                    key = 'test_cache_key'
                })
                local ok, err = t:assert(res, {
                    status = 200,
                    json_has = {success = true}
                })
                if not ok then
                    error('Test failed: ' .. table.concat(err, ', '))
                end
            end
        },
        {
            name = 'POST /cache/incr should increment counter',
            fn = function(t)
                local res = t:post('/cache/incr', {
                    key = 'test_counter',
                    step = 1
                })
                local ok, err = t:assert(res, {
                    status = 200,
                    json_has = {success = true}
                })
                if not ok then
                    error('Test failed: ' .. table.concat(err, ', '))
                end
            end
        },
        {
            name = 'GET /captcha should return image',
            fn = function(t)
                local res = t:get('/captcha', {width = 120, height = 80})
                local ok, err = t:assert(res, {
                    status_range = {200, 300}
                })
                if not ok then
                    error('Test failed: ' .. table.concat(err, ', '))
                end
            end
        },
        {
            name = 'POST /session/destroy should clear session',
            fn = function(t)
                local res = t:post('/session/destroy')
                local ok, err = t:assert(res, {
                    status = 200,
                    json_has = {success = true}
                })
                if not ok then
                    error('Test failed: ' .. table.concat(err, ', '))
                end
            end
        },
        {
            name = 'POST /cache/clear should clear cache',
            fn = function(t)
                local res = t:post('/cache/clear')
                local ok, err = t:assert(res, {
                    status = 200,
                    json_has = {success = true}
                })
                if not ok then
                    error('Test failed: ' .. table.concat(err, ', '))
                end
            end
        }
    })

    local results = test:run_and_report(suite)

    return results
end

return {
    run = run_api_tests
}
