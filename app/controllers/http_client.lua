local BaseController = require('app.core.Controller')
local HttpClient = require('app.lib.http')

local HttpClientController = {}

function HttpClientController:index()
    local response = {
        message = 'HttpClient API',
        endpoints = {
            ['GET /httpclient'] = 'HttpClient info and test',
            ['GET /httpclient/get'] = 'Test GET request',
            ['POST /httpclient/post'] = 'Test POST request',
            ['POST /httpclient/json'] = 'Test JSON request',
            ['POST /httpclient/api'] = 'Call external API (httpbin)',
        },
        documentation = {
            usage = 'Use HttpClient library in your controllers',
            example = 'local http = HttpClient:new()\nlocal res, err = http:get(url)',
        }
    }

    return self:json(response)
end

function HttpClientController:get()
    local url = self.request.get and self.request.get.url or 'https://httpbin.org/get'

    local http = HttpClient:new({timeout = 10000})
    local res, err = http:get(url)

    if not res then
        return self:json({
            success = false,
            error = err,
            url = url
        }, 500)
    end

    return self:json({
        success = res.success,
        method = 'GET',
        url = url,
        status = res.status,
        headers = res.headers,
        body = res.body
    })
end

function HttpClientController:post()
    local url = self.request.post and self.request.post.url or 'https://httpbin.org/post'
    local data = self.request.post and self.request.post.data

    local http = HttpClient:new({timeout = 10000})

    local res, err
    if data then
        res, err = http:post(url, {
            body = data,
            headers = {
                ['Content-Type'] = 'text/plain'
            }
        })
    else
        res, err = http:post(url, {
            body = 'Hello from MyResty HttpClient',
            headers = {
                ['Content-Type'] = 'text/plain'
            }
        })
    end

    if not res then
        return self:json({
            success = false,
            error = err,
            url = url
        }, 500)
    end

    return self:json({
        success = res.success,
        method = 'POST',
        url = url,
        status = res.status,
        body = res.body
    })
end

function HttpClientController:json()
    local url = self.request.post and self.request.post.url or 'https://httpbin.org/post'
    local data_str = self.request.post and self.request.post.data

    local data
    if data_str then
        local ok, decoded = pcall(function()
            local cjson = require('cjson')
            return cjson.decode(data_str)
        end)
        if ok and type(decoded) == 'table' then
            data = decoded
        else
            data = {message = data_str}
        end
    else
        data = {
            name = 'MyResty',
            version = '1.0.0',
            timestamp = os.time()
        }
    end

    local http = HttpClient:new({timeout = 10000})
    local res, err = http:json(url, data, 'POST')

    if not res then
        return self:json({
            success = false,
            error = err,
            url = url
        }, 500)
    end

    return self:json({
        success = res.success,
        method = 'JSON POST',
        url = url,
        sent_data = data,
        status = res.status,
        body = res.body
    })
end

function HttpClientController:api()
    local action = self.request.post and self.request.post.action or 'get'

    local base_url = 'https://httpbin.org'
    local http = HttpClient:new({timeout = 15000})

    local results = {}

    if action == 'get' or action == 'all' then
        local res, err = http:get(base_url .. '/get')
        results.get = {
            success = res and res.success or false,
            status = res and res.status or nil,
            error = err
        }
    end

    if action == 'post' or action == 'all' then
        local res, err = http:json(base_url .. '/post', {
            test = 'MyResty HttpClient',
            time = os.time()
        })
        results.post = {
            success = res and res.success or false,
            status = res and res.status or nil,
            error = err
        }
    end

    if action == 'headers' or action == 'all' then
        local res, err = http:get(base_url .. '/headers')
        results.headers = {
            success = res and res.success or false,
            status = res and res.status or nil,
            error = err
        }
    end

    if action == 'status' or action == 'all' then
        local res, err = http:get(base_url .. '/status/418')
        results.status = {
            success = res and res.success or false,
            status = res and res.status or nil,
            error = err
        }
    end

    return self:json({
        success = true,
        action = action,
        results = results,
        message = 'HttpClient test completed'
    })
end

function HttpClientController:benchmark()
    local count = tonumber(self.request.get and self.request.get.count) or 10
    local url = self.request.get and self.request.get.url or 'https://httpbin.org/get'

    local http = HttpClient:new({timeout = 5000})

    local start_time = ngx.now()
    local success_count = 0
    local fail_count = 0
    local errors = {}

    for i = 1, count do
        local res, err = http:get(url)
        if res and res.success then
            success_count = success_count + 1
        else
            fail_count = fail_count + 1
            table.insert(errors, err or 'Unknown error')
        end
    end

    local end_time = ngx.now()
    local total_time = end_time - start_time
    local avg_time = total_time / count * 1000

    return self:json({
        success = fail_count == 0,
        url = url,
        total_requests = count,
        success_count = success_count,
        fail_count = fail_count,
        total_time_ms = string.format('%.2f', total_time * 1000),
        avg_time_ms = string.format('%.2f', avg_time),
        requests_per_second = string.format('%.2f', count / total_time),
        errors = #errors > 0 and errors or nil
    })
end

return HttpClientController
