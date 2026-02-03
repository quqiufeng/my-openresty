local _M = {}

local ok, httpc = pcall(require, 'resty.http')
if not ok then
    httpc = nil
end

local function create_http_client()
    if httpc then
        local hc = httpc.new()
        return hc
    end
    return nil
end

local function encode_params(params)
    if not params or not next(params) then
        return ''
    end

    local parts = {}
    for k, v in pairs(params) do
        if type(v) == 'table' then
            for i, val in ipairs(v) do
                table.insert(parts, k .. '=' .. tostring(val))
            end
        else
            table.insert(parts, k .. '=' .. tostring(v))
        end
    end

    return table.concat(parts, '&')
end

_M._VERSION = '1.0.0'

function _M.new(options)
    options = options or {}

    local self = {
        base_url = options.base_url or 'http://localhost:8080',
        timeout = options.timeout or 10000,
        headers = options.headers or {},
        cookies = {},
        verbose = options.verbose or false,
        before_request = options.before_request or nil,
        after_request = options.after_request or nil
    }

    setmetatable(self, {__index = _M})

    return self
end

function _M.set_header(self, key, value)
    self.headers[key] = value
    return self
end

function _M.set_headers(self, headers)
    for k, v in pairs(headers) do
        self.headers[k] = v
    end
    return self
end

function _M.set_timeout(self, timeout)
    self.timeout = timeout
    return self
end

function _M.auth(self, username, password)
    self.headers['Authorization'] = 'Basic ' + ngx.encode_base64(username .. ':' .. password)
    return self
end

function _M.bearer(self, token)
    self.headers['Authorization'] = 'Bearer ' .. token
    return self
end

function _M.cookie(self, name, value)
    self.cookies[name] = value
    return self
end

function _M.before(self, fn)
    self.before_request = fn
    return self
end

function _M.after(self, fn)
    self.after_request = fn
    return self
end

local function build_url(self, path, params)
    local url = self.base_url .. path

    if params and next(params) then
        local query = encode_params(params)
        if query and query ~= '' then
            url = url .. '?' .. query
        end
    end

    return url
end

local function build_headers(self)
    local headers = {}
    for k, v in pairs(self.headers) do
        headers[k] = v
    end

    local cookie_str = {}
    for k, v in pairs(self.cookies) do
        table.insert(cookie_str, k .. '=' .. tostring(v))
    end
    if #cookie_str > 0 then
        headers['Cookie'] = table.concat(cookie_str, '; ')
    end

    return headers
end

function _M.get(self, path, params, options)
    local url = build_url(self, path, params)
    local headers = build_headers(self)

    if self.before_request then
        self.before_request({method = 'GET', url = url, headers = headers})
    end

    local res = {
        url = url,
        method = 'GET',
        status = nil,
        body = nil,
        headers = {},
        json = nil,
        success = false,
        error = nil,
        duration = 0
    }

    if httpc then
        local hc = create_http_client()
        hc:set_timeout(self.timeout)

        local start_time = ngx.now()
        local resp, err = hc:request_uri(url, {
            method = 'GET',
            headers = headers
        })
        res.duration = (ngx.now() - start_time) * 1000

        if resp then
            res.status = resp.status
            res.body = resp.body
            res.headers = resp.headers

            local cjson = require('cjson')
            if resp.body and resp.body ~= '' then
                local ok, data = pcall(cjson.decode, resp.body)
                if ok then
                    res.json = data
                end
            end

            res.success = res.status >= 200 and res.status < 300
        else
            res.error = err
        end
    else
        res.error = 'resty.http not available'
    end

    if self.after_request then
        self.after_request(res)
    end

    if self.verbose then
        ngx.log(ngx.INFO, '[TEST] GET ', url, ' -> ', res.status or 'error')
    end

    return res
end

function _M.post(self, path, data, options)
    local url = self.base_url .. path
    local headers = build_headers(self)
    headers['Content-Type'] = headers['Content-Type'] or 'application/x-www-form-urlencoded'

    if self.before_request then
        self.before_request({method = 'POST', url = url, headers = headers, body = data})
    end

    local res = {
        url = url,
        method = 'POST',
        status = nil,
        body = nil,
        headers = {},
        json = nil,
        success = false,
        error = nil,
        duration = 0
    }

    if httpc then
        local body = data
        if type(data) == 'table' then
            if headers['Content-Type'] == 'application/json' then
                local cjson = require('cjson')
                body = cjson.encode(data)
            else
                body = encode_params(data)
            end
        end

        local hc = create_http_client()
        hc:set_timeout(self.timeout)

        local start_time = ngx.now()
        local resp, err = hc:request_uri(url, {
            method = 'POST',
            body = body,
            headers = headers
        })
        res.duration = (ngx.now() - start_time) * 1000

        if resp then
            res.status = resp.status
            res.body = resp.body
            res.headers = resp.headers

            local cjson = require('cjson')
            if resp.body and resp.body ~= '' then
                local ok, data = pcall(cjson.decode, resp.body)
                if ok then
                    res.json = data
                end
            end

            res.success = res.status >= 200 and res.status < 300
        else
            res.error = err
        end
    else
        res.error = 'resty.http not available'
    end

    if self.after_request then
        self.after_request(res)
    end

    if self.verbose then
        ngx.log(ngx.INFO, '[TEST] POST ', url, ' -> ', res.status or 'error')
    end

    return res
end

function _M.put(self, path, data)
    local url = self.base_url .. path
    local headers = build_headers(self)
    headers['Content-Type'] = headers['Content-Type'] or 'application/x-www-form-urlencoded'

    local res = {
        url = url,
        method = 'PUT',
        status = nil,
        body = nil,
        headers = {},
        json = nil,
        success = false,
        error = nil,
        duration = 0
    }

    if httpc then
        local body = data
        if type(data) == 'table' then
            body = encode_params(data)
        end

        local hc = create_http_client()
        hc:set_timeout(self.timeout)

        local start_time = ngx.now()
        local resp, err = hc:request_uri(url, {
            method = 'PUT',
            body = body,
            headers = headers
        })
        res.duration = (ngx.now() - start_time) * 1000

        if resp then
            res.status = resp.status
            res.body = resp.body
            local cjson = require('cjson')
            if resp.body and resp.body ~= '' then
                local ok, data = pcall(cjson.decode, resp.body)
                if ok then
                    res.json = data
                end
            end
            res.success = res.status >= 200 and res.status < 300
        else
            res.error = err
        end
    else
        res.error = 'resty.http not available'
    end

    return res
end

function _M.delete(self, path)
    local url = self.base_url .. path
    local headers = build_headers(self)

    local res = {
        url = url,
        method = 'DELETE',
        status = nil,
        body = nil,
        json = nil,
        success = false,
        error = nil,
        duration = 0
    }

    if httpc then
        local hc = create_http_client()
        hc:set_timeout(self.timeout)

        local start_time = ngx.now()
        local resp, err = hc:request_uri(url, {
            method = 'DELETE',
            headers = headers
        })
        res.duration = (ngx.now() - start_time) * 1000

        if resp then
            res.status = resp.status
            res.success = res.status >= 200 and res.status < 300
        else
            res.error = err
        end
    else
        res.error = 'resty.http not available'
    end

    return res
end

function _M.assert(self, response, conditions)
    local failures = {}

    if conditions.status then
        if response.status ~= conditions.status then
            table.insert(failures, string.format('Expected status %d, got %d', conditions.status, response.status))
        end
    end

    if conditions.status_range then
        if not (response.status >= conditions.status_range[1] and response.status < conditions.status_range[2]) then
            table.insert(failures, string.format('Expected status in %d-%d, got %d', conditions.status_range[1], conditions.status_range[2], response.status))
        end
    end

    if conditions.json_has then
        if not response.json then
            table.insert(failures, 'Expected JSON response, got nil')
        else
            for k, v in pairs(conditions.json_has) do
                if response.json[k] == nil then
                    table.insert(failures, 'Expected json.' .. k .. ' to exist')
                elseif v ~= nil and response.json[k] ~= v then
                    table.insert(failures, string.format('Expected json.%s = %s, got %s', k, tostring(v), tostring(response.json[k])))
                end
            end
        end
    end

    if conditions.json_not_has then
        if response.json then
            for k, _ in pairs(conditions.json_not_has) do
                if response.json[k] ~= nil then
                    table.insert(failures, 'Expected json.' .. k .. ' to not exist')
                end
            end
        end
    end

    if conditions.body_contains then
        if not response.body or not string.find(response.body, conditions.body_contains, 1, true) then
            table.insert(failures, 'Expected body to contain: ' .. conditions.body_contains)
        end
    end

    if conditions.has_cookie then
        if not response.headers or not response.headers['Set-Cookie'] then
            table.insert(failures, 'Expected Set-Cookie header')
        elseif not string.find(response.headers['Set-Cookie'], conditions.has_cookie, 1, true) then
            table.insert(failures, 'Expected cookie containing: ' .. conditions.has_cookie)
        end
    end

    return #failures == 0, failures
end

function _M.describe(self, name, tests)
    return {
        name = name,
        tests = tests,
        run = function(self)
            local results = {
                name = self.name,
                passed = 0,
                failed = 0,
                total = #self.tests,
                duration = 0,
                cases = {}
            }

            local start_time = ngx.now()

            for _, test in ipairs(self.tests) do
                local case_result = {
                    name = test.name,
                    passed = true,
                    error = nil,
                    duration = 0
                }

                local case_start = ngx.now()

                local success, err = pcall(function()
                    test.fn(self)
                end)

                case_result.duration = (ngx.now() - case_start) * 1000

                if not success then
                    case_result.passed = false
                    case_result.error = err
                end

                if case_result.passed then
                    results.passed = results.passed + 1
                else
                    results.failed = results.failed + 1
                end

                table.insert(results.cases, case_result)
            end

            results.duration = (ngx.now() - start_time) * 1000

            return results
        end
    }
end

function _M.run_tests(self, suite)
    local results = suite:run()

    local output = {
        suite = results.name,
        total = results.total,
        passed = results.passed,
        failed = results.failed,
        duration = string.format('%.2f', results.duration) .. 'ms',
        timestamp = os.date('%Y-%m-%d %H:%M:%S')
    }

    if results.failed > 0 then
        output.failures = {}
        for _, case in ipairs(results.cases) do
            if not case.passed then
                table.insert(output.failures, {
                    name = case.name,
                    error = case.error,
                    duration = string.format('%.2f', case.duration) .. 'ms'
                })
            end
        end
    end

    return output
end

function _M.run_and_report(self, suite)
    local results = self:run_tests(suite)

    ngx.log(ngx.INFO, '========================================')
    ngx.log(ngx.INFO, 'Test Suite: ', results.suite)
    ngx.log(ngx.INFO, 'Total: ', results.total)
    ngx.log(ngx.INFO, 'Passed: ', results.passed)
    ngx.log(ngx.INFO, 'Failed: ', results.failed)
    ngx.log(ngx.INFO, 'Duration: ', results.duration)
    ngx.log(ngx.INFO, '========================================')

    if results.failures then
        for _, failure in ipairs(results.failures) do
            ngx.log(ngx.ERR, 'FAILED: ', failure.name)
            ngx.log(ngx.ERR, '  Error: ', failure.error)
        end
    end

    return results
end

return _M
